DSTROOT		= 
DSTUSR		= root
DSTGRP		= admin
DSTMODE		= 0755

INSTALL		= /usr/bin/install
INSTALLDIR	= /usr/local/bin

CFLAGS		= -O2
SRCS		= Tag/main.m Tag/Tag.m
LIBS		= -framework Foundation \
			  -framework CoreServices

PROGRAM		= bin/tag

tag: bin ${PROGRAM}

${PROGRAM}: ${SRCS} Makefile
	${CC} ${CFLAGS} ${SRCS} ${LIBS} -o ${PROGRAM}

bin:
	mkdir -p bin

clean:
	rm -Rf bin
	
distclean: clean

install: tag
	${INSTALL} -o ${DSTUSR} -g ${DSTGRP} -m ${DSTMODE} ${PROGRAM} ${DSTROOT}${INSTALLDIR}
	
.PHONY: tag clean distclean install