prefix		= /usr/local
DESTDIR		= 

DSTUSR		= root
DSTGRP		= admin
DSTMODE		= 0755
MANMODE		= 0644

INSTALL		= /usr/bin/install

BINDIR 		= ${prefix}/bin
MANDIR		= ${prefix}/share/man/man1

SRCS		= Tag/main.m Tag/Tag.m Tag/TagName.m
LIBS		= -framework Foundation \
			  -framework CoreServices

PROGRAM		= bin/tag
MANPAGE		= Tag/tag.1

all: tag

tag: ${PROGRAM}

${PROGRAM}: bin ${SRCS} Makefile
	${CC} ${CFLAGS} ${SRCS} ${LIBS} -o ${PROGRAM}

bin:
	mkdir -p bin

clean:
	rm -Rf bin
	
distclean: clean

install: tag
	${INSTALL} -o ${DSTUSR} -g ${DSTGRP} -m ${DSTMODE} ${PROGRAM} ${DESTDIR}${BINDIR}
	${INSTALL} -o ${DSTUSR} -g ${DSTGRP} -m ${MANMODE} ${MANPAGE} ${DESTDIR}${MANDIR}

.PHONY: all tag clean distclean install
