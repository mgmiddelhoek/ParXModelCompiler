//
// PXModelCompiler.h
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

#ifndef _PXModelCompiler_h
#define _PXModelCompiler_h

@class PXModelCode;

@interface PXModelCompiler : NSObject

- (nullable PXModelCompiler *)initWithPath:(nonnull NSString *)mdlFileName
                                   error:(NSError *_Nullable *_Nullable)error;

- (nullable PXModelCode *)getModelCode;

- (nonnull NSMutableArray *)getSymbolsNotAssigned;

- (nonnull NSMutableArray *)getSymbolsNotUsed;

+ (nonnull NSString *)getReservedNameTokens;

+ (nonnull NSString *)getNotAtNameStartTokens;

+ (nonnull NSString *)getNameSeparatorToken;

@end

#endif
