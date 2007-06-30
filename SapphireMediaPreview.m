//
//  SapphireMediaPreview.m
//  Sapphire
//
//  Created by Graham Booker on 6/26/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "SapphireMediaPreview.h"
#import "SapphireMetaData.h"
#import "SapphireMedia.h"

@interface BRMetadataLayer (protectedAccess)
- (NSArray *)gimmieMetadataObjs;
@end

@implementation BRMetadataLayer (protectedAccess)
- (NSArray *)gimmieMetadataObjs
{
	return _metadataObjs;
}
@end

@implementation SapphireMediaPreview

- (id) initWithScene: (BRRenderScene *) scene
{
	self = [super initWithScene:scene];
	if(!self)
		return nil;
	
	return self;
}

- (void)dealloc
{
	[meta release];
	[super dealloc];
}

- (void)setMetaData:(SapphireFileMetaData *)newMeta
{
	[meta release];
	meta = [newMeta retain];
	NSURL *url = [NSURL fileURLWithPath:[meta path]];
	SapphireMedia *asset  =[[SapphireMedia alloc] initWithMediaURL:url];
	[self setAsset:asset];
}

- (void)_loadCoverArt
{
	[super _loadCoverArt];
	
	if([_coverArtLayer texture] != nil)
		return;
	
	NSURL *url = [NSURL fileURLWithPath:[[[NSBundle bundleForClass:[self class]] bundlePath] stringByAppendingString:@"/Contents/Resources/ApplianceIcon.png"]];
	CGImageSourceRef sourceRef = CGImageSourceCreateWithURL((CFURLRef)url, NULL);
	CGImageRef imageRef = nil;
	if(sourceRef)
	{
		imageRef = CGImageSourceCreateImageAtIndex(sourceRef, 0, NULL);
		CFRelease(sourceRef);
	}
	if(imageRef)
	{
		[_coverArtLayer setImage:imageRef];
		CFRelease(imageRef);
	}	
}

- (void)_populateMetadata
{
	[super _populateMetadata];
	if([[_metadataLayer gimmieMetadataObjs] count])
		return;
	NSMutableDictionary *allMeta = [[meta getAllMetaData] mutableCopy];
	NSString *value = [allMeta objectForKey:META_TITLE_KEY];
	if(value != nil)
	{
		[_metadataLayer setTitle:value];
		[allMeta removeObjectForKey:META_TITLE_KEY];
	}
	value = [allMeta objectForKey:META_RATING_KEY];
	if(value != nil)
	{
		[_metadataLayer setRating:value];
		[allMeta removeObjectForKey:META_RATING_KEY];
	}
	value = [allMeta objectForKey:META_SUMMARY_KEY];
	if(value != nil)
	{
		[_metadataLayer setSummary:value];
		[allMeta removeObjectForKey:META_SUMMARY_KEY];
	}
	value = [allMeta objectForKey:META_COPYRIGHT_KEY];
	if(value != nil)
	{
		[_metadataLayer setCopyright:value];
		[allMeta removeObjectForKey:META_COPYRIGHT_KEY];
	}
	[_metadataLayer setMetadata:[allMeta allValues] withLabels:[allMeta allKeys]];
}

- (BOOL)_assetHasMetadata
{
	return YES;
}


@end
