#include "types.h"
#include "param.h"
#include "riscv.h"
#include "defs.h"
#include "proc.h"
#include "spinlock.h"

// 全局进程表
struct proc proc[NPROC]; // 进程数组
struct cpu cpus[NCPU];   // CPU 数组

// 第一个用户进程，在 userinit 中创建
struct proc *initproc;

int nextpid = 1; // 全局 id 计数器
struct spinlock pid_lock;

// 初始化进程子系统
void procinit(void)
{
    struct proc *p;

    initlock(&pid_lock, "nextpid");

    // 遍历进程表，初始化每个进程的锁
    for (p = proc; p < &proc[NPROC]; p++)
    {
        initlock(&p->lock, "proc");
        // 注意：内核栈的分配推迟到 allocproc 中，
        // 这样可以按需分配资源。
    }
    printf("procinit: process table initialized\n");
}

uint64 cpuid()
{
    uint64 id = r_tp();
    return id;
}

// Return this CPU's cpu struct.
// Interrupts must be disabled.
struct cpu *
mycpu(void)
{
    int id = cpuid();
    struct cpu *c = &cpus[id];
    return c;
}