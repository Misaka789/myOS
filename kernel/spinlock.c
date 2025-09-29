// Mutual exclusion spin locks.
#include "types.h"
#include "param.h"
#include "memlayout.h"
#include "spinlock.h"
#include "riscv.h"
#include "defs.h"

void initlock(struct spinlock *lk, char *name)
{
    lk->name = name;
    lk->locked = 0;
    lk->cpu = 0;
}

void acquire(struct spinlock *lk)
{
    // printf("lock : %s \n", lk->name);
}
void release(struct spinlock *lk)
{
    // printf("unlock : %s \n", lk->name);
}
