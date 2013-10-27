tag
===
**tag** is a command line tool to manipulate tags on Mac OS X 10.9 Mavericks files, and to query for files with those tags. **tag** can use the file system's built-in metadata search functionality to rapidly find all files that have been tagged with a given set of tags.

Usage
---

### Synopsis

	tag - A tool for manipulating and querying file tags.
	  usage:
		tag -a | --add <tags> <file>...     Add tags to file
		tag -r | --remove <tags> <file>...  Remove tags from file
		tag -s | --set <tags> <file>...     Set tags on file
		tag -m | --match <tags> <file>...   Display files with matching tags
		tag -l | --list <file>...           List the tags on file
		tag -f | --find <tags>              Find all files with tags
	  <tags> is a comma-separated list of tag names; use * to match/find any tag.
	  additional options:
			-v | --version      Display app version
			-h | --help         Display this help
			-n | --name         Turn on filename display in output (default)
			-N | --no-name      Turn off filename display in output (list)
			-t | --tags         Turn on tags display in output (find, match)
			-T | --no-tags      Turn off tags display in output (list)
			-g | --garrulous    Display tags each on own line (list, find, match)
			-G | --no-garrulous Display tags comma separated after filename (default)

### Add tag(s) to a file

The *add* operation adds one or more tags to the specified files without modifying any tags already there.

	tag --add tagname file
	tag --add tagname1,tagname2 file1 file2...
	
### Remove tag(s) from a file

The *remove* operation removes one or more tags from the specified files.
	
	tag --remove tagname file
	tag --remove tagname1,tagname2,... file1 file2...
	
To remove all tags from a file, use the wildcard * to match all tags:

	tag --remove \* file

### Set tag(s) on a file

The *set* operaration replaces all tags on the specified files with new tags.

	tag --set tagname file
	tag --set tagname1,tagname2,... file1 file2...

### Show files matching tag(s)

The *match* operation prints the file names that match the specified tags.  Matched files must have at least ALL of the tags specified. Note that it matches only against the files that are provided on input. To search for tagged files across your entire file system, see the --find command.

	tag --match tagname *
	tag --match tagname1,tagname2,... file1 file2...
	
You can use a wildcard (*) character in the tags list to match against any/all tags. Note, however, that you'll need to quote that * against shell expansion. To display all files in the current directory that have any sort of tag, use:

	tag --match \* *
	
Turn on --tags display mode for this operation to additionally show those tags:

	tag --match \* --tags *

Turn on garrulous output to format those tags onto multiple lines:

	tag --match \* --tags --garrulous *

You may use short options as well. The following is equivalent to the previous command:

	tag -tgm \* *

### List the tag(s) on a file

This *list* operation lists all the tags for each file.
	
	tag --list file
	tag --list file1 file2...
	
*list* is the default operation, so you may omit the list option:
	
	tag file1 file2...
	
You can turn on garrulous mode for *list* as well:

	tag -g *
	
If you just want tags, but not filenames, turn off display of files:

	tag --no-file *
	
### Find all files on the filesystem with tag(s)

The *find* operation searches across your local filesystem for all files that contain the specified tags. This uses the same filesystem metadata database that Spotlight uses, so it is fast.

	tag --find tagname
	tag --find tagname,tagname2...
	
You can use the wildcard here too to find all files that contain a tag of any name:

	tag --find \*
	
And of course you could turn on display of tag names, and even ask it to be garrulous, which displays all files on your system with tags, listing the tags independently on lines below the file names.

	tag --tgf \*

### Get help

	tag --help
	
	
Prebuilt Packages
---
There is no binary installer yet, but you may install **tag** using the following package managers:

### MacPorts

	sudo port install tag

Building and Installing
---
You must have Xcode or the Command Line Tools installed to build/install.

To build without installing:

	make
	
This will build tag into ./bin/tag

To build and install onto your system:

	make && sudo make install
	
This will install the tag tool at /usr/local/bin/tag

Advanced Usage
----
Hints:

* Wherever a "tagname" is expected, a list of tags may be provided. They must be comma-separated.
* Tagnames may include spaces, but the entire tag list must be provided as one parameter: "a multiword tag name".
* Wherever a "file" is expected, a list of files may be used instead. These are provided as separate parameters.
* Note that directories can be tagged as well, so directories may be specified instead of files.
* The operation selector --add, --remove, --set, --match, --list, or --find may be abbreviated as -a, -r, -s, -m, -l, or -f, respectively. All of the options have a short version, in fact. See see the synopsis above, or output from help.
* If no operation selector is given, --list is assumed.

Omissions
---
The following features have been contemplated for future enhancement:

* A binary installer
* The ability to control the search scope so that you can search across mounted network volumes instead of just local files
* A man page
* The ability to display and/or set tag colors

But the command is very usable in current form, modulo your testing.
