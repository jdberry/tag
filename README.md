tag
===

A command line tool to manipulate tags on Mavericks files, and to query for files with those tags.

Usage
-----

Add tag(s) to a file(s):

	tag --add tagname file
	tag --add tagname1,tagname2 file1 file2...
	
Remove tag(s) from a file(s):

	tag --remove tagname file
	tag --remove tagname1,tagname2,... file1 file2...
	
Set tag(s) on a file(s):

	tag --set tagname file
	tag --set tagname1,tagname2,... file1 file2...
	
Show files matching tag(s):

	tag --match tagname *
	tag --match tagname1,tagname2,... file1 file2...
	
List the tags on a file(s):

	tag --list file
	tag --list file1 file2...
	tag file
	
Find all files on the system with a tag:

	tag --find tagname
	tag --find tagname,tagname2...
	
Build and Installation
------------

To build and install onto your system:

	sudo make install
	
This will install the tag tool into /usr/local/bin/tag.

To build without installing:

	make
	
This will build the tag tool into the ./bin directory.

Advanced Usage
--------------

Hints:

1. Wherever a "tagname" is expected, a list of tags may be provided. They must be comma-separated
2. Wherever a "file" is expected, a list of files may be used instead. These are provided as separate parameters.
3. The mode parameter --add, --remove, --set, --match, --list, or --find may be abbreviated as -a, -r, -s, -m, -l, or -f, respectively.
4. If no mode selector is given, --list is assumed.

