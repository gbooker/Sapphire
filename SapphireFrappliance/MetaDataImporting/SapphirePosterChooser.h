/*
 * SapphirePosterChooser.h
 * Sapphire
 *
 * Created by Patrick Merrill on Oct. 11, 2007.
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

#import <SapphireCompatClasses/SapphireMediaMenuController.h>
#import <SapphireCompatClasses/SapphireLayoutManager.h>
#import "SapphireChooser.h"

@class BRRenderScene, BRRenderLayer, BRMarchingIconLayer, SapphireFileMetaData;

/*!
 * @brief A subclass of SapphireCenteredMenuController to provide a means to select between posters
 *
 * This class provides a menu and maching icons to display posters for the user to choose.
 */
@interface SapphirePosterChooser : SapphireMediaMenuController <BRIconSourceProtocol, BRMenuListItemProvider, SapphireLayoutDelegate, SapphireChooser> {
	BOOL					displayed;		/*!< @brief YES if currently displayed, NO otherwise*/
	NSMutableArray			*posters;		/*!< @brief The array of poster urls, NSImages, NSData, or BlurredImages*/
	NSString				*fileName;		/*!< @brief The movie filename*/
	NSString				*movieTitle;	/*!< @brief The title of the movie*/
	SapphireChooserChoice	selection;		/*!< @brief The user's selection*/
	BRTextControl			*fileInfoText;	/*!< @brief The text control to display filename and movie title*/
	BRMarchingIconLayer		*posterMarch;	/*!< @brief The icon march to display the posters*/
	BRBlurryImageLayer		*defaultImage;	/*!< @brief The image to use when the poster isn't loaded yet*/
	NSImage					*defaultNSImage;/*!< @brief The NSImage to use when the poster isn't loaded yet*/
	BRBlurryImageLayer		*errorImage;	/*!< @brief The image to use when the poster fails to load*/
	NSImage					*errorNSImage;	/*!< @brief The NSImage to use when the poster fails to load*/
	SapphireFileMetaData	*meta;			/*!< @brief The file's meta*/
	NSInvocation			*refreshInvoke;	/*!< @brief Should the chooser allow a refresh of the available cover art*/
}

/*!
 * @brief Sets the invocation to refresh
 *
 * @param[in] invoke The invocation to refresh
 */
- (void)setRefreshInvocation: (NSInvocation *)invoke;

/*!
 * @brief check ATV version & poster chooser opt out
 *
 * @return The YES if we can display 
 */
- (BOOL)okayToDisplay;

/*!
 * @brief Sets the posters to choose from
 *
 * @param posterList The list of movies to choose from specified as urls
 */
- (void)setPosters:(NSArray *)posterList;

/*!
 * @brief Sets the posters to choose from
 *
 * @param posterList The cover art to choose from specified as image objects
 */
- (void)setPosterImages:(NSArray *)posterList;

/*!
 * @brief Sets the filename to display
 *
 * @param choosingForFileName The filename being choosen for
 */
- (void)setFileName:(NSString *)choosingForFileName;

/*!
 * @brief The filename we searched for
 *
 * @return The file name we searched for
 */
- (NSString *)fileName;

/*!
 * @brief Sets the file's metadata
 *
 * @param path The file's metadata
 */
- (void)setFile:(SapphireFileMetaData *)aMeta;

/*!
 * @brief Sets the string we searched for
 *
 * @param search The string we searched for
 */
- (void)setMovieTitle:(NSString *)theMovieTitle;

/*!
 * @brief The string we searched for
 *
 * @return The string we searched for
 */
- (NSString *)movieTitle;

@end