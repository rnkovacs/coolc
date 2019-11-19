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

#include <assert.h>
#include <string.h>

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

#define ADD_STR (cool_yylval.symbol = stringtable.add_string(yytext))
#define ADD_INT (cool_yylval.symbol = inttable.add_string(yytext))
#define ADD_ID (cool_yylval.symbol = idtable.add_string(yytext))

int multi_open = 0;
int single_open = 0;
int string_open = 0;
char empty_string = 1;
char error = 0;

void process_string(char **error_msg) {
  int idx = 0;
  char last_processed = 0;
  
  for (int i=0; i<(yyleng-1); ++i) {
    if (yytext[i] != '\\' && yytext[i+1] == '\n') {
      *error_msg = "Unterminated string constant";
      error = 1;
      return;
    }

    if (yytext[i] == '\0') {
      *error_msg = "String contains null character";
      error = 1;
      return;
    }

    if (yytext[i] == '\\') {
      i++;
      switch(yytext[i]) {
        case 'n': string_buf[idx++] = '\n'; break;
        case 'b': string_buf[idx++] = '\b'; break;
        case 't': string_buf[idx++] = '\t'; break;
        case 'f': string_buf[idx++] = '\f'; break;
        default: string_buf[idx++] = yytext[i];
      }
      if (i == (yyleng-1)) last_processed = 1;
      continue;
    }

    string_buf[idx++] = yytext[i];
  }
          
  if (yytext[yyleng-1] == '\0') {
    *error_msg = "String contains null character";
    error = 1;
    return;
  }

  if (yytext[yyleng-1] == '\n' && (yyleng == 1 || !last_processed)) {
    *error_msg = "Unterminated string constant";
    error = 1;
    return;
  }

  if (!last_processed)
    string_buf[idx++] = yytext[yyleng-1];
          
  string_buf[idx] = '\0';
}

%}

/*
 * Define names for regular expressions here.
 */

NEWLINE       \n
WHSPACE       [ \t\r\v\f]

DARROW        =>
ASSIGN        <-
LE            <=

CLASS         [cC][lL][aA][sS][sS]
ELSE          [eE][lL][sS][eE]
FI            [fF][iI]
IF            [iI][fF]
IN            [iI][nN]
INHERITS      [iI][nN][hH][eE][rR][iI][tT][sS]
LET           [lL][eE][tT]
LOOP          [lL][oO][oO][pP]
POOL          [pP][oO][oO][lL]
THEN          [tT][hH][eE][nN]
WHILE         [wW][hH][iI][lL][eE]
CASE          [cC][aA][sS][eE]
ESAC          [eE][sS][aA][cC]
OF            [oO][fF]
NEW           [nN][eE][wW]
ISVOID        [iI][sS][vV][oO][iI][dD]
NOT           [nN][oO][tT]

INTEGER       [0-9]+
TRUE          t[rR][uU][eE]
FALSE         f[aA][lL][sS][eE]

TYPE          [A-Z][a-zA-Z0-9_]*
ID            [a-z][a-zA-Z0-9_]*

CHAR          \'[^\0]\'

ILLEGAL       [^ \n\t\v\r\f\'\"\/\-\+\*\(\)\{\}\<\=\,\:\.\;@~a-zA-Z0-9]

%START SINGLELINE
%START MULTILINE
%START STRING

%%

 /* Single-line comments */

"--"        { if (string_open) REJECT;
              single_open = 1;
              BEGIN SINGLELINE;
            }

<SINGLELINE>{
[\n]        { single_open = 0;
              curr_lineno++; BEGIN INITIAL;
            }

.*          ;
} /* END <SINGLELINE> */


 /* Multi-line comments */

"(*"        { if (string_open) REJECT;
              if (!single_open) {
                ++multi_open;
                BEGIN MULTILINE;
              }
            }

<MULTILINE>{
"*)"        { if (multi_open > 1) {
                --multi_open;
              }
              else if (multi_open == 1) {
                --multi_open;
                BEGIN INITIAL;
              }
              else {
                multi_open = 0;
                cool_yylval.error_msg = "Unmatched *)";
                return ERROR;
              }
            }

"(*"        { ++multi_open; }

[^"()*"\n]* ;
"("         ;
")"         ;
"*"         ;
\n          curr_lineno++;

} /* END <MULTILINE> */

"*)"        { if (multi_open) REJECT;
              cool_yylval.error_msg = "Unmatched *)";
              return ERROR;
            }


 /* Strings */

\"          { if (string_open) REJECT;
              if (multi_open > 0) REJECT;
                
              string_open = 1;
              empty_string = 1;
              error = 0;
                
              BEGIN STRING;
            }

<STRING>{

([^"\\\n]|\\.)*\\"\n"/[^"] { yymore(); }

([^"\\\n]|\\.)*\\"\n"/["]  { empty_string = 0;
                             char *error_msg = NULL;
                             process_string(&error_msg);
                             if (error_msg) {
                               cool_yylval.error_msg = error_msg;
                               return ERROR;
                             }
                           }

([^"\\\n]|\\.)*\\"\n"      ;

([^"\\\n]|\\.)*"\n"        { string_open = 0;
                             BEGIN INITIAL;
                             if (!error) {
                             cool_yylval.error_msg =
                             "Unterminated string constant";
                             return ERROR;
                             }
                           }

([^"\\\n]|\\.)*            { empty_string = 0;
                             char *error_msg = NULL;
                             process_string(&error_msg);
                             if (error_msg) {
                               cool_yylval.error_msg = error_msg;
                               return ERROR;
                             }
                           }

\"          { assert(string_open && "Reached end with no open");
              if (strlen(string_buf) > 1024) {
                cool_yylval.error_msg = "String constant too long";
                error = 1;
                return ERROR;
              }

              string_open = 0;
              BEGIN INITIAL;
                
              if (!error) {
                if (empty_string) {
                  empty_string = 0;
                  string_buf[0] = '\0';
                }
                cool_yylval.symbol = stringtable.add_string(string_buf);
                return (STR_CONST);
              }
            }

} /* END <STRING> */

<<EOF>>     { if (multi_open) {
                multi_open = 0;
                cool_yylval.error_msg = "EOF in comment";
                return ERROR;
              }
              if (string_open) {
                string_open = 0;
                cool_yylval.error_msg = "EOF in string constant";
                return ERROR;
              }
              return 0;
            }

 /* Single-character operators */

"+"         { ADD_STR; return (int)'+'; }
"-"         { ADD_STR; return (int)'-'; }
"*"         { ADD_STR; return (int)'*'; }
"/"         { ADD_STR; return (int)'/'; }
"~"         { ADD_STR; return (int)'~'; }
"<"         { ADD_STR; return (int)'<'; }
"="         { ADD_STR; return (int)'='; }
"("         { ADD_STR; return (int)'('; }
")"         { ADD_STR; return (int)')'; }
";"         { ADD_STR; return (int)';'; }
"{"         { ADD_STR; return (int)'{'; }
"}"         { ADD_STR; return (int)'}'; }
":"         { ADD_STR; return (int)':'; }
","         { ADD_STR; return (int)','; }
"@"         { ADD_STR; return (int)'@'; }
"."         { ADD_STR; return (int)'.'; }

 /* Multiple-character operators */

{DARROW}    { ADD_STR; return (DARROW); }
{ASSIGN}    { ADD_STR; return (ASSIGN); }
{LE}        { ADD_STR; return (LE);     }

 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */

{CLASS}     { ADD_STR; return (CLASS);    }
{ELSE}      { ADD_STR; return (ELSE);     }
{FI}        { ADD_STR; return (FI);       }
{IF}        { ADD_STR; return (IF);       }
{IN}        { ADD_STR; return (IN);       }
{INHERITS}  { ADD_STR; return (INHERITS); }
{LET}       { ADD_STR; return (LET);      }
{LOOP}      { ADD_STR; return (LOOP);     }
{POOL}      { ADD_STR; return (POOL);     }
{THEN}      { ADD_STR; return (THEN);     }
{WHILE}     { ADD_STR; return (WHILE);    }
{CASE}      { ADD_STR; return (CASE);     }
{ESAC}      { ADD_STR; return (ESAC);     }
{OF}        { ADD_STR; return (OF);       }
{NEW}       { ADD_STR; return (NEW);      }
{ISVOID}    { ADD_STR; return (ISVOID);   }
{NOT}       { ADD_STR; return (NOT);      }

 /* Booleans */

{TRUE}      { inttable.add_int(1);
              cool_yylval.boolean = 1;
              return (BOOL_CONST);
            }

{FALSE}     { inttable.add_int(0);
              cool_yylval.boolean = 0;
              return (BOOL_CONST);
            }

 /* Integers */

{INTEGER}   { ADD_INT; return (INT_CONST); }

 /* Identifiers */

{TYPE}      { ADD_ID; return (TYPEID);   }
{ID}        { ADD_ID; return (OBJECTID); }

 /* Misc */

{WHSPACE}*  { ADD_STR; }

{CHAR}      { cool_yylval.symbol = stringtable.add_string(yytext+1, yyleng-2);
              return (STR_CONST); }

{NEWLINE}   curr_lineno++;

{ILLEGAL}   { cool_yylval.error_msg = yytext;
              return ERROR; }

.|\n        ;

%%
