//
// mem_func.c
// ParXModelCompiler
//
// Memory management subroutines
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

#include "mem_def.h"

/**
 @brief out of memory
 */
static void mem_noroom(void) {
    fprintf(stderr, "ParX model compiler: out of memory\n");
    exit(1);
}

/**
 @brief allocate a memory tree

 @return pointer to allocated memory
 */
struct MEM_TREE *mem_tree(void) {
    struct MEM_TREE *tptr;

    tptr = (struct MEM_TREE *)malloc(sizeof(struct MEM_TREE));
    if (tptr == NULL) {
        mem_noroom();
    }
    tptr->first = NULL;
    tptr->last = NULL;
    tptr->cnt = 0;
    tptr->size = 0;

    return tptr;
}

/**
 @brief allocate a new leaf in a memory tree

 @param tptr   memory tree
 @param size   size of the leaf
 @return pointer to the leaf
 */
void *mem_slot(struct MEM_TREE *tptr, size_t size) {
    struct MEM_LEAF *lptr;
    void *mem;

    lptr = (struct MEM_LEAF *)malloc(sizeof(struct MEM_LEAF));
    mem = malloc(size);
    if (tptr == NULL || mem == NULL) {
        mem_noroom();
    }
    lptr->next = NULL;
    lptr->mem = mem;

    if (tptr->first == NULL) {
        tptr->first = lptr;
        tptr->last = lptr;
    } else {
        tptr->last->next = lptr;
        tptr->last = lptr;
    }
    tptr->cnt += 1;
    tptr->size += size;
    return (mem);
}

/**
 @brief de-allocate a memory tree

 @param tptr pointer to memory tree
 @return the size of the reclaimed memory
 */
size_t mem_free(struct MEM_TREE *tptr) {
    struct MEM_LEAF *lptr, *next;
    size_t size;

    size = tptr->size;

    if (tptr == NULL) {
        return 0;
    }

    lptr = tptr->first;

    while (lptr != NULL) {
        next = lptr->next;
        free(lptr->mem);
        free(lptr);
        lptr = next;
    }
    free(tptr);

    return size;
}
