tag
===
**tag** is a command line tool to manipulate tags on Mac OS 10.9 Mavericks files, and to query for files with those tags. **tag** can use the file system's built-in metadata search functionality to rapidly find all files that have been tagged with a given set of tags.

Usage
---
### Add tag(s) to a file:

	tag --add tagname file
	tag --add tagname1,tagname2 file1 file2...
	
This command adds one or more tags to the specified files without modifying any tags already there.
	
### Remove tag(s) from a file:

	tag --remove tagname file
	tag --remove tagname1,tagname2,... file1 file2...
	
This command removes one or more tags from the specified files.
	
### Set tag(s) on a file:

	tag --set tagname file
	tag --set tagname1,tagname2,... file1 file2...

This command replaces all tags on the specified files with new tags. To remove all tags from a file, use:

	tag --set "" file1 file2...

### Show files matching tag(s):

	tag --match tagname *
	tag --match tagname1,tagname2,... file1 file2...
	
This command prints the file names that match the specified tags.  Matched files must have at least ALL of the tags specified. Note that it matches only against the files that are provided on input. To search for tagged files across your entire file system, see the --find command.
	
### List the tag(s) on a file:

	tag --list file
	tag --list file1 file2...
	tag file1 file2...
	
This command displays the tags for each file listed.
	
### Find all files on the filesystem with tag(s):

	tag --find tagname
	tag --find tagname,tagname2...
	
This file searches across your local filesystem for all files that contain the specified tags.
	
Building and Installing
---
You must have Xcode installed to build/install. There is no binary installer yet.

To build without installing:

	make
	
This will build tag into ./bin/tag

To build and install onto your system:

	make && sudo make install
	
This will install the tag tool at /usr/local/bin/tag

Advanced Usage
----
Hints:

1. Wherever a "tagname" is expected, a list of tags may be provided. They must be comma-separated.
2. Tagnames may include spaces, but the entire tag list must be provided as one parameter: "a multiword tag name".
3. Wherever a "file" is expected, a list of files may be used instead. These are provided as separate parameters.
4. Note that directories can be tagged as well, so directories may be specified instead of files.
5. The mode selector --add, --remove, --set, --match, --list, or --find may be abbreviated as -a, -r, -s, -m, -l, or -f, respectively.
6. If no mode selector is given, --list is assumed.

Omissions
---
The following features have been contemplated for future enhancement:

1. A binary installer
2. A better format for the output of list
3. The ability to control the search scope so that you can search across mounted network volumes instead of just local files
4. A fleshed-out man page
5. The ability to display and/or set tag colors

But the command is very usable in current form, modulo your testing.
