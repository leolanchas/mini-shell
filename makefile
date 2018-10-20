FLEX = /usr/bin/flex
CFLAGS = -g
LDLIBS = -lfl
CC = /usr/bin/gcc
BISON = /usr/bin/bison

shell:	shell.tab.o shell.lex.o
	$(CC) -o shell shell.tab.o shell.lex.o $(LDLIBS)
shell.lex.o:	shell.lex.c shell.tab.h
	$(CC) -c shell.lex.c 
shell.tab.o:	shell.tab.c shell.tab.h
	$(CC) -c shell.tab.c 
shell.tab.c:	shell.y
	$(BISON) -d shell.y
shell.lex.c:	shell.l
	$(FLEX) shell.l
	mv  lex.yy.c shell.lex.c

clean:
	rm  shell.tab.o shell.lex.o shell.tab.c shell.lex.c shell.tab.h \
	shell 
