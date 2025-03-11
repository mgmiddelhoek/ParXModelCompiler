//
// bt_func.c
// ParXModelCompiler
//
// Binary Tree management subroutines
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

#include "bt_def.h"

#define E_BALANCE 1
#define SYS_S_MEM (-3)

/* local functions */
static int traverse(struct BT_ITEM *, int (*act)(char *));
static struct BT_ITEM *insert(struct BT_ITEM *);

/**
 @brief initialize a binary tree

 @param tptr   memory pool
 @param cmp    node comparison function
 @return pointer to binary tree
 **/
struct BT_HEAD *bt_define_tree(struct MEM_TREE *tptr,
                               int (*cmp)(void *, void *)) {
    struct BT_HEAD *h;
    int (*compare)(void *, void *);

    compare = cmp;
    h = (struct BT_HEAD *)mem_slot(tptr, sizeof(*h));
    if (h == NULL) {
        return NULL;
    }
    h->tptr = tptr;
    h->wu = NULL;
    h->fp = NULL;
    h->cmp = compare;
    return h;
}

/**
 @brief traverse a binary tree and apply a function to each node

 @param head   root of binary tree
 @param action function to perform
 @return status, 0 is ok
 **/
int bt_traverse(struct BT_HEAD *head, int (*action)(char *)) {
    int (*act)(char *);

    act = action;
    return (traverse(head->wu, act));
}

/**
 @brief traverse a binary tree and apply a function to each node

 @discussion internal recursive function

 @param p   leaf of binary tree
 @param act function to perform
 @return status, 0 is ok
 **/
static int traverse(struct BT_ITEM *p, int (*act)(char *)) {
    int stat;

    if (p == NULL) {
        return 0;
    }
    stat = traverse(p->li, act);
    if (stat) {
        return stat;
    }
    stat = (*act)(p->inh);
    if (stat) {
        return stat;
    }
    stat = traverse(p->re, act);
    if (stat) {
        return stat;
    }
    return 0;
}

/* local data */
static struct BT_HEAD *hh;
static int (*cmp)(void *, void *);
static char *crec;
static int vflag;
static int mem_ovfl;

/**
 @brief insert a node in a binary tree

 @param head   root of binary tree
 @param rec    record to insert
 @return status, 0 is ok
 */
int bt_insert(struct BT_HEAD *head, char *rec) {
    struct BT_ITEM *p;

    hh = head;
    cmp = hh->cmp;
    crec = rec;
    mem_ovfl = 0;
    p = insert(hh->wu);
    if (p == NULL) {
        if (mem_ovfl) {
            return SYS_S_MEM;
        } else {
            return BT_S_EXISTS;
        }
    }
    hh->wu = p;
    return 0;
}

/**
 @brief insert a node in a binary tree

 @discussion internal recursive function

 @param p   leaf of binary tree
 @return pointer to parent leaf
 */
static struct BT_ITEM *
insert(struct BT_ITEM *p) { /* recursive helper function */
    struct BT_ITEM *p1, *p2;
    int f;

    vflag = 0; /* same level */
    if (p == NULL) {
        /* create new element */
        if (hh->fp != NULL) {
            p1 = hh->fp;
            hh->fp = (hh->fp)->li;
        } else {
            p1 = (struct BT_ITEM *)mem_slot(hh->tptr, sizeof(struct BT_ITEM));
            if (p1 == NULL) {
                mem_ovfl = 1;
                return NULL;
            }
        }
        p1->li = NULL;
        p1->re = NULL;
        p1->inh = crec;
        p1->fl = 0;
        vflag = 1;
        return p1;
    }
    if ((*cmp)(crec, p->inh) == 0) {
        return NULL;
    }
    if ((*cmp)(crec, p->inh) < 0) {
        p1 = insert(p->li);
        f = -1;
    } else {
        p1 = insert(p->re);
        f = 1;
    }
    if (p1 == NULL) {
        return NULL;
    }
    if (f > 0) {
        p->re = p1;
    } else {
        p->li = p1;
    }
    if (vflag == 0) {
        return p; /* same level */
    }
    if (p->fl == 0) {
        p->fl = f;
        return p;
    }

    /* balance partial tree */
    if (p->fl > 0) { /* partial tree is right heavy */
        if (f < 0) {
            p->fl = 0;
            vflag = 0;
            return p;
        }
        if (p1->fl > 0) {
            p->re = p1->li;
            p1->li = p;
            p->fl = 0;
            p1->fl = 0;
            vflag = 0;
            return p1;
        } else {
            p2 = p1->li;
            assert(p2 != NULL);
            p->re = p2->li;
            p1->li = p2->re;
            p2->li = p;
            p2->re = p1;
            p1->fl = 0;
            p->fl = 0;
            if (p2->fl > 0) {
                p->fl = -1;
            }
            if (p2->fl < 0) {
                p1->fl = 1;
            }
        }
    } else { /* partial tree is left heavy */
        if (f > 0) {
            p->fl = 0;
            vflag = 0;
            return p;
        }
        if (p1->fl < 0) {
            p->li = p1->re;
            p1->re = p;
            p->fl = 0;
            p1->fl = 0;
            vflag = 0;
            return p1;
        } else {
            p2 = p1->re;
            assert(p2 != NULL);
            p->li = p2->re;
            p1->re = p2->li;
            p2->re = p;
            p2->li = p1;
            p1->fl = 0;
            p->fl = 0;
            if (p2->fl < 0) {
                p->fl = 1;
            }
            if (p2->fl > 0) {
                p1->fl = -1;
            }
        }
    }
    p2->fl = 0;
    vflag = 0;
    return p2;
}

/**
 @brief search the binary tree

 @param head   root of binary tree
 @param rec    record to find
 @return pointer to node, or NULL if not found
 */
char *bt_search(struct BT_HEAD *head, char *rec) {
    struct BT_ITEM *p;
    int stat;

    p = head->wu;
    while (p != NULL) {
        stat = (*(head->cmp))(rec, p->inh);
        if (stat == 0) {
            return (p->inh);
        }
        if (stat < 0) {
            p = p->li;
        } else {
            p = p->re;
        }
    }
    return (NULL);
}

/**
 @brief search the binary tree and replace node

 @param head   root of binary tree
 @param rec    record to find
 @return pointer to node, or NULL if not found
 */
char *bt_search_replace(struct BT_HEAD *head, char *rec) {
    struct BT_ITEM *p;
    int stat;

    p = head->wu;
    while (p != NULL) {
        stat = (*(head->cmp))(rec, p->inh);
        if (stat == 0) {
            p->inh = rec;
            return (p->inh);
        }
        if (stat < 0) {
            p = p->li;
        } else {
            p = p->re;
        }
    }
    return (NULL);
}
