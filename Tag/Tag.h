//
//  Tag.h
//  Tag
//
//  Created by James Berry on 10/25/13.
//  Copyright (c) 2013 Culinate, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(int, OperationMode) {
    OperationModeUnknown    = 0,
    OperationModeSet        = 's',
    OperationModeAdd        = 'a',
    OperationModeRemove     = 'r',
    OperationModeMatch      = 'm',
    OperationModeFind       = 'f',
    OperationModeList       = 'l',
};

@interface Tag : NSObject

@property (assign, nonatomic) OperationMode operationMode;
@property (copy, nonatomic) NSArray* tags;
@property (copy, nonatomic) NSArray* URLs;

- (void)parseCommandLineArgv:(char * const *)argv argc:(int)argc;
- (void)process;

@end
