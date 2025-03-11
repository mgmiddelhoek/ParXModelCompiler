//
// PXModelInterpreter.h
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

#ifndef _PXModelInterpreter_h
#define _PXModelInterpreter_h

#import "prx_def.h"

@class PXModelCode;

@interface PXModelInterpreter : NSObject

@property int errorCode;

- (nullable PXModelInterpreter *)initWithCode:(nonnull PXModelCode *)modelCode;

- (BOOL)evaluateForVar:(nonnull const double *)x
                   aux:(nonnull const double *)a
                   par:(nonnull const double *)p
                   con:(nonnull const double *)c
                  flag:(nonnull const double *)f
                   res:(nonnull double *)r
              jacXFlag:(const BOOL)jxf
              varFlags:(nullable const BOOL *)xf
                  JacX:(nullable double *)jx
                  JacA:(nullable double *)ja
              jacPFlag:(const BOOL)jpf
              parFlags:(nullable const BOOL *)pf
                  JacP:(nullable double *)jp;

@end

#endif
