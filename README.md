# ParXModelCompiler
*A Model Compiler and Interpreter with first order derivatives.*

This Model Compiler & Interpreter is part of my [ParX Application](https://parx.middelhoek.com).

ParX models are represented as a set of implicit equations that must be zero in the solution. 
There is no artificial separation between independent and dependent variables. 
In combination with the availability of internal (i.e. auxiliary) and temporary variables, 
this allows for a much wider scope of models without the need for internal iteration. 
A full set of mathematical operators and special functions is provided, 
as well as an abundance of special numbers and physical constants. 
Conditional evaluation allows for the description of regional models.

The basic strategy of the compiler is to convert de (infix) equations to Reverse Polish (postfix) notation, an old classic.
However, what makes this implementation special is the creation of the analytical first order derivatives.
Most optimization and root-finding algorithms gain speed and reliability when derivatives are made available, 
and ParX is no exception. 
Mathematical analysis provides the rules for determining the derivatives for all operators and special functions. 
So all we have to do is build parallel parse trees for each derivative, 
and prune the results to eliminate superfluous operations. 
It sounds straightforward, but it is still a lot of code.

The first version of the ModelCompiler was a stand-alone application, written in C,
and optimized for the anemic computers of the day (1995),
which means a lot of aggressive memory managment and dangerous pointer arithmetic.
This version is still available as part of the old command line implementation of ParX
on GitHub: [ParXCL](https://github.com/mgmiddelhoek/ParXCL).

In 2016, the ModelCompiler was ported from C to Objective-C, 
to be integrated in the first Mac App Store version of ParX. 
In the transition it gained a number of long desired features: 
full Unicode support, a wider range of variable names, 
and unit-strings for the variables and parameters.
This is the version presented here.

For more information visit the [ModelCompiler project page](https://www.middelhoek.com/projects/modelcompiler.html).

## Model Specification Language

The models are described in a text file that specifies its
interface variables, parameters and equations between them, in a flexible format.
For the details of the specification language visit:
[Model Specification Language](https://parx.middelhoek.com/documentation/model-definition.html).

As a simple example: the model for a MOS transistor as proposed by Shichman and Hodges:

```
model:   "MOSFET level 1"
author:  "© parx.middelhoek.com <support@middelhoek.com>"
ident:   "Static model MOSFET level 1"
date:    "2025/01/01"
version: "1.0.0"

var: vgs = {1u} V
var: vds = {1u} V
var: vbs = {1u} V
var: id	 = {1p} A

par: vto    = {1, 0.1, 5} V
par: gamma  = {0, 0, 1} √V
par: phi    = {0.6, 0, 1} V
par: kp     = {20u, 1u, 1m} A/V²
par: lambda = {20m, 0, 1} V⁻¹
par: rd     = {0, 0, 1k} Ω
par: rs     = {0, 0, 1k} Ω

const: w = {1u} m
const: l = {1u} m

aux: Vsat = {1u} V

res: Di, Ds

equations:

// Internal voltages
Vds = vds - id * (rs + rd)
Vgs = vgs - id * rs
Vbs = vbs - id * rs

Vt = vto + gamma * (sqrt(phi - Vbs) - sqrt(phi))

beta = (w / l) * (kp / 2) * (1 + lambda * Vds) 

if (Vgs < Vt) // Cutoff region
    ids = 0
else
    if (Vds < Vsat) // Linear region
        ids = beta * Vds * (2 * (Vgs - Vt) - Vds)
    else // Saturated region
        ids = beta * (Vgs - Vt)^2
    fi
fi

Di = id - ids
Ds = Vsat - (Vgs - Vt)

```

## ModelCompiler API

The `ModelCompiler` Class initializer reads from a model-definition file,
which has usually the file extension `.parx`.
Parsing errors are returned in a `NSError` object that contains a description of the error,
and the line number at which the error occurred.

```
@interface PXModelCompiler : NSObject

- (nullable PXModelCompiler *)initWithPath:(nonnull NSString *)mdlFileName
                              error:(NSError *_Nullable *_Nullable)error;

- (nullable ModelCode *)getModelCode;

- (nonnull NSMutableArray *)getSymbolsNotAssigned;

- (nonnull NSMutableArray *)getSymbolsNotUsed;

@end
```

The compiled code is made available as a `ModelCode` object.

The `ModelInterpreter` Class initializer accepts a `ModelCode` object.
The model is then evaluated for the given input by `evaluateForVar:`.

```
@interface PXModelInterpreter : NSObject

@property int errorCode;

- (nullable ModelInterpreter *) initWithCode: (nonnull ModelCode *) modelCode;

/**
@brief Execution of interpreter code
@param x: variables
@param a: auxillary variables
@param p: parameters
@param c: constants
@param f: flags
@param r: residuals
@param jxf: flag evaluate Jacobian for variables
@param xf: flags per variable
@param jx: Jacobian for variables
@param ja: Jacobian for auxillary variables
@param jpf: flag evaluate Jacobian for parameters
@param pf: flags per parameter
@param jp: Jacobian for parameters
@return YES/NO for success/failure
*/
- (BOOL) evaluateForVar: (nonnull const double *)x
                    aux: (nonnull const double *)a
                    par: (nonnull const double *)p
                    con: (nonnull const double *)c
                   flag: (nonnull const double *)f
                    res: (nonnull double *)r
               jacXFlag: (const BOOL)jxf
               varFlags: (nullable const BOOL *)xf
                   JacX: (nullable double *)jx
                   JacA: (nullable double *)ja
               jacPFlag: (const BOOL)jpf
               parFlags: (nullable const BOOL *)pf
                   JacP: (nullable double *)jp;
@end
```
