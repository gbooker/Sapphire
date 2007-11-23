//
//  SapphireTheme.h
//  Sapphire
//
//  Created by Graham Booker on 6/27/07.
//  Copyright 2007 www.nanopi.net. All rights reserved.
//

#define RED_GEM_KEY @"RedGem"
#define BLUE_GEM_KEY @"BlueGem"
#define GREEN_GEM_KEY @"greenGem"
#define YELLOW_GEM_KEY @"YellowGem"
#define GEAR_GEM_KEY @"GearGem"
#define CONE_GEM_KEY @"ConeGem"
#define EYE_GEM_KEY @"EyeGem"
#define IMDB_GEM_KEY @"IMDBGem"
#define TVR_GEM_KEY @"TVRageGem"
#define AUDIO_GEM_KEY @"AudioGem"
#define FILE_GEM_KEY @"FileGem"
#define REPORT_GEM_KEY @"ReportGem"
#define NOTE_GEM_KEY @"NoteGem"
#define TV_GEM_KEY @"TVGem"
#define MOV_GEM_KEY @"MovieGem"
@class BRTexture, BRRenderScene;

@interface SapphireTheme : NSObject {
	NSMutableDictionary		*gemDict;
	BRRenderScene			*scene;
	NSDictionary			*gemFiles;
}
+ (id)sharedTheme;

- (void)setScene:(BRRenderScene *)scene;
- (BRTexture *)gem:(NSString *)type;
@end
