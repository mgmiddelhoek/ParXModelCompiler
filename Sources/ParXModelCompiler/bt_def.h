//
// bt_def.h
// ParXModelCompiler
//
// Header file for Binary Tree management subroutines
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

#ifndef _BT_DEF_H
#define _BT_DEF_H

#include <stdlib.h>
#include <assert.h>
#include "mem_def.h"

#define BT_S_EXISTS (-101)
#define BT_S_NOTFND (-102)
#define BT_S_BALANCE (-103)
#define BT_S_REPLACE (101)

struct BT_ITEM {
    struct BT_ITEM *li; /* left pointer */
    struct BT_ITEM *re; /* right pointer */
    char *inh;          /* pointer to contents */
    char fl;            /* balanced flag */
};

struct BT_HEAD {
    struct MEM_TREE *tptr;      /* pointer to memory tree */
    struct BT_ITEM *wu;         /* pointer to root node */
    struct BT_ITEM *fp;         /* pointer to first free node */
    int (*cmp)(void *, void *); /* pointer to compare function */
};

extern struct BT_HEAD *bt_define_tree(struct MEM_TREE *,
                                      int (*)(void *, void *));
extern int bt_traverse(struct BT_HEAD *, int (*)(char *));

extern int bt_insert(struct BT_HEAD *head, char *rec);

extern char *bt_search(struct BT_HEAD *head, char *rec);
extern char *bt_search_replace(struct BT_HEAD *head, char *rec);

#endif
