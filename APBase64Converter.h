//
//  APBase64Converter.h
//  APBase64Converter
//
//  Created by Alberto Pasca on 03/04/12.
//  Copyright (c) 2012 albertopasca.it. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface APBase64Converter : NSObject

+ (NSString*) base64forData:(NSData*)theData;
+ (NSData *)  base64DataFromString:(NSString *)string;

@end
