tag
===
**tag** is a command line tool to manipulate tags on Mac OS X files (10.9 Mavericks and above), and to query for files with those tags. **tag** can use the file system's built-in metadata search functionality to rapidly find all files that have been tagged with a given set of tags.

Usage
---

### Synopsis

	tag - A tool for manipulating and querying file tags.
	  usage:
		tag -a | --add <tags> <path>...     Add tags to file
		tag -r | --remove <tags> <path>...  Remove tags from file
		tag -s | --set <tags> <path>...     Set tags on file
		tag -m | --match <tags> <path>...   Display files with matching tags
		tag -l | --list <path>...           List the tags on file
		tag -f | --find <tags> <path>...    Find all files with tags, limited to paths if present
	  <tags> is a comma-separated list of tag names; use * to match/find any tag.
	  additional options:
			-v | --version      Display version
			-h | --help         Display this help
			-A | --all          Display invisible files while enumerating
			-e | --enter        Enter/enumerate directories provided
			-R | --recursive    Recursively process directories
			-n | --name         Turn on filename display in output (default)
			-N | --no-name      Turn off filename display in output (list, find, match)
			-t | --tags         Turn on tags display in output (find, match)
			-T | --no-tags      Turn off tags display in output (list)
			-g | --garrulous    Display tags each on own line (list, find, match)
			-G | --no-garrulous Display tags comma-separated after filename (default)
			     --home         Find tagged files in user home directory
                 --local        Find tagged files in home + local filesystems
			     --network      Find tagged files in home + local + network filesystems
			-0 | --nul          Terminate lines with NUL (\0) for use with xargs -0

### Add tags to a file

The *add* operation adds one or more tags to the specified files without modifying any tags already there.

	tag --add tagname file
	tag --add tagname1,tagname2,... file1 file2...
	
### Remove tags from a file

The *remove* operation removes one or more tags from the specified files.
	
	tag --remove tagname file
	tag --remove tagname1,tagname2,... file1 file2...
	
To remove all tags from a file, use the wildcard * to match all tags:

	tag --remove \* file

### Set tags on a file

The *set* operation replaces all tags on the specified files with one or more new tags.

	tag --set tagname file
	tag --set tagname1,tagname2,... file1 file2...

### Show files matching tags

The *match* operation prints the file names that match the specified tags.  Matched files must have at least *all* of the tags specified. Note that *match* matches only against the files that are provided as parameters (and those that it encounters if you use the --enter or --recursive options). To search for tagged files across your filesystem, see the *find* operation.

	tag --match tagname file
	tag --match tagname1,tagname2,... file1 file2...
	
You can use a wildcard (*) character in the tags list to match against any/all tags. Note, however, that you'll need to quote that * against shell expansion. To display all files in the current directory that have any combination of tags (but not _no_ tags), use:

	tag --match '*' *

Conversely, to match against paths that have _no_ tags, use an empty tag expression:

    tag --match '' *
	
Turn on --tags display mode for this operation to additionally show the tags on the file:

	tag --match '*' --tags *

Turn on garrulous output to format those tags onto multiple lines:

	tag --match '*' --tags --garrulous *

You may use short options as well. The following is equivalent to the previous command:

	tag -tgm '*' *

You may use the --enter or --recursive options to match the contents of, or recursively process, any directories provided. This is similar to the --find operation, but operates recursively from the directories you specify. There may be significant differences in performance and/or output ordering in particular cases, so neither *find* nor *match* will be the better solution for all cases.

    tag --match '*' --recursive .

If no file arguments are given, *match* will enumerate and match against the contents of the current directory:

    tag --match tagname

### List the tags on a file

This *list* operation lists the given files, displaying the tags on each:
	
	tag --list file
	tag --list file1 file2...
	
*list* is the default operation, so you may omit the list option:
	
	tag file1 file2...

As with *match*, if no file arguments are given *list* will display the contents of the current directory and any tags on those files:

    tag
	
You can turn on garrulous mode for *list* as well:

	tag -g *
	
If you just want to see tags, but not filenames, turn off display of files:

	tag --no-name *

You may use the --enter or --recursive options to list the contents of, or recursively process, any directories provided:

    tag --list --enter .
    tag --list --recursive .
    tag -R .

	
### Find all files on the filesystem with specified tags

The *find* operation searches across your filesystem for all files that contain the specified tags. This uses the same filesystem metadata database that Spotlight uses, so it is fast.

	tag --find tagname
	tag --find tagname1,tagname2...
	
You can use the wildcard here too to find all files that contain a tag of any name:

	tag --find '*'
	
Or use an empty tag expression to find all files that have _no_ tag:

    tag --find ''

And of course you could turn on display of tag names, and even ask it to be garrulous, which displays all files on your system with tags, listing the tags independently on lines below the file names.

	tag -tgf '*'
    
*find* by default will search everywhere that it can. You may supply options to specify a search scope of the user home directory, local disks, or attached network file systems.

    tag --find tagname --home
    tag --find tagname --local
    tag --find tagname --network

You may also supply one or more paths in which to search. 
    
    tag --find tagname /path/to/here
    tag --find tagname --home /path/to/here ./there

### Get help

The --help option will show you the command synopsis:

	tag --help
	
	
Prebuilt Packages
---
You may install **tag** using the following package managers:

### MacPorts

	sudo port install tag
	
### Homebrew
	
	brew install tag

Building and Installing
---
You must have Xcode or the Command Line Tools installed to build/install.

To build without installing:

	make
	
This will build **tag** into ./bin/tag

To build and install onto your system:

	make && sudo make install
	
This will install **tag** at /usr/local/bin/tag and the man page at /usr/local/share/man/man1/tag.1

Advanced Usage
----
* Wherever a "tagname" is expected, a list of tags may be provided. They must be comma-separated.
* Tagnames may include spaces, but the entire tag list must be provided as one parameter: "tag1,a multiword tag name,tag3".
* For *match*, *find*, and *remove*, a tag name of '*' is the wildcard and will match any tag. An empty tag expression '' will match only files with no tags.
* Wherever a "file" is expected, a list of files may be used instead. These are provided as separate parameters.
* Note that directories can be tagged as well, so directories may be specified instead of files.
* The --all, --enter, and --recursive options apply to --add, --remove, --set, --match, and --list, and control whether hidden files are processed and whether directories are entered and/or processed recursively. If a directory is supplied, but neither of --enter or --recursive, then the operation will apply to the directory itself, rather than to its contents.
* The operation selector --add, --remove, --set, --match, --list, or --find may be abbreviated as -a, -r, -s, -m, -l, or -f, respectively. All of the options have a short version, in fact. See see the synopsis above, or output from help.
* If no operation selector is given, the operation will default to *list*.
* A *list* operation will default to the current directory if no directory is given.
* For compatibility with Finder, tags are compared in a case-insensitive manner.
* If you plan to pipe the output of **tag** through **xargs**, you might want to use the -0 option of each.
* For compatibility with versions 0.8.1 and earlier, -d/--descend is an alias for -R/--recursive.

Omissions
---
The following features are contemplated for future enhancement:

* Regex or glob matching of tags
* More complicated boolean matching criteria


