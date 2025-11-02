// 内核空间，实现系统调用的功能
#include "types.h"
#include "riscv.h"
#include "defs.h"
#include "param.h"
#include "memlayout.h"
#include "proc.h"
#include "syscall.h"

extern struct spinlock tickslock;
extern uint64 ticks;

// uint64 sys_hello(void)
// {
//     printf("Hello, RISC-V OS!\n");
//     return 114514;
// }

// 退出进程
uint64 sys_exit(void)
{
    int n;
    argint(0, &n);
    exit(n);
    return 0;
}
// 获取当前进程的 pid
uint64 sys_getgid(void)
{
    return myproc()->pid;
}

//  创建进程
uint64 sys_fork(void)
{
    return fork();
}

// 当前进程阻塞知道子进程退出
uint64 sys_wait(void)
{
    uint64 p;
    argaddr(0, &p);
    return wait(p);
}

// 用于增加或者减少进程堆内存的大小， malloc 函数的实现
uint64 sys_sbrk(void)
{
    uint64 addr;
    int n;
    argint(0, &n);
    addr = myproc()->sz;
    if (n < 0)
    {
        extern int shrinkproc(int);
        if (shrinkproc(-n) < 0)
            return -1;
    }
    else
    {
        myproc()->sz += n;
    }
    return addr;
}

// 让当前的进程暂停执行指定的 时钟滴答数
uint64 sys_sleep(void)
{
    int n;
    uint ticks0;
    argint(0, &n);
    if (n < 0)
        n = 0;
    acquire(&tickslock);
    ticks0 = ticks;
    while (ticks - ticks0 < n)
    {
        if (killed(myproc()))
        {
            release(&tickslock);
            return -1;
        }
        sleep(&ticks, &tickslock);
    }
    release(&tickslock);
    return 0;
}

uint64 sys_kill(void)
{
    int pid;
    argint(0, &pid);
    return kill(pid);
}

// 返回从气筒启动到当前时刻所经过的时钟滴答数
uint64 sys_uptime(void)
{
    uint xticks;
    acquire(&tickslock);
    xticks = ticks;
    release(&tickslock);
    return xticks;
}