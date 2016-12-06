//
//  Tag.h
//  Tag
//
//  Created by James Berry on 10/25/13.
//
//  The MIT License (MIT)
//
//  Copyright (c) 2013-2016 James Berry
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of
//  this software and associated documentation files (the "Software"), to deal in
//  the Software without restriction, including without limitation the rights to
//  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
//  the Software, and to permit persons to whom the Software is furnished to do so,
//  subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
//  FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
//  COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//  IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(int, OperationMode) {
    OperationModeNone       = -1,
    OperationModeUnknown    = 0,
    OperationModeSet        = 's',
    OperationModeAdd        = 'a',
    OperationModeRemove     = 'r',
    OperationModeMatch      = 'm',
    OperationModeFind       = 'f',
    OperationModeList       = 'l',
};

typedef NS_OPTIONS(int, OutputFlags) {
    OutputFlagsName         = (1 << 0),
    OutputFlagsTags         = (1 << 1),
    OutputFlagsGarrulous    = (1 << 2),
    OutputFlagsNulTerminate = (1 << 3),
};

typedef NS_ENUM(int, SearchScope) {
    SearchScopeNone         = 0,
    SearchScopeHome,
    SearchScopeLocal,
    SearchScopeNetwork,
};

@interface Tag : NSObject

@property (assign, nonatomic) OperationMode operationMode;
@property (assign, nonatomic) OutputFlags outputFlags;
@property (assign, nonatomic) SearchScope searchScope;

@property (assign, nonatomic) BOOL displayAllFiles;     // Display all (hidden files)
@property (assign, nonatomic) BOOL recurseDirectories;  // Enter/enumerate directories
@property (assign, nonatomic) BOOL enterDirectories;    // Recursively process any directory we encounter

@property (copy, nonatomic) NSSet* tags;
@property (copy, nonatomic) NSArray* URLs;

- (void)parseCommandLineArgv:(char * const *)argv argc:(int)argc;
- (void)performOperation;

@end
