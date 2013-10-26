//
//  Tag.m
//  Tag
//
//  Created by James Berry on 10/25/13.
//
//  The MIT License (MIT)
//
//  Copyright (c) 2013 James Berry
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


/*
    tag --set tagname,tagname filename...
    tag --add tagname,tagname filename...
    tag --remove tagname,tagname filename...
    tag --match tagname,tagname filename...
    tag --find tagname,tagname
    tag --list filename
 */


#import "Tag.h"
#import <getopt.h>

@interface Tag ()

@property (strong, nonatomic) NSMetadataQuery* metadataQuery;

@end


@implementation Tag

- (void)parseCommandLineArgv:(char * const *)argv argc:(int)argc
{
    static struct option options[] = {
        // Operations
        { "set",        required_argument,      0,              OperationModeSet },
        { "add",        required_argument,      0,              OperationModeAdd },
        { "remove",     required_argument,      0,              OperationModeRemove },
        { "match",      required_argument,      0,              OperationModeMatch },
        { "find",       required_argument,      0,              OperationModeFind },
        
        { "list",       no_argument,            0,              OperationModeList },
        
        // other
        { "help",       no_argument,            0,              'h' },
        
        { 0,            0,                      0,              0 }
    };
    
    // Process Options
    int option_char;
    int option_index;
    while ((option_char = getopt_long(argc, argv, "s:a:r:m:f:lh", options, &option_index)) != -1)
    {
        switch (option_char)
        {
            case OperationModeSet:
            case OperationModeAdd:
            case OperationModeRemove:
            case OperationModeMatch:
            case OperationModeFind:
            case OperationModeList:
                if (self.operationMode)
                {
                    fprintf(stderr, "Operation mode cannot be respecified\n");
                    exit(1);
                }
                self.operationMode = option_char;
                
                if (self.operationMode != OperationModeList)
                    [self parseTagsArgument:[NSString stringWithUTF8String:optarg]];
                
                break;
                
            case 'h':
                [self displayHelp];
                break;
                
            case '?':
                break;
        }
    }
    
    // Process path names into URLs
    NSMutableArray* URLs = [NSMutableArray new];
    while (optind < argc)
        [URLs addObject:[NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[optind++]]]];
    self.URLs = URLs;
}


- (void)parseTagsArgument:(NSString*)arg
{
    // The tags arg is a comma-separated list of tags
    NSArray* components = [arg componentsSeparatedByString:@","];
    
    // Form the unique set of tags
    NSMutableSet* uniqueTags = [NSMutableSet new];
    for (NSString* component in components)
        [uniqueTags addObject:[component stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
    
    self.tags = [uniqueTags allObjects];
}


- (void)displayHelp
{
    printf("%s\n", "Sorry, there's no help for you (yet)");
}


- (void)process
{
    switch (self.operationMode)
    {
        case OperationModeSet:
            [self doSet];
            break;
            
        case OperationModeAdd:
            [self doAdd];
            break;
            
        case OperationModeRemove:
            [self doRemove];
            break;
            
        case OperationModeMatch:
            [self doMatch];
            break;
            
        case OperationModeFind:
            [self doFind];
            break;

        case OperationModeUnknown:
        case OperationModeList:
            [self doList];
            break;
    }
}


- (void)reportFatalError:(NSError*)error onURL:(NSURL*)URL
{
    NSString* programName = [NSProcessInfo processInfo].processName;
    NSString* message = [NSString stringWithFormat:@"%@: %@", programName, error.localizedDescription];
    fprintf(stderr, "%s\n", [message UTF8String]);
    exit(2);
}


- (void)doSet
{
    for (NSURL* URL in self.URLs)
    {
        NSError* error;
        if (![URL setResourceValue:self.tags forKey:NSURLTagNamesKey error:&error])
            [self reportFatalError:error onURL:URL];
    }
}


- (void)doAdd
{
    for (NSURL* URL in self.URLs)
    {
        NSError* error;
        
        // Get the existing tags
        NSArray* existingTags;
        if (![URL getResourceValue:&existingTags forKey:NSURLTagNamesKey error:&error])
            [self reportFatalError:error onURL:URL];
        
        // Form the union of the existing tags + new tags
        NSMutableSet* tagSet = [[NSMutableSet alloc] initWithArray:existingTags];
        [tagSet addObjectsFromArray:self.tags];
        
        // Set all the new tags onto the item
        if (![URL setResourceValue:[tagSet allObjects] forKey:NSURLTagNamesKey error:&error])
            [self reportFatalError:error onURL:URL];
    }
}


- (void)doRemove
{
    NSSet* tagsToRemove = [NSSet setWithArray:self.tags];
    
    for (NSURL* URL in self.URLs)
    {
        NSError* error;
        
        // Get the existing tags from the URL
        NSArray* existingTags;
        if (![URL getResourceValue:&existingTags forKey:NSURLTagNamesKey error:&error])
            [self reportFatalError:error onURL:URL];
        
        // Form a set containing difference of the existing tags - tags to remove
        NSMutableSet* tagSet = [[NSMutableSet alloc] initWithArray:existingTags];
        [tagSet minusSet:tagsToRemove];
        
        // Set the revised tags onto the item
        if (![URL setResourceValue:[tagSet allObjects] forKey:NSURLTagNamesKey error:&error])
            [self reportFatalError:error onURL:URL];
    }
}


- (void)doMatch
{
    NSSet* requiredTags = [NSSet setWithArray:self.tags];

    // Display only those items containing all the tags listed
    for (NSURL* URL in self.URLs)
    {
        NSArray* tags;
        NSError* error;

        // Get the tags on the URL
        if (![URL getResourceValue:&tags forKey:NSURLTagNamesKey error:&error])
            [self reportFatalError:error onURL:URL];
        
        NSSet* tagSet = [NSSet setWithArray:tags];
        
        // If the set of existing tags contains all of the required
        // tags then print the path
        if ([requiredTags isSubsetOfSet:tagSet])
        {
            NSString* output = [URL relativePath];
            printf("%s\n", [output UTF8String]);
        }
    }
}


- (void)doList
{
    // List the tags for each item
    for (NSURL* URL in self.URLs)
    {
        NSArray* tags;
        NSError* error;
        if (![URL getResourceValue:&tags forKey:NSURLTagNamesKey error:&error])
            [self reportFatalError:error onURL:URL];
        
        NSString* output = [NSString stringWithFormat:@"%@\t%@", [URL relativePath], [tags count] ? [tags componentsJoinedByString:@","] : @""];
        printf("%s\n", [output UTF8String]);
    }
}


- (void)doFind
{
    // Don't do a search for no tags
    if (![self.tags count])
        return;
    
    // Start a metadata search for files containing all of the given tags
    [self initiateMetadataSearchForTags:self.tags];
    
    // Enter the run loop, exiting only when the query is done
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    while (_metadataQuery && [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]])
        ;
}


- (NSPredicate*)formQueryPredicateForTags:(NSArray*)tags
{
    NSAssert([tags count], @"Assumes there are tags to query for");
    
    NSPredicate* result;
    
    if ([tags count] == 1)
    {
        result = [NSPredicate predicateWithFormat:@"kMDItemUserTags == %@", tags[0]];
    }
    else
    {
        NSMutableArray* subpredicates = [NSMutableArray new];
        for (NSString* tag in tags)
            [subpredicates addObject:[NSPredicate predicateWithFormat:@"kMDItemUserTags == %@", tag]];
        
        result = [NSCompoundPredicate andPredicateWithSubpredicates:subpredicates];
    }
    
    return result;
}


// Initialize Search Method
- (void)initiateMetadataSearchForTags:(NSArray*)tags
{
    // Create the metadata query instance. The metadataSearch @property is
    // declared as retain
    self.metadataQuery=[[NSMetadataQuery alloc] init];
    
    // Register the notifications for batch and completion updates
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(queryDidUpdate:)
                                                 name:NSMetadataQueryDidUpdateNotification
                                               object:_metadataQuery];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(queryComplete:)
                                                 name:NSMetadataQueryDidFinishGatheringNotification
                                               object:_metadataQuery];
    
    // Configure the search predicate to
    NSPredicate *searchPredicate = [self formQueryPredicateForTags:tags];
    [_metadataQuery setPredicate:searchPredicate];
    
    // Set the search scope
    NSArray *searchScopes = @[NSMetadataQueryLocalComputerScope];
    [_metadataQuery setSearchScopes:searchScopes];
    
    // Configure the sorting of the results so it will order the results by the
    // display name
    NSSortDescriptor *sortKeys = [[NSSortDescriptor alloc] initWithKey:(id)kMDItemPath
                                                             ascending:YES];
    [_metadataQuery setSortDescriptors:[NSArray arrayWithObject:sortKeys]];
    
    // Ask the query to send notifications on the main thread, which will
    // ensure we process them on the main thread, and will also ensure that our
    // main thread is kicked so that the run loop will iterate and thus complete.
    [_metadataQuery setOperationQueue:[NSOperationQueue mainQueue]];

    // Begin the asynchronous query
    [_metadataQuery startQuery];
}


// Method invoked when notifications of content batches have been received
- (void)queryDidUpdate:sender;
{
}


// Method invoked when the initial query gathering is completed
- (void)queryComplete:sender;
{
    // Stop the query, the single pass is completed.
    [_metadataQuery stopQuery];
    
    // Print the results from the query
    for (NSUInteger i = 0; i < [_metadataQuery resultCount]; i++) {
        NSMetadataItem *theResult = [_metadataQuery resultAtIndex:i];
        
        // kMDItemPath, kMDItemDisplayName
        NSString *path = [theResult valueForAttribute:(NSString *)kMDItemPath];
        
        printf("%s\n", [path UTF8String]);
    }
    
    // Remove the notification observers
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSMetadataQueryDidUpdateNotification
                                                  object:_metadataQuery];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSMetadataQueryDidFinishGatheringNotification
                                                  object:_metadataQuery];
    
    // Remove the query, also serving as a semaphore that we want to
    // exit our RunLoop loop.
    self.metadataQuery = nil;
}


@end
