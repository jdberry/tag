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
 
    additional options:
        --name, --no-name           Override the display of filenames in output for the operation
        --tags, --no-tags           Override the display of tags in output for the operation
        --garrulous, --no-garrulous Override the garrulous formatting of tags (each on own line)
        --home                      Find files only within the user home directory
        --local                     Find files only within the home directory and on local filesystems
        --network                   Additionally, find files on attached remove filesystems
        --nul                       Terminate lines with NUL (\0) for use with xargs -0
        --version                   Display the version
        --help                      Display help
 */


#import "Tag.h"
#import "TagName.h"
#import <getopt.h>

NSString* const version = @"0.7.3";

NSString* const kMDItemUserTags = @"kMDItemUserTags";


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


- (OutputFlags)outputFlagsForMode:(OperationMode)mode
{
    OutputFlags result = 0;
    switch (mode)
    {
        case OperationModeMatch:
        case OperationModeFind:
            result = OutputFlagsName;
            break;
        case OperationModeList:
            result = OutputFlagsName | OutputFlagsTags;
            break;
        default:
            break;
    }
    return result;
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
        
        // Format options
        { "name",       no_argument,            0,              'n' },
        { "no-name",    no_argument,            0,              'N' },
        { "tags",       no_argument,            0,              't' },
        { "no-tags",    no_argument,            0,              'T' },
        { "garrulous",  no_argument,            0,              'g' },
        { "no-garrulous", no_argument,          0,              'G' },
        { "nul",        no_argument,            0,              '0' },
        
        // Search Scope
        { "home",       no_argument,            0,              'H' },
        { "local",      no_argument,            0,              'L' },
        { "network",    no_argument,            0,              'R' },

        // other
        { "help",       no_argument,            0,              'h' },
        { "version",    no_argument,            0,              'v' },
        
        { 0,            0,                      0,              0 }
    };
    
    // Initialize to a known state
    self.operationMode = OperationModeUnknown;
    self.outputFlags = 0;
    self.searchScope = SearchScopeLocal;
    
    self.tags = nil;
    self.URLs = nil;
    
    int name_flag = 0;
    int tags_flag = 0;
    int garrulous_flag = 0;
    BOOL nulTerminate = NO;
    
    // Parse Options
    int option_char;
    int option_index;
    while ((option_char = getopt_long(argc, argv, "s:a:r:m:f:lnNtTgG0hv", options, &option_index)) != -1)
    {
        switch (option_char)
        {
            case OperationModeSet:
            case OperationModeAdd:
            case OperationModeRemove:
            case OperationModeMatch:
            case OperationModeFind:
            case OperationModeList:
            {
                if (self.operationMode)
                {
                    FPrintf(stderr, @"%@: Operation mode cannot be respecified\n", [self programName]);
                    exit(1);
                }
                self.operationMode = option_char;
                
                if (self.operationMode != OperationModeList)
                    [self parseTagsArgument:[NSString stringWithUTF8String:optarg]];
                
                break;
            }
                
            case 'n':
                name_flag = 2;
                break;
            case 'N':
                name_flag = 1;
                break;
                
            case 't':
                tags_flag = 2;
                break;
            case 'T':
                tags_flag = 1;
                break;
                
            case 'g':
                garrulous_flag = 2;
                break;
            case 'G':
                garrulous_flag = 1;
                break;
                
            case 'H':
                _searchScope = SearchScopeHome;
                break;
            case 'L':
                _searchScope = SearchScopeLocal;
                break;
            case 'R':
                _searchScope = SearchScopeNetwork;
                break;
                
            case '0':
                nulTerminate = YES;
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
    
    // If the operation wasn't set, default to list
    if (self.operationMode == OperationModeUnknown)
        self.operationMode = OperationModeList;
    
    // Set default output flags for the chosen operation
    _outputFlags = [self outputFlagsForMode:self.operationMode];
    
    // Override the output flags if they were explicitly set on command line
    if (name_flag)
        _outputFlags = (_outputFlags & ~OutputFlagsName) | ((name_flag - 1) * OutputFlagsName);
    if (tags_flag)
        _outputFlags = (_outputFlags & ~OutputFlagsTags) | ((tags_flag - 1) * OutputFlagsTags);
    if (garrulous_flag)
        _outputFlags = (_outputFlags & ~OutputFlagsGarrulous) | ((garrulous_flag - 1) * OutputFlagsGarrulous);
    
    if (nulTerminate)
        _outputFlags |= OutputFlagsNulTerminate;
    
    // Process any remaining arguments as pathnames, converting into URLs
    [self parseFilenameArguments:&argv[optind] argc:argc - optind];
}


- (void)parseFilenameArguments:(char * const *)argv argc:(int)argc
{
    NSMutableArray* URLs = [NSMutableArray new];
    for (int arg = 0; arg < argc; ++arg)
    {
        // Get the path
        NSString* path = [NSString stringWithUTF8String:argv[arg]];
        
        // Trim path; ignore empty parameters
        NSString* trimmed = [path stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (![trimmed length])
            continue;
        
        // Add the URL to our array of URLs to process
        NSURL* URL = [NSURL fileURLWithPath:trimmed];
        if (!URL)
        {
            FPrintf(stderr, @"%@: Can't form a URL from path %@\n", [self programName], trimmed);
            exit(3);
        }
        [URLs addObject:URL];
    }
    self.URLs = URLs;
}


- (void)parseTagsArgument:(NSString*)arg
{
    // The tags arg is a comma-separated list of tags
    NSArray* components = [arg componentsSeparatedByString:@","];
    
    // Form the unique set of tags
    NSMutableSet* uniqueTags = [NSMutableSet new];
    for (NSString* component in components)
    {
        NSString* trimmed = [component stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if ([trimmed length])
            [uniqueTags addObject:[[TagName alloc] initWithTag:trimmed]];
    }
    
    self.tags = uniqueTags;
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
           "    tag -a | --add <tags> <file>...     Add tags to file\n"
           "    tag -r | --remove <tags> <file>...  Remove tags from file\n"
           "    tag -s | --set <tags> <file>...     Set tags on file\n"
           "    tag -m | --match <tags> <file>...   Display files with matching tags\n"
           "    tag -l | --list <file>...           List the tags on file\n"
           "    tag -f | --find <tags>              Find all files with tags\n"
           "  <tags> is a comma-separated list of tag names; use * to match/find any tag.\n"
           "  additional options:\n"
           "        -v | --version      Display version\n"
           "        -h | --help         Display this help\n"
           "        -n | --name         Turn on filename display in output (default)\n"
           "        -N | --no-name      Turn off filename display in output (list)\n"
           "        -t | --tags         Turn on tags display in output (find, match)\n"
           "        -T | --no-tags      Turn off tags display in output (list)\n"
           "        -g | --garrulous    Display tags each on own line (list, find, match)\n"
           "        -G | --no-garrulous Display tags comma-separated after filename (default)\n"
           "        -H | --home         Find tagged files only in user home directory\n"
           "        -L | --local        Find tagged files only in home + local filesystems (default)\n"
           "        -R | --network      Find tagged files in home + local + network filesystems\n"
           "        -0 | --nul          Terminate lines with NUL (\\0) for use with xargs -0\n"
    );
}


- (void)performOperation
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

        case OperationModeList:
            [self doList];
            break;
            
        case OperationModeUnknown:
            break;
    }
}


- (void)reportFatalError:(NSError*)error onURL:(NSURL*)URL
{
    FPrintf(stderr, @"%@: %@\n", [self programName], error.localizedDescription);
    exit(2);
}


- (NSString*)string:(NSString*)s paddedToMinimumLength:(int)minLength
{
    NSInteger length = [s length];
    if (length >= minLength)
        return s;
    
    return [s stringByPaddingToLength:minLength withString:@"    " startingAtIndex:0];
}


- (void)emitURL:(NSURL*)URL tags:(NSArray*)tagArray
{
    NSString* fileName = (_outputFlags & OutputFlagsName) ? [URL relativePath] : nil;
    BOOL tagsOnSeparateLines = !!(_outputFlags & OutputFlagsGarrulous);
    BOOL printTags = (_outputFlags & OutputFlagsTags) && [tagArray count];
    char lineTerminator = (_outputFlags & OutputFlagsNulTerminate) ? '\0' : '\n';

    if (fileName)
    {
        int minFileFieldWidth = tagsOnSeparateLines ? 0 : 31;
        NSString* fileField = [self string:fileName paddedToMinimumLength:minFileFieldWidth];
        Printf(@"%@", fileField);
    }
    
    if (printTags)
    {
        BOOL needLineTerm = NO;
        NSArray* sortedTags = [tagArray sortedArrayUsingSelector:@selector(compare:)];
    
        NSString* tagSeparator;
        NSString* startingSepator;
        if (tagsOnSeparateLines)
        {
            needLineTerm = !!fileName;
            tagSeparator = fileName ? @"    " : @"";
            startingSepator = tagSeparator;
        }
        else
        {
            tagSeparator = @",";
            startingSepator = fileName ? @"\t" : @"";
        }
        
        NSString* sep = startingSepator;
        for (NSString* tag in sortedTags)
        {
            if (needLineTerm)
                putc(lineTerminator, stdout);
            Printf(@"%@%@", sep, tag);
            sep = tagSeparator;
            needLineTerm = tagsOnSeparateLines;
        }
    }
    
    if (fileName || printTags)
        putc(lineTerminator, stdout);
}


- (BOOL)wildcardInTagSet:(NSSet*)set
{
    static TagName* wildcard;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        wildcard = [[TagName alloc] initWithTag:@"*"];
    });
    return [set containsObject:wildcard];
}


- (NSMutableSet*)tagSetFromArrayOfTags:(NSArray*)tagArray
{
    NSMutableSet* set = [[NSMutableSet alloc] initWithCapacity:[tagArray count]];
    for (NSString* tag in tagArray)
        [set addObject:[[TagName alloc] initWithTag:tag]];
    return set;
}


- (NSArray*)tagArrayFromTagSet:(NSSet*)tagSet
{
    NSMutableArray* array = [[NSMutableArray alloc] initWithCapacity:[tagSet count]];
    for (TagName* tag in tagSet)
        [array addObject:tag.visibleName];
    return array;
}


- (void)doSet
{
    NSArray* tagArray = [self tagArrayFromTagSet:self.tags];
    for (NSURL* URL in self.URLs)
    {
        NSError* error;
        if (![URL setResourceValue:tagArray forKey:NSURLTagNamesKey error:&error])
            [self reportFatalError:error onURL:URL];
    }
}


- (void)doAdd
{
    if (![self.tags count])
        return;
    
    for (NSURL* URL in self.URLs)
    {
        @autoreleasepool {
            NSError* error;
            
            // Get the existing tags
            NSArray* existingTags;
            if (![URL getResourceValue:&existingTags forKey:NSURLTagNamesKey error:&error])
                [self reportFatalError:error onURL:URL];
            
            // Form the union of the existing tags + new tags.
            NSMutableSet* tagSet = [self tagSetFromArrayOfTags:existingTags];
            [tagSet unionSet:self.tags];
            
            // Set all the new tags onto the item
            if (![URL setResourceValue:[self tagArrayFromTagSet:tagSet] forKey:NSURLTagNamesKey error:&error])
                [self reportFatalError:error onURL:URL];
        }
    }
}


- (void)doRemove
{
    if (![self.tags count])
        return;
    
    BOOL matchAny = [self wildcardInTagSet:self.tags];
    
    for (NSURL* URL in self.URLs)
    {
        @autoreleasepool {
            NSError* error;
            
            // Get the existing tags from the URL
            NSArray* existingTags;
            if (![URL getResourceValue:&existingTags forKey:NSURLTagNamesKey error:&error])
                [self reportFatalError:error onURL:URL];
            
            // Form a set containing difference of the existing tags - tags to remove
            NSMutableSet* tagSet = [self tagSetFromArrayOfTags:existingTags];
            if (matchAny)
                [tagSet removeAllObjects];
            else
                [tagSet minusSet:self.tags];
            
            // Set the revised tags onto the item
            if (![URL setResourceValue:[self tagArrayFromTagSet:tagSet] forKey:NSURLTagNamesKey error:&error])
                [self reportFatalError:error onURL:URL];
        }
    }
}


- (void)doMatch
{
    BOOL matchAny = [self wildcardInTagSet:self.tags];

    // Display only those items containing all the tags listed
    for (NSURL* URL in self.URLs)
    {
        @autoreleasepool {
            NSError* error;
            
            // Get the tags on the URL
            NSArray* tagArray;
            if (![URL getResourceValue:&tagArray forKey:NSURLTagNamesKey error:&error])
                [self reportFatalError:error onURL:URL];
            
            // If the set of existing tags contains all of the required
            // tags then print the path
            if ((matchAny && [tagArray count]) || [self.tags isSubsetOfSet:[self tagSetFromArrayOfTags:tagArray]])
                [self emitURL:URL tags:tagArray];
        }
    }
}


- (void)doList
{
    // List the tags for each item
    for (NSURL* URL in self.URLs)
    {
        @autoreleasepool {
            NSError* error;
            NSArray* tagArray;
            if (![URL getResourceValue:&tagArray forKey:NSURLTagNamesKey error:&error])
                [self reportFatalError:error onURL:URL];
            
            [self emitURL:URL tags:tagArray];
        }
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


- (NSPredicate*)formQueryPredicateForTags:(NSSet*)tagSet
{
    NSAssert([tagSet count], @"Assumes there are tags to query for");
    
    // Note for future: the following can be used to search for files that have
    // no tags: [NSPredicate predicateWithFormat:@"NOT %K LIKE '*'", kMDItemUserTags]
    
    NSPredicate* result;
    if ([self wildcardInTagSet:tagSet])
    {
        result = [NSPredicate predicateWithFormat:@"%K LIKE '*'", kMDItemUserTags];
    }
    else if ([tagSet count] == 1)
    {
        result = [NSPredicate predicateWithFormat:@"%K ==[c] %@", kMDItemUserTags, ((TagName*)tagSet.anyObject).visibleName];
    }
    else
    {
        NSMutableArray* subpredicates = [NSMutableArray new];
        for (TagName* tag in tagSet)
            [subpredicates addObject:[NSPredicate predicateWithFormat:@"%K ==[c] %@", kMDItemUserTags, tag.visibleName]];
        result = [NSCompoundPredicate andPredicateWithSubpredicates:subpredicates];
    }
    
    return result;
}


- (NSArray*)searchScopesFromSearchScope:(SearchScope)scope
{
    NSArray* result;
    switch (scope)
    {
        case SearchScopeHome:
            result = @[NSMetadataQueryUserHomeScope];
            break;
        case SearchScopeLocal:
            result = @[NSMetadataQueryLocalComputerScope];
            break;
        case SearchScopeNetwork:
            result = @[NSMetadataQueryLocalComputerScope,NSMetadataQueryNetworkScope];
            break;
    }
    return result;
}


- (void)initiateMetadataSearchForTags:(NSSet*)tagSet
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
    NSPredicate *searchPredicate = [self formQueryPredicateForTags:tagSet];
    [_metadataQuery setPredicate:searchPredicate];
    
    // Set the search scope
    NSArray *searchScopes = [self searchScopesFromSearchScope:self.searchScope];
    [_metadataQuery setSearchScopes:searchScopes];
    
    // Configure the sorting of the results
    // (note that the query can't sort by the item path, which makes sorting less usefull)
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
    for (NSUInteger i = 0; i < [_metadataQuery resultCount]; i++)
    {
        @autoreleasepool {
            NSMetadataItem* theResult = [_metadataQuery resultAtIndex:i];
            NSString* path = [theResult valueForAttribute:(NSString *)kMDItemPath];
            if (path)
            {
                NSURL* URL = [NSURL fileURLWithPath:path];
                NSArray* tagArray = [theResult valueForAttribute:kMDItemUserTags];
                
                [self emitURL:URL tags:tagArray];
            }
        }
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
