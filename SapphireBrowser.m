//
//  SapphireBrowser.m
//  Sapphire
//
//  Created by pnmerrill on 6/20/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "SapphireBrowser.h"
#import <BackRow/BackRow.h>
#import "SapphireMetaData.h"
#import "SapphireMarkMenu.h"
#import "SapphireMedia.h"
#import "SapphireVideoPlayer.h"
#import "SapphireMediaPreview.h"

@interface SapphireBrowser (private)
- (void)reloadDirectoryContents;
- (void)processFiles:(NSArray *)files;
- (void)filesProcessed:(NSDictionary *)files;
- (NSMutableDictionary *)metaDataForPath:(NSString *)path;
@end

@interface BRTVShowsSortControl (bypassAccess)
- (BRTVShowsSortSelectorStateLayer *)gimmieDate;
- (BRTVShowsSortSelectorStateLayer *)gimmieShow;
- (int)gimmieState;
@end

@interface BRTVShowsSortSelectorStateLayer (bypassAccess)
- (BRTextLayer *)gimmieDate;
- (BRTextLayer *)gimmieShow;
@end


@implementation BRTVShowsSortControl (bypassAccess)
- (BRTVShowsSortSelectorStateLayer *)gimmieDate
{
	return _sortedByDateWidget;
}

- (BRTVShowsSortSelectorStateLayer *)gimmieShow
{
	return _sortedByShowWidget;
}

- (int)gimmieState
{
	return _state;
}

@end

@implementation BRTVShowsSortSelectorStateLayer (bypassAccess)
- (BRTextLayer *)gimmieDate
{
	return _dateLayer;
}

- (BRTextLayer *)gimmieShow
{
	return _showLayer;
}

@end

@implementation SapphireBrowser

- (void)replaceControlText:(BRTextLayer *)control withString:(NSString *)str
{
	NSMutableAttributedString  *dateString = [[control attributedString] mutableCopy];
	[dateString replaceCharactersInRange:NSMakeRange(0, [dateString length]) withString:str];
	[control setAttributedString:dateString];
	[dateString release];
}

- (id) initWithScene: (BRRenderScene *) scene metaData: (SapphireDirectoryMetaData *)meta
{
	return [self initWithScene:scene metaData:meta predicate:NULL];
}

- (id) initWithScene: (BRRenderScene *) scene metaData: (SapphireDirectoryMetaData *)meta predicate:(SapphirePredicate *)newPredicate;
{
	if ( [super initWithScene: scene] == nil ) return ( nil );
		
	_names = [NSMutableArray new];
	metaData = [meta retain];
	[metaData setDelegate:self];
	predicate = [newPredicate retain];
	sort = [[BRTVShowsSortControl alloc] initWithScene:scene state:1];

	NSRect frame = [self masterLayerFrame];
	NSRect listFrame = [self listFrameForBounds:frame.size];
	NSRect sortRect;
	sortRect.size = [sort preferredSizeForScreenHeight:frame.size.height];
	sortRect.origin.y = listFrame.origin.y * 1.5f;
	sortRect.origin.x = (listFrame.size.width - sortRect.size.width)/2 + listFrame.origin.x;
	listFrame.size.height -= listFrame.origin.y;
	listFrame.origin.y *= 4.0f;
	[self replaceControlText:[[sort gimmieDate] gimmieDate] withString:@"Select"];
	[self replaceControlText:[[sort gimmieDate] gimmieShow] withString:@"Mark"];
	[self replaceControlText:[[sort gimmieShow] gimmieDate] withString:@"Select"];
	[self replaceControlText:[[sort gimmieShow] gimmieShow] withString:@"Mark"];
	[sort setFrame:sortRect];
	[[_listControl layer] setFrame:listFrame];
	[self addControl:sort];
	
	// set the datasource *after* you've setup your array
	[[self list] setDatasource: self] ;
		
	return ( self );
}

- (void)_doLayout
{
	[super _doLayout];
	NSRect listFrame = [[_listControl layer] frame];
	listFrame.size.height -= listFrame.origin.y;
	listFrame.origin.y *= 2;
	[[_listControl layer] setFrame:listFrame];
}

- (void)reloadDirectoryContents
{
	int divider = 0;
	[metaData reloadDirectoryContents];
	[_names removeAllObjects];
	if(predicate == NULL)
	{
		[_names addObjectsFromArray:[metaData directories]];
		divider = [_names count];
		[_names addObjectsFromArray:[metaData files]];
	}
	else
	{
		[_names addObjectsFromArray:[metaData predicatedDirectories:predicate]];
		divider = [_names count];
		[_names addObjectsFromArray:[metaData predicatedFiles:predicate]];
	}

	BRListControl *list = [self list];
	[list reload];
	if(divider && divider != [_names count])
		[list addDividerAtIndex:divider];
	[[self scene] renderScene];
}

- (void) dealloc
{
    // always remember to deallocate your resources
	[_names release];
	[metaData release];
	[predicate release];
	[sort release];
    [super dealloc];
}

- (void) willBePushed
{
    // We're about to be placed on screen, but we're not yet there
    
    // always call super
    [super willBePushed];
	[self reloadDirectoryContents];
}

- (void) wasPushed
{
    // We've just been put on screen, the user can see this controller's content now
    
    // always call super
    [super wasPushed];
	[metaData resumeImport];
}

- (void) willBePopped
{
    // The user pressed Menu, but we've not been removed from the screen yet
    
    // always call super
    [super willBePopped];
	[metaData cancelImport];
	[metaData setDelegate:nil];
}

- (void) wasPopped
{
    // The user pressed Menu, removing us from the screen
    
    // always call super
    [super wasPopped];
}

- (void) willBeBuried
{
    // The user just chose an option, and we will be taken off the screen
    
    // always call super
	[metaData cancelImport];
    [super willBeBuried];
}

- (void) wasBuriedByPushingController: (BRLayerController *) controller
{
    // The user chose an option and this controller os no longer on screen
    
    // always call super
    [super wasBuriedByPushingController: controller];
}

- (void) willBeExhumed
{
    // the user pressed Menu, but we've not been revealed yet
    
	id controller = [[self stack] peekController];
	if([controller isKindOfClass:[BRVideoPlayerController class]])
	{
		BRVideoPlayer *player = [(BRVideoPlayerController *)controller player];
		float elapsed = [player elapsedPlaybackTime];
		float duration = [player trackDuration];
		if(elapsed / duration > 0.9f)
		{
			[currentPlayFile setWatched:YES];
			[[self list] reload];
			[[self scene] renderScene];
		}
		if(elapsed < duration - 2)
			[currentPlayFile setResumeTime:[player elapsedPlaybackTime]];
		else
			[currentPlayFile setResumeTime:0];
		[currentPlayFile writeMetaData];
	}
	[currentPlayFile release];
	currentPlayFile = nil;
	[self reloadDirectoryContents];
    // always call super
    [super willBeExhumed];
}

- (void) wasExhumedByPoppingController: (BRLayerController *) controller
{
    // handle being revealed when the user presses Menu
    
    // always call super
    [super wasExhumedByPoppingController: controller];
	if([_names count] == 0)
		[[self stack] popController];
	else
		[metaData resumeImport];
}

- (long) itemCount
{
    // return the number of items in your menu list here
	if([_names count])
		return ( [ _names count]);
	// Put up an empty item
	return 1;
}

- (id<BRMenuItemLayer>) itemForRow: (long) row
{
/*
    // build a BRTextMenuItemLayer or a BRAdornedMenuItemLayer, etc. here
    // return that object, it will be used to display the list item.
    return ( nil );
*/
	if( [_names count] == 0)
	{
		BRAdornedMenuItemLayer *result = [BRAdornedMenuItemLayer adornedMenuItemWithScene:[self scene]];
		[[result textItem] setTitle:@"< EMPTY >"];
		return result;
	}
	if( row >= [_names count] ) return ( nil ) ;
	
	BRAdornedMenuItemLayer * result = nil ;
	NSString *name = [_names objectAtIndex:row];
	BOOL watched = NO;
	if([[metaData directories] containsObject:name])
	{
		result = [BRAdornedMenuItemLayer adornedFolderMenuItemWithScene: [self scene]] ;
		SapphireDirectoryMetaData *meta = [metaData metaDataForDirectory:name];
		watched = [meta watched];
	}
	else
	{
		result = [BRAdornedMenuItemLayer adornedMenuItemWithScene: [self scene]] ;
		SapphireFileMetaData *meta = [metaData metaDataForFile:name];
		if(meta != nil)
		{
			[[result textItem] setRightJustifiedText:[meta sizeString]];
			watched = [meta watched];
		}
	}
	if(!watched)
		[result setLeftIcon:[[BRThemeInfo sharedTheme] unplayedPodcastImageForScene:[self scene]]]; 
			
	// add text

	[[result textItem] setTitle: name] ;
				
	return ( result ) ;
}

- (NSString *) titleForRow: (long) row
{

	if ( row >= [ _names count] ) return ( nil );
	
	NSString *result = [ _names objectAtIndex: row] ;
	return ( result ) ;
}

- (long) rowForTitle: (NSString *) title
{
    long result = -1;
    long i, count = [self itemCount];
    for ( i = 0; i < count; i++ )
    {
        if ( [title isEqualToString: [self titleForRow: i]] )
        {
            result = i;
            break;
        }
    }
    
    return ( result );
}

- (void) itemSelected: (long) row
{
    // This is called when the user presses play/pause on a list item
	
	if([_names count] == 0)
	{
		[[self stack] popController];
		return;
	}
	
	NSString *name = [_names objectAtIndex:row];
	NSString *dir = [metaData path];
	
	if([sort gimmieState] == 2)
	{
		id meta = nil;
		if([[metaData directories] containsObject:name])
			meta = [metaData metaDataForDirectory:name];
		else
			meta = [metaData metaDataForFile:name];
		id controller = [[SapphireMarkMenu alloc] initWithScene:[self scene] metaData:meta];
		[[self stack] pushController:controller];
		[controller release];
		return;
	}
	
	if([[metaData directories] containsObject:name])
	{
		id controller = [[SapphireBrowser alloc] initWithScene:[self scene] metaData:[metaData metaDataForDirectory:name] predicate:predicate];
		[controller setListTitle:name];
		[controller setListIcon:[self listIcon]];
		[[self stack] pushController:controller];
		[controller release];
	}
	else
	{
		BRVideoPlayerController *controller = [[BRVideoPlayerController alloc] initWithScene:[self scene]];
		
		currentPlayFile = [[metaData metaDataForFile:name] retain];
		[controller setAllowsResume:YES];
		
		NSString *path = [dir stringByAppendingPathComponent:name];
		NSURL *url = [NSURL fileURLWithPath:path];
		SapphireMedia *asset  =[[SapphireMedia alloc] initWithMediaURL:url];
		[asset setResumeTime:[currentPlayFile resumeTime]];

		SapphireVideoPlayer *player = [[SapphireVideoPlayer alloc] init];
		[player setMetaData:currentPlayFile];
		NSError *error = nil;
		[player setMedia:asset error:&error];
		
		[controller setVideoPlayer:player];
		[[self stack] pushController:controller];

		[asset release];
		[player release];
		[controller release];
	}
}

- (id<BRMediaPreviewController>) previewControllerForItem: (long) item
{
    // If subclassing BRMediaMenuController, this function is called when the selection cursor
    // passes over an item.
	if(item >= [_names count])
		return nil;
	NSString *name = [_names objectAtIndex:item];
	if([[metaData files] containsObject:name])
	{
		SapphireFileMetaData *fileMeta = [metaData metaDataForFile:name];
		
		SapphireMediaPreview *preview = [[SapphireMediaPreview alloc] initWithScene:[self scene]];
		
		NSURL *url = [NSURL fileURLWithPath:@"/System/Library/PrivateFrameworks/BackRow.framework/Resources/Movies.png"];
		CGImageSourceRef sourceRef = CGImageSourceCreateWithURL((CFURLRef)url, NULL);
		CGImageRef imageRef = nil;
		if(sourceRef)
		{
			imageRef = CGImageSourceCreateImageAtIndex(sourceRef, 0, NULL);
			CFRelease(sourceRef);
		}
		if(imageRef)
		{
			[preview setImage:imageRef];
			CFRelease(imageRef);
		}
		
		NSMutableDictionary *attrs = [[[BRThemeInfo sharedTheme] metadataSummaryFieldAttributes] mutableCopy];
		NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
		float tabLoc = [[self masterLayer] frame].size.width * 0.4f;
		NSTextTab *myTab = [[NSTextTab alloc] initWithType:NSRightTabStopType location:tabLoc];
		NSArray *tabs = [NSArray arrayWithObject:myTab];
		[myTab release];
		[style setTabStops:tabs];
		[attrs removeObjectForKey:@"CTTextAlignment"];
		[attrs setObject:style forKey:NSParagraphStyleAttributeName];
		[preview setText:[[[NSAttributedString alloc] initWithString:[fileMeta metaDataDescription] attributes:attrs] autorelease]];
		[attrs release];
		
		return [preview autorelease];
	}
    return ( nil );
}

- (void)updateComplete
{
	BRListControl *list = [self list];
	[list reload];
	[[self scene] renderScene];
}

@end
