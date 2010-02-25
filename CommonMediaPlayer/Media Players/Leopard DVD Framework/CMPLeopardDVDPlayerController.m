/*
 * CMPLeopardDVDPlayerController.m
 * CommonMediaPlayer
 *
 * Created by Graham Booker on Feb. 6 2010
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

#import "CMPLeopardDVDPlayerController.h"
#import "CMPLeopardDVDPlayer.h"

@interface BRDVDLoadingController (compat)
- (id)initWithAsset:(BRDVDMediaAsset *)asset;
@end

@implementation CMPLeopardDVDPlayerController

+ (NSSet *)knownPlayers
{
	return [NSSet setWithObject:[CMPLeopardDVDPlayer class]];
}

- (id)initWithScene:(BRRenderScene *)scene player:(id <CMPPlayer>)player
{
	NSURL *URLPath = [NSURL URLWithString:[[player asset] mediaURL]];
	NSString *path = [URLPath path];
	BRDVDMediaAsset *asset = [[BRDVDMediaAsset alloc] initWithPath:path];

	if([[BRDVDLoadingController class] instancesRespondToSelector:@selector(initWithScene:forAsset:)])
		return [super initWithScene:scene forAsset:[asset autorelease]];
	
	return [super initWithAsset:[asset autorelease]];
}

//None of this is supported
- (id <CMPPlayer>)player
{
	return nil;
}

- (void)setPlaybackSettings:(NSDictionary *)settings
{
}

- (void)setPlaybackDelegate:(id <CMPPlayerControllerDelegate>)delegate
{
}

- (id <CMPPlayerControllerDelegate>)delegate
{
	return nil;
}

@end
