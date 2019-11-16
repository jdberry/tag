//
//  Tag.m
//  Tag
//
//  Created by James Berry on 10/25/13.
//
//  The MIT License (MIT)
//
//  Copyright (c) 2013-2019 James Berry
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
 FUTURE POTENTIALS:
 
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

NSString* const version = @"0.10.0";

// This constant doesn't seem to be defined in MDItem.h, so we define it here
NSString* const kMDItemUserTags = @"kMDItemUserTags";


@interface Tag ()
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
        { "invert",     required_argument,      0,              OperationModeInvert },
        { "match",      required_argument,      0,              OperationModeMatch },
        { "find",       required_argument,      0,              OperationModeFind },
        { "usage",      optional_argument,      0,              OperationModeUsage },

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
        { "color",      no_argument,            0,              'c' },
        { "slash",      no_argument,            0,              'p' },  // Write a slash ('/') after is each filename if that file is a directory
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
    
    self.tagColors = nil;

    int name_flag = 0;
    int tags_flag = 0;
    int garrulous_flag = 0;
    
    BOOL slash = NO;
    BOOL color = NO;
    BOOL nulTerminate = NO;
    
    // Parse Options
    int option_char;
    int option_index;
    while ((option_char = getopt_long(argc, argv, "s:a:r:i:m:f:u::lAeRdnNtTgGcp0hv", options, &option_index)) != -1)
    {
        switch (option_char)
        {
            case OperationModeSet:
            case OperationModeAdd:
            case OperationModeRemove:
            case OperationModeInvert:
            case OperationModeMatch:
            case OperationModeFind:
            case OperationModeUsage:
            case OperationModeList:
            {
                if (self.operationMode)
                {
                    FPrintf(stderr, @"%@: Operation mode cannot be respecified\n", [self programName]);
                    exit(1);
                }
                self.operationMode = option_char;
                
                if (optarg == nil && self.operationMode == OperationModeUsage)
                    optarg = "*";
                
                if (optarg != nil)
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
                
            case 'c':
                color = YES;
                break;

            case 'p':
                slash = YES;
                break;
                
            case '0':
                nulTerminate = YES;
                break;

            case '?':
            case ':':
            case 'h':
                _operationMode = OperationModeNone;
                [self displayHelp];
                break;
                
            case 'v':
                _operationMode = OperationModeNone;
                [self displayVersion];
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
    
    // Set additional output flags
    if (slash)
        _outputFlags |= OutputFlagsSlashDirectory;
    if (nulTerminate)
        _outputFlags |= OutputFlagsNulTerminate;
    
    // Get colors if we're able to use them. If tagColors is nil, we won't try to emit color escapes
    if (color && isatty(fileno(stdout)))
        self.tagColors = [self getTagColors];

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

// show, display, enumerate, discover, all, usage

- (void)displayHelp
{
    Printf(@"%@ - %@", [self programName], @"A tool for manipulating and querying file tags.\n"
           "  usage:\n"
           "    tag -a | --add <tags> <path>...     Add tags to file\n"
           "    tag -r | --remove <tags> <path>...  Remove tags from file\n"
           "    tag -s | --set <tags> <path>...     Set tags on file\n"
           "    tag -i | --invert <tags> <path>...  Invert tags on file\n"
           "    tag -m | --match <tags> <path>...   Display files with matching tags\n"
           "    tag -f | --find <tags> <path>...    Find all files with tags (-A, -e, -R ignored)\n"
           "    tag -u | --usage <tags> <path>...   Display tags used, with usage counts\n"
           "    tag -l | --list <path>...           List the tags on file\n"
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
           "        -c | --color        Display tags in color\n"
           "        -p | --slash        Terminate each directory name with a slash\n"
           "        -0 | --nul          Terminate lines with NUL (\\0) for use with xargs -0\n"
           "             --home         Find tagged files in user home directory\n"
           "             --local        Find tagged files in home + local filesystems\n"
           "             --network      Find tagged files in home + local + network filesystems\n"
    );
}


#define COLORS_ESCAPE    @"\033["
#define COLORS_NONE      COLORS_ESCAPE @"m"
#define COLORS_GRAY      COLORS_ESCAPE @"48;5;241m"
#define COLORS_GREEN     COLORS_ESCAPE @"42m"
#define COLORS_PURPLE    COLORS_ESCAPE @"48;5;129m"
#define COLORS_BLUE      COLORS_ESCAPE @"44m"
#define COLORS_YELLOW    COLORS_ESCAPE @"43m"
#define COLORS_RED       COLORS_ESCAPE @"41m"
#define COLORS_ORANGE    COLORS_ESCAPE @"48;5;208m"


- (NSDictionary*)getTagColors
{
    // Get the tag colors
    //
    // Since this is using private finder data structures, it may not always continue to work.
    // We make a best effort attempt and try to bail if we don't find what we expect to find there
    
    NSError* error;
    NSString* homeDir = NSHomeDirectory();
    NSString* finderPlistPath = [homeDir stringByAppendingString: @"/Library/SyncedPreferences/com.apple.finder.plist"];
    NSURL* url = [NSURL fileURLWithPath:finderPlistPath];
    
    NSData* data = [NSData dataWithContentsOfURL:url];
    if (!data)
        return nil;

    id properties = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:nil error:&error];
    if (!properties)
        return nil;
    
    NSArray* tagsArray = [properties valueForKeyPath:@"values.FinderTagDict.value.FinderTags"];
    if (![tagsArray isKindOfClass:[NSArray class]])
        return nil;
    
    // Form a map from tag name to color escape sequence for that tag
    NSUInteger tagCount = [tagsArray count];
    NSMutableDictionary *colors = [NSMutableDictionary dictionaryWithCapacity:tagCount];
    
    for (NSDictionary* tagEntry in tagsArray)
    {
        if (![tagEntry isKindOfClass:[NSDictionary class]])
            return nil;
        
        NSString* tag = tagEntry[@"n"];
        NSNumber* colorCode = tagEntry[@"l"];
        if (tag == nil || colorCode == nil)
            continue;
        
        NSString* colorSequence = nil;
        switch ([colorCode intValue])
        {
            case 1:
                colorSequence = COLORS_GRAY;
                break;
            case 2:
                colorSequence = COLORS_GREEN;
                break;
            case 3:
                colorSequence = COLORS_PURPLE;
                break;
            case 4:
                colorSequence = COLORS_BLUE;
                break;
            case 5:
                colorSequence = COLORS_YELLOW;
                break;
            case 6:
                colorSequence = COLORS_RED;
                break;
            case 7:
                colorSequence = COLORS_ORANGE;
                break;
        }
        
        if (colorSequence != nil)
            [colors setObject:colorSequence forKey:[[TagName alloc] initWithTag:tag]];
    }

    return [colors copy];
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
            
        case OperationModeInvert:
            [self doInvert];
            break;
            
        case OperationModeMatch:
            [self doMatch];
            break;
            
        case OperationModeFind:
            [self doFind];
            break;

        case OperationModeUsage:
            [self doUsage];
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


- (NSString*)displayStringForTag:(NSString*)tag
{
    NSString* result = nil;
    NSString* colorSequence = (self.tagColors != nil) ? _tagColors[[[TagName alloc] initWithTag:tag]] : nil;
    if (colorSequence != nil)
        result = [NSString stringWithFormat:@"%@%@%@", colorSequence, tag, COLORS_NONE];
    else
        result = tag;
    return result;
}


- (void)emitURL:(NSURL*)URL tags:(NSArray*)tagArray
{
    NSString* fileName = nil;
    if (_outputFlags & OutputFlagsName)
    {
        NSString* suffix = @"";
        if (_outputFlags & OutputFlagsSlashDirectory)
        {
            NSNumber* isDir = nil;
            [URL getResourceValue:&isDir forKey:NSURLIsDirectoryKey error:nil];
            if ([isDir boolValue])
                suffix = @"/";
        }
        fileName = [NSString stringWithFormat:@"%@%@", [URL relativePath], suffix];
    }
    
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
        NSString* startingSeparator;
        if (tagsOnSeparateLines)
        {
            needLineTerm = !!fileName;
            tagSeparator = fileName ? @"    " : @"";
            startingSeparator = tagSeparator;
        }
        else
        {
            tagSeparator = @",";
            startingSeparator = fileName ? @"\t" : @"";
        }
        
        NSString* sep = startingSeparator;
        for (NSString* tag in sortedTags)
        {
            if (needLineTerm)
                putc(lineTerminator, stdout);
            
            Printf(@"%@%@", sep, [self displayStringForTag:tag]);

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
                                          includingPropertiesForKeys:@[NSURLTagNamesKey]
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


- (void)doInvert
{
    // If there are no tags to invert, we're done
    if (![self.tags count])
        return;
    
    // Only perform invert on specified URLs
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
        
        NSMutableSet* curTags = [self tagSetFromTagArray:existingTags];
        
        // Calculate tags to be removed
        NSMutableSet* tagsToRemove = [curTags mutableCopy];
        [tagsToRemove intersectSet:self.tags];
        
        // Calculate tags to be added
        NSMutableSet* tagsToAdd = [self.tags mutableCopy];
        [tagsToAdd minusSet:tagsToRemove];
        
        // Remove tags to be removed
        [curTags minusSet:tagsToRemove];
        // Add tags to be added
        [curTags unionSet:tagsToAdd];
        
        // Set all the new tags onto the item
        if (![URL setResourceValue:[self tagArrayFromTagSet:curTags] forKey:NSURLTagNamesKey error:&error])
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
    [self findGutsWithUsage:NO];
}


- (void)doUsage
{
    [self findGutsWithUsage:YES];
}


- (void)findGutsWithUsage:(BOOL)usageMode
{
    // Start a metadata search for files containing all of the given tags
    NSMetadataQuery* metadataQuery = [self performMetadataSearchForTags:self.tags usageMode:usageMode];
    
    // Emit the results of the query, either for tags or for usage
    if (usageMode)
    {
        // Print the statistics, ignoring the general query results
        NSDictionary* valueLists = [metadataQuery valueLists];
        NSArray* tagTuples = valueLists[kMDItemUserTags];
        for (NSMetadataQueryAttributeValueTuple* tuple in tagTuples)
        {
            NSString* tag = (tuple.value == [NSNull null]) ? @"<no_tag>" : tuple.value;
            Printf(@"%ld\t%@\n", (long)tuple.count, [self displayStringForTag:tag]);
        }
    }
    else
    {
        // Print the query results
        [metadataQuery enumerateResultsUsingBlock:^(NSMetadataItem* theResult, NSUInteger idx, BOOL * _Nonnull stop) {
            @autoreleasepool {
                NSString* path = [theResult valueForAttribute:(NSString *)kMDItemPath];
                if (path)
                {
                    NSURL* URL = [NSURL fileURLWithPath:path];
                    NSArray* tagArray = [theResult valueForAttribute:kMDItemUserTags];
                    
                    [self emitURL:URL tags:tagArray];
                }
            }
        }];
    }
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


- (NSMetadataQuery*)performMetadataSearchForTags:(NSSet*)tagSet usageMode:(BOOL)usageMode
{
    // Create the metadata query
    NSMetadataQuery* metadataQuery = [[NSMetadataQuery alloc] init];
    
    // Register the notifications for batch and completion updates
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(queryComplete:)
                                                 name:NSMetadataQueryDidFinishGatheringNotification
                                               object:metadataQuery];
    
    // Configure the search predicate
    NSPredicate *searchPredicate = [self formQueryPredicateForTags:tagSet];
    [metadataQuery setPredicate:searchPredicate];
    
    // Set the search scope
    NSArray *searchScopes = [self searchScopesFromSearchScope:self.searchScope];
    [metadataQuery setSearchScopes:searchScopes];
    
    // Configure the sorting of the results
    // (note that the query can't sort by the item path, which makes sorting less useful)
    NSSortDescriptor *sortKeys = [[NSSortDescriptor alloc] initWithKey:(id)kMDItemDisplayName
                                                             ascending:YES];
    [metadataQuery setSortDescriptors:[NSArray arrayWithObject:sortKeys]];
    
    // If we're collecting usage stats, request that values be saved for tags
    if (usageMode)
        [metadataQuery setValueListAttributes:@[kMDItemUserTags]];
    
    // Ask the query to send notifications on the main thread, which will
    // ensure we process them on the main thread, and will also ensure that our
    // main thread is kicked so that the run loop will iterate and thus complete.
    [metadataQuery setOperationQueue:[NSOperationQueue mainQueue]];
    
    // Begin the asynchronous query
    [metadataQuery startQuery];

    // Enter the run loop, exiting only when the query is done
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    while (!metadataQuery.stopped && [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]])
        ;
    
    // Remove the notification observers
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSMetadataQueryDidFinishGatheringNotification
                                                  object:metadataQuery];
    
    return metadataQuery;
}


- (void)queryComplete:(NSNotification*)sender
{
    // Stop the query, the single pass is completed.
    // This will cause our runloop loop to terminate.
    NSMetadataQuery* metadataQuery = sender.object;
    [metadataQuery stopQuery];
}


@end
