#import "SapphireXMLData.h"
#import "SapphireFileMetaData.h"
#import "SapphireCast.h"
#import "SapphireGenre.h"
#import "SapphireDirector.h"
#import "CoreDataSupportFunctions.h"
#import "SapphireMovie.h"
#import "SapphireEpisode.h"

#define MODIFIED_KEY				@"Modified"
#define FILE_CLASS_KEY				@"File Class"

#define ORDERED_CAST_KEY		@"orderedCast"
#define ORDERED_CAST_DATA		@"orderedCastData"
#define ORDERED_DIRECTOR_KEY	@"orderedDirectors"
#define ORDERED_DIRECTOR_DATA	@"orderedDirectorsData"
#define ORDERED_GENRES_KEY		@"orderedGenres"
#define ORDERED_GENRES_DATA		@"orderedGenresData"

@implementation SapphireXMLData

+ (void)upgradeV1XMLFromContext:(NSManagedObjectContext *)oldMoc toContext:(NSManagedObjectContext *)newMoc file:(NSDictionary *)fileLookup
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSArray *xmls = doFetchRequest(SapphireXMLDataName, oldMoc, nil);
	NSEnumerator *xmlEnum = [xmls objectEnumerator];
	NSManagedObject *oldXML;
	while((oldXML = [xmlEnum nextObject]) != nil)
	{
		NSString *path = [oldXML valueForKeyPath:@"file.path"];
		SapphireFileMetaData *file = nil;
		if(path != nil)
			file = [fileLookup objectForKey:path];
		if(file == nil)
			continue;
		
		SapphireXMLData *newXML = [NSEntityDescription insertNewObjectForEntityForName:SapphireXMLDataName inManagedObjectContext:newMoc];
		newXML.contentDescription = [oldXML valueForKey:@"contentDescription"];
		newXML.fileClass = [oldXML valueForKey:@"fileClass"];
		newXML.modified = [oldXML valueForKey:@"modified"];
		newXML.summary = [oldXML valueForKey:@"summary"];
		newXML.title = [oldXML valueForKey:@"title"];
		
		NSManagedObject *epXML = [oldXML valueForKey:@"episode"];
		if(epXML != nil)
		{
			newXML.absoluteEpisodeNumber = [epXML valueForKey:@"absoluteEpisodeNumber"];
			newXML.episodeNumber = [epXML valueForKey:@"episodeNumber"];
			newXML.lastEpisodeNumber = [epXML valueForKey:@"lastEpisodeNumber"];
			newXML.searchEpisode = [epXML valueForKey:@"searchEpisode"];
			newXML.searchLastEpisodeNumber = [epXML valueForKey:@"searchLastEpisodeNumber"];
			newXML.searchSeasonNumber = [epXML valueForKey:@"searchSeasonNumber"];
			newXML.searchShowName = [epXML valueForKey:@"searchShowName"];			
		}
		NSManagedObject *movieXML = [oldXML valueForKey:@"movie"];
		if(movieXML != nil)
		{
			newXML.orderedCastData = [movieXML valueForKey:@"orderedCastData"];
			newXML.orderedDirectorsData = [movieXML valueForKey:@"orderedDirectorsData"];
			newXML.orderedGenresData = [movieXML valueForKey:@"orderedGenresData"];
		}
		file.xmlData = newXML;
		
		if(newXML.episode == nil)
			[newXML constructEpisode];
		if(newXML.movie == nil)
			[newXML constructMovie];
	}
	[pool drain];
}

+ (void)upgradeV2XMLFromContext:(NSManagedObjectContext *)oldMoc toContext:(NSManagedObjectContext *)newMoc file:(NSDictionary *)fileLookup
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSArray *xmls = doFetchRequest(SapphireXMLDataName, oldMoc, nil);
	NSEnumerator *xmlEnum = [xmls objectEnumerator];
	NSManagedObject *oldXML;
	while((oldXML = [xmlEnum nextObject]) != nil)
	{
		NSString *path = [oldXML valueForKeyPath:@"file.path"];
		SapphireFileMetaData *file = nil;
		if(path != nil)
			file = [fileLookup objectForKey:path];
		if(file == nil)
			continue;
		
		SapphireXMLData *newXML = [NSEntityDescription insertNewObjectForEntityForName:SapphireXMLDataName inManagedObjectContext:newMoc];
		newXML.absoluteEpisodeNumber = [oldXML valueForKey:@"absoluteEpisodeNumber"];
		newXML.contentDescription = [oldXML valueForKey:@"contentDescription"];
		newXML.episodeNumber = [oldXML valueForKey:@"episodeNumber"];
		newXML.fileClass = [oldXML valueForKey:@"fileClass"];
		newXML.imdbRating = [oldXML valueForKey:@"imdbRating"];
		newXML.imdbTop250Ranking = [oldXML valueForKey:@"imdbTop250Ranking"];
		newXML.lastEpisodeNumber = [oldXML valueForKey:@"lastEpisodeNumber"];
		newXML.modified = [oldXML valueForKey:@"modified"];
		newXML.MPAARating = [oldXML valueForKey:@"MPAARating"];
		newXML.orderedCastData = [oldXML valueForKey:@"orderedCastData"];
		newXML.orderedDirectorsData = [oldXML valueForKey:@"orderedDirectorsData"];
		newXML.orderedGenresData = [oldXML valueForKey:@"orderedGenresData"];
		newXML.oscarsWon = [oldXML valueForKey:@"oscarsWon"];
		newXML.releaseDate = [oldXML valueForKey:@"releaseDate"];
		newXML.searchEpisode = [oldXML valueForKey:@"searchEpisode"];
		newXML.searchIMDBNumber = [oldXML valueForKey:@"searchIMDBNumber"];
		newXML.searchLastEpisodeNumber = [oldXML valueForKey:@"searchLastEpisodeNumber"];
		newXML.searchSeasonNumber = [oldXML valueForKey:@"searchSeasonNumber"];
		newXML.searchShowName = [oldXML valueForKey:@"searchShowName"];			
		newXML.summary = [oldXML valueForKey:@"summary"];
		newXML.title = [oldXML valueForKey:@"title"];
		
		file.xmlData = newXML;
	}
	[pool drain];
}

+ (void)upgradeXMLVersion:(int)version fromContext:(NSManagedObjectContext *)oldMoc toContext:(NSManagedObjectContext *)newMoc file:(NSDictionary *)fileLookup
{
	if(version == 1)
		[SapphireXMLData upgradeV1XMLFromContext:oldMoc toContext:newMoc file:fileLookup];
	else
		[SapphireXMLData upgradeV2XMLFromContext:oldMoc toContext:newMoc file:fileLookup];
}

- (void)insertDictionary:(NSDictionary *)dict
{
	self.contentDescription = nil;
	self.fileClass = nil;
	self.modified = nil;
	self.summary = nil;
	self.title = nil;
	
	self.absoluteEpisodeNumber = nil;
	self.episodeNumber = nil;
	self.lastEpisodeNumber = nil;
	self.searchEpisode = nil;
	self.searchLastEpisodeNumber = nil;
	self.searchSeasonNumber = nil;
	self.searchShowName = nil;

	self.imdbTop250Ranking = nil;
	self.imdbRating = nil;
	self.MPAARating = nil;
	self.orderedCastData = nil;
	self.orderedDirectorsData = nil;
	self.orderedGenresData = nil;
	self.oscarsWon = nil;
	self.releaseDate = nil;
	self.searchIMDBNumber = nil;
	
	
	NSNumber *searchVal = [dict objectForKey:META_ABSOLUTE_EP_NUMBER_KEY];
	if(searchVal != nil)
		self.absoluteEpisodeNumber = searchVal;
	
	searchVal = [dict objectForKey:META_EPISODE_NUMBER_KEY];
	if(searchVal != nil)
		self.episodeNumber = searchVal;
	
	searchVal = [dict objectForKey:META_EPISODE_2_NUMBER_KEY];
	if(searchVal != nil)
		self.lastEpisodeNumber = searchVal;

	searchVal = [dict objectForKey:META_SEARCH_EPISODE_NUMBER_KEY];
	if(searchVal != nil)
		self.searchEpisode = searchVal;
	
	searchVal = [dict objectForKey:META_SEASON_NUMBER_KEY];
	if(searchVal != nil)
		self.searchSeasonNumber = searchVal;
	
	searchVal = [dict objectForKey:META_SEARCH_SEASON_NUMBER_KEY];
	if(searchVal != nil)
		self.searchSeasonNumber = searchVal;
	
	searchVal = [dict objectForKey:META_SEARCH_EPISODE_2_NUMBER_KEY];
	if(searchVal != nil)
		self.searchLastEpisodeNumber = searchVal;
	
	searchVal = [dict objectForKey:META_SEARCH_IMDB_NUMBER_KEY];
	if(searchVal != nil)
		self.searchIMDBNumber = searchVal;
		
	NSString *strVal = [dict objectForKey:META_SHOW_NAME_KEY];
	if(strVal != nil)
		self.searchShowName = strVal;
	
	NSDate *releaseDate = [dict objectForKey:META_SHOW_AIR_DATE];
	if(releaseDate != nil)
		self.releaseDate = releaseDate;
	
	NSNumber *userRating = [dict objectForKey:META_SHOW_FAVORITE_RATING_KEY];
	if(userRating != nil)
		self.imdbRating = userRating;
	
	NSString *rating = [dict objectForKey:META_SHOW_RATING_KEY];
	if(rating != nil)
		self.MPAARating = rating;
	
	
	NSArray *arrVal = [dict objectForKey:META_MOVIE_CAST_KEY];
	NSEnumerator *arrEnum = [arrVal objectEnumerator];
	if([arrVal count])
	{
		NSMutableArray *castArray = [NSMutableArray array];
		while((strVal = [arrEnum nextObject]) != nil)
			[castArray addObject:[SapphireCast createCast:strVal inContext:[self managedObjectContext]]];
		self.orderedCast = castArray;
	}
	
	arrVal = [dict objectForKey:META_MOVIE_GENRES_KEY];
	arrEnum = [arrVal objectEnumerator];
	if([arrVal count])
	{
		NSMutableArray *genreArray = [NSMutableArray array];
		while((strVal = [arrEnum nextObject]) != nil)
			[genreArray addObject:[SapphireGenre createGenre:strVal inContext:[self managedObjectContext]]];
		self.orderedGenres = genreArray;
	}
	
	arrVal = [dict objectForKey:META_MOVIE_DIRECTOR_KEY];
	arrEnum = [arrVal objectEnumerator];
	if([arrVal count])
	{
		NSMutableArray *directorArray = [NSMutableArray array];
		while((strVal = [arrEnum nextObject]) != nil)
			[directorArray addObject:[SapphireDirector createDirector:strVal inContext:[self managedObjectContext]]];
		self.orderedDirectors = directorArray;
	}
	
	strVal = [dict objectForKey:META_TITLE_KEY];
	if(strVal != nil)
		self.title = strVal;
	
	strVal = [dict objectForKey:META_DESCRIPTION_KEY];
	if(strVal != nil)
		self.contentDescription = strVal;
	
	strVal = [dict objectForKey:META_SUMMARY_KEY];
	if(strVal != nil)
		self.summary = strVal;
	
	id value = [dict objectForKey:MODIFIED_KEY];
	if(value != nil)
		self.modified = [NSDate dateWithTimeIntervalSince1970:[value intValue]];
	
	value = [dict objectForKey:FILE_CLASS_KEY];
	if(value != nil)
		self.fileClass = value;

	value = [dict objectForKey:META_MOVIE_SORT_TITLE_KEY];
	if(value != nil)
		self.movieSortTitle = value;
	
	if(self.episode == nil)
		[self constructEpisode];
	if(self.movie == nil)
		[self constructMovie];	
}

- (void)constructMovie
{
	int imdbNumber = self.searchIMDBNumberValue;
	NSString *title = self.title;
	SapphireMovie *ret;
	if(imdbNumber != 0)
		ret = [SapphireMovie createMovieWithIMDB:imdbNumber inContext:[self managedObjectContext]];
	else if(title != nil && [[self file] fileClassValue] == FileClassMovie)
		ret = [SapphireMovie createMovieWithTitle:title inContext:[self managedObjectContext]];
	else
		return;
	
	self.movie = ret;
	self.file.movie = ret;
}

- (NSArray *)orderedCast
{
	[self willAccessValueForKey:ORDERED_CAST_KEY];
	NSArray *ret = [self primitiveValueForKey:ORDERED_CAST_KEY];
	[self didAccessValueForKey:ORDERED_CAST_KEY];
	if(ret == nil)
	{
		NSData *propData = [self valueForKey:ORDERED_CAST_DATA];
		if(propData != nil)
		{
			NSArray *names = [NSKeyedUnarchiver unarchiveObjectWithData:propData];
			NSMutableArray *mutRet = [NSMutableArray arrayWithCapacity:[names count]];
			NSManagedObjectContext *moc = [self managedObjectContext];
			NSEnumerator *nameEnum = [names objectEnumerator];
			NSString *name;
			while((name = [nameEnum nextObject]) != nil)
			{
				SapphireCast *aCast = [SapphireCast cast:name inContext:moc];
				if(aCast != nil)
					[mutRet addObject:aCast];
			}
			ret = [NSArray arrayWithArray:mutRet];
			[self setPrimitiveValue:ret forKey:ORDERED_CAST_KEY];
		}
	}
	
	return ret;
}

- (void)setOrderedCast:(NSArray *)ordered
{
	[self willChangeValueForKey:ORDERED_CAST_KEY];
	[self setPrimitiveValue:ordered forKey:ORDERED_CAST_KEY];
	[self didChangeValueForKey:ORDERED_CAST_KEY];
	NSArray *arc = [ordered valueForKey:@"name"];
	[self setValue:[NSKeyedArchiver archivedDataWithRootObject:arc] forKey:ORDERED_CAST_DATA];
	[self.movie checkOrderedCast];
}

- (NSArray *)orderedGenres
{
	[self willAccessValueForKey:ORDERED_GENRES_KEY];
	NSArray *ret = [self primitiveValueForKey:ORDERED_GENRES_KEY];
	[self didAccessValueForKey:ORDERED_GENRES_KEY];
	if(ret == nil)
	{
		NSData *propData = [self valueForKey:ORDERED_GENRES_DATA];
		if(propData != nil)
		{
			NSArray *genres = [NSKeyedUnarchiver unarchiveObjectWithData:propData];
			NSMutableArray *mutRet = [NSMutableArray arrayWithCapacity:[genres count]];
			NSManagedObjectContext *moc = [self managedObjectContext];
			NSEnumerator *genreEnum = [genres objectEnumerator];
			NSString *genre;
			while((genre = [genreEnum nextObject]) != nil)
			{
				SapphireGenre *aGenre = [SapphireGenre genre:genre inContext:moc];
				if(aGenre != nil)
					[mutRet addObject:aGenre];
			}
			ret = [NSArray arrayWithArray:mutRet];
			[self setPrimitiveValue:ret forKey:ORDERED_GENRES_KEY];
		}
	}
	
	return ret;
}

- (void)setOrderedGenres:(NSArray *)ordered
{
	[self willChangeValueForKey:ORDERED_GENRES_KEY];
	[self setPrimitiveValue:ordered forKey:ORDERED_GENRES_KEY];
	[self didChangeValueForKey:ORDERED_GENRES_KEY];
	NSArray *arc = [ordered valueForKey:@"name"];
	[self setValue:[NSKeyedArchiver archivedDataWithRootObject:arc] forKey:ORDERED_GENRES_DATA];
	[self.movie checkOrderedGenres];
}

- (NSArray *)orderedDirectors
{
	[self willAccessValueForKey:ORDERED_DIRECTOR_KEY];
	NSArray *ret = [self primitiveValueForKey:ORDERED_DIRECTOR_KEY];
	[self didAccessValueForKey:ORDERED_DIRECTOR_KEY];
	if(ret == nil)
	{
		NSData *propData = [self valueForKey:ORDERED_DIRECTOR_DATA];
		if(propData != nil)
		{
			NSArray *names = [NSKeyedUnarchiver unarchiveObjectWithData:propData];
			NSMutableArray *mutRet = [NSMutableArray arrayWithCapacity:[names count]];
			NSManagedObjectContext *moc = [self managedObjectContext];
			NSEnumerator *nameEnum = [names objectEnumerator];
			NSString *name;
			while((name = [nameEnum nextObject]) != nil)
			{
				SapphireDirector *aDir = [SapphireDirector director:name inContext:moc];
				if(aDir != nil)
					[mutRet addObject:aDir];
			}
			ret = [NSArray arrayWithArray:mutRet];
			[self setPrimitiveValue:ret forKey:ORDERED_DIRECTOR_KEY];
		}
	}
	
	return ret;
}

- (void)setOrderedDirectors:(NSArray *)ordered
{
	[self willChangeValueForKey:ORDERED_DIRECTOR_KEY];
	[self setPrimitiveValue:ordered forKey:ORDERED_DIRECTOR_KEY];
	[self didChangeValueForKey:ORDERED_DIRECTOR_KEY];
	NSArray *arc = [ordered valueForKey:@"name"];
	[self setValue:[NSKeyedArchiver archivedDataWithRootObject:arc] forKey:ORDERED_DIRECTOR_DATA];
	[self.movie checkOrderedDirectors];
}

- (void)constructEpisode
{
	NSNumber *season = self.searchSeasonNumber;
	NSString *show = self.searchShowName;
	
	if([season intValue] == 0 || show == nil)
		return;
	
	NSMutableDictionary *firstEp = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
									show, META_SHOW_NAME_KEY,
									season, META_SEASON_NUMBER_KEY,
									nil];
	
	NSMutableDictionary *lastEp = nil;
	
	NSNumber *ep = self.episodeNumber;
	if(ep != nil)
		[firstEp setObject:ep forKey:META_EPISODE_NUMBER_KEY];
	NSNumber *lastEpNumber = self.lastEpisodeNumber;
	if([lastEpNumber intValue] != 0)
	{
		lastEp = [firstEp mutableCopy];
		[lastEp setObject:lastEpNumber forKey:META_EPISODE_NUMBER_KEY];
	}
	NSString *title = self.title;
	if(title != nil)
		[firstEp setObject:title forKey:META_TITLE_KEY];
	
	NSString *desc = self.contentDescription;
	if(desc != nil)
		[firstEp setObject:desc forKey:META_DESCRIPTION_KEY];
	
	NSNumber *absEpisode = self.absoluteEpisodeNumber;
	if(absEpisode != nil)
		[firstEp setObject:absEpisode forKey:META_ABSOLUTE_EP_NUMBER_KEY];
	
	NSDate *airDate = self.releaseDate;
	if(airDate != nil)
		[firstEp setObject:airDate forKey:META_SHOW_AIR_DATE];
	
	[firstEp autorelease];
	[lastEp autorelease];

	SapphireEpisode *ret;
	if(ep != 0 || title != nil)
		ret = [SapphireEpisode episodeWithDictionaries:[NSArray arrayWithObjects:firstEp, lastEp, nil] inContext:[self managedObjectContext]];
	else
		return;
	
	self.episode = ret;
	self.file.tvEpisode = ret;
}

@end
