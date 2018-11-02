/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
*/ 

int nesting = 0;
int length = 0;

%}

%option yylineno
%option noyywrap

/*
 * Define names for regular expressions here.
 */

DARROW          "=>"
INT_CONST	[0-9]+
TYPEID		[A-Z][a-zA-Z0-9_]*
OBJECTID	[a-z][a-zA-Z0-9_]*
CLASS		[Cc][Ll][Aa][Ss][Ss]
ELSE		[Ee][Ll][Ss][Ee]
BOOL_CONST	"f"[Aa][Ll][Ss][Ee]|"t"[Rr][Uu][Ee]
FI		[Ff][Ii]
IF		[Ii][Ff]
IN		[Ii][Nn]
INHERITS	[Ii][Nn][Hh][Ee][Rr][Ii][Tt][Ss]
ISVOID		[Ii][Ss][Vv][Oo][Ii][Dd]
LET		[Ll][Ee][Tt]
LOOP		[Ll][Oo][Oo][Pp]
POOL		[Pp][Oo][Oo][Ll]
THEN		[Tt][Hh][Ee][Nn]
WHILE		[Ww][Hh][Ii][Ll][Ee]
CASE		[Cc][Aa][Ss][Ee]
ESAC		[Ee][Ss][Aa][Cc]
NEW		[Nn][Ee][Ww]
OF		[Oo][Ff]
NOT		[Nn][Oo][Tt]
ASSIGN		"<-"
LE		"<="

OPERATION	[=\+\-\*/.,:;\(\){}@~<]

%x COMMENT
%x STRING
%x BADSTRING

%%

 /*
  *  Nested comments
  */

<INITIAL,COMMENT>"(*" 	{ nesting++;
                    	  BEGIN(COMMENT); }

<COMMENT>\n     	{ curr_lineno++; }

<COMMENT>.		{}

<COMMENT>"*)"		{ nesting--;
			  if (nesting == 0)
			  {
				BEGIN(INITIAL);
                    	  } }

<COMMENT><<EOF>> 	{ BEGIN(INITIAL);
			  cool_yylval.error_msg = "EOF in comment";
			  return(ERROR); }

<INITIAL>"*)"   	{ cool_yylval.error_msg = "Unmatched *)";
			  return(ERROR); }

"--".*\n        	{ curr_lineno++; }
"--".* 			{ curr_lineno++; }

 /*
  *  The multiple-character operators.
  */
{DARROW}		{ return (DARROW); }
{LE}			{ return (LE); }
{ASSIGN}		{ return (ASSIGN); }
{CLASS}			{ return (CLASS); }
{ELSE}			{ return (ELSE); }
{FI}			{ return (FI); }
{IF}			{ return (IF); }
{IN}			{ return (IN); }
{INHERITS}		{ return (INHERITS); }
{LET}			{ return (LET); }
{LOOP}			{ return (LOOP); }
{POOL}			{ return (POOL); }
{THEN}			{ return (THEN); }
{WHILE}			{ return (WHILE); }
{CASE}			{ return (CASE); }
{ESAC}			{ return (ESAC); }
{OF}			{ return (OF); }
{NEW}			{ return (NEW); }
{ISVOID}		{ return (ISVOID); }
{NOT}			{ return (NOT); }

{OPERATION}		{ return yytext[0]; }

{BOOL_CONST}		{	if (yytext[0] == 't') cool_yylval.boolean = true;
				else cool_yylval.boolean = false;
				return (BOOL_CONST);				}

{TYPEID}		{	cool_yylval.symbol = idtable.add_string (yytext);
				return (TYPEID); 				}

{OBJECTID}		{	cool_yylval.symbol = idtable.add_string (yytext);
				return (OBJECTID);				}

{INT_CONST}		{	cool_yylval.symbol = inttable.add_string (yytext);
				return (INT_CONST);				}



 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */

\"			{ BEGIN(STRING); }

<STRING>\"		{ cool_yylval.symbol = stringtable.add_string (string_buf);
			  string_buf[0] = 0;
			  length = 0;
			  BEGIN(INITIAL);
			  return (STR_CONST); }

<STRING>(\0|\\\0)	{ cool_yylval.error_msg = "String contains null character";
			  BEGIN(BADSTRING);
			  return (ERROR); }

<BADSTRING>.*[\"\n]	{ BEGIN(INITIAL); }

<STRING>\\\n		{ if (length + 1 >= MAX_STR_CONST)
			  {
				BEGIN(BADSTRING);
				string_buf[0] = 0;
				length = 0;
				cool_yylval.error_msg = "String too long";
				return (ERROR);
			  }
			  curr_lineno++;
			  strcat (string_buf, "\n");
			  length++; }

<STRING>\n		{ curr_lineno++;
			  BEGIN(INITIAL);
			  string_buf[0] = 0;
			  length = 0;
			  cool_yylval.error_msg = "Unterminated string constant";
			  return (ERROR); }

<STRING><<EOF>>		{ BEGIN(INITIAL);
			  cool_yylval.error_msg = "EOF in string constant";
			  return (ERROR); }

<STRING>\\([nbtf]|.)	{ if (length + 1 >= MAX_STR_CONST)
			  {
				BEGIN(BADSTRING);
				string_buf[0] = 0;
				length = 0;
				cool_yylval.error_msg = "String too long";
				return (ERROR);
			  }
			  if (yytext[1] == 'n')
			  {
				curr_lineno++;
				strcat (string_buf, "\n");
			  }
			  else
			  {
				  if (yytext[1] == 'b') strcat (string_buf, "\b");
				  else if (yytext[1] == 't') strcat (string_buf, "\t");
				  else if (yytext[1] == 'f') strcat (string_buf, "\f");
				  else strcat (string_buf, &strdup(yytext)[1]);
				  length++;
			  } }

<STRING>.		{ if (length + 1 >= MAX_STR_CONST)
			  {
				BEGIN(BADSTRING);
				string_buf[0] = 0;
				length = 0;
				cool_yylval.error_msg = "String too long";
				return (ERROR);
			  }
			  strcat (string_buf, yytext);
			  length++; }

\n			{ curr_lineno++; }

[ \r\t\v\f]		{}

.			{ cool_yylval.error_msg = yytext;
			  return (ERROR); }

 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */



%%

