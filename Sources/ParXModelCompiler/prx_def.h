//
// prx_def.h
// ParXModelCompiler
//
// Main header file
//
// Copyright (c) 2015-2025 Martin G. Middelhoek <martin@middelhoek.com>.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
//

#ifndef _PRX_DEF_H
#define _PRX_DEF_H

#include <ctype.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* File identifier */
#define FILEID "ParX interpreter code"
/* Version */
#define CODE_VERSION 4.2
/* maximum line length in model description file (without newline) */
#define MAXLINE 200
/* maximum expression length in model file (by continuation) */
#define MAXCMD 1005
/* maximum nesting level of conditional statements */
#define MAXLEVEL 16
/* maximum name length */
#define MAXNAME 32
/* maximum unit length */
#define MAXUNIT 32
/* maximum number of statements (assignments, if, else, fi) */
#define MAXEQU 1000
/* number of values in value declaration */
#define NUMDECVALUES 5

typedef enum { /* operands */
    VAR, AUX, PAR, CON, FLG, RES, TMP, DRES, DTMP
} TYP;

typedef enum { /* operators */
    INVAL, AND, OR, NOT, LT, GT, LE, GE, EQ, NE,
    NEG, ADD, SUB, MUL, DIV, POW, REV, SQR, INC, DEC, EQU,
    SIN, COS, TAN, ASIN, ACOS, ATAN, SINH, COSH, TANH, ERF,
    EXP, LOG, LG, SQRT, ABS, SGN, RET, CHKL, CHKG,
    OPD, NUM, DOPD, LDF, ASS, NASS, CLR,
    JMP, IF, ELSE, FI, EOD, SOK, STOP
} OPR;

/* the parse tree */
struct PRX_NODE_S {
    OPR opr;
    struct PRX_NODE_S *o1;

    union {
        struct PRX_NODE_S *o2;
        struct PRX_OPD_S *optr;
        struct PRX_NUM_S *nptr;
    } c;

    struct PRX_NODE_S *abl;
};
typedef struct PRX_NODE_S PRX_NODE;

/* number node */
struct PRX_NUM_S {
    double val;
    PRX_NODE *node;
    int ind;
};
typedef struct PRX_NUM_S PRX_NUM;

/* name node */
struct PRX_OPD_S {
    char *name;
    PRX_NODE *node;
    int ind;
    TYP typ;
};
typedef struct PRX_OPD_S PRX_OPD;

/* code stack element */
union PRX_CODE_U {
    OPR o;
    int i;
    TYP t;
    union PRX_CODE_U *c;
};
typedef union PRX_CODE_U CODE;

extern int prx_name(char *);
extern int prx_constant(char *ps, double *);
extern int prx_unit(char *);
extern int prx_number(char *, double *, int *);
extern int prx_number_format(double, int, char *);
extern int prx_values(char *, double *, int *, int);

extern const char reserved_name_tokens[];
extern const char not_at_name_start_tokens[];
extern const char name_separator_token[];

#endif
