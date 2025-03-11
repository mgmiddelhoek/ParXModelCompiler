//
// PXModelCode.h
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

#ifndef _PXModelCode_h
#define _PXModelCode_h

#import "prx_def.h"

@interface PXModelCode : NSObject

@property(nonnull) NSString *fileName;
@property(nonnull) NSString *model;
@property(nonnull) NSString *author;
@property(nonnull) NSString *date;
@property(nonnull) NSString *version;
@property(nonnull) NSString *ident;

@property(nonnull) NSMutableArray<NSString *> *varName;
@property(nonnull) NSMutableArray<NSNumber *> *varAbsTol;
@property(nonnull) NSMutableArray<NSNumber *> *varLowerLimit;
@property(nonnull) NSMutableArray<NSNumber *> *varUpperLimit;
@property(nonnull) NSMutableArray<NSString *> *varUnit;

@property(nonnull) NSMutableArray<NSString *> *auxName;
@property(nonnull) NSMutableArray<NSNumber *> *auxAbsTol;
@property(nonnull) NSMutableArray<NSNumber *> *auxLowerLimit;
@property(nonnull) NSMutableArray<NSNumber *> *auxUpperLimit;

@property(nonnull) NSMutableArray<NSString *> *parName;
@property(nonnull) NSMutableArray<NSNumber *> *parDefaultValue;
@property(nonnull) NSMutableArray<NSNumber *> *parLowerBound;
@property(nonnull) NSMutableArray<NSNumber *> *parUpperBound;
@property(nonnull) NSMutableArray<NSNumber *> *parLowerLimit;
@property(nonnull) NSMutableArray<NSNumber *> *parUpperLimit;
@property(nonnull) NSMutableArray<NSString *> *parUnit;

@property(nonnull) NSMutableArray<NSString *> *conName;
@property(nonnull) NSMutableArray<NSNumber *> *conDefaultValue;
@property(nonnull) NSMutableArray<NSString *> *conUnit;

@property(nonnull) NSMutableArray<NSString *> *flgName;
@property(nonnull) NSMutableArray<NSNumber *> *flgDefaultValue;

@property(nonnull) NSMutableArray<NSString *> *resName;

@property int numberOfTemp;

- (void)addOperator:(OPR)operator;
- (void)addType:(TYP)type;
- (void)addIndex:(int)index;

- (void)addVarName:(nonnull NSString *)name
        withAbsTol:(nonnull NSNumber *)abstol
    withLowerLimit:(nonnull NSNumber *)lowerLimit
    withUpperLimit:(nonnull NSNumber *)upperLimit
          withUnit:(nonnull NSString *)unit;

- (void)addAuxName:(nonnull NSString *)name
        withAbsTol:(nonnull NSNumber *)abstol
    withLowerLimit:(nonnull NSNumber *)lowerLimit
    withUpperLimit:(nonnull NSNumber *)upperLimit;

- (void)addParName:(nonnull NSString *)name
    withDefaultValue:(nonnull NSNumber *)defVal
      withLowerBound:(nonnull NSNumber *)lowVal
      withUpperBound:(nonnull NSNumber *)upVal
      withLowerLimit:(nonnull NSNumber *)lowerLimit
      withUpperLimit:(nonnull NSNumber *)upperLimit
            withUnit:(nonnull NSString *)unit;

- (void)addConName:(nonnull NSString *)name
    withDefaultValue:(nonnull NSNumber *)defVal
            withUnit:(nonnull NSString *)unit;

- (void)addFlgName:(nonnull NSString *)name
    withDefaultValue:(nonnull NSNumber *)defVal;

- (void)addResName:(nonnull NSString *)name;

- (void)addNumber:(double)number;

- (nullable CODE *)getModelCode;
- (int)getLengthCode;

- (nullable double *)getModelNumbers;
- (int)getLengthNumbers;

- (void)print;

@end

#endif
