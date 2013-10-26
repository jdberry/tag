//
//  main.m
//  Tag
//
//  Created by James Berry on 10/25/13.
//  Copyright (c) 2013 Culinate, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "Tag.h"

int main(int argc, char * const argv[])
{
    @autoreleasepool {
        Tag* tag = [Tag new];
        
        [tag parseCommandLineArgv:argv argc:argc];
        [tag process];
    }
    return 0;
}

