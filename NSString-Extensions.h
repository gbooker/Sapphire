//
//  NSString-Extensions.h
//  Sapphire
//
//  Created by Graham Booker on 6/30/07.
//  Copyright 2007 www.nanopi.net. All rights reserved.
//

@interface NSString (PostStrings)
- (NSString *)URLEncode;
@end

@interface NSString (Replacements)
- (NSString *)stringByReplacingAllOccurancesOf:(NSString *)search withString:(NSString *)replacement;
@end

@interface NSMutableString (Replacements)
- (void)replaceAllOccurancesOf:(NSString *)search withString:(NSString *)replacement;
@end
