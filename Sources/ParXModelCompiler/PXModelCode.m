//
// PXModelCode.m
// ParXModelCompiler
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

#import <Foundation/Foundation.h>
#import "PXModelCode.h"

@interface PXModelCode ()

- (void)extendCodeArrayByOne;
- (void)extendNumberArrayByOne;

@end

/**
 @brief Representation of the model code, output of the Compiler, input for the Interpreter
 */
@implementation PXModelCode {
    CODE *modelCode;
    CODE *lastCode;
    int lengthCode;
    int lengthCodeBlock;

    double *modelNumbers;
    double *lastNumber;
    int lengthNumbers;
    int lengthNumbersBlock;
}

- (PXModelCode *)init {
    self = [super init];

    if (self) {

        self.varName = [[NSMutableArray alloc] init];
        self.varAbsTol = [[NSMutableArray alloc] init];
        self.varLowerLimit = [[NSMutableArray alloc] init];
        self.varUpperLimit = [[NSMutableArray alloc] init];
        self.varUnit = [[NSMutableArray alloc] init];

        self.auxName = [[NSMutableArray alloc] init];
        self.auxAbsTol = [[NSMutableArray alloc] init];
        self.auxLowerLimit = [[NSMutableArray alloc] init];
        self.auxUpperLimit = [[NSMutableArray alloc] init];

        self.parName = [[NSMutableArray alloc] init];
        self.parDefaultValue = [[NSMutableArray alloc] init];
        self.parLowerBound = [[NSMutableArray alloc] init];
        self.parUpperBound = [[NSMutableArray alloc] init];
        self.parLowerLimit = [[NSMutableArray alloc] init];
        self.parUpperLimit = [[NSMutableArray alloc] init];
        self.parUnit = [[NSMutableArray alloc] init];

        self.conName = [[NSMutableArray alloc] init];
        self.conDefaultValue = [[NSMutableArray alloc] init];
        self.conUnit = [[NSMutableArray alloc] init];

        self.flgName = [[NSMutableArray alloc] init];
        self.flgDefaultValue = [[NSMutableArray alloc] init];

        self.resName = [[NSMutableArray alloc] init];

        self.numberOfTemp = 0;

        modelCode = NULL;
        lastCode = NULL;
        lengthCode = 0;
        lengthCodeBlock = 0;

        modelNumbers = NULL;
        lastNumber = NULL;
        lengthNumbers = 0;
        lengthNumbersBlock = 0;
    }
    return self;
}

- (CODE *)getModelCode {
    return modelCode;
}

- (int)getLengthCode {
    return lengthCode;
}

- (double *)getModelNumbers {
    return modelNumbers;
}

- (int)getLengthNumbers {
    return lengthNumbers;
}

#define ALLOC_BLOCKSIZE 4096

- (void)extendCodeArrayByOne {
    CODE *new;

    if (lengthCode == 0) {
        lengthCodeBlock = ALLOC_BLOCKSIZE;
        modelCode = malloc(lengthCodeBlock * sizeof(CODE));
    }
    if (++lengthCode > lengthCodeBlock) {
        lengthCodeBlock += ALLOC_BLOCKSIZE;
        new = (CODE *)realloc(modelCode, lengthCodeBlock * sizeof(CODE));
        if (new == NULL) {
            free(modelCode);
            exit(1);
        }
        modelCode = new;
    }
    lastCode = &modelCode[lengthCode - 1];
}

- (void)extendNumberArrayByOne {
    double *new;

    if (lengthNumbers == 0) {
        lengthNumbersBlock = ALLOC_BLOCKSIZE;
        modelNumbers = malloc(lengthNumbersBlock * sizeof(double));
    }
    if (++lengthNumbers > lengthNumbersBlock) {
        lengthNumbersBlock += ALLOC_BLOCKSIZE;
        new = (double *)realloc(modelNumbers,
                                lengthNumbersBlock * sizeof(double));
        if (new == NULL) {
            free(modelNumbers);
            exit(1);
        }
        modelNumbers = new;
    }
    lastNumber = &modelNumbers[lengthNumbers - 1];
}

- (void)dealloc {
    free(modelCode);
    free(modelNumbers);
}

- (void)addOperator:(OPR)operator{
    [self extendCodeArrayByOne];
    lastCode->o = operator;
}

- (void)addType:(TYP)type {
    [self extendCodeArrayByOne];
    lastCode->t = type;
}

- (void)addIndex:(int)index {
    [self extendCodeArrayByOne];
    lastCode->i = index;
}

- (void)addVarName:(NSString *)name
        withAbsTol:(NSNumber *)abstol
    withLowerLimit:(NSNumber *)lowerLimit
    withUpperLimit:(NSNumber *)upperLimit
          withUnit:(NSString *)unit {
    [self.varName addObject:name];
    [self.varAbsTol addObject:abstol];
    [self.varLowerLimit addObject:lowerLimit];
    [self.varUpperLimit addObject:upperLimit];
    [self.varUnit addObject:unit];
}

- (void)addAuxName:(NSString *)name
        withAbsTol:(NSNumber *)abstol
    withLowerLimit:(NSNumber *)lowerLimit
    withUpperLimit:(NSNumber *)upperLimit {
    [self.auxName addObject:name];
    [self.auxAbsTol addObject:abstol];
    [self.auxLowerLimit addObject:lowerLimit];
    [self.auxUpperLimit addObject:upperLimit];
}

- (void)addParName:(NSString *)name
    withDefaultValue:(NSNumber *)defVal
      withLowerBound:(NSNumber *)lowVal
      withUpperBound:(NSNumber *)upVal
      withLowerLimit:(NSNumber *)lowerLimit
      withUpperLimit:(NSNumber *)upperLimit
            withUnit:(NSString *)unit {
    [self.parName addObject:name];
    [self.parDefaultValue addObject:defVal];
    [self.parLowerBound addObject:lowVal];
    [self.parUpperBound addObject:upVal];
    [self.parLowerLimit addObject:lowerLimit];
    [self.parUpperLimit addObject:upperLimit];
    [self.parUnit addObject:unit];
}

- (void)addConName:(NSString *)name
    withDefaultValue:(NSNumber *)defVal
            withUnit:(NSString *)unit {
    [self.conName addObject:name];
    [self.conDefaultValue addObject:defVal];
    [self.conUnit addObject:unit];
}

- (void)addFlgName:(NSString *)name withDefaultValue:(NSNumber *)defVal {
    [self.flgName addObject:name];
    [self.flgDefaultValue addObject:defVal];
}

- (void)addResName:(NSString *)name {
    [self.resName addObject:name];
}

- (void)addNumber:(double)number {
    [self extendNumberArrayByOne];
    *lastNumber = number;
}

- (void)print {

    char *oprName[128]; /* operator names */
    char *varTyp[16];   /* operand types */
    OPR opr;            /* operator */
    TYP type;
    int index;
    int nSok, nEod;
    NSString *pe, *pd;

    varTyp[VAR] = "var";
    varTyp[AUX] = "aux";
    varTyp[PAR] = "par";
    varTyp[CON] = "con";
    varTyp[FLG] = "flg";
    varTyp[RES] = "res";
    varTyp[TMP] = "tmp";
    varTyp[DTMP] = "dTmp";
    varTyp[DRES] = "dRes";

    oprName[AND] = "&";
    oprName[OR] = "|";
    oprName[NOT] = "not";
    oprName[LT] = "<";
    oprName[GT] = ">";
    oprName[LE] = "<=";
    oprName[GE] = ">=";
    oprName[EQ] = "==";
    oprName[NE] = "!=";
    oprName[NEG] = "~";
    oprName[ADD] = "+";
    oprName[SUB] = "-";
    oprName[MUL] = "*";
    oprName[DIV] = "/";
    oprName[POW] = "^";
    oprName[REV] = "1/";
    oprName[SQR] = "^2";
    oprName[INC] = "+1";
    oprName[DEC] = "-1";
    oprName[SGN] = "sgn";
    oprName[IF] = "if";
    oprName[ELSE] = "else";
    oprName[FI] = "fi";
    oprName[EOD] = "eod";
    oprName[SOK] = "sok";
    oprName[SIN] = "sin";
    oprName[COS] = "cos";
    oprName[TAN] = "tan";
    oprName[ASIN] = "asin";
    oprName[ACOS] = "acos";
    oprName[ATAN] = "atan";
    oprName[SINH] = "sinh";
    oprName[COSH] = "cosh";
    oprName[TANH] = "tanh";
    oprName[EXP] = "exp";
    oprName[ERF] = "erf";
    oprName[LOG] = "log";
    oprName[LG] = "log10";
    oprName[SQRT] = "sqrt";
    oprName[ABS] = "abs";
    oprName[RET] = "return";
    oprName[OPD] = "opd";
    oprName[NUM] = "num";
    oprName[LDF] = "ldf";
    oprName[JMP] = "jmp";
    oprName[STOP] = "stop";
    oprName[DOPD] = "dopd";
    oprName[ASS] = "+->";
    oprName[NASS] = "-->";
    oprName[CLR] = "0->";
    oprName[CHKL] = "<?:ret";
    oprName[CHKG] = ">?:ret";
    oprName[127] = ">126";
    oprName[INVAL] = "INVALID";

    nSok = nEod = 0;
    pd = self.varName[0];

    fprintf(stderr, "model code:\n\n");

    for (int i = 0; i < lengthCode; i++) {

        opr = modelCode[i].o;
        if (opr == STOP) {
            break;
        }

        switch (opr) {
        case AND:
        case OR:
        case LT:
        case GT:
        case LE:
        case GE:
        case EQ:
        case NE:
        case NOT:
        case ADD:
        case SUB:
        case MUL:
        case DIV:
        case POW:
        case NEG:
        case REV:
        case SQR:
        case INC:
        case DEC:
        case SGN:
        case SIN:
        case COS:
        case TAN:
        case ASIN:
        case ACOS:
        case ATAN:
        case EXP:
        case LOG:
        case LG:
        case SQRT:
        case ABS:
            fprintf(stderr, "%s ", oprName[opr]);
            break;
        case RET:
            fprintf(stderr, "%s\n", oprName[opr]);
            break;
        case OPD:
            type = modelCode[++i].t;
            index = modelCode[++i].i;
            switch (type) {
            case VAR:
                pe = self.varName[index];
                fprintf(stderr, "%s ", [pe UTF8String]);
                break;
            case AUX:
                pe = self.auxName[index];
                fprintf(stderr, "%s ", [pe UTF8String]);
                break;
            case PAR:
                pe = self.parName[index];
                fprintf(stderr, "%s ", [pe UTF8String]);
                break;
            case CON:
                pe = self.conName[index];
                fprintf(stderr, "%s ", [pe UTF8String]);
                break;
            case FLG:
                pe = self.flgName[index];
                fprintf(stderr, "%s ", [pe UTF8String]);
                break;
            case RES:
                pe = self.resName[index];
                fprintf(stderr, "%s ", [pe UTF8String]);
                break;
            case TMP:
                fprintf(stderr, "tmp[%d] ", index);
                break;
            case DRES:
                pe = self.resName[index];
                fprintf(stderr, "d_%s/d_%s ", [pe UTF8String], [pd UTF8String]);
                break;
            case DTMP:
                fprintf(stderr, "d_tmp[%d]/d_%s ", index, [pd UTF8String]);
                break;
            default:
                break;
            }
            break;
        case NUM:
            index = modelCode[++i].i;
            double d = modelNumbers[index];
            fprintf(stderr, "%g ", d);
            break;
        case ASS:
        case NASS:
        case CLR:
            type = modelCode[++i].t;
            index = modelCode[++i].i;
            switch (type) {
            case VAR:
                pe = self.varName[index];
                fprintf(stderr, "%s %s\n", oprName[opr], [pe UTF8String]);
                break;
            case AUX:
                pe = self.auxName[index];
                fprintf(stderr, "%s %s\n", oprName[opr], [pe UTF8String]);
                break;
            case PAR:
                pe = self.parName[index];
                fprintf(stderr, "%s %s\n", oprName[opr], [pe UTF8String]);
                break;
            case CON:
                pe = self.conName[index];
                fprintf(stderr, "%s %s\n", oprName[opr], [pe UTF8String]);
                break;
            case FLG:
                pe = self.flgName[index];
                fprintf(stderr, "%s %s\n", oprName[opr], [pe UTF8String]);
                break;
            case RES:
                pe = self.resName[index];
                fprintf(stderr, "%s %s\n", oprName[opr], [pe UTF8String]);
                break;
            case TMP:
                printf("%s tmp[%d]\n", oprName[opr], index);
                break;
            case DRES:
                pe = self.resName[index];
                fprintf(stderr, "%s d_%s/d_%s\n", oprName[opr], [pe UTF8String],
                        [pd UTF8String]);
                break;
            case DTMP:
                fprintf(stderr, "%s d_tmp[%d]/d_%s\n", oprName[opr], index,
                        [pd UTF8String]);
                break;
            default:
                break;
            }
            break;
        case CHKG:
        case CHKL:
            fprintf(stderr, "%s\n", oprName[opr]);
            break;
        case EOD:
            fprintf(stderr, "%s__________________________%s\n\n", oprName[opr],
                    [pd UTF8String]);
            nEod++;
            switch (nSok) {
            case 1:
                pd = nEod < [self.varName count] ? self.varName[nEod]
                                                 : [NSString new];
                break;
            case 2:
                pd = nEod < [self.auxName count] ? self.auxName[nEod]
                                                 : [NSString new];
                break;
            case 3:
                pd = nEod < [self.parName count] ? self.parName[nEod]
                                                 : [NSString new];
                break;
            }

            break;
        case SOK:
            nSok++;
            nEod = 0;
            switch (nSok) {
            case 1:
                pd = nEod < [self.varName count] ? self.varName[nEod]
                                                 : [NSString new];
                fprintf(stderr, "%s__________________________________dVar\n\n",
                        oprName[opr]);
                break;
            case 2:
                pd = nEod < [self.auxName count] ? self.auxName[nEod]
                                                 : [NSString new];
                fprintf(stderr, "%s__________________________________dAux\n\n",
                        oprName[opr]);
                break;
            case 3:
                pd = nEod < [self.parName count] ? self.parName[nEod]
                                                 : [NSString new];
                fprintf(stderr, "%s__________________________________dPar\n\n",
                        oprName[opr]);
                break;
            }
            break;
        case IF:
        case ELSE:
        case FI:
            fprintf(stderr, "%s\n", oprName[opr]);
            break;
        default:
            fprintf(stderr, "Invalid operator: %d\n", opr);
            break;
        }
    }
}

@end
