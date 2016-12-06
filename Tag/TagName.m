//
//  TagName.m
//  Tag
//
//  Created by James Berry on 11/1/13.
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

#import "TagName.h"

@implementation TagName

- (instancetype)initWithTag:(NSString*)tag
{
    self = [super init];
    if (self)
    {
        _visibleName = [tag copy];
        _comparableName = [_visibleName lowercaseString];
    }
    return self;
}


- (BOOL)isEqualToTagName:(TagName*)tagName
{
    return [self.comparableName isEqualToString:tagName.comparableName];
}


- (BOOL)isEqual:(id)obj
{
    if (obj == self)
        return YES;
    if (!obj || ![obj isKindOfClass:[self class]])
        return NO;
    return [self isEqualToTagName:obj];
}


- (NSUInteger)hash
{
    return [self.comparableName hash];
}


@end
