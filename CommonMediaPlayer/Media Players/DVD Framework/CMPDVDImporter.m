/*
 * CMPDVDImporter.m
 * CommonMediaPlayer
 *
 * Created by nito on Feb. 15 2010
 * Copyright 2010 Common Media Player
 * All rights reserved.
 *
 * This program is free software; you can redistribute it and/or modify it under the terms of the GNU
 * Lesser General Public License as published by the Free Software Foundation; either version 3 of the
 * License, or (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even
 * the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser
 * General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License along with this program; if
 * not, write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 
 * 02111-1307, USA.
 */

#import "CMPDVDImporter.h"

@interface NSObject (GrowlApplicationBridgeRoutines)
+ (void)setGrowlDelegate:(id)delegate;
+ (void) notifyWithTitle:(NSString *)title description:(NSString *)description notificationName:(NSString *)notifName iconData:(NSData *)iconData priority:(signed int)priority isSticky:(BOOL)isSticky clickContext:(id)clickContext;
@end


@implementation CMPDVDImporter


- (void) importDVD:(NSArray *)inputArray
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	Class cls = NSClassFromString( @"GrowlApplicationBridge" );
	if (cls != nil){
		[cls setGrowlDelegate:self];
	}
	
	NSString *theDVD = [inputArray objectAtIndex:0];
	NSString *dvdPath = [inputArray objectAtIndex:1];
	NSString *defaultOutput = [NSHomeDirectory() stringByAppendingPathComponent:@"Movies/DVD"];
	int ripErrorMode = 2;
	
	NSFileManager *man = [NSFileManager defaultManager];
	NSDictionary *attrs = [man fileAttributesAtPath:dvdPath traverseLink:YES];
	NSNumber *dvdSize = [attrs objectForKey:NSFileSize];
	
	
	if ([man fileExistsAtPath:defaultOutput]){
		if ([man isWritableFileAtPath:defaultOutput]){
			NSDictionary *outputAttrs = [man fileAttributesAtPath:defaultOutput traverseLink:YES];
			NSNumber *freeSpace = [outputAttrs objectForKey:NSFileSystemFreeSize];
			if ([freeSpace isLessThan:dvdSize])
			{
				NSLog(@"CMPError: not enough space free at path: %@", defaultOutput);
				[pool release];
				[NSThread exit];
				return;
			}
			
		} else { // not writable
			
			NSLog(@"CMPError: not writable at path: %@", defaultOutput);
			[pool release];
			[NSThread exit];
			return;
		}
	}
	
	NSString *dvdbPath = [[NSBundle bundleForClass:[CMPDVDImporter class]] pathForResource:@"dvdbackup" ofType:@"" inDirectory:@"bin"];
	NSTask *backupTask = [[NSTask alloc] init];
	NSMutableArray *bArgs = [[NSMutableArray alloc] init];
	[bArgs addObject:@"-i"]; //--input=DEVICE 
	[bArgs addObject:theDVD]; //rdisk input
	[bArgs addObject:@"-M"]; //  -M, --mirror       backup the whole DVD
	[bArgs addObject:@"-o"];
	[bArgs addObject:defaultOutput]; //defaults to ~/Movies/DVD
	[bArgs addObject:@"-n"]; //-n, --name=NAME   
	[bArgs addObject:[dvdPath lastPathComponent]]; //actual name of the DVD
	[bArgs addObject:@"-r"];
	
	switch (ripErrorMode) {
			
		case 0:
			[bArgs addObject:@"a"]; //a=abort: default
			break;
			
		case 1:
			[bArgs addObject:@"b"]; //b=skip block
			break;
			
		case 2:
			[bArgs addObject:@"m"]; //m=skip multiple blocks
			break;
			
		default:
			[bArgs addObject:@"m"]; //m=skip multiple blocks default
			break;
	}
	
	[backupTask setLaunchPath:dvdbPath];
	[backupTask setArguments:bArgs];
	//NSLog(@"dvdbackup: %@", [bArgs componentsJoinedByString:@" "]);
	[bArgs release];
	
	[backupTask launch];
	[backupTask waitUntilExit];
	
	int termStatus = [backupTask terminationStatus];
	NSLog(@"dvdbackup terminated with status: %i", termStatus);
	
	if (termStatus != 0)
	{
		NSString *finalPath = [defaultOutput stringByAppendingPathComponent:[dvdPath lastPathComponent]];
		NSLog(@"should remove: %@", finalPath);
		//[man removeFileAtPath:finalPath handler:nil];
		
	}
	
	[backupTask release];
	backupTask = nil;
	[self performSelectorOnMainThread: @selector(_postFinishedImportingNotification)
						   withObject: nil
						waitUntilDone: NO];
	[pool release];
	
}

- (BOOL)canPlay:(NSString *)path withError:(NSError **)error
{
	if([super canPlay:path withError:error])
		return ![CMPDVDPlayer isImage:path]; //return the opposite of isImage, kind of confusing
	return NO;
}

- (AGProcess *) dvdImporting
{
	
	NSArray *theProcesses = [AGProcess processesForCommand:@"dvdbackup"];
	if ([theProcesses count] > 0)
		return [theProcesses objectAtIndex:0];

	return nil;
}

- (void)initiatePlaybackWithResume:(BOOL *)resume
{
	
	NSURL *url = [NSURL URLWithString:[asset mediaURL]];
	NSString *path = [url path];
	NSString *volumePath = [@"/mnt/Scratch/Volumes" stringByAppendingPathComponent:[path lastPathComponent]];
	volumePath = [CMPDVDImporter rdiskForPath:volumePath];
	NSArray *dvdArray = [NSArray arrayWithObjects:volumePath, path, nil];
	//NSLog(@"volumePath: %@", volumePath);
	AGProcess *currentTask = [self dvdImporting];
	if (currentTask != nil)
	{
		[currentTask terminate];
		//if a dvd is already importing, we kill it
	}
	[NSThread detachNewThreadSelector: @selector(importDVD:)
							 toTarget: self
						   withObject: dvdArray];
}

+ (NSString *)rdiskForPath:(NSString *)path
{
    NSString *rdisk = path;
    NSString *theName = [path lastPathComponent];
    
	NSTask *mnt = [[NSTask alloc] init];
	NSPipe *pip = [[NSPipe alloc] init];
	NSFileHandle *handle = [pip fileHandleForReading];
	NSData *outData;
	[mnt setLaunchPath:@"/sbin/mount"];
	[mnt setStandardError:pip];
	[mnt setStandardOutput:pip];
	[mnt launch];
	
	NSMutableArray *lineArray = [[NSMutableArray alloc] init];
	while((outData = [handle readDataToEndOfFile]) && [outData length])
	{
		NSString *temp = [[NSString alloc] initWithData:outData encoding:NSASCIIStringEncoding];
		[lineArray addObjectsFromArray:[temp componentsSeparatedByString:@"\n"]];
		[temp release];
	}
	
	
	int i;
	for(i = 0 ; i < [lineArray count] ; i++)
	{
		NSArray *arr = [[lineArray objectAtIndex:i] componentsSeparatedByString:[NSString stringWithFormat:@" on /mnt/Scratch/Volumes/%@",theName]];
		NSArray *arr1 = [[lineArray objectAtIndex:i] componentsSeparatedByString:[NSString stringWithFormat:@" on /Volumes/%@",theName]];
		if([arr count] > 1)
		{
			rdisk = [arr objectAtIndex:0];
			NSArray *arc = [rdisk pathComponents];
			rdisk = [NSString stringWithFormat:@"/dev/r%@", [arc lastObject]];
			[mnt release];
			mnt = nil;
			[pip release];
			pip = nil;
			break;
		}
		else if([arr1 count] > 1)
		{
			rdisk = [arr1 objectAtIndex:0];
			NSArray *arc = [rdisk pathComponents];
			rdisk = [NSString stringWithFormat:@"/dev/r%@", [arc lastObject]];
			[mnt release];
			mnt = nil;
			[pip release];
			pip = nil;
			break;
		}
	}
	[lineArray release];
    [mnt release];
	mnt = nil;
	[pip release];
	pip = nil;
    return rdisk;
}

NSString * const kCMPDVDFinishedImport = @"kCMPDVDFinishedImport";
- (void) _postFinishedImportingNotification
{
	//NSLog(@"%@ %s", self, _cmd);
    [[NSNotificationCenter defaultCenter] postNotificationName: kCMPDVDFinishedImport
                                                        object: self];
	
	Class cls = NSClassFromString( @"GrowlApplicationBridge" );
	if (cls != nil){
		[cls notifyWithTitle:@"DVD Import Completed" description:@"Your disc is finished importing." notificationName:@"CMPDVDFinishedImport" iconData:nil priority:1 isSticky:NO clickContext:nil];
	}
	
	
}
@end
