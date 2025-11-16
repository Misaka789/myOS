#ifndef PROC_H
#define PROC_H

#include "riscv.h"
#include "types.h"
#include "spinlock.h"
#include "param.h"

// 进程状态
enum procstate
{
    UNUSED,   // 未使用
    USED,     // 已分配，但未完全初始化
    SLEEPING, // 正在等待某个事件
    RUNNABLE, // 等待被调度器选中
    RUNNING,  // 正在 CPU 上运行
    ZOMBIE
}; // 已退出，等待父进程回收

// 保存 swtch 切换时的上下文
// swtch 只保存和恢复被调用者保存的寄存器 (callee-saved registers)
struct context // 用于内核态中进程的切换
{
    uint64 ra; // 返回地址
    uint64 sp; // 栈指针

    // 被调用者保存的寄存器
    uint64 s0;
    uint64 s1;
    uint64 s2;
    uint64 s3;
    uint64 s4;
    uint64 s5;
    uint64 s6;
    uint64 s7;
    uint64 s8;
    uint64 s9;
    uint64 s10;
    uint64 s11;
};

struct trapframe // 用于内核态和用户态的切换
{
    /*   0 */ uint64 kernel_satp;   // 内核页表
    /*   8 */ uint64 kernel_sp;     // 进程内核栈顶部
    /*  16 */ uint64 kernel_trap;   // usertrap()
    /*  24 */ uint64 epc;           // 保存的用户程序计数器
    /*  32 */ uint64 kernel_hartid; // 保存的内核 hartid
    /*  40 */ uint64 ra;
    /*  48 */ uint64 sp;
    /*  56 */ uint64 gp;
    /*  64 */ uint64 tp;
    /*  72 */ uint64 t0;
    /*  80 */ uint64 t1;
    /*  88 */ uint64 t2;
    /*  96 */ uint64 s0;
    /* 104 */ uint64 s1;
    /* 112 */ uint64 a0;
    /* 120 */ uint64 a1;
    /* 128 */ uint64 a2;
    /* 136 */ uint64 a3;
    /* 144 */ uint64 a4;
    /* 152 */ uint64 a5;
    /* 160 */ uint64 a6;
    /* 168 */ uint64 a7;
    /* 176 */ uint64 s2;
    /* 184 */ uint64 s3;
    /* 192 */ uint64 s4;
    /* 200 */ uint64 s5;
    /* 208 */ uint64 s6;
    /* 216 */ uint64 s7;
    /* 224 */ uint64 s8;
    /* 232 */ uint64 s9;
    /* 240 */ uint64 s10;
    /* 248 */ uint64 s11;
    /* 256 */ uint64 t3;
    /* 264 */ uint64 t4;
    /* 272 */ uint64 t5;
    /* 280 */ uint64 t6;
};

struct cpu
{
    struct proc *proc;
    struct context context;
    int noff;   // 嵌套调用的深度
    int intena; // 中断使能
};

extern struct cpu cpus[NCPU];

// 进程控制块 (PCB)
struct proc
{
    struct spinlock lock;

    // p->lock 必须持有时才能修改的字段
    enum procstate state; // 进程状态
    void *chan;           // 如果非零，表示正在 chan 上睡眠
    int killed;           // 如果非零，表示进程已被标记为杀死
    int xstate;           // 退出状态，由父进程读取
    int pid;              // 进程 ID
    // wait_lock 必须持有时才能修改的字段
    struct proc *parent; // 父进程

    // 这些字段通常在进程自己的锁保护下是安全的
    uint64 kstack;               // 此进程的内核栈顶地址
    uint64 sz;                   // 进程内存大小 (bytes)
    pagetable_t pagetable;       // 用户页表
    struct trapframe *trapframe; // 用于保存 S 模式陷阱的上下文
    struct context context;      // 用于在 swtch 中切换的上下文
    char name[16];               // 进程名 (debugging)
    struct inode *cwd;           // 当前工作目录
    struct file *ofile[NOFILE];  // 打开的文件
};

#endif