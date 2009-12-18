/*
 * SapphireMovieImporter.m
 * Sapphire
 *
 * Created by Patrick Merrill on Sep. 10, 2007.
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

#import "SapphireMovieImporter.h"
#import "SapphireFileMetaData.h"
#import "NSString-Extensions.h"
#import "NSFileManager-Extensions.h"
#import "SapphireMovieChooser.h"
#import "SapphirePosterChooser.h"
#import <SapphireCompatClasses/SapphireFrontRowCompat.h>
#import "SapphireShowChooser.h"
#import "SapphireSettings.h"
#import "SapphireMetaDataSupport.h"
#import "NSArray-Extensions.h"
#import "SapphireMovie.h"
#import "SapphireMovieTranslation.h"
#import "SapphireMoviePoster.h"
#import "SapphireApplianceController.h"
#import "SapphireURLLoader.h"

#define MOVIE_TRAN_IMDB_NAME_KEY				@"name"
#define MOVIE_TRAN_IMDB_LINK_KEY				@"IMDB Link"

 /* IMDB XPATHS */
#define	IMDB_SEARCH_XPATH				@"//td[starts-with(a/@href,'/title')]"
#define IMDB_UNIQUE_SEARCH_XPATH		@"//a/@href[contains(.,'http://pro.imdb.com/title')]"
#define IMDB_RESULT_LINK_XPATH			@"a/@href"
#define IMDB_POSTER_LINK_XPATH			@"//ul/li/a/@href"
#define	IMDB_RESULT_NAME_XPATH			@"normalize-space(string())"
#define IMDB_RESULT_TITLE_YEAR_XPATH	@"//div[@id='tn15title']/h1/string()"
#define IMDB_RESULT_INFO_XPATH	@"//div[@class='info']"
#define IMDB_RESTULT_CAST_NAMES_XPATH	@"//table[@class='cast']/tr/td/a"
/* IMP XPATHS */
#define IMP_POSTER_CANDIDATES_XPATH		@"//img/@src"
#define IMP_LINK_REDIRECT_XPATH				@"//head/meta/@content/string()"

@implementation SapphireMovieImporter

- (void)setDelegate:(id <SapphireImporterDelegate>)aDelegate
{
	delegate = aDelegate;
}

- (void)cancelImports
{
	//No background imports so nothing to do
}

/*!
* @brief Gets IMPAwards.com Poster page link
 *
 * @param candidateIMDBLink The functions IMDB Posters Path
 */
- (NSString *)getPosterPath:(NSString *)candidateIMDBLink
{
	NSError *error = nil ;
	NSURL * url=[NSURL URLWithString:[NSString stringWithFormat:@"http://www.imdb.com%@/posters",candidateIMDBLink]] ;
	NSXMLDocument *document = [[[NSXMLDocument alloc] initWithContentsOfURL:url options:NSXMLDocumentTidyHTML error:&error] autorelease];
	NSXMLElement *root = [document rootElement];

	/*Get the results list*/
	NSArray *results = [root objectsForXQuery:IMDB_POSTER_LINK_XPATH error:&error];
	if([results count])
	{
		/*Get each result*/
		NSEnumerator *resultEnum = [results objectEnumerator];
		NSXMLElement *result = nil;
		while((result = [resultEnum nextObject]) != nil)
		{
			/*Add the result to the list*/			
			NSString *resultURL =[[result stringValue] lowercaseString];
			if(resultURL == nil)
				continue;
			else if([resultURL hasPrefix:@"http://www.impawards.com"])/* See if the link is to IMP */
			{
				NSString * foundPosterLink =[resultURL stringByReplacingAllOccurancesOf:@"http://www.impawards.com" withString:@""];
				return foundPosterLink;
			}
		}		
	}
	return nil;
}

/*!
* @brief Compile IMPAwards.com Poster link list
 *
 * @param posterPageLink The Movie's IMP Poster link extention
 * @return An array of canidate poster images
 */
- (NSSet *)getPosterLinks:(NSString *)posterPageLink inContext:(NSManagedObjectContext *)moc
{
	NSError *error = nil ;
	NSURL * url=[NSURL URLWithString:[NSString stringWithFormat:@"http://www.IMPAwards.com%@",posterPageLink]] ;
	NSXMLDocument *document = [[[NSXMLDocument alloc] initWithContentsOfURL:url options:NSXMLDocumentTidyHTML error:&error] autorelease];
	NSXMLElement *root = [document rootElement];
	NSMutableArray * candidatePosterLinks=[NSMutableArray arrayWithObjects:nil] ;
	NSString * yearPathComponent=[posterPageLink stringByDeletingLastPathComponent];
	
	/*Get the results list*/
	NSArray *results = [root objectsForXQuery:IMP_POSTER_CANDIDATES_XPATH error:&error];
	if([results count]<1)
	{
		/* IMDB had the wrong release year link, see if IMP Tried to redirect*/
		NSArray *newPosterPageLinkArray = [root objectsForXQuery:IMP_LINK_REDIRECT_XPATH error:&error];
		if([newPosterPageLinkArray count])
		{
			NSString * newPosterPageLink=[newPosterPageLinkArray objectAtIndex:0] ;
			NSScanner *trimmer=[NSScanner scannerWithString:newPosterPageLink];
			[trimmer scanUpToString:@"URL=.." intoString:&yearPathComponent];
			newPosterPageLink=[newPosterPageLink substringFromIndex:[yearPathComponent length]+6];
			yearPathComponent=[newPosterPageLink stringByDeletingLastPathComponent];
			url=[NSURL URLWithString:[NSString stringWithFormat:@"http://www.IMPAwards.com%@",newPosterPageLink]] ;
			document = [[[NSXMLDocument alloc] initWithContentsOfURL:url options:NSXMLDocumentTidyHTML error:&error] autorelease];
			root = [document rootElement];
			results = [root objectsForXQuery:IMP_POSTER_CANDIDATES_XPATH error:&error];			
		}
	}

	if([results count])
	{
		/*Get each result*/
		NSEnumerator *resultEnum = [results objectEnumerator];
		NSXMLElement *result = nil;
		while((result = [resultEnum nextObject]) != nil)
		{
			/*Add the result to the list*/			
			NSString *resultURL =[[result stringValue] lowercaseString];
			if(resultURL == nil)
				continue;
			if([resultURL hasPrefix:@"posters/"]) /* get the displayed poster link */
			{
				NSString * subPath=[resultURL substringFromIndex:7];
				subPath=[NSString stringWithFormat:[NSString stringWithFormat:@"%@/posters%@",yearPathComponent,subPath]];
				[candidatePosterLinks addObject:subPath];
			}
			else if([resultURL hasPrefix:@"thumbs/"]) /* get the displayed poster link */
			{
				NSString * subPath=[resultURL substringFromIndex:11];
				subPath=[NSString stringWithFormat:[NSString stringWithFormat:@"%@/posters/%@",yearPathComponent,subPath]];
				[candidatePosterLinks addObject:subPath];
			}
		}
	}
	[candidatePosterLinks uniqueObjects];
	NSMutableSet *ret = [[NSMutableSet alloc] init];
	int i, count = [candidatePosterLinks count];
	for(i=0; i<count; i++)
	{
		[ret addObject:[SapphireMoviePoster createPosterWithLink:[candidatePosterLinks objectAtIndex:i] index:i translation:nil inContext:moc]];
	}
	return [ret autorelease];
}

/*!
* @brief Fetch information for a movie
 *
 * @param movieTitleLink The IMDB link extention (part of the show's URL)
 * @param moviePath The movie file's location
 * @return A cached dictionary of the movie info
 */
- (NSMutableDictionary *)getMetaForMovie:(NSString *)movieTitleLink withPath:(NSString*)moviePath
{
	NSError *error = nil;
	NSMutableDictionary *ret = [NSMutableDictionary dictionary];
	
	/* Gather IMDB Data */
	/*Get the movie html*/
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://www.IMDB.com%@",movieTitleLink]];
	NSXMLDocument *document = [[[NSXMLDocument alloc] initWithContentsOfURL:url options:NSXMLDocumentTidyHTML error:&error] autorelease];
	
	/* Get the movie title */
	NSString *movieTitle= [[document objectsForXQuery:IMDB_RESULT_TITLE_YEAR_XPATH error:&error] objectAtIndex:0];
	NSScanner *metaTrimmer=[NSScanner scannerWithString:movieTitle];
	[metaTrimmer scanUpToString:@" (" intoString:&movieTitle];
	
	/* Get the User Rating (IMDB) */
	NSArray *ratingCandidates=[document objectsForXQuery:@"(//b | //h5)/string()" error:&error];
	int ratingIndex = [ratingCandidates indexOfObject:@"User Rating:\n"];
	NSString *usrRating=nil;
	if(ratingIndex != NSNotFound)
	{
		int i;
		for(i=1; i<4; i++)
		{
			usrRating = [ratingCandidates objectAtIndex:ratingIndex+i];
			if([usrRating floatValue] != 0.0f)
				break;
		}
		metaTrimmer=[NSScanner scannerWithString:usrRating];
		[metaTrimmer scanUpToString:@"/" intoString:&usrRating];		
	}
	/* Check for IMDB top 250 */
	NSNumber * top250=nil ;
	NSArray *top250Candidate=[document objectsForXQuery:@"//div[@class='left']/a/string()" error:&error];
	
	if([top250Candidate count])
	{
		NSString *top250Str=[top250Candidate objectAtIndex:0];
		if([top250Str hasPrefix:@"Top 250:"])
			top250=[NSNumber numberWithInt:[[top250Str substringFromIndex:10] intValue]];
	}
	
	/* Get the release date */
	NSArray *rawData=[document objectsForXQuery:IMDB_RESULT_INFO_XPATH error:&error];
	NSDate * releaseDate=nil ;
	NSString * plot=nil;
	NSString * mpaaRating=nil;
	NSNumber * oscarsWon=nil ;
	NSArray * directors=nil;
//	NSArray * writers=nil;
	NSArray * genres=nil;
	if([rawData count])
	{
		NSEnumerator *resultEnum = [rawData objectEnumerator];
		NSXMLElement *result = nil;
		while((result = [resultEnum nextObject]) != nil)
		{
			NSString *dataCandidate=[result stringValue];
			
			if([dataCandidate length])
			{
				NSString * dataType=nil;
				NSScanner * trimmer=[NSScanner scannerWithString:dataCandidate];
				[trimmer scanUpToString:@"\n" intoString:&dataType];
				if([dataType hasPrefix:@"Release"])
				{
					[trimmer scanUpToString:@"(" intoString:&dataCandidate];
					releaseDate=[NSDate dateWithNaturalLanguageString:dataCandidate];
					
				}
//				else if([dataType hasPrefix:@"Writer"])
//				{
//					NSString *writersStr = [[trimmer string] substringFromIndex:[trimmer scanLocation]+1];
//					NSMutableArray *mutDirs = [[writersStr componentsSeparatedByString:@"\n"] mutableCopy];
//					[mutDirs removeObject:@""];
//					int i, count = [mutDirs count];
//					for(i=0; i<count; i++)
//					{
//						NSString *tdirector;
//						NSScanner *typeTrimmer = [[NSScanner alloc] initWithString:[mutDirs objectAtIndex:i]];
//						[typeTrimmer scanUpToString:@" (" intoString:&tdirector];
//						[mutDirs replaceObjectAtIndex:i withObject:tdirector];
//						[typeTrimmer release];
//					}
//					writers = [[mutDirs copy] autorelease];
//					[mutDirs release];
//				}
				else if([dataType hasPrefix:@"Director"])
				{
					NSString *directorsStr = [[trimmer string] substringFromIndex:[trimmer scanLocation]+1];
					NSMutableArray *mutDirs = [[directorsStr componentsSeparatedByString:@"\n"] mutableCopy];
					[mutDirs removeObject:@""];
					[mutDirs removeObject:@"more"];
					int i, count = [mutDirs count];
					for(i=0; i<count; i++)
					{
						NSString *tdirector;
						NSScanner *typeTrimmer = [[NSScanner alloc] initWithString:[mutDirs objectAtIndex:i]];
						[typeTrimmer scanUpToString:@" (" intoString:&tdirector];
						[mutDirs replaceObjectAtIndex:i withObject:tdirector];
						[typeTrimmer release];
					}
					directors = [[mutDirs copy] autorelease];
					[mutDirs release];
				}
				else if([dataType hasPrefix:@"Awards"])
				{
					NSString *awardsStr = [[trimmer string] substringFromIndex:[trimmer scanLocation]+1];
					trimmer=[NSScanner scannerWithString:awardsStr];
					[trimmer scanUpToString:@" Oscars." intoString:&awardsStr];
					if([awardsStr length]<[[trimmer string] length])
					{
						awardsStr=[awardsStr substringFromIndex:3];
						oscarsWon=[NSNumber numberWithInt:[awardsStr intValue]];
					}
					else if([awardsStr hasPrefix:@"Won Oscar"])
						oscarsWon=[NSNumber numberWithInt:1];
					
				}
				else if([dataType hasPrefix:@"MPAA"])
				{
					NSString *mpaaStr = [[trimmer string] substringFromIndex:[trimmer scanLocation]+1];
					if([mpaaStr hasPrefix:@"Rated"])
					{
						trimmer=[NSScanner scannerWithString:[mpaaStr substringFromIndex:6]] ;
						[trimmer scanUpToString:@" " intoString:&mpaaRating];
					}
				}
				else if([dataType hasPrefix:@"Genre"])
				{
					
					NSMutableArray *myGenres=[NSMutableArray array];
					NSCharacterSet *seperators = [NSCharacterSet characterSetWithCharactersInString:@"/|"];
					while(![trimmer isAtEnd])
					{
						NSString *aGenre=nil;
						[trimmer scanUpToCharactersFromSet:seperators intoString:&aGenre];
						if(aGenre)
						{
							if([aGenre rangeOfCharacterFromSet:seperators options:0].length == [aGenre length])
								continue ;
							else if([aGenre hasSuffix:@"more\n"])
								aGenre=[aGenre substringToIndex:[aGenre length]-6];
							else if([aGenre hasSuffix:@" "])
								aGenre=[aGenre substringToIndex:[aGenre length]-1];
							else if([aGenre hasSuffix:@"\n"])
								aGenre=[aGenre substringToIndex:[aGenre length]-1];
							[myGenres addObject:aGenre];
						}
						else
						{
							[trimmer scanUpToString:@" " intoString:&aGenre];
						}
					}
					genres = [[myGenres copy] autorelease];
				}
				else if([dataType hasPrefix:@"Plot:"])
				{
					NSArray *children = [result children];
					NSEnumerator *childEnum = [children objectEnumerator];
					NSXMLElement *child;
					while((child = [childEnum nextObject]) != nil)
					{
						if([[child name] isEqualToString:@"div"])
						{
							NSArray *plotChildren = [child children];
							NSXMLElement *potentialPlot = nil;
							if([plotChildren count])
								potentialPlot = [plotChildren objectAtIndex:0];
							if([potentialPlot kind] == NSXMLTextKind)
								plot = [potentialPlot stringValue];
							break;
						}
					}
				}
				else 
					continue ;
			}
			else
				continue ;
		}
		
		
	}
	
	/* Get the cast list */
	NSArray *rawCast=[document objectsForXQuery:IMDB_RESTULT_CAST_NAMES_XPATH error:&error];
	NSArray *completeCast=nil ;
	if([rawCast count])
	{
		NSMutableArray *results=nil;
		NSEnumerator *resultEnum = [rawCast objectEnumerator];
		NSXMLElement *result = nil;
		while((result = [resultEnum nextObject]) != nil)
		{
			NSString *castName=nil;
			castName=[result stringValue];
			if([castName length])
			{
				NSString * castURL=[[[result attributeForName:@"href"]stringValue]lowercaseString];
				if([castURL hasPrefix:@"/name/"])
				{
					if(!results)
						results=[NSMutableArray arrayWithObject:castName];
					else
						[results addObject:castName];
				}
				else continue ;
			}
			else
				continue ;
		}
		completeCast=[[results copy] autorelease] ;
	}
	
	/* populate metadata to return */
	[ret setObject:movieTitleLink forKey:META_MOVIE_IDENTIFIER_KEY];
	if(oscarsWon)
		[ret setObject:oscarsWon forKey:META_MOVIE_OSCAR_KEY];
	else
		[ret setObject:[NSNumber numberWithInt:0] forKey:META_MOVIE_OSCAR_KEY];
	if(top250)
		[ret setObject:top250 forKey:META_MOVIE_IMDB_250_KEY];
	if([usrRating length]>0)
		[ret setObject:[NSNumber numberWithFloat:[usrRating floatValue]] forKey:META_MOVIE_IMDB_RATING_KEY];
	if(mpaaRating)
		[ret setObject:mpaaRating forKey:META_MOVIE_MPAA_RATING_KEY];
	else
		[ret setObject:@"N/A" forKey:META_MOVIE_MPAA_RATING_KEY];
	if(directors)
		[ret setObject:directors forKey:META_MOVIE_DIRECTOR_KEY];
	if(plot)
		[ret setObject:plot forKey:META_MOVIE_PLOT_KEY];
	if(releaseDate)
		[ret setObject:releaseDate forKey:META_MOVIE_RELEASE_DATE_KEY];
	if(genres)
		[ret setObject:genres forKey:META_MOVIE_GENRES_KEY];
	if(completeCast)
		[ret setObject:completeCast forKey:META_MOVIE_CAST_KEY];
	if(movieTitle)
		[ret setObject:movieTitle forKey:META_MOVIE_TITLE_KEY];
	return ret;
}



/*!
* @brief Searches for a movie based on the filename
 *
 * @param searchStr Part of the filename to use in the show search
 * @return An array of possible results
 */
- (NSArray *)searchResultsForMovie:(NSString *)searchStr
{
	/* prep the search string */
	searchStr = [searchStr stringByDeletingPathExtension];
	searchStr = [searchStr stringByReplacingAllOccurancesOf:@"_" withString:@" "];
	searchStr = [searchStr stringByReplacingAllOccurancesOf:@"." withString:@" "];
	searchStr = [searchStr stringByReplacingAllOccurancesOf:@"-" withString:@" "];
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://www.imdb.com/find?s=tt&site=aka&q=%@", [searchStr URLEncode]]];
	SapphireLog(SAPPHIRE_LOG_IMPORT, SAPPHIRE_LOG_LEVEL_DEBUG, @"Loading search URL: %@", url);
	NSError * error = nil;
	BOOL uniqueResult=NO ;
	NSArray * results = nil;
	NSMutableArray *ret=nil;
	NSXMLDocument *document = [[[NSXMLDocument alloc] initWithContentsOfURL:url options:NSXMLDocumentTidyHTML error:&error] autorelease];
	NSXMLElement *root = [document rootElement];	
	NSString *resultTitle=[[[root objectsForXQuery:@"//title" error:&error]objectAtIndex:0] stringValue];
	SapphireLog(SAPPHIRE_LOG_IMPORT, SAPPHIRE_LOG_LEVEL_DEBUG, @"Got title: %@ for document: %@", resultTitle, document);
	
	if([resultTitle isEqualToString:@"IMDb Title Search"])/*Make sure we didn't get back a unique result */
	{
		results = [root objectsForXQuery:IMDB_SEARCH_XPATH error:&error];
		ret = [NSMutableArray arrayWithCapacity:[results count]];
	}
	else /* IMDB directly linked to a unique movie title */
	{
		uniqueResult=YES ;
		ret = [NSMutableArray arrayWithCapacity:1];
		results = [root objectsForXQuery:IMDB_UNIQUE_SEARCH_XPATH error:&error];		
	}
	
	SapphireLog(SAPPHIRE_LOG_IMPORT, SAPPHIRE_LOG_LEVEL_DETAIL, @"Got search results: %@", results);
	if([results count])
	{
		/*Get each result*/
		NSEnumerator *resultEnum = [results objectEnumerator];
		NSXMLElement *result = nil;
		while((result = [resultEnum nextObject]) != nil)
		{
			if(uniqueResult)/*Check for a unique title link*/
			{
				NSString *resultString = [result stringValue];
				unsigned int location = [resultString rangeOfString:@"http://pro.im"].location;
				if(location == NSNotFound)
					continue;
				resultString = [resultString substringFromIndex:location];
				NSURL *resultURL = [NSURL URLWithString:resultString];
				if(resultURL == nil)
					continue;
				NSString *URLSubPath =[resultURL path];
				location = [URLSubPath rangeOfString:@"/title/"].location;
				int count = 0;
				if(location != NSNotFound)
				{
					NSString *subStr = [URLSubPath substringFromIndex:location];
					count = [[subStr pathComponents] count];
					if(count > 3)
					{
						int i;
						for(i=count; i>3; i--)
							URLSubPath = [URLSubPath stringByDeletingLastPathComponent];
						count = 3;
					}
				}
				SapphireLog(SAPPHIRE_LOG_IMPORT, SAPPHIRE_LOG_LEVEL_DEBUG, @"URLSubPath is %@", URLSubPath);
				if(count == 3)
				{
					URLSubPath=[URLSubPath stringByReplacingAllOccurancesOf:@"//pro." withString:@"//www."];
					[ret addObject:[NSDictionary dictionaryWithObjectsAndKeys:
									resultTitle, MOVIE_TRAN_IMDB_NAME_KEY,
									URLSubPath, MOVIE_TRAN_IMDB_LINK_KEY,
									nil]];
					return ret;					
				}
			}
			else
			{
				/*Add the result to the list*/
				NSURL *resultURL = [NSURL URLWithString:[[[result objectsForXQuery:IMDB_RESULT_LINK_XPATH error:&error] objectAtIndex:0] stringValue]] ;
				NSString * resultTitleValue=[result stringValue];
				/* Deal with AKA titles */
				if([resultTitleValue hasPrefix:@"\n"])
				{
					resultTitleValue=[resultTitleValue substringFromIndex:3];
					resultTitle=[resultTitle stringByReplacingAllOccurancesOf:@"\n" withString:@" "];
				}
				/* Skip image links */
				else if(resultURL == nil || [resultTitleValue characterAtIndex:0] == 160)
					continue;
				/*Skip Video Game titles (VG) */
				if([resultTitleValue rangeOfString:@"(VG)"].location != NSNotFound)
					continue ;
				if([resultTitleValue rangeOfString:@"(TV series)" options:NSCaseInsensitiveSearch].location != NSNotFound)
					continue;
				[ret addObject:[NSDictionary dictionaryWithObjectsAndKeys:
					[[result objectsForXQuery:IMDB_RESULT_NAME_XPATH error:&error] objectAtIndex:0], MOVIE_TRAN_IMDB_NAME_KEY,
					[resultURL path], MOVIE_TRAN_IMDB_LINK_KEY,
					nil]];
			}
		}
		if(!uniqueResult && [ret count]>0)return ret;
	}
	return nil ;
}

/*!
* @brief verify file extention of a file
 *
 * @param metaData The file's metadata
 * @return YES if candidate, NO otherwise
 */
- (BOOL)isMovieCandidate:(SapphireFileMetaData *)metaData;
{
	NSString *path = [metaData path];
	BOOL ret = [[NSFileManager defaultManager] acceptFilePath:path];
	if([metaData fileContainerType] == FILE_CONTAINER_TYPE_QT_MOVIE)
		ret &= [[NSFileManager videoExtensions] containsObject:[path pathExtension]];
	if([metaData fileClassValue]==FILE_CLASS_TV_SHOW) /* File is a TV Show - skip it */
		ret = NO;
	return ret;
}

- (ImportState)importMetaData:(SapphireFileMetaData *)metaData path:(NSString *)path
{
	/*Check to see if it is already imported*/
	if([metaData importTypeValue] & IMPORT_TYPE_MOVIE_MASK)
		return ImportStateNotUpdated;
	/*Get path*/
	if(![self isMovieCandidate:metaData])
		return ImportStateNotUpdated;
	SapphireLog(SAPPHIRE_LOG_IMPORT, SAPPHIRE_LOG_LEVEL_DEBUG, @"Going to movie import %@", path);
	NSString *fileName = [path lastPathComponent];
	/*choose between file or directory name for lookup */
	NSString *lookupName;
	if([[SapphireSettings sharedSettings] dirLookup])
		lookupName = [[path stringByDeletingLastPathComponent] lastPathComponent];
	else
		lookupName = fileName;
	
	/*Get the movie title*/
	NSString *movieDataLink = nil ;
	/*Check to see if we know this movie*/
	NSString *movieTranslationString = [[lookupName lowercaseString] stringByDeletingPathExtension];
	SapphireLog(SAPPHIRE_LOG_IMPORT, SAPPHIRE_LOG_LEVEL_DETAIL, @"Searching for movie %@", movieTranslationString);
	NSManagedObjectContext *moc = [metaData managedObjectContext];
	SapphireMovieTranslation *tran = [SapphireMovieTranslation movieTranslationWithName:movieTranslationString inContext:moc];
	int searchIMDBNumber = [metaData searchIMDBNumber];
	if(searchIMDBNumber > 0)
		[tran setIMDBLink:[NSString stringWithFormat:@"/title/tt%d", searchIMDBNumber]];
	if([tran IMDBLink] == nil)
	{
		if(![delegate canDisplayChooser])
		/*There is no data menu, background import. So we can't ask user, skip*/
			return ImportStateNotUpdated;
		/*Ask the user what movie this is*/
		NSArray *movies = [self searchResultsForMovie:lookupName];
		SapphireLog(SAPPHIRE_LOG_IMPORT, SAPPHIRE_LOG_LEVEL_DETAIL, @"Found results: %@", movies);
		/* No need to prompt the user for an empty set */
		if(movies==nil)
		{
			/* We tried to import but found nothing - mark this file to be skipped on future imports */
			[metaData didImportType:IMPORT_TYPE_MOVIE_MASK];
			[metaData setFileClassValue:FILE_CLASS_OTHER];
			return ImportStateUpdated;
		}
		if([[SapphireSettings sharedSettings] autoSelection])
		{
			if(tran == nil)
				tran = [SapphireMovieTranslation createMovieTranslationWithName:movieTranslationString inContext:moc];
			[tran setIMDBLink:[[movies objectAtIndex:0] objectForKey:MOVIE_TRAN_IMDB_LINK_KEY]];
		}
		else
		{
			/*Bring up the prompt*/
			SapphireMovieChooser *chooser = [[SapphireMovieChooser alloc] initWithScene:[delegate chooserScene]];
			[chooser setMovies:movies];
			[chooser setFileName:lookupName];		
			[chooser setListTitle:BRLocalizedString(@"Select Movie Title", @"Prompt the user for title of movie")];
			SapphireImportStateData *state = [[SapphireImportStateData alloc] initWithFile:metaData atPath:path];
			/*And display prompt*/
			[delegate displayChooser:chooser forImporter:self withContext:state];
			[chooser release];
			[state release];
			return ImportStateSuspend;
			//Data will be ready for access on the next call
		}
	}
	
	SapphireMoviePoster *selectedPoster = [tran selectedPoster];
	SapphireMoviePoster *autoSelectPoster = nil;
	if(!selectedPoster)
	{
		if(![delegate canDisplayChooser])
		/*There is no data menu, background import. So we can't ask user, skip*/
			return ImportStateNotUpdated;
		/* Posters will be downloaded, let the user choose one */
		NSSet *posters = [tran postersSet];
		if(![posters count])
		{
			NSString *posterPath=nil ;
			/* Get the IMP Key with the IMDB Posters page */
			posterPath = [self getPosterPath:[tran IMDBLink]];
			if(posterPath!=nil)
			{
				[tran setIMPLink:posterPath];
				/*We got a posterPath, get the posterLinks */
				posters = [self getPosterLinks:posterPath inContext:moc];
				if(posters != nil)
				{
					/* Add the poster links */
					NSMutableSet *posterSet = [tran postersSet];
					[posterSet setSet:posters];
					[SapphireMetaDataSupport save:moc];
				}
				/* Add another method via chooser incase IMDB doesn't have an IMP link */
			}
			else posters=nil ;
		}
		if([posters count])
		{
			SapphirePosterChooser *posterChooser=[[SapphirePosterChooser alloc] initWithScene:[delegate chooserScene]];
			if(![posterChooser okayToDisplay] || [[SapphireSettings sharedSettings] autoSelection])
			{
				/* Auto Select the first poster */
				autoSelectPoster = [tran posterAtIndex:0];
				[posterChooser release];
			}
			else
			{
				NSMutableArray *posterPaths = [[[tran orderedPosters] valueForKey:@"link"] mutableCopy];
				int i, count = [posterPaths count];
				for(i=0; i<count; i++)
				{
					[posterPaths replaceObjectAtIndex:i withObject:[@"http://www.IMPAwards.com" stringByAppendingString:[posterPaths objectAtIndex:i]]];
				}
				[posterChooser setPosters:posterPaths];
				[posterPaths release];
				[posterChooser setFileName:lookupName];
				[posterChooser setFile:(SapphireFileMetaData *)metaData];
				[posterChooser setListTitle:BRLocalizedString(@"Select Movie Poster", @"Prompt the user for poster selection")];
				SapphireImportStateData *state = [[SapphireImportStateData alloc] initWithFile:metaData atPath:path];
				[delegate displayChooser:posterChooser forImporter:self withContext:state];
				[posterChooser release];
				[state release];
				return ImportStateSuspend;
			}
		}
	}
	NSFileManager *fileAgent=[NSFileManager defaultManager];
	NSString * coverart=[[SapphireMetaDataSupport collectionArtPath] stringByAppendingPathComponent:@"@MOVIES"];
	[fileAgent constructPath:coverart];
	int imdbNumber = [SapphireMovie imdbNumberFromString:[tran IMDBLink]];
	coverart=[coverart stringByAppendingPathComponent:[NSString stringWithFormat:@"%d", imdbNumber]];
	if(selectedPoster && [tran IMPLink])
	{
		[[SapphireApplianceController urlLoader] saveDataAtURL:[@"http://www.IMPAwards.com" stringByAppendingString:[selectedPoster link]] toFile:coverart];
	}
	else if(autoSelectPoster)
	{
		/* The poster chooser wasn't loaded - ATV 1.0 */
		[[SapphireApplianceController urlLoader] saveDataAtURL:[@"http://www.IMPAwards.com" stringByAppendingString:[autoSelectPoster link]] toFile:coverart];
	}
	
	/* If we have JPEG art and content is a ripped DVD we provide Preview.jpg coverart in the film folder,
	 * To allow for updates the preview.jpg is not a copy, but instead a symbolic link to the cover
	 * art in the Collection Art/@MOVIES folder */
	if( ([[coverart pathExtension] caseInsensitiveCompare:@"jpg" ] == NSOrderedSame ||
	     [[coverart pathExtension] caseInsensitiveCompare:@"jpeg"] == NSOrderedSame  ) &&
	   [metaData fileContainerTypeValue] == FILE_CONTAINER_TYPE_VIDEO_TS )
	{
		/* This is non-critical code, just adding fluff, ignore returned value */
		[fileAgent createSymbolicLinkAtPath:[[metaData path] stringByAppendingPathComponent:@"Preview.jpg"] pathContent:coverart];
	}
	
	
	/*Import the info*/
	SapphireMovie *movie = [tran movie];
	if(movie == nil)
	{
		/*IMDB Data */
		NSMutableDictionary *infoIMDB = nil;
		movieDataLink = [tran IMDBLink];
		infoIMDB = [self getMetaForMovie:movieDataLink withPath:path];
		if(!infoIMDB)
			return ImportStateNotUpdated;
		movie = [SapphireMovie movieWithDictionary:infoIMDB inContext:moc];
		if(movie == nil)
		{
			SapphireLog(SAPPHIRE_LOG_IMPORT, SAPPHIRE_LOG_LEVEL_ERROR, @"Failed to import movie for %@", path);
			return ImportStateNotUpdated;
		}
		[tran setMovie:movie];
	}
	[metaData setMovie:movie];
	/*We imported something*/
	return ImportStateUpdated;
}


- (NSString *)completionText
{
	return BRLocalizedString(@"All available Movie data has been imported", @"The Movie import is complete");
}

- (NSString *)initialText
{
	return BRLocalizedString(@"Fetch Movie Data", @"Title");
}

- (NSString *)informativeText
{
	return BRLocalizedString(@"This tool will attempt to fetch information about your Movie files from the Internet (IMDB/IMPAwards).  This procedure may take quite some time and could ask you questions.  You may cancel at any time.", @"Description of the movie import");
}

- (NSString *)buttonTitle
{
	return BRLocalizedString(@"Start Fetching Data", @"Button");
}

- (void)exhumedChooser:(BRLayerController <SapphireChooser> *)chooser withContext:(id)context
{
	/*See if it was a movie chooser*/
	if([chooser isKindOfClass:[SapphireMovieChooser class]])
	{
		/*Get the user's selection*/
		SapphireMovieChooser *movieChooser = (SapphireMovieChooser *)chooser;
		SapphireImportStateData *state = (SapphireImportStateData *)context;
		SapphireFileMetaData *currentData = state->file;
		NSString *path = state->path;
		NSManagedObjectContext *moc = [currentData managedObjectContext];
		int selection = [movieChooser selection];
		if(selection == SapphireChooserChoiceCancel)
		{
			/*They aborted, skip*/
			[delegate backgroundImporter:self completedImportOnPath:path withState:ImportStateUpdated];
		}
		else if(selection == SapphireChooserChoiceNotType)
		{
			/*They said it is not a movie, so put in empty data so they are not asked again*/
			[currentData didImportType:IMPORT_TYPE_MOVIE_MASK];
			if ([currentData fileClassValue] != FILE_CLASS_TV_SHOW)
				[currentData setFileClassValue:FILE_CLASS_UNKNOWN];
		}
		else
		{
			/*They selected a movie title, save the translation and write it*/
			NSDictionary *movie = [[movieChooser movies] objectAtIndex:selection];
			NSString *filename = [[[movieChooser fileName] lowercaseString] stringByDeletingPathExtension];
			SapphireMovieTranslation *tran = [SapphireMovieTranslation createMovieTranslationWithName:filename inContext:moc];
			/* Add IMDB Key */
			[tran setIMDBLink:[movie objectForKey:MOVIE_TRAN_IMDB_LINK_KEY]];
		}
		[SapphireMetaDataSupport save:moc];
		/*We can resume now*/
		[delegate resumeWithPath:path];
	}
	else if([chooser isKindOfClass:[SapphirePosterChooser class]])
	{
		SapphirePosterChooser *posterChooser = (SapphirePosterChooser *)chooser;
		SapphireImportStateData *state = (SapphireImportStateData *)context;
		SapphireFileMetaData *currentData = state->file;
		NSString *path = state->path;
		NSManagedObjectContext *moc = [currentData managedObjectContext];
		SapphireChooserChoice selectedPoster = [posterChooser selection];
		if(selectedPoster == SapphireChooserChoiceCancel)
			/*They aborted, skip*/
			[delegate backgroundImporter:self completedImportOnPath:path withState:ImportStateUpdated];
		else
		{
			NSString *filename = [[[posterChooser fileName] lowercaseString] stringByDeletingPathExtension];
			SapphireMovieTranslation *tran = [SapphireMovieTranslation createMovieTranslationWithName:filename inContext:moc];
			[tran setSelectedPosterIndexValue:selectedPoster];
		}
		posterChooser = nil;
		[SapphireMetaDataSupport save:moc];
		/*We can resume now*/
		[delegate resumeWithPath:path];
	}
	else
		return;
}

@end