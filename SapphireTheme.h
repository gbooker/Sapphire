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
#define OSCAR_GEM_KEY @"OscarGem"
#define TVR_GEM_KEY @"TVRageGem"
#define AC3_GEM_KEY @"AC3Gem"
#define AUDIO_GEM_KEY @"AudioGem"
#define VIDEO_GEM_KEY @"VideoGem"
#define FILE_GEM_KEY @"FileGem"
#define REPORT_GEM_KEY @"ReportGem"
#define IMPORT_GEM_KEY @"ImportGem"
#define FRONTROW_GEM_KEY @"FrontRowGem"
#define FAST_GEM_KEY @"FastGem"
#define NOTE_GEM_KEY @"NoteGem"
#define TV_GEM_KEY @"TVGem"
#define MOV_GEM_KEY @"MovieGem"
@class BRTexture, BRRenderScene;

/*!
 * @brief The Theme
 *
 * This class contains all the theme related materials for Sapphire.  It will dynamically create them upon demand and after the first request, return the same object to save CPU and memory.
 */
@interface SapphireTheme : NSObject {
	NSMutableDictionary		*gemDict;		/*!< @brief The left icons*/
	BRRenderScene			*scene;			/*!< @brief The render scene*/
	NSDictionary			*gemFiles;		/*!< @brief The left icon paths*/
}

/*!
 * @brief Get the shared theme
 *
 * @return The shared theme
 */
+ (id)sharedTheme;


/*!
 * @brief Sets the scene
 *
 * @param theScene The new scene
 */
- (void)setScene:(BRRenderScene *)scene;

/*!
 * @brief Load a gem for a type
 *
 * @param type The gem type
 * @return The gem's texture
 */
- (BRTexture *)gem:(NSString *)type;
@end
