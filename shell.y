%{
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#define MAX 255
#define STDIN  0
#define STDOUT 1

#define VERSION \
"-----------------------------------------------------------------\n\
-\tMini-Shell - Versión 1.0, 13 de mayo de 2010\t\t-\n\
-\tCopyright (C) 2010 LL Software Foundation, Inc.\t\t-\n\
-\tEste es software es propietario así que no eres\t\t-\n\
-\tlibre de redistribuirlo: CUIDADIN !!!\t\t\t-\n\
-\tAutor: Leonardo Lanchas.\t\t\t\t-\n\
-\tAsignatura: Diseño de sistemas operativos.\t\t-\n\
-----------------------------------------------------------------\n"\

// Definidas en shell.l
extern int n;  // índice del vector expresión

// vector que contiene la sentencia tecleada por el usuario (comando + argumentos, redirecciones, etc.)
extern char * expresion[ MAX ]; 
int pid = 0, fd_entrada = -1, fd_salida = -1, fd[ 2 ], aux;

// Se emplea para ejecutar CTRL + C
void abortar() { if( pid ) kill( pid, SIGINT ); }

// Libera toda la memoria empleada por el programa
void free_res( void ) { while( n ) { free( expresion[ --n ] ); expresion[ n ] = NULL; } }

// Muestra el mensaje de error correspondiente en una redirección.
void file_error( int output, char * file )
{
	printf( "Error en la redireccion de %s\n", output ? "salida" : "entrada" );
	printf( "Fichero: %s\n\n", file );
}

// Redireccion de salida: crea el fichero de salida alternativo a la consola, donde se vuelca los resultados de ejecución.
int redir_sal( void )
{
	if ( ( fd_salida = open( expresion[ --n ], O_WRONLY | O_TRUNC | O_CREAT, S_IRUSR | S_IWUSR ) ) == -1 )
	{
		file_error( 1, expresion[ n ] );
		return 0;
	}
	free( expresion[ n ] ); // se libera la posición que ocupaba el nombre del fichero de salida dado que ya no hace falta.
	
	return 1;  // éxito en la creación del fichero
}

// Redireccion de salida + anexar: abre el fichero de salida alternativo a la consola,
// donde se anexan los resultados de ejecución. Si no existe, se crea.
int redir_append( void )
{
	if ( ( fd_salida = open( expresion[ --n ], O_WRONLY | O_APPEND | O_CREAT, S_IRUSR | S_IWUSR ) ) == -1 )
	{
		file_error( 1, expresion[ n ] );
		return 0;
	}
	free( expresion[ n ] ); // se libera la posición que ocupaba el nombre del fichero de salida dado que ya no hace falta.
	
	return 1; // éxito en la creación del fichero
}

// Redireccion de entrada: lee del fichero de entrada alternativo al teclado la información necesaria para realizar la ejecución.
int redir_entrada( void )
{
	if ( ( fd_entrada = open( expresion[ --n ], O_RDONLY ) ) == -1 )
	{
		file_error( 0, expresion[ n ] );
		return 0;
	}
	free( expresion[ n ] );  // se libera la posición que ocupaba el nombre del fichero de salida dado que ya no hace falta.
	
	return 1; // éxito en la creación del fichero
}

// vrfy_in_out desvía la salida o la entrada standard ante una redireccion y cierra los ficheros tras esta.
void vrfy_in_out( int get_entry )
{
	if( get_entry )
	{
		if ( fd_entrada != -1 )  // si se debe redireccionar la entrada
		{
			close( STDIN );		 // se cierra la entrada standard,
			dup( fd_entrada );	 // se usa fd_entrada como la nueva entrada standard
			close( fd_entrada ); // y se libera el descriptor que sobra
		}

		if ( fd_salida != -1 )	// si se debe redireccionar la salida
		{
			close( STDOUT );	// se cierra la salida standard,
			dup( fd_salida );	// se usa fd_salida como la nueva salida standard
			close( fd_salida );	// y se libera el descriptor que sobra
		}
	}
	else // tras la ejecución de la redirección, se cierran los ficheros pertinentes
	{
		if ( fd_salida != -1 )	{ close( fd_salida ); fd_salida = -1; }
		if ( fd_entrada != -1 ) { close( fd_entrada ); fd_entrada = -1; }
	}
}

// Realiza la ejecución en si del comando cmd[]
void ejecutar( char * cmd[] )
{
	// ls con colores
	if( !strcmp( cmd[ 0 ], "ls" ) ){ cmd[ n ] = ( char * ) malloc( 15 ); cmd[ n++ ] = "--color=auto"; }
	
	cmd[ n ] = NULL; // el vector de argumentos pasado a execvp debe terminar en NULL
	execvp( cmd[ 0 ], cmd );
	printf( "No se encuentra el comando: %s\n", cmd[ 0 ] );
	exit( 1 );
}

int exec_pipe( void )
{
	int hpid;

	pipe( fd );

	switch ( hpid = fork() )
	{
		case -1:	printf( "Error: Fork sin éxito\n" ); return -1; // Fallo

		case 0: 			// Proceso hijo
			close( STDIN );	// prepara para una nueva entrada estandar.
			dup( aux ); 	// coloca la entrada estandar a fd[0]
			close( aux );	// pipe no necesita ninguno más

			close( STDOUT );  // prepara para una nueva salida estandar.
			dup( fd[ 1 ] );	  // coloca la salida estandar a fd[1]
			close( fd[ 0 ] ); // proceso uno no necesita leer de pipe
			close( fd[ 1 ] ); // pipe no necesita ninguno más
			
			vrfy_in_out( 1 ); // Comprobamos las rediredirecciones de entrada o salida

			ejecutar( expresion );	// Ejecutamos la orden
		break;
			
		default: 				// Proceso padre
			close( aux );		// pipe no necesita ninguno más
			dup( fd[ 0 ] ); 	// coloca la entrada estandar a fd[0]
			close( fd[ 0 ] );	// proceso uno no necesita leer de pipe
			close( fd[ 1 ] );	// proceso dos no necesita escribir en pipe
			
			waitpid( hpid, NULL, WNOHANG );
			
			free_res();				// limpiamos la memoria
			
			return 0;
	}
}

// Ejecuta el comando tecleado por el usuario.
// en_bgrnd indica si ha de ejecutarse en segundo plano o no.
int ejecutar_cmd( int en_bgrnd )
{
	if ( !strcmp( expresion[ 0 ], "exit" ) ) return -1; // cmd == exit --> termina el programa
	
	if ( !strcmp( expresion[ 0 ], "version" ) ){ printf( VERSION ); return 0; } // cmd == version --> imprimir info
	
	if ( !strcmp( expresion[ 0 ], "cd" ) ) // cmd == cd --> cambiar de directorio mediante chdir( expresion[ 1 ] )
	{
		// Ir a directorio personal (Si no hay directorio personal, se va a la raíz)
		if ( ( expresion[ 1 ] == NULL ) 
		 || !( strcmp( expresion[ 1 ], "~" ) )
		 || !( strcmp( expresion[ 1 ], "--" ) )
			) chdir( getenv( "HOME" ) != NULL ? getenv( "HOME" ) : "/" );
		// Ir al directorio indicado
		else chdir( expresion[ 1 ] );
		return 0;
	}

	if ( !( pid = fork() ) )
	{
		close( STDIN );	// prepara para una nueva entrada estandar.
		dup( aux );		// coloca la entrada estandar a fd[0]
		close( aux );	// pipe no necesita ninguno más

		vrfy_in_out( 1 ); 	// existen redirecciones?
	}

	switch( pid )
	{
		case -1:	printf( "Error: Fork sin éxito\n" ); return -1; // Fallo
		case  0:	ejecutar( expresion ); 									// Hijo
		default:	waitpid( pid, NULL, en_bgrnd ? WNOHANG : 0 ); 	// Padre
	}

	vrfy_in_out( 0 ); // Cerramos los ficheros
	
	return 0;
}

%}

%token NAME NUMBER COMANDO ENTRADA SALIDA APPEND BACKGROUND TUBERIA PCOMA SALTO_DE_LINEA

%%

// Axioma
sentencia: CMD PIPE SALTO_DE_LINEA { return ejecutar_cmd( 0 ); }	// Modo de ejecución: NORMAL
			| CMD PIPE BACKGROUND SALTO_DE_LINEA { return ejecutar_cmd( 1 ); } 	// Modo de ejecución: BACKGROUND
			| SALTO_DE_LINEA { return 0; }
			;

CMD:		  COMANDO ARG | COMANDO ARG REDIR ; 	// Comandos + argumentos y/o redirecciones

PIPE:		  TUBERIA { exec_pipe(); } CMD PIPE | ; // Una o más tuberías (pipes)

ARG:	  	  COMANDO ARG | ;	// Uno o más argumentos

// Control de redireccionamiento
REDIR:	ENTRADA COMANDO	  { if( !redir_entrada() ) return 0; }
		| SALIDA COMANDO  { if( !redir_sal() 	 ) return 0; }
		| APPEND COMANDO  { if( !redir_append()  ) return 0; }
		| ENTRADA COMANDO { if( !redir_entrada() ) return 0; } SALIDA COMANDO  { if( !redir_sal()	  ) return 0; }
		| SALIDA COMANDO  { if( !redir_sal() 	 ) return 0; } ENTRADA COMANDO { if( !redir_entrada() ) return 0; }
		;
%%

int main ( void )
{
	// Directorio actual y del nombre del equipo.
	char * directorio = ( char * ) malloc( sizeof( char ) * MAX );
	char * hostname   = ( char * ) malloc( sizeof( char ) * MAX );

	signal( SIGINT, abortar );
	
	aux = dup( STDIN ); // guardamos el descriptor del teclado
	
	while( 1 )
	{
		gethostname( hostname, MAX );
		getcwd( directorio, MAX );

		printf( "[Mini-Shell::%s@%s:~~ %s]$ ", getlogin(), hostname, directorio );

		// Análisis léxico, sintáctico y ejecución del comando
		if ( yyparse() == -1 ) break;

		// Libera todos los recursos utilizados por el programa
		free_res();
	}
	
	free( directorio );
	free( hostname );
	
	return 0;
}

/* Added because panther doesn't have liby.a installed. */
int yyerror (char *msg) {	return fprintf (stderr, "BISON: %s\n", msg);	}
