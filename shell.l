%{
#include "shell.tab.h"

#define MAX 255

extern int yylval;

int n = 0;
char * expresion[ MAX ];
char cmd[ MAX ];

void a_Buffer( char * str )
{
	expresion[ n ] = ( char * ) malloc( strlen( str ) + 1 );
	strcpy( expresion[ n++ ], str );
}

%}

%s comando

%%

[ \t]		;

\n			{ return SALTO_DE_LINEA; }

"<"		{ return ENTRADA; }

">"		{ return SALIDA; }

">>"		{ return APPEND; }

&			{ return BACKGROUND; }

"|"		{ return TUBERIA; }

<comando>"\""
			{
				BEGIN(INITIAL);
				return COMANDO;
			}

<comando>[^\"]*		{
				cmd[ 0 ] = '\0';
				strcat( cmd, yytext );
				a_Buffer( cmd );
			}

"\""			BEGIN(comando);

"$"[^&">""<"" ""|"\n]+ {
				a_Buffer( getenv( yytext + 1 ) );
				return COMANDO; 
			}

[^&">""<"" ""|"\n]+	{
				a_Buffer( yytext );
				return COMANDO;
			}

%%
