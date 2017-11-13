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

unsigned int comment = 0;
unsigned int string_buf_left;
bool str_error;

int str_cpy(char *str, unsigned int len)
{
  if (len < string_buf_left)
  {
    strncpy(string_buf_ptr, str, len);
    string_buf_ptr += len;
    string_buf_left -= len;
    return 0;
  }
  else
  {
    str_error = true;
    yylval.error_msg = "String is too long";
    return -1;
  }
}

int null_str_err()
{
  yylval.error_msg = "String is null character";
  str_error = true;
  return -1;
}

char* special_characters()
{
  char *current = &yytext[1];
  if (*current =='\n')
  {
    curr_lineno ++; 
  }
  return current;
}

/*
 *  Add Your own definitions here
 */

%}

%option yylineno
%option noyywrap

/*
 * Define names for regular expressions here.
 */

DARROW          [=][>]
LE              [<][=]
CLASS           [cC][lL][aA][sS][sS]
ELSE            [eE][lL][sS][eE]
FI              [fF][iI]
IF              [iI][fF]
IN              [iI][nN]
INHERITS        [iI][nN][hH][eE][rR][iI][tT][sS]
LET             [lL][eE][tT]
LOOP            [lL][oO][oO][pP]
POOL            [pP][oO][oO][lL]
THEN            [tT][hH][eE][nN]
WHILE           [wW][hH][iI][lL][eE]
CASE            [cC][aA][sS][eE]
ESAC            [eE][sS][aA][cC]
OF              [oO][fF]
NEW             [nN][eE][wW]
ISVOID          [iI][sS][vV][oO][iI][dD]
DIGIT           [0-9]
FALSE           f[aA][lL][sS][eE]
NOT             [nN][oO][tT]
TRUE            t[rR][uU][eE]
ASSIGN  	[<][-]
NOTSTRING	[^\n\0\\\"]
BACKSLASH 	[\\]
STAR 		[*]
NOTSTAR		[^*]
LEFTBRACKET	[(]
RIGHTBRACKET	[)]
OBJECTID	[A-Z][a-zA-Z0-9]*
TYPEID		[a-z][a-zA-Z0-9]*
NEWLINE		[\n]
SPECIALCHARACTER[\r\t\f\v]
NULLCH	 	[\O]
NOTRIGHTBRACKET [^)]
NOTLEFTBRACKET	[^(]
NOTCOMMENT	[[^\n*(\\]
NOTNEWLINE	[^\n]

QUOTE		[\]["]
LINECOMMENT 	[-][-]
STARTCOMMENT	[(][*]
FINISHCOMMENT	[*][)]

%x COMMENT
%x STRING

%%

 /*
  *  Nested comments
  */


 /*
  *  The multiple-character operators.
  */

<INITIAL,COMMENT>{NEWLINE} {
  curr_lineno ++;
}

{STARTCOMMENT} {
  comment++;
  BEGIN(COMMENT);
}

<COMMENT><<EOF>> {
  yylval.error_msg = "EOF was in comment";
  BEGIN(INITIAL);
  return (ERROR);
}

<COMMENT>{STAR}/{NOTRIGHTBRACKET};
<COMMENT>{LEFTBRACKET}/{NOTSTAR};
<COMMENT>{NOTCOMMENT}*;

<COMMENT>{BACKSLASH} {
  special_characters();
};
<COMMENT>{BACKSLASH};

<COMMENT>{STARTCOMMENT} {
  comment++;
}

<COMMENT>{FINISHCOMMENT} {
  comment--;
  if (comment == 0) {
    BEGIN(INITIAL);
  }
}

<INITIAL>{FINISHCOMMENT} {
  yylval.error_msg = "The forgotten *)";
  return(ERROR);
}

<INITIAL>{LINECOMMENT}{NOTNEWLINE}*;

<INITIAL>{QUOTE} {
  BEGIN(STRING);
  string_buf_ptr = string_buf;
  string_buf_left = MAX_STR_CONST;
  str_error = false;
}

<STRING><<EOF>> {
  yylval.error_msg = "EOF was in string";
  BEGIN(INITIAL);
  return (ERROR);
}

<STRING>{NOTSTRING}* {
  int current = str_cpy(yytext, strlen(yytext));
  if (current != 0) 
  {
    return (ERROR);
  }
}
<STRING>{NULLCH} {
  null_str_err();
  return (ERROR);
}

<STRING>{NEWLINE} {
 BEGIN(INITIAL);
  curr_lineno ++;
  if (!str_error)
  {
    yylval.error_msg = "NONterminated string";
    return (ERROR);
  }
}

<STRING>{BACKSLASH}(.|{NEWLINE}) {
  char* current_str = special_characters();
  int current_int ;
  switch (* current_str)
  {
    case 'n':
      current_int = str_cpy("\n",1);
      break;
    case 'b':
      current_int = str_cpy("\b", 1);
      break;
    case 't':
      current_int = str_cpy("\t",1);
      break;
    case 'f':
      current_int = str_cpy("\f",1);
      break;
    case '\0':
      current_int = null_str_err();
      break; 
    default:
      current_int = str_cpy(current_str,1);
      break;
  }
  if (current_int != 0)
    return (ERROR);
}

<STRING>{BACKSLASH};

<STRING>{QUOTE} {
  BEGIN(INITIAL);
  if (!str_error) 
  {
    yylval.symbol = stringtable.add_string(string_buf, string_buf_ptr - string_buf);
    return (STR_CONST);
  }
}

{SPECIALCHARACTER};

<INITIAL>{TRUE}                  { yylval.boolean = true; return (BOOL_CONST); }
<INITIAL>{FALSE}                 { yylval.boolean = false; return (BOOL_CONST); }
<INITIAL>{CLASS}                 { return (CLASS); }
<INITIAL>{ELSE}                  { return (ELSE); }
<INITIAL>{FI}                    { return (FI); }
<INITIAL>{IF}                    { return (IF); }
<INITIAL>{IN}                    { return (IN); }
<INITIAL>{INHERITS}              { return (INHERITS); }
<INITIAL>{ISVOID}                { return (ISVOID); }
<INITIAL>{LET}                   { return (LET); }
<INITIAL>{LOOP}                  { return (LOOP); }
<INITIAL>{POOL}                  { return (POOL); }
<INITIAL>{THEN}                  { return (THEN); }
<INITIAL>{WHILE}                 { return (WHILE); }
<INITIAL>{CASE}                  { return (CASE); }
<INITIAL>{ESAC}                  { return (ESAC); }
<INITIAL>{NEW}                   { return (NEW); }
<INITIAL>{OF}                    { return (OF); }
<INITIAL>{NOT}                   { return (NOT); }
<INITIAL>{DARROW}		 { return (DARROW); }
<INITIAL>{ASSIGN}                { return (ASSIGN); }
<INITIAL>{LE}                    { return (LE); }

<INITIAL>{TYPEID}                { yylval.symbol = stringtable.add_string(yytext); return (TYPEID); }
<INITIAL>{OBJECTID}              { yylval.symbol = stringtable.add_string(yytext); return (OBJECTID); }
<INITIAL>{DIGIT}+                { yylval.symbol = stringtable.add_string(yytext); return (INT_CONST); }
<INITIAL>";"                     { return int(';'); }
<INITIAL>","                     { return int(','); }
<INITIAL>":"                     { return int(':'); }
<INITIAL>"{"                     { return int('{'); }
<INITIAL>"}"                     { return int('}'); }
<INITIAL>"+"                     { return int('+'); }
<INITIAL>"-"                     { return int('-'); }
<INITIAL>"*"                     { return int('*'); }
<INITIAL>"/"                     { return int('/'); }
<INITIAL>"<"                     { return int('<'); }
<INITIAL>"="                     { return int('='); }
<INITIAL>"~"                     { return int('~'); }
<INITIAL>"."                     { return int('.'); }
<INITIAL>"@"                     { return int('@'); }
<INITIAL>"("                     { return int('('); }
<INITIAL>")"                     { return int(')'); }
<INITIAL>.                       { yylval.error_msg = yytext; return (ERROR); }

 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */


 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */


%%
