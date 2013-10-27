prefix		= /usr/local
DESTDIR		= 

DSTUSR		= root
DSTGRP		= admin
DSTMODE		= 0755

INSTALL		= /usr/bin/install

BINDIR 		= ${prefix}/bin
MANDIR		= ${prefix}/man

SRCS		= Tag/main.m Tag/Tag.m
LIBS		= -framework Foundation \
			  -framework CoreServices

PROGRAM		= bin/tag

all: tag

tag: bin ${PROGRAM}

${PROGRAM}: ${SRCS} Makefile
	${CC} ${CFLAGS} ${SRCS} ${LIBS} -o ${PROGRAM}

bin:
	mkdir -p bin

clean:
	rm -Rf bin
	
distclean: clean

install: tag
	${INSTALL} -o ${DSTUSR} -g ${DSTGRP} -m ${DSTMODE} ${PROGRAM} ${DESTDIR}${BINDIR}
	
.PHONY: tag clean distclean install