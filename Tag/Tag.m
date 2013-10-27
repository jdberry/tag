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
 
    tag --version
    tag --help
 */

/*
    Maybe:
        --find should be able to find all files with tags, even if the tags aren't specified?
        --find should list the tags on the files it finds?
 */


#import "Tag.h"
#import <getopt.h>


NSString* const version = @"0.5.1";


@interface Tag ()

@property (strong, nonatomic) NSMetadataQuery* metadataQuery;

@end


@implementation Tag


static void FPrintf(FILE* f, NSString* fmt, ...) __attribute__ ((format(__NSString__, 2, 3)));
static void Printf(NSString* fmt, ...) __attribute__ ((format(__NSString__, 1, 2)));


static void FPrintf(FILE* f, NSString* fmt, ...)
{
    va_list ap;
    va_start (ap, fmt);
    NSString *output = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end (ap);
    fprintf(f, "%s", [output UTF8String]);
}


static void Printf(NSString* fmt, ...)
{
    va_list ap;
    va_start (ap, fmt);
    NSString *output = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end (ap);
    printf("%s", [output UTF8String]);
}



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
        { "version",    no_argument,            0,              'v' },
        
        { 0,            0,                      0,              0 }
    };
    
    // Process Options
    int option_char;
    int option_index;
    while ((option_char = getopt_long(argc, argv, "s:a:r:m:f:lhv", options, &option_index)) != -1)
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
                    FPrintf(stderr, @"Operation mode cannot be respecified\n");
                    exit(1);
                }
                self.operationMode = option_char;
                
                if (self.operationMode != OperationModeList)
                    [self parseTagsArgument:[NSString stringWithUTF8String:optarg]];
                
                break;
                
            case 'h':
                [self displayHelp];
                break;
                
            case 'v':
                [self displayVersion];
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


- (NSString*)programName
{
    return [NSProcessInfo processInfo].processName;
}


- (void)displayVersion
{
    Printf(@"%@ v%@\n", [self programName], version);
}


- (void)displayHelp
{
    Printf(@"%@ - %@", [self programName], @"A tool for manipulating and querying file tags.\n"
           "  usage:\n"
           "    tag -v | --version                  Version information\n"
           "    tag -h | --help                     Display this help\n"
           "    tag -a | --add <tags> <file>...     Add tags to file\n"
           "    tag -r | --remove <tags> <file>...  Remove tags from file\n"
           "    tag -s | --set <tags> <file>...     Set tags on file\n"
           "    tag -m | --match <tags> <file>...   Display files with matching tags\n"
           "    tag -l | --list <file>...           List the tags on file\n"
           "    tag -f | --find <tags>              Find all files with tags\n"
           "  <tags> is be a comma-separated list of tag names.\n"
    );
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
    FPrintf(stderr, @"%@: %@", [self programName], error.localizedDescription);
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
        NSError* error;

        // Get the tags on the URL
        NSArray* tags;
        if (![URL getResourceValue:&tags forKey:NSURLTagNamesKey error:&error])
            [self reportFatalError:error onURL:URL];
        
        NSSet* tagSet = [NSSet setWithArray:tags];
        
        // If the set of existing tags contains all of the required
        // tags then print the path
        if ([requiredTags isSubsetOfSet:tagSet])
            Printf(@"%@\n", [URL relativePath]);
    }
}


- (NSString*)string:(NSString*)s paddedToMinimumLength:(int)minLength
{
    NSInteger length = [s length];
    if (length >= minLength)
        return s;
    
    return [s stringByPaddingToLength:minLength withString:@"    " startingAtIndex:0];
}


- (void)doList
{
    // List the tags for each item
    for (NSURL* URL in self.URLs)
    {
        NSError* error;
        NSArray* tags;
        if (![URL getResourceValue:&tags forKey:NSURLTagNamesKey error:&error])
            [self reportFatalError:error onURL:URL];
        
        // Canonicalize the tag order
        tags = [tags sortedArrayUsingSelector:@selector(compare:)];
        
        NSString* tagString = [tags count] ? [tags componentsJoinedByString:@","] : @"";
        NSString* fileName = [URL relativePath];

        // Print the file and tags, with a generally fixed field format for the filename
        NSString* fileField = [self string:fileName paddedToMinimumLength:31];
        Printf(@"%@\t%@\n", fileField, tagString);
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


- (void)initiateMetadataSearchForTags:(NSArray*)tags
{
    // Create the metadata query instance
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
    
    // Configure the search predicate
    NSPredicate *searchPredicate = [self formQueryPredicateForTags:tags];
    [_metadataQuery setPredicate:searchPredicate];
    
    // Set the search scope
    NSArray *searchScopes = @[NSMetadataQueryLocalComputerScope];
    [_metadataQuery setSearchScopes:searchScopes];
    
    // Configure the sorting of the results
    // (note that the query can't sort by the item path, which likely makes this useless)
    NSSortDescriptor *sortKeys = [[NSSortDescriptor alloc] initWithKey:(id)kMDItemDisplayName
                                                             ascending:YES];
    [_metadataQuery setSortDescriptors:[NSArray arrayWithObject:sortKeys]];
    
    // Ask the query to send notifications on the main thread, which will
    // ensure we process them on the main thread, and will also ensure that our
    // main thread is kicked so that the run loop will iterate and thus complete.
    [_metadataQuery setOperationQueue:[NSOperationQueue mainQueue]];

    // Begin the asynchronous query
    [_metadataQuery startQuery];
}


- (void)queryDidUpdate:sender;
{
}


- (void)queryComplete:sender;
{
    // Stop the query, the single pass is completed.
    [_metadataQuery stopQuery];
    
    // Print results from the query
    for (NSUInteger i = 0; i < [_metadataQuery resultCount]; i++) {
        NSMetadataItem *theResult = [_metadataQuery resultAtIndex:i];
        
        // kMDItemPath, kMDItemDisplayName
        NSString *path = [theResult valueForAttribute:(NSString *)kMDItemPath];
        Printf(@"%@\n", path);
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
