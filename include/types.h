#ifndef TYPES_H
#define TYPES_H

typedef unsigned int uint;
typedef unsigned short ushort;
typedef unsigned char uchar;

typedef unsigned char uint8;
typedef unsigned short uint16;
typedef unsigned int uint32;
typedef unsigned long uint64;

typedef uint64 pde_t;
typedef uint64 *pagetable_t;
typedef uint64 pte_t;

typedef void (*interrupt_handler_t)(void);

#define NULL ((void *)0)

#endif