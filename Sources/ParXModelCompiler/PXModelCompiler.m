//
// PXModelCompiler.m
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
#import "mem_def.h"
#import "bt_def.h"
#import "prx_def.h"
#import "PXModelCompiler.h"
#import "PXModelCode.h"

@interface PXModelCompiler ()

- (int)setStatics;
- (int)freeMemoryPools;
- (int)getError;
- (int)parseModelFile:(FILE *)inFile;
- (PRX_NODE *)getNum:(double)value;
- (PRX_OPD *)newName:(char *)name withType:(TYP)typ withIndex:(int)ind;
- (int)parseHeaderDefinition:(char *)definition;
- (int)createDerivativesIndex;
- (void)addNotUsed:(char *)name;
- (void)addNotAssigned:(char *)name;
- (int)checkModelConsistency;
- (int)parseEquation:(char *)equation;
- (int)parseExpression:(char *)expression;
- (int)genCodeForNode:(PRX_NODE *)pNode;
- (int)numOut;
- (int)generateDerivatives;
- (int)derivativeToVariable:(PRX_OPD *)pOpd;
- (int)derivativeForSubExpression:(PRX_NODE *)p
                       toVariable:(PRX_OPD *)arg
                          withVal:(PRX_OPD *)fval;
- (int)simplifyExpressionAtNode:(PRX_NODE *)p;

@end

/**
 @brief Compiler for generating the code from the model input description
 */
@implementation PXModelCompiler {

    PXModelCode *modelCode;
    NSMutableArray *symbolsNotAssigned;
    NSMutableArray *symbolsNotUsed;
}

__weak id thisClass; /* for calling self in C-functions */

static int prxErrorLineno = 0;
static char prxErrorString[1024];

- (PXModelCompiler *)initWithPath:(NSString *)modelFileName
                          error:(NSError **)error {
    FILE *inFile;
    const char *fileName;

    prxErrorLineno = 0;
    prxErrorString[0] = '\0';

    NSString *errorDomain = @"com.Middelhoek.ParXModelCompiler";
    NSString *errorDescription;
    NSDictionary *errorUserInfo;
    NSString *errorLineNumber;

    self = [super init];

    if (self) {

        if (!modelFileName || modelFileName.length == 0) {

            if (error != nil) {
                errorDescription = @"No model file specified";
                errorLineNumber = nil;
                errorUserInfo = [NSDictionary
                    dictionaryWithObjectsAndKeys:
                        errorDescription, NSLocalizedDescriptionKey,
                        errorLineNumber, NSLocalizedFailureReasonErrorKey, nil];
                *error = [NSError errorWithDomain:errorDomain
                                             code:0
                                         userInfo:errorUserInfo];
            }
            return nil;
        }
        fileName = [modelFileName cStringUsingEncoding:NSUTF8StringEncoding];

        inFile = fopen(fileName, "r");

        if (!inFile) { /* file open error */
            if (error != nil) {
                errorDescription = @"Error opening model file";
                errorLineNumber = nil;
                errorUserInfo = [NSDictionary
                    dictionaryWithObjectsAndKeys:
                        errorDescription, NSLocalizedDescriptionKey,
                        errorLineNumber, NSLocalizedFailureReasonErrorKey, nil];
                *error = [NSError errorWithDomain:errorDomain
                                             code:1
                                         userInfo:errorUserInfo];
            }
            return nil;
        }

        thisClass = self;

        modelCode = [[PXModelCode alloc] init];
        modelCode.fileName = modelFileName;

        symbolsNotAssigned = [NSMutableArray new];
        symbolsNotUsed = [NSMutableArray new];

        [self setStatics];

        if (![self parseModelFile:inFile]) {
            goto error;
        }

        if ([self getError]) { // check for deep errors
            goto error;
        }

        if (![self checkModelConsistency]) {
            goto error;
        }

        if (![self generateDerivatives]) {
            goto error;
        }

        modelCode.numberOfTemp = nTmp;

        if (![self numOut]) {
            goto error;
        }

        if ([self getError]) { // check for deep errors
            goto error;
        }

        fclose(inFile);

        return self;
    }

    return self;

error: /* abnormal end of program execution */

    fclose(inFile);

    if (error != nil) {
        errorDescription = [NSString stringWithUTF8String:prxErrorString];
        errorLineNumber = [NSString stringWithFormat:@"%d", prxErrorLineno];
        errorUserInfo = [NSDictionary
            dictionaryWithObjectsAndKeys:errorDescription,
                                         NSLocalizedDescriptionKey,
                                         errorLineNumber,
                                         NSLocalizedFailureReasonErrorKey, nil];
        *error = [NSError errorWithDomain:errorDomain
                                     code:1
                                 userInfo:errorUserInfo];
    }

    return nil;
}

- (void)dealloc {
    [self freeMemoryPools];
}

- (PXModelCode *)getModelCode {
    return modelCode;
}

- (NSMutableArray *)getSymbolsNotAssigned {
    return symbolsNotAssigned;
}

- (NSMutableArray *)getSymbolsNotUsed {
    return symbolsNotUsed;
}

+ (NSString *)getReservedNameTokens {
    NSString *tokenString = [NSString stringWithCString:reserved_name_tokens
                                               encoding:NSASCIIStringEncoding];
    return tokenString;
}

+ (NSString *)getNotAtNameStartTokens {
    NSString *tokenString = [NSString stringWithCString:not_at_name_start_tokens
                                               encoding:NSASCIIStringEncoding];
    return tokenString;
}

+ (NSString *)getNameSeparatorToken {
    NSString *tokenString = [NSString stringWithCString:name_separator_token
                                               encoding:NSASCIIStringEncoding];
    return tokenString;
}

/* ========================================================================== */

static const struct {
    char *name;
    OPR opr;
} FunSt[] = {/* standard function parser keywords */
             {"sin", SIN},   {"cos", COS},   {"tan", TAN},   {"asin", ASIN},
             {"acos", ACOS}, {"atan", ATAN}, {"sinh", SINH}, {"cosh", COSH},
             {"tanh", TANH}, {"erf", ERF},   {"exp", EXP},   {"log", LOG},
             {"ln", LOG},    {"log10", LG},  {"sqrt", SQRT}, {"abs", ABS},
             {"sign", SGN},  {"not", NOT}};
static const int nFunSt = sizeof(FunSt) / sizeof(FunSt[0]);

static struct MEM_TREE *Tree, *DTree; /* memory trees */
static struct BT_HEAD *BtNames;       /* balanced bin. tree of names */
static struct BT_HEAD *BtNumbers;     /* balanced bin. tree of numbers */

static int prxLineno; /* line number model file */
static int prxError;  /* general error flag */
static int bDeriv;    /* Deriv.s are (not) actually computed */
static int ifLevel;   /* if nesting level */
static int bAssign;   /* subexpression can start with assign */

static char *sModel, *sDate, *sAuthor; /* model identifiers */
static char *sVersion, *sIdent;

static int nVar, nAux; /* number of model symbols */
static int nPar, nCon, nFlag;
static int nRes, nNum, nTmp;

static double *Numbers; /* numeric constants */

static PRX_NODE *NodeH[MAXEQU]; /* array of tree pointers */
static int UsageFlag[MAXEQU];   /* bit flag: operand of corr. is */
static int TmpTyp[MAXEQU];      /* flag: corresponding temporary derivative
                                 * is (not) needed to compute further */
static PRX_NODE **pHead;        /* pointer for array NodeH */
static int nHead;               /* number of expression trees */
static PRX_NODE *pxNode;        /* pointer to any node in a tree */

static PRX_NODE *PriorityStack[MAXEQU]; /* priority stack */
static PRX_NODE **pSt;                  /* priority stack pointer */
static int Priority[STOP + 1];          /* operator priority */
static int IfStatus[MAXLEVEL + 1];

static PRX_OPD **varDefs; /* pointer to variables list */
static PRX_OPD **auxDefs; /* pointer to auxiliaries list */
static PRX_OPD **parDefs; /* pointer to parameters list */

static PRX_NODE *N_0, *N_1, *N_2, *N_0p5, *N_1_ln10, *N_2_SQRT_PI;

/* forward function prototypes */
static int bt_cmp_names(void *s1, void *s2);
static int bt_cmp_numbers(void *s1, void *s2);
static int namTraverse(char *rec);
static int namTraverse2(char *rec);
static int numTraverse(char *rec);

/**
 @brief Initialization routine

 Reset all the statically declared C variables

 @return 0 - error, 1 - success
 */
- (int)setStatics {

    assert(NUMDECVALUES >= 5);

    Tree = mem_tree();
    DTree = mem_tree();

    BtNames = bt_define_tree(Tree, bt_cmp_names);
    BtNumbers = bt_define_tree(Tree, bt_cmp_numbers);

    prxLineno = 0;
    prxError = 0;
    bDeriv = 0;
    ifLevel = 0;
    bAssign = 1;

    sModel = sDate = sAuthor = sVersion = sIdent = NULL;
    nVar = nAux = nPar = nCon = nFlag = 0;
    nRes = nNum = nTmp = 0;
    Numbers = NULL;

    for (int i = 0; i < MAXEQU; i++) {
        NodeH[i] = NULL;
        UsageFlag[i] = 0;
        TmpTyp[i] = 0;
        PriorityStack[i] = NULL;
    }

    pHead = NodeH;
    nHead = 0;
    pxNode = NULL;
    pSt = NULL;

    for (int i = 0; i <= STOP; i++) {
        Priority[i] = 0;
    }
    Priority[INVAL] = 0;
    Priority[AND] = Priority[OR] = 1;
    Priority[NOT] = 2;
    Priority[LT] = Priority[GT] = Priority[LE] = Priority[GE] = Priority[EQ] =
        Priority[NE] = 3;
    Priority[ADD] = 5;
    Priority[NEG] = Priority[SUB] = 6;
    Priority[MUL] = 7;
    Priority[DIV] = Priority[REV] = 8;
    Priority[POW] = Priority[SQR] = 9;

    for (int i = 0; i < (MAXLEVEL + 1); i++) {
        IfStatus[i] = 0;
    }

    varDefs = auxDefs = parDefs = NULL;

    N_0 = [self getNum:0.0];
    N_1 = [self getNum:1.0];
    N_2 = [self getNum:2.0];
    N_0p5 = [self getNum:0.5];
    N_1_ln10 = [self getNum:M_LOG10E];
    N_2_SQRT_PI = [self getNum:M_2_SQRTPI];

    return 1;
}

/* ========================================================================== */

/**
 @brief End game routine

 Deallocate C memory pools

 @return size of reclaimed memory
 */
- (int)freeMemoryPools {

    size_t sT, sD;

    sT = Tree ? mem_free(Tree) : 0;
    sD = DTree ? mem_free(DTree) : 0;

    return (int)(sT + sD);
}

/* ========================================================================== */

/** @return current error status */
- (int)getError {
    return prxError;
}

#define ERROR(s)                                                               \
    {                                                                          \
        snprintf(prxErrorString, 1024, "%s", s);                               \
        prxError = 1;                                                          \
        prxErrorLineno = prxLineno;                                            \
        return 0;                                                              \
    }

#define ERRORA(f, s)                                                           \
    {                                                                          \
        snprintf(prxErrorString, 1024, f, s);                                  \
        prxError = 1;                                                          \
        prxErrorLineno = prxLineno;                                            \
        return 0;                                                              \
    }

/* ========================================================================== */

#define NODE(p, op, op1, op2)                                                  \
    p = (PRX_NODE *)mem_slot(Tree, sizeof(PRX_NODE));                          \
    p->opr = op;                                                               \
    p->o1 = op1;                                                               \
    p->c.o2 = op2;

/* ========================================================================== */

/** comparison routine for the balanced binary tree of names */
int bt_cmp_names(void *s1, void *s2) {
    return strcmp(((PRX_OPD *)s1)->name, ((PRX_OPD *)s2)->name);
}

/** comparison routine for the balanced binary tree of numbers */
int bt_cmp_numbers(void *s1, void *s2) {
    return (((PRX_NUM *)s1)->val < ((PRX_NUM *)s2)->val)
               ? -1
               : (((PRX_NUM *)s1)->val > ((PRX_NUM *)s2)->val) ? 1 : 0;
}

/* ========================================================================== */

/**
 @brief parse the model file

 @param inFile model definition file
 @return 0 = error, 1 = success
 */
- (int)parseModelFile:(FILE *)inFile {

    char Buf[MAXLINE + 4] = {'\0'}, *pBuf;
    char Cmd[MAXCMD] = {'\0'}, *pCmd;
    int hRet;

    int bComment;     /* comment switch */
    int bLineComment; /* line comment switch */
    int bString;      /* string switch */
    int bCont;        /* continuation line switch */

    /* parsing header part of PARX model description file */
    prxLineno = 0;
    bComment = bLineComment = bString = bCont = 0;
    pBuf = Buf;
    *pBuf = '\n';
    pCmd = Cmd;

    while (1) {
        if (*pBuf == '\n') {
            bLineComment = 0;
            if (!bComment && !bCont) {
                if (pCmd != Cmd) {
                    *pCmd = 0;
                    hRet = [self parseHeaderDefinition:Cmd];
                    if (hRet == 2) {
                        break;
                    } else if (hRet == 0) {
                        return 0;
                    }
                    pCmd = Cmd;
                }
            }
            if (bCont) {
                pCmd--;
                size_t len = pCmd - Cmd;
                if (len >= MAXCMD - (MAXLINE + 4)) {
                    ERRORA("Expression too long (>%d)", MAXCMD);
                }
            }
            if (!fgets(Buf, MAXLINE, inFile)) {
                break;
            } else {
                prxLineno++;
                size_t len = strlen(Buf);
                if (feof(inFile)) { /* missing newline on last line */
                    Buf[len] = '\n';
                    Buf[len + 1] = '\0';
                } else if (len > 0 && Buf[len - 1] != '\n') {
                    ERRORA("Line too long (>%d)", MAXLINE);
                }
            }
            pBuf = Buf;
            bString = 0;
            bCont = 0;
            continue;
        }
        if (bComment) {
            if (*pBuf == '*' && *(pBuf + 1) == '/') {
                bComment = 0;
                pBuf++;
            }
            pBuf++;
            continue;
        }
        if (bLineComment) {
            pBuf++;
            continue;
        }
        if (*pBuf == '"') {
            bString = !bString;
            pBuf++;
            bCont = 0;
            continue;
        }
        if (bString) {
            *(pCmd++) = *(pBuf++);
            continue;
        }
        if (*pBuf == ' ' || *pBuf == '\t' || *pBuf == '\r') {
            pBuf++;
            continue;
        }
        bCont = 0;
        if (*pBuf == '/' && *(pBuf + 1) == '*') {
            bComment = 1;
            pBuf += 2;
            continue;
        }
        if (*pBuf == '|' && *(pBuf + 1) == '|') {
            bLineComment = 1;
            pBuf += 2;
            continue;
        }
        if (*pBuf == '/' && *(pBuf + 1) == '/') {
            bLineComment = 1;
            pBuf += 2;
            continue;
        }
        if (*pBuf == '\\') {
            *(pCmd++) = '\\';
            pBuf++;
            bCont = 1;
            continue;
        }
        if (*pBuf == ';') {
            if (pCmd != Cmd) {
                *pCmd = 0;
                hRet = [self parseHeaderDefinition:Cmd];
                if (hRet == 2) {
                    break;
                } else if (hRet == 0) {
                    return 0;
                }
                pCmd = Cmd;
            }
            pBuf++;
            continue;
        }
        *(pCmd++) = *(pBuf++);
    }

    if ([self getError]) {
        return 0;
    }
    if (![self createDerivativesIndex]) {
        return 0;
    }

    /* parsing equation part of ParX model description file */
    bComment = bLineComment = bCont = 0;
    pBuf = Buf;
    *pBuf = '\n';
    pCmd = Cmd;

    while (1) {
        if (*pBuf == '\n') {
            bLineComment = 0;
            if (!bComment && !bCont) {
                *pCmd = 0;
                if (![self parseEquation:Cmd]) { /* break at first error */
                    return 0;
                }
                pCmd = Cmd;
            }
            if (bCont) {
                pCmd--;
                size_t len = pCmd - Cmd;
                if (len >= MAXCMD - (MAXLINE + 4)) {
                    ERRORA("Expression too long (>%d)", MAXCMD);
                }
            }
            if (!fgets(Buf, MAXLINE, inFile)) {
                break;
            } else {
                prxLineno++;
                size_t len = strlen(Buf);
                if (feof(inFile)) { /* missing newline on last line */
                    Buf[len] = '\n';
                    Buf[len + 1] = '\0';
                } else if (len > 0 && Buf[len - 1] != '\n') {
                    ERRORA("Line too long (>%d)", MAXLINE);
                }
            }
            pBuf = Buf;
            bCont = 0;
            continue;
        }
        if (bComment) {
            if (*pBuf == '*' && *(pBuf + 1) == '/') {
                bComment = 0;
                pBuf++;
            }
            pBuf++;
            continue;
        }
        if (bLineComment) {
            pBuf++;
            continue;
        }
        if (*pBuf == ' ' || *pBuf == '\t' || *pBuf == '\r') {
            pBuf++;
            continue;
        }
        bCont = 0;
        if (*pBuf == '/' && *(pBuf + 1) == '*') {
            bComment = 1;
            pBuf += 2;
            continue;
        }
        if (*pBuf == '|' && *(pBuf + 1) == '|') {
            bLineComment = 1;
            pBuf += 2;
            continue;
        }
        if (*pBuf == '/' && *(pBuf + 1) == '/') {
            bLineComment = 1;
            pBuf += 2;
            continue;
        }
        if (*pBuf == '\\') {
            *(pCmd++) = '\\';
            pBuf++;
            bCont = 1;
            continue;
        }
        if (*pBuf == ';') {
            *pCmd = 0;
            if (![self parseEquation:Cmd]) {
                return 0;
            }
            pCmd = Cmd;
            pBuf++;
            continue;
        }
        *(pCmd++) = *(pBuf++);
    }
    return 1;
}

/* ========================================================================== */

/**
 @brief Providing a number contained in balanced binary tree of numbers

 If desired number is not yet present it is generated

 @param value number to search for
 @return node pointer in numbers parse tree
 */
- (PRX_NODE *)getNum:(double)value {

    PRX_NUM *pNum;
    PRX_NODE *p;

    pNum = (PRX_NUM *)bt_search(BtNumbers, (char *)&value);
    if (pNum) {
        return pNum->node;
    }
    pNum = (PRX_NUM *)mem_slot(Tree, sizeof(PRX_NUM));
    pNum->val = value;
    pNum->ind = nNum++;
    NODE(p, NUM, NULL, (PRX_NODE *)pNum);
    pNum->node = p;
    bt_insert(BtNumbers, (char *)pNum);
    return p;
}

/* ========================================================================== */

/**
 @brief Generating an object in balanced binary tree of names:

 var, par, aux, const, flag, res, temp

 @param name symbol to store
 @param typ type of the symbol
 @param ind index of the symbol
 @return node pointer in names parse tree
 */
- (PRX_OPD *)newName:(char *)name withType:(TYP)typ withIndex:(int)ind {

    PRX_OPD *pOpd;
    char *pc;

    pOpd = (PRX_OPD *)mem_slot(Tree, sizeof(PRX_OPD) + strlen(name) + 1);
    pc = ((char *)pOpd) + sizeof(PRX_OPD);
    strcpy(pc, name);
    pOpd->name = pc;
    pOpd->typ = typ;
    pOpd->ind = ind;
    pOpd->node = NULL;
    bt_insert(BtNames, (char *)pOpd);
    return pOpd;
}

/* ========================================================================== */

/**
 @brief Parse a header definition of ParX model description file

 and generating interpreter code for boundary checks

 @param definition line of model header
 @return 0 - error, 1 - success, 2 - end of header (on equation statement)
 */
- (int)parseHeaderDefinition:(char *)definition {

    TYP typ;
    int length;
    char *pDef;  /* pointer in definition */
    int *pCount; /* pointer to counter to be increased */
    char Name[MAXNAME + 1] = {'\0'};
    char Unit[MAXUNIT + 1] = {'\0'};
    char *name = Name;
    char *unit = Unit;
    double Vals[NUMDECVALUES]; /* Array for default, bounds, scales */
    int nValues;
    double minLim, maxLim;
    PRX_NODE *pNode;
    PRX_OPD *pOpd;

    length = prx_name(definition);
    if (length <= 2 || definition[length] != ':') {
        ERROR("Invalid keyword");
    }
    pDef = definition + length + 1;

    if (memcmp(definition, "model", MIN(length, 5)) == 0) {
        sModel = (char *)mem_slot(DTree, (strlen(pDef) + 1) * sizeof(char));
        strcpy(sModel, pDef);
        return 1;
    } else if (memcmp(definition, "date", MIN(length, 4)) == 0) {
        sDate = (char *)mem_slot(DTree, (strlen(pDef) + 1) * sizeof(char));
        strcpy(sDate, pDef);
        return 1;
    } else if (memcmp(definition, "author", MIN(length, 6)) == 0) {
        sAuthor = (char *)mem_slot(DTree, (strlen(pDef) + 1) * sizeof(char));
        strcpy(sAuthor, pDef);
        return 1;
    } else if (memcmp(definition, "version", MIN(length, 7)) == 0) {
        sVersion = (char *)mem_slot(DTree, (strlen(pDef) + 1) * sizeof(char));
        strcpy(sVersion, pDef);
        return 1;
    } else if (memcmp(definition, "identifier", MIN(length, 10)) == 0) {
        sIdent = (char *)mem_slot(DTree, (strlen(pDef) + 1) * sizeof(char));
        strcpy(sIdent, pDef);
        return 1;
    } else if (memcmp(definition, "information", MIN(length, 11)) == 0) {
        sIdent = (char *)mem_slot(DTree, (strlen(pDef) + 1) * sizeof(char));
        strcpy(sIdent, pDef);
        return 1;
    } else if (memcmp(definition, "equations", MIN(length, 9)) == 0) {

        if (sModel) {
            modelCode.model = [NSString stringWithUTF8String:sModel];
        } else {
            modelCode.model = [NSString stringWithUTF8String:""];
        }
        if (sVersion) {
            modelCode.version = [NSString stringWithUTF8String:sVersion];
        } else {
            modelCode.version = [NSString stringWithUTF8String:""];
        }
        if (sAuthor) {
            modelCode.author = [NSString stringWithUTF8String:sAuthor];
        } else {
            modelCode.author = [NSString stringWithUTF8String:""];
        }
        if (sDate) {
            modelCode.date = [NSString stringWithUTF8String:sDate];
        } else {
            modelCode.date = [NSString stringWithUTF8String:""];
        }
        if (sIdent) {
            modelCode.ident = [NSString stringWithUTF8String:sIdent];
        } else {
            modelCode.ident = [NSString stringWithUTF8String:""];
        }

        return 2;

    } else if (memcmp(definition, "parameters", MIN(length, 10)) == 0) {
        typ = PAR;
        pCount = &nPar;
    } else if (memcmp(definition, "variables", MIN(length, 9)) == 0) {
        typ = VAR;
        pCount = &nVar;
    } else if (memcmp(definition, "constants", MIN(length, 9)) == 0) {
        typ = CON;
        pCount = &nCon;
    } else if (memcmp(definition, "flags", MIN(length, 5)) == 0) {
        typ = FLG;
        pCount = &nFlag;
    } else if (memcmp(definition, "residuals", MIN(length, 9)) == 0) {
        typ = RES;
        pCount = &nRes;
    } else if (memcmp(definition, "auxiliary", MIN(length, 9)) == 0) {
        typ = AUX;
        pCount = &nAux;
    } else if (memcmp(definition, "auxiliaries", MIN(length, 11)) == 0) {
        typ = AUX;
        pCount = &nAux;

    } else {
        ERROR("Invalid keyword");
    }

    do {
        length = prx_name(pDef);
        if (length == 0) {
            ERROR("Syntax in name list");
        }
        if (length < 0) {
            length = MAXNAME;
            memcpy(name, pDef, length);
            name[length] = 0;
            ERRORA("Name too long: %s", name);
        }
        memcpy(name, pDef, length);
        name[length] = 0;

        pOpd = (PRX_OPD *)bt_search(BtNames, (char *)&name);
        if (pOpd) {
            ERRORA("%s has already been declared", name);
        }

        pOpd = [self newName:name withType:typ withIndex:(*pCount)++];

        pDef += length;
        Vals[0] = 0;
        Vals[1] = -HUGE_VAL;
        Vals[2] = HUGE_VAL;
        Vals[3] = -HUGE_VAL;
        Vals[4] = HUGE_VAL;

        if (*pDef == '=') {
            length = prx_values(++pDef, Vals, &nValues, NUMDECVALUES);
            if (length <= 0) {
                ERRORA("Error in value list of %s", name);
            }
            if (typ == PAR || typ == VAR || typ == AUX) {
                if (typ != PAR && nValues > 3) {
                    ERRORA("Maximum quantity of values exceeded for %s", name);
                }
                minLim = (typ == PAR) ? Vals[3] : Vals[1];
                maxLim = (typ == PAR) ? Vals[4] : Vals[2];
                if (minLim > -HUGE_VAL) {
                    [modelCode addOperator:OPD];
                    [modelCode addType:pOpd->typ];
                    [modelCode addIndex:pOpd->ind];
                    pNode = [self getNum:minLim];
                    [modelCode addOperator:NUM];
                    [modelCode addIndex:pNode->c.nptr->ind];
                    [modelCode addOperator:CHKL];
                }
                if (maxLim < HUGE_VAL) {
                    [modelCode addOperator:OPD];
                    [modelCode addType:pOpd->typ];
                    [modelCode addIndex:pOpd->ind];
                    pNode = [self getNum:maxLim];
                    [modelCode addOperator:NUM];
                    [modelCode addIndex:pNode->c.nptr->ind];
                    [modelCode addOperator:CHKG];
                }
            } else if (nValues > 1) {
                ERRORA("Maximum quantity of values exceeded for %s", name);
            }
            pDef += length;
        } else {
            if (typ != RES) {
                if (*pDef == ',' || *pDef == ';' || *pDef == '\0') {
                    ERRORA("Missing definition for %s", name);
                } else {
                    ERRORA("Illegal character in name after: %s", name);
                }
            }
        }

        length = prx_unit(pDef);
        if (length < 0) {
            length = MAXUNIT;
            memcpy(unit, pDef, length);
            unit[length] = 0;
            ERRORA("Unit too long: %s", unit);
        }
        memcpy(unit, pDef, length);
        unit[length] = 0;
        pDef += length;

        switch (typ) {
        case RES:
            [modelCode addResName:[NSString stringWithUTF8String:name]];
            break;
        case VAR:
            [modelCode addVarName:[NSString stringWithUTF8String:name]
                       withAbsTol:[NSNumber numberWithDouble:Vals[0]]
                   withLowerLimit:[NSNumber numberWithDouble:Vals[1]]
                   withUpperLimit:[NSNumber numberWithDouble:Vals[2]]
                         withUnit:[NSString stringWithUTF8String:unit]];
            break;
        case AUX:
            [modelCode addAuxName:[NSString stringWithUTF8String:name]
                       withAbsTol:[NSNumber numberWithDouble:Vals[0]]
                   withLowerLimit:[NSNumber numberWithDouble:Vals[1]]
                   withUpperLimit:[NSNumber numberWithDouble:Vals[2]]];
            break;
        case CON:
            [modelCode addConName:[NSString stringWithUTF8String:name]
                 withDefaultValue:[NSNumber numberWithDouble:Vals[0]]
                         withUnit:[NSString stringWithUTF8String:unit]];
            break;
        case FLG:
            [modelCode addFlgName:[NSString stringWithUTF8String:name]
                 withDefaultValue:[NSNumber numberWithDouble:trunc(Vals[0])]];
            break;
        case PAR:
            Vals[1] = Vals[1] < Vals[3] ? Vals[3] : Vals[1];
            Vals[2] = Vals[2] > Vals[4] ? Vals[4] : Vals[2];
            Vals[0] = Vals[0] < Vals[1] ? Vals[1] : Vals[0];
            Vals[0] = Vals[0] > Vals[2] ? Vals[2] : Vals[0];
            [modelCode addParName:[NSString stringWithUTF8String:name]
                 withDefaultValue:[NSNumber numberWithDouble:Vals[0]]
                   withLowerBound:[NSNumber numberWithDouble:Vals[1]]
                   withUpperBound:[NSNumber numberWithDouble:Vals[2]]
                   withLowerLimit:[NSNumber numberWithDouble:Vals[3]]
                   withUpperLimit:[NSNumber numberWithDouble:Vals[4]]
                         withUnit:[NSString stringWithUTF8String:unit]];
            break;

        default:
            break;
        }
    } while (*(pDef++) == ',');

    if (*(--pDef) != 0) { /* something remains */
        ERROR("Syntax error in name list");
    }

    return 1;
}

/* ========================================================================== */

/**
 @brief Action routine used in tree traverse of the following procedure

 @param rec symbol to index
 @return 0 - success
 */
int namTraverse(char *rec) {
    PRX_OPD *pOpd;

    pOpd = (PRX_OPD *)rec;
    if (pOpd->typ == PAR) {
        parDefs[pOpd->ind] = pOpd;
    } else if (pOpd->typ == VAR) {
        varDefs[pOpd->ind] = pOpd;
    } else if (pOpd->typ == AUX) {
        auxDefs[pOpd->ind] = pOpd;
    }
    return 0;
}

/**
 @brief Generation of indices of derivative variables

 @return 0 - error, 1 - success
 */
- (int)createDerivativesIndex {

    varDefs = (PRX_OPD **)mem_slot(Tree, nVar * sizeof(PRX_OPD *));
    auxDefs = (PRX_OPD **)mem_slot(Tree, nAux * sizeof(PRX_OPD *));
    parDefs = (PRX_OPD **)mem_slot(Tree, nPar * sizeof(PRX_OPD *));

    bt_traverse(BtNames, namTraverse);

    return 1;
}

/* ========================================================================== */

/**
 @brief Action routine used in tree traverse of the following procedure

 Detect unused and unassigned symbols and contruct a warning

 @param rec symbol to check
 @return 0 - success
 */
int namTraverse2(char *rec) {
    PRX_OPD *pOpd;
    TYP typ;

    pOpd = (PRX_OPD *)rec;
    typ = pOpd->typ;
    if (typ == PAR || typ == VAR || typ == TMP || typ == AUX) {

        if (!(UsageFlag[pOpd->ind] & (1 << typ))) {

            [thisClass addNotUsed:pOpd->name];
        }
    } else if (typ == RES) {

        if (!(UsageFlag[pOpd->ind] & (1 << typ))) {

            [thisClass addNotAssigned:pOpd->name];
        }
    }

    return 0;
}

- (void)addNotUsed:(char *)name {
    [symbolsNotUsed addObject:[NSString stringWithUTF8String:name]];
}

- (void)addNotAssigned:(char *)name {
    [symbolsNotAssigned addObject:[NSString stringWithUTF8String:name]];
}

/**
 @brief Check if everything is ok before generating derivatives

 @return 0 - error, 1 - success
 */
- (int)checkModelConsistency {

    if (ifLevel > 0) {
        ERROR("If condition not closed by fi");
    }
    if (nHead > MAXEQU) {
        ERRORA("Maximum number of statements (%d) exceeded", MAXEQU);
    }

    bt_traverse(BtNames, namTraverse2);

    if (nRes <= 0) {
        ERROR("No residuals");
    }
    if (nRes >= nVar + nAux) {
        ERROR("No independent variables");
    }

    *pHead = NULL;
    return 1;
}

/* ========================================================================== */

/**
 @brief Parse an equation from a ParX model description file

 @param equation a single equation statement
 @return 0 - error, 1 - success
 */
- (int)parseEquation:(char *)equation {
    int length;
    PRX_NODE *pNodeV;

    if (*equation == 0) {
        return 1;
    }
    if (++nHead > MAXEQU) {
        ERRORA("Maximum number of statements (%d) exceeded", MAXEQU);
    }
    pSt = PriorityStack;

    /* if ... then ... else */
    if (memcmp(equation, "if(", 3) == 0) {
        bAssign = 0;
        length = [self parseExpression:equation + 2];
        if (length <= 0) {
            return 0;
        }
        pNodeV = pxNode;
        NODE(pxNode, IF, pNodeV, NULL);
        *(pHead++) = pxNode;
        [self genCodeForNode:pxNode];
        if (ifLevel >= MAXLEVEL) {
            ERRORA("Maximum 'if' hierarchy depth (%d) exceeded", MAXLEVEL);
        }
        ifLevel++;
        IfStatus[ifLevel] = 0;
        return 1;
    } else if (strcmp(equation, "else") == 0) {
        if (ifLevel <= 0) {
            ERROR("No preceding 'if' statement");
        }
        if (IfStatus[ifLevel] > 0) {
            ERROR("Multiple 'else'");
        }
        NODE(pxNode, ELSE, NULL, NULL);
        *(pHead++) = pxNode;
        [self genCodeForNode:pxNode];
        IfStatus[ifLevel] = 1;
        return 1;
    } else if (strcmp(equation, "fi") == 0) {
        if (ifLevel <= 0) {
            ERROR("No active 'if' statement");
        }
        NODE(pxNode, FI, NULL, NULL);
        *(pHead++) = pxNode;
        [self genCodeForNode:pxNode];
        ifLevel--;
        return 1;
    }

    /* Assignment */
    bAssign = 1;
    length = [self parseExpression:equation];
    if (length <= 0 || equation[length] != 0) {
        return 0;
    }
    [self simplifyExpressionAtNode:pxNode];
    [self simplifyExpressionAtNode:pxNode];
    *(pHead++) = pxNode;
    [self genCodeForNode:pxNode];

    return 1;
}

/* ========================================================================== */

/**
 @brief Checking a substring Arguments

 @param expression substring to be analyzed
 @return length of parsed expression
 */
- (int)parseExpression:(char *)expression {

    char *pExpr;
    char nameBuffer[MAXNAME + 1] = {'\0'};
    char *name;
    int length;
    int notNumber;
    int iFun;
    double value;
    OPR opr;
    OPR Op[MAXCMD] = {0}; /* Operator buffer for Priority control */
    int iOp;
    PRX_OPD *pOpd;

    name = nameBuffer;
    pExpr = expression;
    iOp = 0;

    if (!bAssign) {
        goto operand;
    }

    if (memcmp(pExpr, "error(", 6) == 0) {
        bAssign = 0;
        pExpr += 6;
        length = [self parseExpression:pExpr];
        if (length <= 0) {
            return 0;
        }
        pSt--;
        NODE(pxNode, RET, *pSt, NULL);
        *(pSt++) = pxNode;
        pExpr += length;
        if (*pExpr == ')') {
            pExpr++;
        }
        return (int)(pExpr - expression);
    }

    /* Assignment */

    length = prx_name(pExpr);
    if (length == 0) {
        ERROR("Syntax error in variable name");
    }
    if (length < 0) {
        ERROR("Variable name too long");
    }
    if (pExpr[length] != '=' || pExpr[length + 1] == '=') {
        ERROR("Assignment expected");
    }

    bAssign = 0;
    memcpy(name, pExpr, length);
    name[length] = 0;
    pExpr += length + 1;
    length = [self parseExpression:pExpr];
    if (length <= 0) {
        return 0;
    }
    pOpd = (PRX_OPD *)bt_search(BtNames, (char *)&name);
    if (pOpd) {
        if (pOpd->typ == CON || pOpd->typ == FLG) {
            ERROR("Invalid assignment")
        }
        if (pOpd->typ != RES && pOpd->typ != TMP) {
            ERRORA("Assignment to '%s' is not allowed", name);
        }
    } else {
        pOpd = [self newName:name withType:TMP withIndex:nTmp++];
    }
    if (pOpd->typ == RES) {
        UsageFlag[pOpd->ind] |= (1 << RES);
    }
    if (!pOpd->node) {
        NODE(pxNode, OPD, NULL, (PRX_NODE *)pOpd);
        pOpd->node = pxNode;
    }
    pSt--;
    NODE(pxNode, ASS, *pSt, (PRX_NODE *)pOpd);
    *(pSt++) = pxNode;
    pExpr += length;
    return (int)(pExpr - expression);

operation:

    switch (*pExpr) {
    case '&':
        opr = AND;
        break;
    case '|':
        opr = OR;
        break;
    case '<':
        if (*(pExpr + 1) == '=') {
            opr = LE;
            pExpr++;
        } else if (*(pExpr + 1) == '>') {
            opr = NE;
            pExpr++;
        } else
            opr = LT;
        break;
    case '>':
        if (*(pExpr + 1) == '=') {
            opr = GE;
            pExpr++;
        } else
            opr = GT;
        break;
    case '!':
        if (*(pExpr + 1) == '=') {
            opr = NE;
            pExpr++;
        } else
            opr = INVAL;
        break;
    case '=':
        if (*(pExpr + 1) == '=') {
            opr = EQ;
            pExpr++;
        } else
            opr = INVAL;
        break;
    case '+':
        opr = ADD;
        break;
    case '-':
        opr = SUB;
        break;
    case '*':
        opr = MUL;
        break;
    case '/':
        opr = DIV;
        break;
    case '^':
        opr = POW;
        break;
    default:
        opr = INVAL;
    }
    while (iOp > 0) {
        if (Priority[opr] > Priority[Op[iOp - 1]]) {
            break;
        }
        pSt--;
        iOp--;
        if (Op[iOp] == NEG || Op[iOp] == NOT) { /* 1 operand  */
            NODE(pxNode, Op[iOp], *pSt, NULL);
        } else { /* 2 operands */
            pSt--;
            NODE(pxNode, Op[iOp], *pSt, *(pSt + 1));
        }
        *(pSt++) = pxNode;
    }
    if (*pExpr == ',' || *pExpr == ')' || *pExpr == ';' || *pExpr == 0) {
        return (int)(pExpr - expression);
    }
    if (opr == INVAL) {
        ERROR("syntax error");
    }
    Op[iOp++] = opr;
    pExpr++;
    goto operand;

operand: /* arithmetic operand */

    if (!bAssign) { /* digest prefix operators */
        if (*pExpr == '+') {
            pExpr++;
            goto operand;
        }
        if (*pExpr == '-') {
            Op[iOp++] = NEG;
            pExpr++;
            goto operand;
        }
        if (*pExpr == '!') {
            Op[iOp++] = NOT;
            pExpr++;
            goto operand;
        }
    }

    notNumber = prx_number(pExpr, &value, &length);
    if (notNumber && length == 0) {
        goto name;
    }

    /* operand is number */

    if (notNumber) { /* partial number */
        memcpy(name, pExpr, MIN(length, MAXNAME));
        name[MIN(length, MAXNAME)] = 0;
        ERRORA("Illegal number format %s", name);
    }
    pxNode = [self getNum:value];
    *(pSt++) = pxNode;
    pExpr += length;
    goto operation;

name:

    length = prx_name(pExpr);
    if (length <= 0) {
        goto parenth;
    }
    memcpy(name, pExpr, length);
    name[length] = 0;
    if (pExpr[length] == ')' - 1) {
        goto function;
    }

    /* operand is variable */
    pOpd = (PRX_OPD *)bt_search(BtNames, (char *)&name);
    if (!pOpd) {
        ERRORA("Undefined item %s", name);
    }
    if (pOpd->typ != RES) {
        UsageFlag[pOpd->ind] |= (1 << pOpd->typ);
    } else if (!(UsageFlag[pOpd->ind] & ((1) << RES))) {
        ERRORA("%s is used before being assigned", name);
    }
    pxNode = pOpd->node;
    if (!pxNode) {
        NODE(pxNode, OPD, NULL, (PRX_NODE *)pOpd);
        pOpd->node = pxNode;
    }
    *(pSt++) = pxNode;
    pExpr += length;
    goto operation;

parenth: /* expression in parentheses */

    if (*pExpr != '(') {
        ERRORA("Syntax error, expected ( but got '%s'", pExpr);
    }
    pExpr++;
    length = [self parseExpression:pExpr];
    if (length <= 0) {
        return 0;
    }
    pExpr += length;
    if (*(pExpr++) != ('(' + 1)) {
        ERROR("Closing parenthesis missing");
    }
    goto operation;

function: /* function call */

    pExpr += length;
    for (iFun = 0; iFun < nFunSt; iFun++) {
        if (!strcmp(FunSt[iFun].name, name)) {
            break;
        }
    }
    if (iFun >= nFunSt) {
        ERRORA("Function %s undefined", name);
    }
    length = [self parseExpression:++pExpr];
    if (length <= 0 || pExpr[length] != ')') {
        ERRORA("Argument error in function '%s'", name);
    }
    pSt--;
    NODE(pxNode, FunSt[iFun].opr, *pSt, NULL);
    *(pSt++) = pxNode;
    pExpr += length + 1;
    goto operation;
}

/* ========================================================================== */

/**
 @brief Generation of arithmetic code from parse tree

 @param pNode node in the parse tree
 @return 0 - error, 1 - success
 */
- (int)genCodeForNode:(PRX_NODE *)pNode {
    OPR opr;
    TYP typ;
    double value;
    PRX_NODE *pN;

    if (!pNode) {
        return 0;
    }
    opr = pNode->opr;
    switch (opr) {
    case AND:
    case OR:
    case LT:
    case GT:
    case LE:
    case GE:
    case EQ:
    case NE:
    case MUL:
    case DIV:
    case POW:
        if (![self genCodeForNode:pNode->o1]) {
            return 0;
        }
        if (![self genCodeForNode:pNode->c.o2]) {
            return 0;
        }
        [modelCode addOperator:opr];
        break;
    case SUB:
        if (![self genCodeForNode:pNode->o1]) {
            return 0;
        }
        if (pNode->c.o2 == N_1) {
            [modelCode addOperator:DEC];
        } else {
            if (![self genCodeForNode:pNode->c.o2]) {
                return 0;
            }
            [modelCode addOperator:opr];
        }
        break;
    case ADD:
        if (pNode->c.o2 == N_1) {
            if (![self genCodeForNode:pNode->o1]) {
                return 0;
            }
            [modelCode addOperator:INC];
        } else if (pNode->o1 == N_1) {
            if (![self genCodeForNode:pNode->c.o2]) {
                return 0;
            }
            [modelCode addOperator:INC];
        } else {
            if (![self genCodeForNode:pNode->o1]) {
                return 0;
            }
            if (![self genCodeForNode:pNode->c.o2]) {
                return 0;
            }
            [modelCode addOperator:opr];
        }
        break;
    case NEG:
        if (pNode->o1->opr == NUM) {
            value = -pNode->o1->c.nptr->val;
            if (value == HUGE_VAL) {
                ERROR("Subtraction overflow");
            }
            pN = [self getNum:value];
            [modelCode addOperator:NUM];
            [modelCode addIndex:pN->c.nptr->ind];
        } else {
            if (![self genCodeForNode:pNode->o1]) {
                return 0;
            }
            [modelCode addOperator:opr];
        }
        break;
    case REV:
        if (pNode->o1->opr == NUM) {
            value = 1.0 / pNode->o1->c.nptr->val;
            if (fabs(value) == HUGE_VAL) {
                ERROR("Division overflow");
            }
            pN = [self getNum:value];
            [modelCode addOperator:NUM];
            [modelCode addIndex:pN->c.nptr->ind];
        } else {
            if (![self genCodeForNode:pNode->o1]) {
                return 0;
            }
            [modelCode addOperator:opr];
        }
        break;
    case EQU:
        if (![self genCodeForNode:pNode->o1]) {
            return 0;
        }
        break;
    case OPD:
        [modelCode addOperator:opr];
        [modelCode addType:pNode->c.optr->typ];
        [modelCode addIndex:pNode->c.optr->ind];
        break;
    case DOPD:
        [modelCode addOperator:OPD];
        typ = pNode->c.optr->typ;
        if (typ == RES) {
            typ = DRES;
        } else if (typ == TMP) {
            typ = DTMP;
        }
        [modelCode addType:typ];
        [modelCode addIndex:pNode->c.optr->ind];
        break;
    case NUM:
        [modelCode addOperator:NUM];
        [modelCode addIndex:pNode->c.nptr->ind];
        break;
    case ASS:
        if (pNode->o1 == N_0) {
            opr = CLR;
        } else {
            pN = pNode->o1;
            if (pN->opr == NEG) {
                if (pN->o1->opr != NUM) {
                    pN = pN->o1;
                    opr = NASS;
                }
            }
            if (![self genCodeForNode:pN]) {
                return 0;
            }
        }
        typ = pNode->c.optr->typ;
        if (bDeriv) {
            if (typ == RES) {
                typ = DRES;
            } else if (typ == TMP) {
                if (opr == CLR) {
                    if (TmpTyp[pNode->c.optr->ind] == 0) {
                        break;
                    }
                }
                typ = DTMP;
            }
        }
        [modelCode addOperator:opr];
        [modelCode addType:typ];
        [modelCode addIndex:pNode->c.optr->ind];
        break;
    case SQR:
    case SGN:
    case IF:
    case SIN:
    case COS:
    case TAN:
    case ASIN:
    case ACOS:
    case ATAN:
    case SINH:
    case COSH:
    case TANH:
    case ERF:
    case EXP:
    case LOG:
    case LG:
    case SQRT:
    case ABS:
    case NOT:
    case RET:
        if (![self genCodeForNode:pNode->o1]) {
            return 0;
        }
        [modelCode addOperator:opr];
        break;
    case ELSE:
    case FI:
        [modelCode addOperator:opr];
        break;
    default:
        break;
    }
    return 1;
}

/* ========================================================================== */

/**
 @brief Action routine used in tree traverse of the following procedure

 copy number to Numbers at index

 @param rec symbol to check
 @return 0 - success
 */
int numTraverse(char *rec) {
    PRX_NUM *pNum;

    pNum = (PRX_NUM *)rec;
    Numbers[pNum->ind] = pNum->val;
    return 0;
}

/**
 @brief Output of all constants

 @return 0 - error, 1 - success
 */
- (int)numOut {

    Numbers = (double *)mem_slot(Tree, nNum * sizeof(double));
    bt_traverse(BtNumbers, numTraverse);

    for (int i = 0; i < nNum; i++) {
        [modelCode addNumber:Numbers[i]];
    }

    return 1;
}

/* ========================================================================== */

/**
 @brief Derivative generation frame

 @return 0 - error, 1 - success
 */
- (int)generateDerivatives {

    bDeriv = 1;
    [modelCode addOperator:SOK];
    for (int i = 0; i <= nVar - 1; i++) {
        if (![self derivativeToVariable:varDefs[i]]) {
            return 0;
        }
        [modelCode addOperator:EOD];
    }
    [modelCode addOperator:SOK];
    for (int i = 0; i <= nAux - 1; i++) {
        if (![self derivativeToVariable:auxDefs[i]]) {
            return 0;
        }
        [modelCode addOperator:EOD];
    }
    [modelCode addOperator:SOK];
    for (int i = 0; i <= nPar - 1; i++) {
        if (![self derivativeToVariable:parDefs[i]]) {
            return 0;
        }
        [modelCode addOperator:EOD];
    }
    [modelCode addOperator:STOP];

    return 1;
}

/* ========================================================================== */

/**
 @brief Derivative for a specific variable, parameter or auxiliary

 @return 0 - error, 1 - success
 */
- (int)derivativeToVariable:(PRX_OPD *)pOpd {
    TYP typ;
    int level; /* if-level */
    PRX_NODE *pElse;
    PRX_NODE *IfNode[MAXLEVEL + 1] = {NULL};   /* pos. of last if-node */
    PRX_NODE *ElseNode[MAXLEVEL + 1] = {NULL}; /* pos. of last else-node */

    for (int i = 0; i < nTmp; i++) {
        TmpTyp[i] = 0;
    }

    /*
     * 1st pass - simplify expressions and determine the temporaries
     * which need to be computed
     */
    for (pHead = NodeH; *pHead; pHead++) {
        pxNode = *pHead;
        if (pxNode->opr == IF || pxNode->opr == FI || pxNode->opr == ELSE) {
            pxNode->abl = NULL;
            continue;
        }
        if (pxNode->opr != ASS) {
            continue;
        }
        if (![self derivativeForSubExpression:pxNode
                                   toVariable:pOpd
                                      withVal:NULL]) {
            return 0;
        }
        [self simplifyExpressionAtNode:pxNode->abl];
        [self simplifyExpressionAtNode:pxNode->abl];
        if (pxNode->c.optr->typ == TMP) {
            if (pxNode->abl->o1 != N_0) {
                TmpTyp[pxNode->c.optr->ind] = 1;
            }
        }
    }

    /*
     * 2nd pass - determining the if-nodes that are necessary for
     * the current derivative variable
     */
    level = 0;
    for (pHead = NodeH; *pHead; pHead++) {
        pxNode = *pHead;
        switch (pxNode->opr) {
        case IF:
            IfNode[++level] = pxNode;
            ElseNode[level] = NULL;
            break;
        case FI:
            assert(IfNode[level] != NULL);
            if (IfNode[level--]->abl) {
                pxNode->abl = pxNode;
                if (level > 0) {
                    pElse = ElseNode[level];
                    if (pElse) {
                        pElse->abl = pElse;
                    }
                    IfNode[level]->abl = IfNode[level];
                }
            }
            break;
        case ELSE:
            ElseNode[level] = pxNode;
            break;
        case ASS:
            if (level <= 0) {
                break;
            }
            typ = pxNode->c.optr->typ;
            if (typ == TMP) {
                if (!TmpTyp[pxNode->c.optr->ind]) {
                    break;
                }
            }
            pElse = ElseNode[level];
            if (pElse) {
                pElse->abl = pElse;
            }
            IfNode[level]->abl = IfNode[level];
            break;
        default:
            break;
        }
    }

    /* 3rd pass - output to file */
    for (pHead = NodeH; *pHead; pHead++) {
        pxNode = *pHead;
        switch (pxNode->opr) {
        case ASS:
            if (![self genCodeForNode:pxNode->abl]) {
                return 0;
            }
            break;
        case IF:
        case ELSE:
        case FI: /* case RET: */
            if (pxNode->abl) {
                if (![self genCodeForNode:pxNode->abl]) {
                    return 0;
                }
            }
            break;
        default:
            break;
        }
    }

    return 1;
}

/* ========================================================================== */

#define NODED(p, op, op1, op2)                                                 \
    p = (PRX_NODE *)mem_slot(DTree, sizeof(PRX_NODE));                         \
    p->opr = op;                                                               \
    p->o1 = op1;                                                               \
    p->c.o2 = op2

/**
 @brief Derivative for a subexpression

 @param p pointer to sub-expression
 @param arg pointer to variable or parameter
 @param fval optional constant value, when variable itself is part of the
 derivative
 @return 0 - error, 1 - success
 */
- (int)derivativeForSubExpression:(PRX_NODE *)p
                       toVariable:(PRX_OPD *)arg
                          withVal:(PRX_OPD *)fval {

    PRX_NODE *p1, *p2 = NULL, *p1a, *p2a, *pD = NULL, *pDv, *pDvv;
    OPR opr;
    PRX_OPD *optr;

    opr = p->opr;
    p1 = p->o1;
    if (p1) {
        optr = (opr == ASS) ? p->c.optr : NULL;
        if (![self derivativeForSubExpression:p1 toVariable:arg withVal:optr]) {
            return 0;
        }
        if (opr != ASS) {
            p2 = p->c.o2;
            if (p2) {
                if (![self derivativeForSubExpression:p2
                                           toVariable:arg
                                              withVal:NULL]) {
                    return 0;
                }
            }
        }
    }
    switch (opr) {
    case AND:
    case OR:
    case NOT:
    case LT:
    case GT:
    case LE:
    case GE:
    case EQ:
    case NE:
        p->abl = N_0;
        break;
    case NEG:
        assert(p1 != NULL);
        p1a = p1->abl;
        if (p1a == N_0) {
            p->abl = p1a;
        } else {
            NODED(pD, NEG, p1a, NULL);
            p->abl = pD;
        }
        break;
    case ADD:
        assert(p1 != NULL);
        assert(p2 != NULL);
        p1a = p1->abl;
        p2a = p2->abl;
        if (p1a == N_0) {
            p->abl = p2a;
        } else if (p2a == N_0) {
            p->abl = p1a;
        } else if (p1a->opr == OPD && p2a->opr == OPD) {
            ;
        } else {
            NODED(pD, ADD, p1a, p2a);
            p->abl = pD;
        }
        break;
    case SUB:
        assert(p1 != NULL);
        assert(p2 != NULL);
        p1a = p1->abl;
        p2a = p2->abl;
        if (p1a == N_0) {
            if (p2a == N_0) {
                p->abl = N_0;
            } else {
                NODED(pD, NEG, p2a, NULL);
                p->abl = pD;
            }
        } else if (p2a == N_0) {
            p->abl = p1a;
        } else {
            NODED(pD, SUB, p1a, p2a);
            p->abl = pD;
        }
        break;
    case MUL:
        assert(p1 != NULL);
        assert(p2 != NULL);
        p1a = p1->abl;
        p2a = p2->abl;
        if (p1a == N_0) {
            if (p2a == N_0) {
                p->abl = N_0;
            } else {
                if (p2a == N_1) {
                    p->abl = p1;
                } else {
                    NODED(pD, MUL, p2a, p1);
                    p->abl = pD;
                }
            }
        } else if (p2a == N_0) {
            if (p1a == N_1) {
                p->abl = p2;
            } else {
                NODED(pD, MUL, p1a, p2);
                p->abl = pD;
            }
        } else if (p1 == p2) {
            NODED(pD, MUL, N_2, p1);
            if (p1a != N_1) {
                pDv = pD;
                NODED(pD, MUL, p1a, pDv);
            }
            p->abl = pD;
        } else {
            if (p1a == N_1) {
                pDvv = p2;
            } else {
                NODED(pDvv, MUL, p1a, p2);
            }
            if (p2a == N_1) {
                pDv = p1;
            } else {
                NODED(pDv, MUL, p2a, p1);
            }
            NODED(pD, ADD, pDvv, pDv);
            p->abl = pD;
        }
        break;
    case DIV:
        assert(p1 != NULL);
        assert(p2 != NULL);
        p1a = p1->abl;
        p2a = p2->abl;
        if (p2a == N_0) {
            if (p1a == N_0) {
                p->abl = N_0;
            } else {
                NODED(pD, DIV, p1a, p2);
                p->abl = pD;
            }
        } else if (fval) {
            if (p2a == N_1) {
                pDvv = fval->node;
            } else {
                NODED(pDvv, MUL, p2a, fval->node);
            }
            if (p1a == N_0) {
                NODED(pDv, NEG, pDvv, NULL);
            } else {
                NODED(pDv, SUB, p1a, pDvv);
            }
            NODED(pD, DIV, pDv, p2);
            p->abl = pD;
        } else {
            if (p1a == N_0) {
                if (p1 == N_1) {
                    NODED(pDv, NEG, p2a, NULL);
                } else if (p2a == N_1) {
                    NODED(pDv, NEG, p1, NULL);
                } else {
                    NODED(pDvv, MUL, p2a, p1);
                    NODED(pDv, NEG, pDvv, NULL);
                }
            } else {
                if (p1a == N_1) {
                    pDvv = p2;
                } else {
                    NODED(pDvv, MUL, p1a, p2);
                }
                if (p2a == N_1) {
                    pDv = p1;
                } else {
                    NODED(pDv, MUL, p2a, p1);
                }
                NODED(pD, SUB, pDvv, pDv);
                pDv = pD;
            }
            NODED(pDvv, SQR, p2, NULL);
            NODED(pD, DIV, pDv, pDvv);
            p->abl = pD;
        }
        break;
    case POW:
        assert(p1 != NULL);
        assert(p2 != NULL);
        p1a = p1->abl;
        p2a = p2->abl;
        if (p1a == N_0) {
            if (p2a == N_0) {
                p->abl = N_0;
            } else {
                NODED(pDvv, LOG, p1, NULL);
                if (p2a == N_1) {
                    pDv = pDvv;
                } else {
                    NODED(pDv, MUL, p2a, pDvv);
                }
                NODED(pD, MUL, pDv, p);
                p->abl = pD;
            }
        } else {
            if (p2a == N_0) {
                NODED(pDvv, SUB, p2, N_1);
                NODED(pDv, POW, p1, pDvv);
                NODED(pD, MUL, p2, pDv);
                if (p1a != N_1) {
                    pDv = pD;
                    NODED(pD, MUL, p1a, pDv);
                }
            } else {
                if (p1a == N_1) {
                    NODED(pDv, DIV, p2, p1);
                } else {
                    NODED(pDvv, DIV, p1a, p1);
                    NODED(pDv, MUL, p2, pDvv);
                }
                NODED(pD, LOG, p1, NULL);
                if (p2a == N_1) {
                    pDvv = pD;
                } else {
                    NODED(pDvv, MUL, p2a, pD);
                }
                pD = pDv;
                NODED(pDv, ADD, pDvv, pD);
                if (fval) {
                    NODED(pD, MUL, pDv, fval->node);
                } else {
                    NODED(pD, MUL, pDv, p);
                }
            }
            p->abl = pD;
        }
        break;
    case REV:
        assert(p1 != NULL);
        p1a = p1->abl;
        if (p1a == N_0) {
            p->abl = N_0;
        } else {
            NODED(pDvv, SQR, p1, NULL);
            if (p1a == N_1) {
                NODED(pDv, REV, pDvv, NULL);
            } else {
                NODED(pDv, DIV, p1a, pDvv);
            }
            NODED(pD, NEG, pDv, NULL);
            p->abl = pD;
        }
        break;
    case EQU:
        assert(p1 != NULL);
        p->abl = p1->abl;
        break;
    case OPD:
        if (p->c.optr->typ == TMP) {
            if (TmpTyp[p->c.optr->ind]) {
                NODED(pD, DOPD, NULL, (PRX_NODE *)p->c.optr);
                p->abl = pD;
            } else
                p->abl = N_0;
        } else if (p->c.optr->typ == RES) {
            NODED(pD, DOPD, NULL, (PRX_NODE *)p->c.optr);
            p->abl = pD;
        } else
            p->abl = (p->c.optr == arg) ? N_1 : N_0;
        break;
    case NUM:
        p->abl = N_0;
        break;
    case ASS:
        assert(p1 != NULL);
        NODED(pD, ASS, p1->abl, NULL);
        pD->c.optr = p->c.optr;
        p->abl = pD;
        break;
    case SGN:
        p->abl = N_0;
        break;
    case SIN:
    case COS:
    case TAN:
    case ASIN:
    case ACOS:
    case ATAN:
    case SINH:
    case COSH:
    case TANH:
    case ERF:
    case EXP:
    case LOG:
    case LG:
    case SQRT:
    case ABS:
    case SQR:
        assert(p1 != NULL);
        p1a = p1->abl;
        if (p1a == N_0) {
            p->abl = N_0;
            break;
        }
        switch (opr) {
        case SIN:
            NODED(pD, COS, p1, NULL);
            break;
        case COS:
            NODED(pD, SIN, p1, NULL);
            pDv = pD;
            NODED(pD, NEG, pDv, NULL);
            break;
        case TAN:
            pDv = fval ? fval->node : p;
            NODED(pD, SQR, pDv, NULL);
            pDv = pD;
            NODED(pD, ADD, pDv, N_1);
            break;
        case ASIN:
        case ACOS:
            NODED(pD, SQR, p1, NULL);
            pDv = pD;
            NODED(pD, SUB, N_1, pDv);
            pDv = pD;
            NODED(pD, SQRT, pDv, NULL);
            pDv = pD;
            NODED(pD, REV, pDv, NULL);
            if (opr == ASIN)
                break;
            pDv = pD;
            NODED(pD, NEG, pDv, NULL);
            break;
        case ATAN:
            NODED(pD, SQR, p1, NULL);
            pDv = pD;
            NODED(pD, ADD, pDv, N_1);
            pDv = pD;
            NODED(pD, REV, pDv, NULL);
            break;
        case SINH:
            NODED(pD, COSH, p1, NULL);
            break;
        case COSH:
            NODED(pD, SINH, p1, NULL);
            break;
        case TANH:
            NODED(pD, TANH, p1, NULL);
            pDv = pD;
            NODED(pD, SQR, pDv, NULL);
            pDv = pD;
            NODED(pD, SUB, N_1, pDv);
            break;
        case ERF:
            NODED(pD, SQR, p1, NULL);
            pDv = pD;
            NODED(pD, NEG, pDv, NULL);
            pDv = pD;
            NODED(pD, EXP, pDv, NULL);
            pDv = pD;
            NODED(pD, MUL, N_2_SQRT_PI, pDv);
            break;
        case EXP:
            if (fval) {
                NODED(pD, EQU, fval->node, NULL);
            } else {
                NODED(pD, EXP, p1, NULL);
            }
            break;
        case LOG:
            NODED(pD, REV, p1, NULL);
            break;
        case LG:
            NODED(pD, DIV, N_1_ln10, p1);
            break;
        case SQRT:
            if (fval) {
                NODED(pD, DIV, N_0p5, fval->node);
            } else {
                NODED(pD, DIV, N_0p5, p);
            }
            break;
        case ABS:
            NODED(pD, SGN, p1, NULL);
            break;
        case SQR:
            NODED(pD, MUL, N_2, p1);
            break;
        default:
            break;
        }
        if (p1a != N_1) {
            pDv = pD;
            NODED(pD, MUL, p1a, pDv);
        }
        p->abl = pD;
        break;
    default:
        break;
    }
    return 1;
}

/* ========================================================================== */

/**
 @brief Simplification of expressions

 @param p pointer to expression
 @return 0 - error, 1 - success
 */
- (int)simplifyExpressionAtNode:(PRX_NODE *)p {
    PRX_NODE *p1, *p2 = NULL, *pD;
    OPR opr;
    double value;

    opr = p->opr;
    p1 = p->o1;
    if (p1) {
        [self simplifyExpressionAtNode:p1];
        if (p1->opr == EQU) {
            p->o1 = p1 = p1->o1;
        }
        if (opr != ASS) {
            p2 = p->c.o2;
            if (p2) {
                [self simplifyExpressionAtNode:p2];
                if (p2->opr == EQU) {
                    p->c.o2 = p2 = p2->o1;
                }
                if (opr == MUL && p2->opr == NUM) {
                    p->o1 = p2;
                    p->c.o2 = p1;
                    p1 = p->o1;
                    p2 = p->c.o2;
                }
            }
        }
    }
    switch (opr) {
    case NEG:
        assert(p1 != NULL);
        if (p1->opr == NEG) {
            p->opr = EQU;
            p->o1 = p1->o1;
            p->c.o2 = NULL;
        } else if (p1->opr == SUB) {
            p->opr = SUB;
            p->o1 = p1->c.o2;
            p->c.o2 = p1->o1;
        } else if (p1->opr == MUL) {
            if (p1->o1->opr == NEG) {
                p->opr = MUL;
                p->o1 = p1->o1->o1;
                p->c.o2 = p1->c.o2;
            } else if (p1->c.o2->opr == NEG) {
                p->opr = MUL;
                p->o1 = p1->o1;
                p->c.o2 = p1->c.o2->o1;
            }
        }
        break;
    case ADD:
        assert(p2 != NULL);
        if (p2->opr == NEG) {
            p->opr = SUB;
            p->c.o2 = p2->o1;
        } else if (p1->opr == NEG) {
            p->opr = SUB;
            p->o1 = p2;
            p->c.o2 = p1->o1;
        } else if (p1->opr == NUM && p2->opr == NUM) {
            p->opr = EQU;
            p->c.o2 = NULL;
            value = p1->c.nptr->val + p2->c.nptr->val;
            if (fabs(value) == HUGE_VAL) {
                ERROR("Addition overflow");
            }
            p->o1 = [self getNum:value];
        }
        break;
    case SUB:
        assert(p2 != NULL);
        if (p2->opr == NEG) {
            p->opr = ADD;
            p->c.o2 = p2->o1;
        }
        if (p1 == p2) {
            p->opr = EQU;
            p->o1 = N_0;
            p->c.o2 = NULL;
        } else if (p1->opr == NUM && p2->opr == NUM) {
            p->opr = EQU;
            p->c.o2 = NULL;
            value = p1->c.nptr->val - p2->c.nptr->val;
            if (fabs(value) == HUGE_VAL) {
                ERROR("Subtraction overflow");
            }
            p->o1 = [self getNum:value];
        } else if (p2->opr == MUL) {
            if (p2->o1->opr == NEG) {
                p->opr = ADD;
                p2->o1 = p2->o1->o1;
            } else if (p2->c.o2->opr == NEG) {
                p->opr = ADD;
                p2->c.o2 = p2->c.o2->o1;
            }
        }
        break;
    case MUL:
        assert(p1 != NULL);
        assert(p2 != NULL);
        if (p1 == N_1) {
            p->opr = EQU;
            p->o1 = p2;
            p->c.o2 = NULL;
        } else if (p2 == N_1) {
            p->opr = EQU;
            p->c.o2 = NULL;
        } else if (p1 == N_0 || p2 == N_0) {
            p->opr = EQU;
            p->o1 = N_0;
            p->c.o2 = NULL;
        } else if (p1->opr == NEG && p2->opr == NEG) {
            p->o1 = p1->o1;
            p->c.o2 = p2->o1;
        } else if (p2->opr == NEG) {
            if (p2->o1 == N_1) {
                p->opr = NEG;
                p->c.o2 = NULL;
            }
        } else if (p1->opr == NEG) {
            if (p1->o1 == N_1) {
                p->opr = NEG;
                p->o1 = p2;
                p->c.o2 = NULL;
            } else if (bDeriv && p1->o1->opr != NUM) {
                NODED(pD, MUL, p1->o1, p2);
                p->opr = NEG;
                p->o1 = pD;
                p->c.o2 = NULL;
            }
        } else if (p2->opr == REV) {
            p->opr = DIV;
            p->c.o2 = p2->o1;
        } else if (p1->opr == REV) {
            p->opr = DIV;
            p->o1 = p2;
            p->c.o2 = p1->o1;
        } else if (p1->opr == NUM && p2->opr == NUM) {
            p->opr = EQU;
            p->c.o2 = NULL;
            value = p1->c.nptr->val * p2->c.nptr->val;
            if (fabs(value) == HUGE_VAL) {
                ERROR("Multiplication overflow");
            }
            p->o1 = [self getNum:value];
        }
        break;
    case DIV:
        assert(p1 != NULL);
        assert(p2 != NULL);
        if (p2 == N_1) {
            p->opr = EQU;
            p->c.o2 = NULL;
        } else if (p1 == N_0) {
            p->opr = EQU;
            p->o1 = N_0;
            p->c.o2 = NULL;
        } else if (p1 == N_1) {
            p->opr = REV;
            p->o1 = p2;
            p->c.o2 = NULL;
        } else if (p2->opr == REV) {
            p->opr = MUL;
            p->c.o2 = p2->o1;
        } else if (p1->opr == NEG && p2->opr == NEG) {
            p->o1 = p1->o1;
            p->c.o2 = p2->o1;
        } else if (p1->opr == NEG) {
            if (bDeriv && p1->o1->opr != NUM) {
                NODED(pD, DIV, p1->o1, p2);
                p->opr = NEG;
                p->o1 = pD;
                p->c.o2 = NULL;
            }
        } else if (p1->opr == NUM && p2->opr == NUM) {
            p->opr = EQU;
            p->c.o2 = NULL;
            value = p1->c.nptr->val / p2->c.nptr->val;
            if (fabs(value) == HUGE_VAL) {
                ERROR("Division overflow");
            }
            p->o1 = [self getNum:value];
        } else if (p1->opr == OPD && p2->opr == OPD) {
            if (p1->c.optr == p2->c.optr) {
                p->opr = EQU;
                p->o1 = N_1;
                p->c.o2 = NULL;
            }
        }
        break;
    case REV:
        assert(p1 != NULL);
        if (p1->opr == REV) {
            p->opr = EQU;
            p->o1 = p1->o1;
            p->c.o2 = NULL;
        } else if (p1->opr == DIV) {
            p->opr = DIV;
            p->o1 = p1->c.o2;
            p->c.o2 = p1->o1;
        } else if (p1->opr == NUM) {
            p->opr = EQU;
            p->c.o2 = NULL;
            p->o1 = [self getNum:1 / p1->c.nptr->val];
        }
        break;
    case POW:
        if (p2 == N_1) {
            p->opr = EQU;
            p->c.o2 = NULL;
        } else if (p1 == N_0) {
            p->opr = EQU;
            p->o1 = N_0;
            p->c.o2 = NULL;
        } else if (p2 == N_0 || p1 == N_1) {
            p->opr = EQU;
            p->o1 = N_1;
            p->c.o2 = NULL;
        } else if (p2 == N_2) {
            p->opr = SQR;
            p->c.o2 = NULL;
        } else if (p2 == N_0p5) {
            p->opr = SQRT;
            p->c.o2 = NULL;
        }
        break;
    case EXP:
        assert(p1 != NULL);
        if (p1->opr == LOG) {
            p->opr = EQU;
            p->o1 = p1->o1;
            p->c.o2 = NULL;
        }
        break;
    case LOG:
        assert(p1 != NULL);
        if (p1->opr == EXP) {
            p->opr = EQU;
            p->o1 = p1->o1;
            p->c.o2 = NULL;
        }
        break;
    default:
        break;
    }
    return 1;
}

@end
