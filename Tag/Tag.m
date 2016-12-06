//
//  Tag.m
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


/*
    tag --set <tags> <path>...
    tag --add <tags> <path>...
    tag --remove <tags> <path>...
    tag --match <tags> <path>...
    tag --find <tags> <path>...
    tag --list <path>...
 
    additional options:
        --all                       While enumerating, evaluate hidden (as well as non-hidden) files/directories
        --enter                     Enter and enumerate directories provided
        --recursive                 Recursively enumerate directories provided
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


/*
 TODO:
 
    Potential simple boolean tag query:
 
        foo OR bar
        foo,bar         -- comma same as AND
        foo AND bar
        NOT foo
        foo,bar AND baz
        foo,bar OR baz
        foo,bar AND NOT biz,baz
        *               -- Some tag
        <empty expr>    -- No tag
        
        support glob patterns?
        support queries for both match and find?
 
        Use NSPredicate for both find and match?
 */


#import "Tag.h"
#import "TagName.h"
#import <getopt.h>

NSString* const version = @"0.9.0";

// This constant doesn't seem to be defined in MDItem.h, so we define it here
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
    
    
typedef NS_ENUM(int, CommandCode) {
    CommandCodeHome     = 1000,
    CommandCodeLocal,
    CommandCodeNetwork
};


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
        
        // Directory Enumeration Options
        { "all",        no_argument,            0,              'A' },  // Display all (hidden files)
        { "enter",      no_argument,            0,              'e' },  // Enter/enumerate directories: enumerate contents of provided directories
        { "recursive",  no_argument,            0,              'R' },  // Recursively process any directory we encounter
        { "descend",    no_argument,            0,              'd' },  // Recursively process any directory we encounter (alias for backwards compatibility)
        
        // Format options
        { "name",       no_argument,            0,              'n' },
        { "no-name",    no_argument,            0,              'N' },
        { "tags",       no_argument,            0,              't' },
        { "no-tags",    no_argument,            0,              'T' },
        { "garrulous",  no_argument,            0,              'g' },
        { "no-garrulous", no_argument,          0,              'G' },
        { "nul",        no_argument,            0,              '0' },
        
        // Search Scope
        { "home",       no_argument,            0,              CommandCodeHome },
        { "local",      no_argument,            0,              CommandCodeLocal },
        { "network",    no_argument,            0,              CommandCodeNetwork },

        // other
        { "help",       no_argument,            0,              'h' },
        { "version",    no_argument,            0,              'v' },
        
        { 0,            0,                      0,              0 }
    };
    
    // Initialize to a known state
    self.operationMode = OperationModeUnknown;
    self.outputFlags = 0;
    self.searchScope = SearchScopeNone;
    
    self.displayAllFiles = NO;
    self.recurseDirectories = NO;
    self.enterDirectories = NO;
    
    self.tags = nil;
    self.URLs = nil;
    
    int name_flag = 0;
    int tags_flag = 0;
    int garrulous_flag = 0;
    BOOL nulTerminate = NO;
    
    // Parse Options
    int option_char;
    int option_index;
    while ((option_char = getopt_long(argc, argv, "s:a:r:m:f:lAeRdnNtTgG0hv", options, &option_index)) != -1)
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
                
            case 'A':
                _displayAllFiles = YES;
                break;
            case 'e':
                _enterDirectories = YES;
                break;
            case 'R':
            case 'd':       // -d is a backward compatibility alias for -R
                _recurseDirectories = YES;
                break;
                
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
                
            case CommandCodeHome:
                _searchScope = SearchScopeHome;
                break;
            case CommandCodeLocal:
                _searchScope = SearchScopeLocal;
                break;
            case CommandCodeNetwork:
                _searchScope = SearchScopeNetwork;
                break;
                
            case '0':
                nulTerminate = YES;
                break;

            case 'h':
                _operationMode = OperationModeNone;
                [self displayHelp];
                break;
                
            case 'v':
                _operationMode = OperationModeNone;
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
        // Get the path, ignoring empty paths
        NSString* path = [NSString stringWithUTF8String:argv[arg]];
        if (![path length])
            continue;
        
        // Add the URL to our array of URLs to process
        NSURL* URL = [NSURL fileURLWithPath:path];
        if (!URL)
        {
            FPrintf(stderr, @"%@: Can't form a URL from path %@\n", [self programName], path);
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
           "    tag -a | --add <tags> <path>...     Add tags to file\n"
           "    tag -r | --remove <tags> <path>...  Remove tags from file\n"
           "    tag -s | --set <tags> <path>...     Set tags on file\n"
           "    tag -m | --match <tags> <path>...   Display files with matching tags\n"
           "    tag -l | --list <path>...           List the tags on file\n"
           "    tag -f | --find <tags> <path>...    Find all files with tags (-A, -e, -R ignored)\n"
           "  <tags> is a comma-separated list of tag names; use * to match/find any tag.\n"
           "  additional options:\n"
           "        -v | --version      Display version\n"
           "        -h | --help         Display this help\n"
           "        -A | --all          Display invisible files while enumerating\n"
           "        -e | --enter        Enter and enumerate directories provided\n"
           "        -R | --recursive    Recursively process directories\n"
           "        -n | --name         Turn on filename display in output (default)\n"
           "        -N | --no-name      Turn off filename display in output (list, find, match)\n"
           "        -t | --tags         Turn on tags display in output (find, match)\n"
           "        -T | --no-tags      Turn off tags display in output (list)\n"
           "        -g | --garrulous    Display tags each on own line (list, find, match)\n"
           "        -G | --no-garrulous Display tags comma-separated after filename (default)\n"
           "        -H | --home         Find tagged files in user home directory\n"
           "        -L | --local        Find tagged files in home + local filesystems\n"
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
            
        case OperationModeNone:
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
        BOOL padFileField = printTags && !tagsOnSeparateLines;
        NSString* fileField = padFileField ? [self string:fileName paddedToMinimumLength:31] : fileName;
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
    TagName* wildcard = [[TagName alloc] initWithTag:@"*"];
    return [set containsObject:wildcard];
}


- (NSMutableSet*)tagSetFromTagArray:(NSArray*)tagArray
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


- (void)enumerateDirectory:(NSURL*)directoryURL withBlock:(void (^)(NSURL *URL))block
{
    NSURL* baseURL = directoryURL;
    
    NSInteger enumerationOptions = 0;
    if (!_displayAllFiles)
        enumerationOptions |= NSDirectoryEnumerationSkipsHiddenFiles;
    if (!_recurseDirectories)
        enumerationOptions |= NSDirectoryEnumerationSkipsSubdirectoryDescendants;
    
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSDirectoryEnumerator* enumerator = [fileManager enumeratorAtURL:baseURL
                                          includingPropertiesForKeys:@[]
                                                             options:enumerationOptions
                                                        errorHandler:nil];
    
    NSString* baseURLString = [baseURL absoluteString];
    for (NSObject* obj in enumerator)
    {
        @autoreleasepool {
            NSURL* fullURL = (NSURL*)obj;
            
            // The directory enumerator returns full URLs, not partial URLs, which are what we really want.
            // So remake the URL as a partial URL if possible
            NSURL* URL = fullURL;
            NSString* fullURLString = [fullURL absoluteString];
            if ([fullURLString hasPrefix:baseURLString])
            {
                NSString* relativePart = [fullURLString substringFromIndex:[baseURLString length]];
                URL = [NSURL URLWithString:relativePart relativeToURL:baseURL];
            }
            
            block(URL);
        }
    }
}


- (void)enumerateURLsWithBlock:(void (^)(NSURL *URL))block
{
    if (!block)
        return;
    
    NSFileManager* fileManager = [NSFileManager defaultManager];
    
    if ([self.URLs count] == 0)
    {
        // No URLs were provided on the command line; enumerate the current directory
        NSURL* currentDirectoryURL = [NSURL fileURLWithPath:[fileManager currentDirectoryPath]];
        [self enumerateDirectory:currentDirectoryURL withBlock:block];
    }
    else
    {
        // Process URLs provided on the command line
        for (NSURL* URL in self.URLs)
        {
            @autoreleasepool {
                // Invoke the block
                block(URL);
                
                // If we want to enter or recurse directories then do so
                // if we have a directory
                if (_enterDirectories || _recurseDirectories)
                {
                    NSNumber* isDir = nil;
                    [URL getResourceValue:&isDir forKey:NSURLIsDirectoryKey error:nil];
                    if ([isDir boolValue])
                        [self enumerateDirectory:URL withBlock:block];
                }
            }
        }
    }
}


- (void)doSet
{
    // Only perform set on specified URLs
    // (we don't implicitly enumerate the current directory)
    if ([self.URLs count] == 0)
        return;
    
    // Enumerate the provided URLs, setting tags on each
    // --all, --enter, and --recursive apply
    NSArray* tagArray = [self tagArrayFromTagSet:self.tags];
    [self enumerateURLsWithBlock:^(NSURL *URL) {
        NSError* error;
        if (![URL setResourceValue:tagArray forKey:NSURLTagNamesKey error:&error])
            [self reportFatalError:error onURL:URL];
    }];
}


- (void)doAdd
{
    // If there are no tags to add, we're done
    if (![self.tags count])
        return;
    
    // Only perform add on specified URLs
    // (we don't implicitly enumerate the current directory)
    if ([self.URLs count] == 0)
        return;

    // Enumerate the provided URLs, adding tags to each
    // --all, --enter, and --recursive apply
    [self enumerateURLsWithBlock:^(NSURL *URL) {
        NSError* error;
        
        // Get the existing tags
        NSArray* existingTags;
        if (![URL getResourceValue:&existingTags forKey:NSURLTagNamesKey error:&error])
            [self reportFatalError:error onURL:URL];
        
        // Form the union of the existing tags + new tags.
        NSMutableSet* tagSet = [self tagSetFromTagArray:existingTags];
        [tagSet unionSet:self.tags];
        
        // Set all the new tags onto the item
        if (![URL setResourceValue:[self tagArrayFromTagSet:tagSet] forKey:NSURLTagNamesKey error:&error])
            [self reportFatalError:error onURL:URL];
    }];
}


- (void)doRemove
{
    // If there are no tags to remove, we're done
    if (![self.tags count])
        return;
    
    // Only perform remove on specified URLs
    // (we don't implicitly enumerate the current directory)
    if ([self.URLs count] == 0)
        return;
    
    BOOL matchAny = [self wildcardInTagSet:self.tags];
    
    // Enumerate the provided URLs, removing tags from each
    // --all, --enter, and --recursive apply
    [self enumerateURLsWithBlock:^(NSURL *URL) {
        NSError* error;
        
        // Get existing tags from the URL
        NSArray* existingTags;
        if (![URL getResourceValue:&existingTags forKey:NSURLTagNamesKey error:&error])
            [self reportFatalError:error onURL:URL];
        
        // Form the revised array of tags
        NSArray* revisedTags;
        if (matchAny)
        {
            // We matched the wildcard, so remove all tags from the item
            revisedTags = [[NSArray alloc] init];
        }
        else
        {
            // Existing tags minus tags to remove
            NSMutableSet* tagSet = [self tagSetFromTagArray:existingTags];
            [tagSet minusSet:self.tags];
            revisedTags = [self tagArrayFromTagSet:tagSet];
        }
        
        // Set the revised tags onto the item
        if (![URL setResourceValue:revisedTags forKey:NSURLTagNamesKey error:&error])
            [self reportFatalError:error onURL:URL];
    }];
}


- (void)doMatch
{
    BOOL matchAny = [self wildcardInTagSet:self.tags];
    BOOL matchNone = [self.tags count] == 0;
    
    // Enumerate the provided URLs or current directory, listing all paths that match the specified tags
    // --all, --enter, and --recursive apply
    [self enumerateURLsWithBlock:^(NSURL *URL) {
        NSError* error;
        
        // Get the tags on the URL
        NSArray* tagArray;
        if (![URL getResourceValue:&tagArray forKey:NSURLTagNamesKey error:&error])
            [self reportFatalError:error onURL:URL];
        NSUInteger tagCount = [tagArray count];
        
        // If the set of existing tags contains all of the required
        // tags then emit
        if (   (matchAny && tagCount > 0)
            || (matchNone && tagCount == 0)
            || (!matchNone && [self.tags isSubsetOfSet:[self tagSetFromTagArray:tagArray]])
            )
            [self emitURL:URL tags:tagArray];
    }];
}


- (void)doList
{
    // Enumerate the provided URLs or current directory, listing the tags for each path
    // --all, --enter, and --recursive apply
    [self enumerateURLsWithBlock:^(NSURL* URL) {
        // Get the tags
        NSError* error;
        NSArray* tagArray;
        if (![URL getResourceValue:&tagArray forKey:NSURLTagNamesKey error:&error])
            [self reportFatalError:error onURL:URL];
        
        // Emit
        [self emitURL:URL tags:tagArray];
    }];
}


- (void)doFind
{
    // Start a metadata search for files containing all of the given tags
    [self initiateMetadataSearchForTags:self.tags];
    
    // Enter the run loop, exiting only when the query is done
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    while (_metadataQuery && [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]])
        ;
}


- (NSPredicate*)formQueryPredicateForTags:(NSSet*)tagSet
{
    BOOL matchAny = [self wildcardInTagSet:tagSet];
    BOOL matchNone = [tagSet count] == 0;

    NSPredicate* result;
    if (matchAny)
    {
        result = [NSPredicate predicateWithFormat:@"%K LIKE '*'", kMDItemUserTags];
    }
    else if (matchNone)
    {
        result = [NSPredicate predicateWithFormat:@"NOT %K LIKE '*'", kMDItemUserTags];
    }
    else if ([tagSet count] == 1)
    {
        result = [NSPredicate predicateWithFormat:@"%K ==[c] %@", kMDItemUserTags, ((TagName*)tagSet.anyObject).visibleName];
    }
    else // if tagSet count > 0
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
    NSMutableArray* result = [[NSMutableArray alloc] init];

    // Add URLs in which to explicitly search
    if ([self.URLs count])
        [result addObjectsFromArray:self.URLs];
    
    // Add any specified search scopes
    switch (scope)
    {
        case SearchScopeNone:
            break;
        case SearchScopeHome:
            [result addObject:NSMetadataQueryUserHomeScope];
            break;
        case SearchScopeLocal:
            [result addObject:NSMetadataQueryLocalComputerScope];
            break;
        case SearchScopeNetwork:
            [result addObjectsFromArray:@[NSMetadataQueryLocalComputerScope,NSMetadataQueryNetworkScope]];
            break;
    }
    
    // In the absence of any scope, the search is not scoped
    
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


- (void)queryDidUpdate:sender
{
    // We don't need this at present
}


- (void)queryComplete:sender
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
