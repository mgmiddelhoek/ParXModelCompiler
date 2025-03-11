//
// prx_func.c
// ParXModelCompiler
//
// Helper subroutines
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

#include "prx_def.h"

const char reserved_name_tokens[] = {
    '\r', '\n', '\t', ' ', '\\', '"', ',', ';', ':', '=', '(', ')', '{',
    '}',  '+',  '-',  '*', '/',  '^', '!', '>', '<', '&', '|', '\0'};
#define NUMBER_OF_RESERVED_NAME_TOKENS                                         \
    (sizeof(reserved_name_tokens) / sizeof(char))

const char not_at_name_start_tokens[] = {'.', '_', '0', '1', '2', '3', '4',
                                         '5', '6', '7', '8', '9', '\0'};
#define NUMBER_OF_NOT_AT_NAME_START_TOKENS                                     \
    (sizeof(not_at_name_start_tokens) / sizeof(char))

const char name_separator_token[] = {':', '\0'};

/**
 @brief syntax check of a name token

 @discussion first character is alpha, <br>
 other characters are alnum or '_', <br>
 no Unicode support

 @param ps input string pointer
 @return number of characters in valid name
 */
int prx_name_ascii(char *ps) {
    char c;
    char *pe;

    pe = ps;
    /* 1. character = letter */
    if (!isalpha(*pe)) {
        return 0;
    }
    /* 2-nd to last character */
    while ((void)(c = *(++pe)), isalnum(c) || *pe == '_')
        ;
    if (pe - ps > MAXNAME) {
        return (int)(ps - pe);
    }
    return (int)(pe - ps);
}

/**
 @brief syntax check of a name token

 @discussion first character is not token, '_' or digit, <br>
 other characters are not token <br>
 implicit Unicode UTF8 support

 @param ps input string pointer
 @return number of bytes in valid name
 */
int prx_name(char *ps) {
    int i, stop;
    char *pe;

    pe = ps;

    /* 1. character */

    for (i = 0; i < NUMBER_OF_NOT_AT_NAME_START_TOKENS; i++) {
        if (*pe == not_at_name_start_tokens[i]) {
            return 0;
        }
    }
    for (i = 0; i < NUMBER_OF_RESERVED_NAME_TOKENS; i++) {
        if (*pe == reserved_name_tokens[i]) {
            return 0;
        }
    }

    /* 2-nd to last character */

    stop = 0;
    while (stop == 0 && *(++pe)) {
        for (i = 0; i < NUMBER_OF_RESERVED_NAME_TOKENS; i++) {
            if (*pe == reserved_name_tokens[i]) {
                stop = 1;
                break;
            }
        }
    }

    if (pe - ps > MAXNAME) {
        return (int)(ps - pe);
    }
    return (int)(pe - ps);
}

/**
 @brief syntax check of a constant token

 @discussion first character is '_', <br>
 other characters are alnum or '_', <br>
 no Unicode support

 @param ps input string pointer
 @param value constant value
 @return number of characters in valid constant
 */
int prx_constant(char *ps, double *value) {
    char c;
    int length;
    char *pe;

    pe = ps;
    *value = 0.0;
    /* 1. character = '_' */
    if (*pe != '_') {
        return 0;
    }
    /* 2-nd to last character */
    while ((void)(c = *(++pe)), isalnum(c) || *pe == '_')
        ;
    if (pe - ps > MAXNAME) {
        return (int)(ps - pe);
    }

    length = (int)(pe - ps);

    if (length == 3 && 0 == memcmp(ps, "_pi", 3)) { /* special number pi */
        *value = M_PI;
    } else if (length == 5 &&
               0 == memcmp(ps, "_pi_2", 5)) { /* special number pi/2 */
        *value = M_PI_2;
    } else if (length == 5 &&
               0 == memcmp(ps, "_pi_4", 5)) { /* special number pi/4 */
        *value = M_PI_4;
    } else if (length == 5 &&
               0 == memcmp(ps, "_1_pi", 5)) { /* special number 1/pi */
        *value = M_1_PI;
    } else if (length == 5 &&
               0 == memcmp(ps, "_2_pi", 5)) { /* special number 2/pi */
        *value = M_2_PI;
    } else if (length == 7 &&
               0 == memcmp(ps, "_sqrtpi", 7)) { /* special number sqrt(pi) */
        *value = sqrt(M_PI);
    } else if (length == 8 &&
               0 == memcmp(ps, "_sqrt2pi", 8)) { /* special number sqrt(2pi) */
        *value = sqrt(2.0 * M_PI);
    } else if (length == 9 && 0 == memcmp(ps, "_1_sqrtpi",
                                          9)) { /* special number 1/sqrt(pi) */
        *value = M_2_SQRTPI / 2.0;
    } else if (length == 9 && 0 == memcmp(ps, "_2_sqrtpi",
                                          9)) { /* special number 2/sqrt(pi) */
        *value = M_2_SQRTPI;

    } else if (length == 2 && 0 == memcmp(ps, "_e", 2)) { /* special number e */
        *value = M_E;
    } else if (length == 4 &&
               0 == memcmp(ps, "_ln2", 4)) { /* special number ln(2) */
        *value = M_LN2;
    } else if (length == 5 &&
               0 == memcmp(ps, "_ln10", 5)) { /* special number ln(10) */
        *value = M_LN10;
    } else if (length == 7 &&
               0 == memcmp(ps, "_log10e", 7)) { /* special number log10(e) */
        *value = M_LOG10E;

    } else if (length == 6 &&
               0 == memcmp(ps, "_sqrt2", 6)) { /* special number sqrt(2) */
        *value = M_SQRT2;
    } else if (length == 8 &&
               0 == memcmp(ps, "_sqrt1_2", 8)) { /* special number sqrt(1/2) */
        *value = M_SQRT1_2;

    } else if (length == 2 &&
               0 == memcmp(ps, "_k", 2)) { /* Boltzman constant */
        *value = 1.3806485279e-23;
    } else if (length == 2 &&
               0 == memcmp(ps, "_c", 2)) { /* light speed in vacuum */
        *value = 2.99792458e8;
    } else if (length == 2 &&
               0 == memcmp(ps, "_G", 2)) { /* gravitational constant */
        *value = 6.67259e-11;
    } else if (length == 5 &&
               0 == memcmp(ps, "_eps0", 4)) { /* electric constant */
        *value = 8.854187817e-12;
    } else if (length == 4 &&
               0 == memcmp(ps, "_mu0", 4)) { /* magnetic constant */
        *value = 1.2566370614e-6;
    } else if (length == 3 && 0 == memcmp(ps, "_0C", 3)) { /* 0C in Kelvin */
        *value = 273.15;
    } else if (length == 3 &&
               0 == memcmp(ps, "_NA", 3)) { /* Avogadro constant */
        *value = 6.022140857e+23;
    } else if (length == 2 && 0 == memcmp(ps, "_R", 2)) { /* Gas constant */
        *value = 8.314459848;
    } else if (length == 2 && 0 == memcmp(ps, "_h", 2)) { /* Planck constant */
        *value = 6.626070040e-34;
    } else if (length == 2 && 0 == memcmp(ps, "_F", 2)) { /* Faraday constant */
        *value = 9.64853328959e+4;
    } else if (length == 2 &&
               0 == memcmp(ps, "_q", 2)) { /* elementary charge */
        *value = 1.602176620898e-19;
    } else {
        return -length;
    }
    return length;
}

/**
 @brief syntax check of a unit token

 @discussion accept all except "," or EOL, also UTF8

 @param ps input string pointer
 @return number of bytes in valid unit
 */
int prx_unit(char *ps) {
    char c;
    char *pe;

    pe = ps;
    if (*pe == '\0' || *pe == ',') {
        return 0;
    }

    while ((c = *(++pe) && *pe != ','))
        ;
    if (pe - ps > MAXUNIT) {
        return (int)(ps - pe);
    }
    return (int)(pe - ps);
}

/**
 @brief syntax check of a number token

 @param ps input string pointer
 @param value output value as double
 @param length number of characters in input
 @return 0 when successful, 1 when error

 */
int prx_number(char *ps, double *value, int *length) {
    int i;
    char c;
    int nDig, dot, dDig, eDig;
    double sign, factor, number, constant;

    i = 0;
    sign = 1.0;
    nDig = 0;
    dot = 0;
    dDig = 0;
    eDig = 0;

    c = ps[i++];
    *length = 0;
    if (c == '+' || c == '-') {
        if (c == '+') {
            sign = 1.0;
        }
        if (c == '-') {
            sign = -1.0;
        }
        c = ps[i++];
    }
    while (c >= '0' && c <= '9') { /* digits before dot */
        c = ps[i++];
        nDig++;
    }
    if (nDig == 0 && c != '_') { /* numbers must start with a digit or '_' */
        return 1;
    }
    if (c == '.') {
        dot = 1;
        c = ps[i++];
    }
    while (c >= '0' && c <= '9') { /* digits after dot */
        c = ps[i++];
        dDig++;
    }
    if (dot == 1 && dDig == 0) {
        *length = --i;
        return 1;
    }
    if (c == 'e') { /* e as exponent */
        c = ps[i++];
        if (c == '-' || c == '+') {
            c = ps[i++];
        }
        while (c >= '0' && c <= '9') {
            c = ps[i++]; /* digits exponent */
            eDig++;
        }
        if (eDig == 0) {
            *length = --i;
            return 1;
        }
    }
    switch (c) {
    case 'y':
        factor = 1e-24;
        break;
    case 'z':
        factor = 1e-21;
        break;
    case 'a':
    case 'A':
        factor = 1e-18;
        break;
    case 'f':
    case 'F':
        factor = 1e-15;
        break;
    case 'p':
        factor = 1e-12;
        break;
    case 'n':
    case 'N':
        factor = 1e-9;
        break;
    case 'u':
    case 'U':
        factor = 1e-6;
        break;
    case 'm':
        factor = 1e-3;
        break;
    case 'k':
    case 'K':
        factor = 1e3;
        break;
    case 'M':
        factor = 1e6;
        break;
    case 'G':
        factor = 1e9;
        break;
    case 'T':
        factor = 1e12;
        break;
    case 'P':
        factor = 1e15;
        break;
    case 'E':
        factor = 1e18;
        break;
    case 'Z':
        factor = 1e21;
        break;
    case 'Y':
        factor = 1e24;
        break;
    default:
        factor = 1.0;
        i--;
    }

    if (nDig > 0) {
        *length = i;

        int fields = sscanf(ps, "%le", &number);
        if (fields != 1) {
            return 1; /* not a valid number */
        }
        number *= factor;
        sign = 1.0;
        *value = number;
    } else {
        number = 1.0;
    }
    if (ps[i] == '_') { /* trailing constant */
        int len = prx_constant(&ps[i], &constant);
        if (len <= 1) {
            *length += abs(len);
            return 1;
        }
        *value = sign * number * constant;
        *length += len;
    }
    return 0;
}

/* Output functions */

/**
 @brief Convert value to engineering notation

 @param value input value as a double
 @param n     number of digits
 @param eng   number in engineering notation

 @return
 0 - engineering notation created,
 1 - scientific notation created
 */
int prx_number_format(double value, int n, char *eng) {
    int ibase, itrans;
    int iexp;
    char *scale;
    int length;
    char *cptr;

    length = n + 6;
    sprintf(eng, "%*.*e", length, length - 7, value);

    /* find the exponent */
    cptr = strchr(eng, 'e');
    if (cptr == NULL) {
        cptr = strchr(eng, 'E');
    }
    if (cptr == NULL) {
        return (1);
    }
    sscanf(cptr + 1, "%d", &iexp);
    if (iexp < -18 || iexp >= 15) {
        return (1);
    }
    *cptr = 0;

    /* set the decimal dot */
    cptr = strchr(eng, '.');
    if (cptr == NULL) {
        return (1);
    }

    ibase = ((iexp + 18) / 3) * 3 - 18;
    itrans = iexp - ibase;

    if (itrans == 1) {
        cptr[0] = cptr[1];
        cptr[1] = '.';
    } else if (itrans == 2) {
        cptr[0] = cptr[1];
        cptr[1] = cptr[2];
        cptr[2] = '.';
    }

    switch (ibase) {
    case -3:
        scale = "m";
        break;
    case 3:
        scale = "k";
        break;
    case -6:
        scale = "u";
        break;
    case 6:
        scale = "M";
        break;
    case -9:
        scale = "n";
        break;
    case 9:
        scale = "G";
        break;
    case -12:
        scale = "p";
        break;
    case 12:
        scale = "T";
        break;
    case -15:
        scale = "f";
        break;
    case 15:
        scale = "T";
        break;
    case -18:
        scale = "a";
        break;
    case 18:
        scale = "E";
        break;
    case -21:
        scale = "z";
        break;
    case 21:
        scale = "Z";
        break;
    case -24:
        scale = "y";
        break;
    case 24:
        scale = "Y";
        break;
    default:
        scale = "";
        break;
    }
    strcat(eng, scale);
    return (0);
}

/**
 @brief syntax check of a value list in declarations

 @param ps         input string pointer
 @param Vals       found values
 @param pNVals     number of values
 @param maxVals    maximum number of values to parse
 @return number of parsed characters, 0 in case of error
 */
int prx_values(char *ps, double *Vals, int *pNVals, int maxVals) {
    char *pe;
    int length, nVals;

    pe = ps;
    nVals = 0;
    if (*(pe++) != '{') {
        return 0;
    }
    do {
        if (nVals >= maxVals) {
            return 0;
        }
        if (memcmp(pe, "inf", 3) == 0 || memcmp(pe, "Inf", 3) == 0) {
            Vals[nVals++] = +HUGE_VAL;
            pe += 3;
            continue;
        } else if (memcmp(pe, "-inf", 4) == 0 || memcmp(pe, "-Inf", 4) == 0) {
            Vals[nVals++] = -HUGE_VAL;
            pe += 4;
            continue;
        }
        if (prx_number(pe, Vals + nVals, &length)) {
            return 0;
        }
        nVals++;
        pe += length;
    } while (*(pe++) == ',');

    *pNVals = nVals;

    if (*(pe - 1) != '}') {
        return 0;
    }
    return (int)(pe - ps);
}
