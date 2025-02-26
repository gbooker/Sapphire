/*
 * SapphireImportHelper.m
 * Sapphire
 *
 * Created by Graham Booker on Dec. 8, 2007.
 * Copyright 2007 Sapphire Development Team and/or www.nanopi.net
 * All rights reserved.
 *
 * This program is free software; you can redistribute it and/or modify it under the terms of the GNU
 * General Public License as published by the Free Software Foundation; either version 3 of the License,
 * or (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even
 * the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
 * Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License along with this program; if not,
 * write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */

#import <Security/Security.h>
#include <sys/stat.h>
#include <sys/mount.h>

#import "SapphireImportHelper.h"
#import "SapphireAllImporter.h"
#import "SapphireFileMetaData.h"
#import "SapphireMetaDataSupport.h"
#import "SapphireApplianceController.h"

#define CONNECTION_NAME @"Sapphire Server"

@interface SapphireImportFile : NSObject <SapphireImportFileProtocol>{
	NSString								*path;
	id <SapphireImporterBackgroundProtocol>	informer;
	FileContainerType						type;
}
- (id)initWithPath:(NSString *)aPath type:(FileContainerType)aType informer:(id <SapphireImporterBackgroundProtocol>)aInformer;
@end

@interface SapphireImportHelperServer ()
- (void)startClient;
@end

@implementation SapphireImportHelper

static SapphireImportHelper *shared = nil;

+ (SapphireImportHelper *)sharedHelperForContext:(NSManagedObjectContext *)moc
{
	if(shared == nil && moc != nil)
		shared = [[SapphireImportHelperServer alloc] initWithContext:moc];

	return shared;
}

+ (void)relinquishHelper
{
	if(shared != nil)
		[shared relinquishHelper];
}

- (void)relinquishHelper
{
}

- (BOOL)importFileData:(SapphireFileMetaData *)file inform:(id <SapphireImporterBackgroundProtocol>)inform;
{
	return YES;
}

- (void)importAllData:(SapphireFileMetaData *)file inform:(id <SapphireImporterBackgroundProtocol>)inform;
{
}

- (void)removeObjectsWithInform:(id <SapphireImporterBackgroundProtocol>)inform
{
}

@end

@implementation SapphireImportHelperClient

- (id)init
{
	self = [super init];
	if(!self)
		return nil;
	
	keepRunning = YES;
	
	return self;
}
- (void) dealloc
{
	[server release];
	[super dealloc];
}

- (void)startChild
{
	/*Child here*/
	@try {
		NSConnection *connection = [NSConnection connectionWithRegisteredName:CONNECTION_NAME host:nil];
		id serverobj = [[connection rootProxy] retain];
		[serverobj setProtocolForProxy:@protocol(SapphireImportServer)];
		shared = self;
		[serverobj setClient:(SapphireImportHelperClient *)shared];
		server = serverobj;
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(connectionDidDie:) name:NSConnectionDidDieNotification object:nil];
	}
	@catch (NSException * e) {
		[SapphireApplianceController logException:e];
		keepRunning = NO;
	}
}

- (BOOL)keepRunning
{
	return keepRunning;
}

- (void)connectionDidDie:(NSNotification *)note
{
	[self exitChild];
}

- (oneway void)exitChild
{
	keepRunning = NO;
}

- (void)realStartQueue
{
	@try {
		id <SapphireImportFileProtocol> file;
		while((file = [server nextFile]) != nil)
		{
			NSAutoreleasePool *singleImportPool = [[NSAutoreleasePool alloc] init];
			NSString *path = [file path];
			NSDictionary *fileMeta = fileMetaData(path, [file fileContainerType]);
			[server fileImportCompleteWithMeta:fileMeta path:path];
			[singleImportPool release];
		}
	}
	@catch (NSException * e) {
		[SapphireApplianceController logException:e];
		keepRunning = NO;
	}
}

- (oneway void)startQueue
{
	[self performSelectorOnMainThread:@selector(realStartQueue) withObject:nil waitUntilDone:NO];
}

@end

@implementation SapphireImportHelperServer

- (id)initWithContext:(NSManagedObjectContext *)context
{
	self = [super init];
	if (self == nil)
		return nil;
	
	queue = [[NSMutableArray alloc] init];
	queueSuspended = NO;
	allImporter = [[SapphireAllImporter alloc] init];
	[allImporter setDelegate:self];
	informers = [[NSMutableDictionary alloc] init];

	serverConnection = [NSConnection defaultConnection];
	[serverConnection setRootObject:self];
	if([serverConnection registerName:CONNECTION_NAME] == NO)
		SapphireLog(SapphireLogTypeGeneral, SapphireLogLevelError, @"Register failed");
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(connectionDidDie:) name:NSConnectionDidDieNotification object:nil];
	moc = [context retain];
	
	[self startClient];
	
	return self;
}

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[client release];
	[moc release];
	[queue release];
	[currentImporting release];
	[allImporter release];
	[informers release];
	[super dealloc];
}

- (void)relinquishHelper
{
	[client exitChild];
	[serverConnection registerName:nil];
	[serverConnection setRootObject:nil];
	[shared autorelease];
	shared = nil;
}

- (BOOL)isSlashReadOnly
{
	struct statfs *mntbufp;
	
    int i, mountCount = getmntinfo(&mntbufp, MNT_NOWAIT);
	for(i=0; i<mountCount; i++)
	{
		if(!strcmp(mntbufp[i].f_mntonname, "/"))
			return (mntbufp[i].f_flags & MNT_RDONLY) ? YES : NO;
	}
	
	return NO;
}

- (BOOL)fixClientPermissions:(NSString *)path
{
	/* Permissions are incorrect */
	AuthorizationItem authItems[2] = {
		{kAuthorizationEnvironmentUsername, strlen("frontrow"), "frontrow", 0},
		{kAuthorizationEnvironmentPassword, strlen("frontrow"), "frontrow", 0},
	};
	AuthorizationEnvironment environ = {2, authItems};
	AuthorizationItem rightSet[] = {{kAuthorizationRightExecute, 0, NULL, 0}};
	AuthorizationRights rights = {1, rightSet};
	AuthorizationRef auth;
	OSStatus result = AuthorizationCreate(&rights, &environ, kAuthorizationFlagPreAuthorize | kAuthorizationFlagExtendRights, &auth);
	if(result == errAuthorizationSuccess)
	{
		BOOL roslash = [self isSlashReadOnly];
		if(roslash)
		{
			char *command = "mount -uw /";
			char *arguments[] = {"-c", command, NULL};
			AuthorizationExecuteWithPrivileges(auth, "/bin/sh", kAuthorizationFlagDefaults, arguments, NULL);
		}
		char *command = "chmod +rx \"$HELP\"";
		setenv("HELP", [path fileSystemRepresentation], 1);
		char *arguments[] = {"-c", command, NULL};
		result = AuthorizationExecuteWithPrivileges(auth, "/bin/sh", kAuthorizationFlagDefaults, arguments, NULL);
		unsetenv("HELP");
		if(roslash)
		{
			char *command = "mount -ur /";
			char *arguments[] = {"-c", command, NULL};
			AuthorizationExecuteWithPrivileges(auth, "/bin/sh", kAuthorizationFlagDefaults, arguments, NULL);
		}
	}
	if(result != errAuthorizationSuccess)
		return NO;
	
	return YES;
}

- (void)startClient
{
	NSString *path = [[NSBundle bundleForClass:[SapphireImportHelper class]] pathForResource:@"ImportHelper" ofType:@""];
	NSDictionary *attrs = [[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:YES];
	if(([[attrs objectForKey:NSFilePosixPermissions] intValue] | S_IXOTH) || [self fixClientPermissions:path])
	{
		@try {
			[NSTask launchedTaskWithLaunchPath:path arguments:[NSArray array]];
		}
		@catch (NSException * e) {
			SapphireLog(SapphireLogTypeGeneral, SapphireLogLevelError, @"Could not launch helper because of exception %@ launching %@.  Make this file executable", e, path);
		}		
	}
	else
		SapphireLog(SapphireLogTypeGeneral, SapphireLogLevelError, @"Could not correct helper permissions on %@.  Make this file executable!", path);
}

- (void)connectionDidDie:(NSNotification *)note
{
	[client release];
	client = nil;
	/*Inform that import completed (since it crashed, no update done)*/
	[self importCompleteWithChanges:nil updated:NO];
	if(shared != nil)
		/* Don't start it again if we are shutting down*/
		[self startClient];
}

- (void)itemAdded
{
	if(!queueSuspended)
		return;
	queueSuspended = NO;
	[SapphireMetaDataSupport save:moc];
	[client startQueue];
}

- (BOOL)importFileData:(SapphireFileMetaData *)file inform:(id <SapphireImporterBackgroundProtocol>)inform;
{
	SapphireImportFile *item = [[SapphireImportFile alloc] initWithPath:[file path] type:[file fileContainerTypeValue] informer:inform];
	[queue addObject:item];
	[item release];
	[self itemAdded];
	return NO;
}

- (void)importAllData:(SapphireFileMetaData *)file inform:(id <SapphireImporterBackgroundProtocol>)inform;
{
	NSString *path = [file path];
	[informers setObject:inform forKey:path];
	ImportState result = [allImporter importMetaData:file path:[file path]];
	switch (result) {
		case ImportStateNotUpdated:
		case ImportStateUpdated:
			[inform informComplete:result == ImportStateUpdated onPath:path];
			[informers removeObjectForKey:path];
			break;
		default:
			break;
	}
}

- (void)removeObjectsWithInform:(id <SapphireImporterBackgroundProtocol>)inform
{
	if(inform == nil)
		return;
	
	int i, count=[queue count];
	for(i=0; i<count; i++)
	{
		id <SapphireImportFileProtocol> file = [queue objectAtIndex:i];
		if([file informer] == inform)
		{
			[queue removeObjectAtIndex:i];
			i--;
			count--;
		}
	}
	if([currentImporting informer] == inform)
	{
		[currentImporting release];
		currentImporting = nil;
	}
}

- (id <SapphireImportFileProtocol>)nextFile
{
	if(![queue count])
	{
		queueSuspended = YES;
		return nil;
	}
	[currentImporting release];
	currentImporting = [[queue objectAtIndex:0] retain];
	[queue removeObjectAtIndex:0];
	return currentImporting;
}

- (oneway void)setClient:(id <SapphireImportClient>)aClient
{
	if(shared == nil)
	{
		[aClient exitChild];
		return;
	}
	client = [aClient retain];
	if([queue count])
	{
		queueSuspended = NO;
		[client startQueue];
	}
	else
		queueSuspended = YES;
}

- (void)importCompleteWithChanges:(bycopy NSDictionary *)changes updated:(BOOL)updated
{
	if(changes != nil)
		[SapphireMetaDataSupport applyChanges:changes toContext:moc];
	if(currentImporting == nil)
		return;
	[[currentImporting informer] informComplete:updated onPath:[currentImporting path]];
	[currentImporting release];
	currentImporting = nil;
}

- (void)fileImportCompleteWithMeta:(bycopy NSDictionary *)fileMeta path:(NSString *)path
{
	SapphireFileMetaData *file = [SapphireFileMetaData fileWithPath:path inContext:moc];
	[file addFileData:fileMeta];
	if(![[currentImporting path] isEqualToString:path])
		return;
	
	[[currentImporting informer] informComplete:YES onPath:path];
	[currentImporting release];
	currentImporting = nil;
}

- (void)backgroundImporter:(id <SapphireImporter>)importer completedImportOnPath:(NSString *)path withState:(ImportState)state
{
	id <SapphireImporterBackgroundProtocol> informer = [informers objectForKey:path];
	if(informer == nil)
		return;
	
	[informer informComplete:state == ImportStateUpdated onPath:path];
	[informers removeObjectForKey:path];
}

- (BOOL)canDisplayChooser
{
	return NO;
}

- (id)chooserScene
{
	return nil;
}

- (void)displayChooser:(BRLayerController <SapphireChooser> *)chooser forImporter:(id <SapphireImporter>)importer withContext:(id)context
{
}

@end

@implementation SapphireImportFile
- (id)initWithPath:(NSString *)aPath type:(FileContainerType)aType informer:(id <SapphireImporterBackgroundProtocol>)aInformer
{
	self = [super init];
	if(!self)
		return nil;
	
	path = [aPath retain];
	type = aType;
	informer = [aInformer retain];
	
	return self;
}
- (void) dealloc
{
	[path release];
	[informer release];
	[super dealloc];
}

- (bycopy NSString *)path
{
	return path;
}
- (id <SapphireImporterBackgroundProtocol>)informer
{
	return informer;
}
- (FileContainerType)fileContainerType
{
	return type;
}

@end
