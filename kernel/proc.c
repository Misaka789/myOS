#include "types.h"
#include "param.h"
#include "riscv.h"
#include "defs.h"
#include "proc.h"
#include "spinlock.h"
#include "memlayout.h"

// 全局进程表
struct proc proc[NPROC]; // 进程数组
struct cpu cpus[NCPU];   // CPU 数组

// 第一个用户进程，在 userinit 中创建
struct proc *initproc;

int nextpid = 1; // 全局 id 计数器
struct spinlock pid_lock;

extern void forkret(void); // fork 返回时的函数
static void freeproc(struct proc *p);

void trampoline(); // trampoline.S

struct spinlock wait_lock; // 保护 p->parent

pagetable_t proc_pagetable(struct proc *p);

void proc_freepagetable(pagetable_t pagetable, uint64 sz)
{
    uvmunmap(pagetable, TRAMPOLINE, 1, 0);
    uvmunmap(pagetable, TRAPFRAME, 1, 0);
    uvmfree(pagetable, sz);
}

// 初始化进程子系统
void procinit(void)
{
    struct proc *p;

    initlock(&pid_lock, "nextpid");

    // 遍历进程表，初始化每个进程的锁
    for (p = proc; p < &proc[NPROC]; p++)
    {
        initlock(&p->lock, "proc");
        p->state = UNUSED;
        p->kstack = KSTACK((int)(p - proc)); // 计算内核栈的虚拟地址
    }
    printf("procinit: process table initialized\n");
}

static void freeproc(struct proc *p)
{
    if (p->trapframe)
        kfree((void *)p->trapframe);
    p->trapframe = 0;
    if (p->pagetable)
        proc_freepagetable(p->pagetable, p->sz);
    p->pagetable = 0;
    p->sz = 0;
    p->pid = 0;
    p->parent = 0;
    p->name[0] = 0;
    p->chan = 0;
    p->killed = 0;
    p->xstate = 0;
    p->state = UNUSED;
}

void proc_mapstacks(pagetable_t kpgtbl)
{
    struct proc *p;

    for (p = proc; p < &proc[NPROC]; p++)
    {
        char *pa = kalloc();
        if (pa == 0)
            panic("kalloc");
        // uint64 va = KSTACK((int)(p - proc)); // 计算内核栈的虚拟地址
        kvmmap(kpgtbl, p->kstack, (uint64)pa, PGSIZE, PTE_R | PTE_W);
    }
}

struct proc *myproc(void)
{
    push_off(); // 关闭 中断
    struct cpu *c = mycpu();
    struct proc *p = c->proc;
    pop_off(); // 恢复 中断
    return p;
}

int allocpid()
{
    int pid;
    acquire(&pid_lock);
    pid = nextpid;
    nextpid = nextpid + 1;
    release(&pid_lock);
    return pid;
}

static struct proc *allocproc(void) // 创建一个进程和 页表
{
    struct proc *p;
    for (p = proc; p < &proc[NPROC]; p++)
    {
        acquire(&p->lock);
        if (p->state == UNUSED)
        {
            goto found;
            release(&p->lock);
            return p;
        }
        else
        {
            release(&p->lock);
        }
    }
    return 0; // alloc failed
found:
    p->pid = allocpid();
    p->state = USED;
    // 分配 trapframe 页面
    if ((p->trapframe = (struct trapframe *)kalloc()) == 0)
    {
        freeproc(p);
        release(&p->lock);
        return 0;
    }
    // 分配空的用户页表
    p->pagetable = proc_pagetable(p);
    if (p->pagetable == 0)
    {
        freeproc(p);
        release(&p->lock);
        return 0;
    }
    memset(&p->context, 0, sizeof(p->context));
    p->context.ra = (uint64)forkret;
    p->context.sp = p->kstack + PGSIZE;
    return p;
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

pagetable_t proc_pagetable(struct proc *p)
{
    // return (uint64)p->pagetable;
    pagetable_t pagetable = create_pagetable();
    if (pagetable == 0)
        return 0;

    // 映射 trampoline 代码（用于系统调用返回）
    // 映射到最高的用户虚拟地址
    // 只有超级用户使用它，在进入/离开用户空间时使用，所以不是 PTE_U
    if (mappages(pagetable, TRAMPOLINE, PGSIZE,
                 (uint64)trampoline, PTE_R | PTE_X) < 0)
    {
        proc_freepagetable(pagetable, 0);
        return 0;
    }

    // 为每个进程分配一个 trapframe 页面
    if (mappages(pagetable, TRAPFRAME, PGSIZE,
                 (uint64)(p->trapframe), PTE_R | PTE_W) < 0)
    {
        proc_freepagetable(pagetable, 0);
        return 0;
    }

    return pagetable;
}

extern void fork_test_main();
void userinit(void)
{
    struct proc *p;
    p = allocproc();
    initproc = p;
    // p->cwd = namei("/"); // 设置当前工作目录为根目录
    // proc_freepagetable(p->pagetable, 0);
    // extern char _binary_user_first_prog_bin_start[];
    // extern char _binary_user_first_prog_bin_size[];
    // if (uvmcopy(p->pagetable, p->sz, (uint64)_binary_user_first_prog_bin_start, (uint64)_binary_user_first_prog_bin_size) < 0)
    //     panic("userinit: uvmcopy failed");
    p->sz = PGSIZE;

    // prepare for the first return from kernel to user.
    p->trapframe->epc = 0;     // user program counter
    p->trapframe->sp = PGSIZE; // user stack pointer

    safestrcpy(p->name, "first_prog", sizeof(p->name)); // Give it a proper name    release(&p->lock);
}

int shrinkproc(int n)
{ // 收缩用户内存 作用是释放用户内存
    struct proc *p = myproc();

    if (n > p->sz)
        return -1;
    uint64 sz = p->sz;
    uvmdealloc(p->pagetable, sz, sz - n);
    p->sz = p->sz - n;
    return 0;
}

int fork(void)
{
    int pid;
    struct proc *np;
    struct proc *p = myproc();
    if ((np = allocproc()) == 0)
    {
        return -1; // 创建新的进程失败
    }
    if (uvmcopy(p->pagetable, np->pagetable, p->sz) < 0)
    {
        freeproc(np);
        release(&np->lock);
        return -1; // 复制页表失败
    }
    np->sz = p->sz;                     // 设置新进程的内存大小
    *(np->trapframe) = *(p->trapframe); // 复制寄存器状态
    np->trapframe->a0 = 0;              // 让子进程返回 0
    // 这里先暂时不管文件和目录的复制
    // for (i = 0; i < NOFILE; i++)
    //     if (p->ofile[i])
    //         np->ofile[i] = filedup(p->ofile[i]);    // 复制打开的文件
    // np->cwd = idup(p->cwd);                         // 复制当前工作目录
    safestrcpy(np->name, p->name, sizeof(p->name)); // 复制进程名
    pid = np->pid;                                  // 获取新进程的 PID
    release(&np->lock);
    acquire(&wait_lock);
    np->parent = p; // 设置新进程的父进程
    release(&wait_lock);
    acquire(&np->lock);
    np->state = RUNNABLE; // 设置新进程为可运行状态
    release(&np->lock);
    return pid; // 返回新进程的 PID
}

// 放弃 cpu 调用者必须持有 p -> lock
// 函数保存上下文 改变进程状态 调用 scheduler()
void sched(void)
{
    int intena;
    struct proc *p = myproc();

    // 如果没有持有锁
    if (!holding(&p->lock))
        panic("sched p->lock");

    // 如果嵌套调用深度不为 1
    if (mycpu()->noff != 1)
        panic("sched locks");

    // 如果进程状态不是 RUNNING
    if (p->state == RUNNING)
        panic("sched running");

    // 如果中断是开启的
    if (intr_get())
        panic("sched interruptible");
    intena = mycpu()->intena;
    // 切换cpu 核心的上下文
    swtch(&p->context, &mycpu()->context);
    mycpu()->intena = intena;
}

void sleep(void *chan, struct spinlock *lk)
{
    struct proc *p = myproc();
    acquire(&p->lock);   // 获取进程锁
    release(lk);         // 释放条件锁
    p->chan = chan;      // 设置睡眠通道
    p->state = SLEEPING; // 设置进程状态为睡眠
    sched();             // 调度其他进程
    p->chan = 0;         // 唤醒后清除睡眠通道
    release(&p->lock);   // 释放进程锁
    acquire(lk);         // 重新获取条件锁
}

void wakeup(void *chan)
{
    struct proc *p;
    for (p = proc; p < &proc[NPROC]; p++)
    {
        acquire(&p->lock);
        if (p->state == SLEEPING && p->chan == chan)
        {
            p->state = RUNNABLE;
        }
        release(&p->lock);
    }
}

// 等待子进程退出
int wait(uint64 addr)
{
    struct proc *p = myproc();
    int havekids, pid;
    acquire(&wait_lock);
    for (;;)
    {
        havekids = 0;
        for (p = proc; p < &proc[NPROC]; p++)
        {
            if (p->parent == myproc())
            {
                havekids = 1;
                acquire(&p->lock);
                if (p->state == ZOMBIE)
                {
                    pid = p->pid;
                    if (addr != 0 && copyout(myproc()->pagetable, addr, (char *)&p->xstate, sizeof(p->xstate)) < 0)
                    {
                        release(&p->lock);
                        release(&wait_lock);
                        return -1;
                    }
                    freeproc(p);
                    p->state = UNUSED;
                    release(&p->lock);
                    release(&wait_lock);
                    return pid;
                }
                release(&p->lock);
            }
        }
        if (!havekids || myproc()->killed)
        {
            release(&wait_lock);
            return -1;
        }
        sleep(myproc(), &wait_lock);
    }
}

void exit(void)
{ // 一个进程退出的时候不仅需要释放资源，还要把他所有的子进程过继给 init 进程
    struct proc *p = myproc();
    if (p == initproc)
        panic("init exiting");
    // for (int fd = 0; fd < NOFILE; fd++)
    // {
    //     if (p->ofile[fd])
    //     {
    //         struct file *f = p->ofile[fd];
    //         fileclose(f);
    //         p->ofile[fd] = 0;
    //     }
    // }
    // begin_op();
    // iput(p->cwd);
    // end_op();
    // p->cwd = 0;
    acquire(&wait_lock);
    // 将子进程的父进程设置为 initproc
    for (struct proc *pp = proc; pp < &proc[NPROC]; pp++)
    {
        if (pp->parent == p)
        {
            pp->parent = initproc;
            if (pp->state == ZOMBIE)
            {
                wakeup(initproc);
            }
        }
    }
    // 通知父进程
    wakeup(p->parent);
    acquire(&p->lock);
    p->xstate = 0;     // 设置退出状态
    p->state = ZOMBIE; // 设置进程状态为僵尸
    release(&p->lock);
    release(&wait_lock);
    sched(); // 调度其他进程
    panic("zombie exit");
}

// 将 p 的子进程过继给 initproc 如果子进程是zombie 进程唤醒initproc
void reparent(struct proc *p)
{
    struct proc *pp;
    for (pp = proc; pp < &proc[NPROC]; pp++)
    {
        if (pp->parent == p)
        {
            pp->parent = initproc;
            if (pp->state == ZOMBIE)
            {
                wakeup(initproc);
            }
        }
    }
}

void scheduler(void)
{
    struct proc *p;
    struct cpu *c = mycpu();
    c->proc = 0;
    for (;;)
    {
        intr_on();
        intr_off();
        int found = 0;
        for (p = proc; p < &proc[NPROC]; p++)
        {
            acquire(&p->lock);
            if (p->state == RUNNABLE)
            {
                p->state = RUNNING;
                c->proc = p;
                swtch(&c->context, &p->context);
                // 这里会跳转到 p 进程的执行代码中
                // 对应的进程通过调用sched()函数切换回调度器
                c->proc = 0;
                found = 1;
            }
            release(&p->lock);
        }
        if (found == 0)
        {
            // 表示没有进程可以被切换
            asm volatile("wfi"); // 等待中断
        }
    }
}

void yield(void)
{
    struct proc *p = myproc();
    acquire(&p->lock);
    if (p->state != RUNNING)
        panic("yield");
    p->state = RUNNABLE;
    sched();
    release(&p->lock);
}

void forkret(void)
{
    // 子进程第一次被调度时会从这里开始。
    // 它仍然持有从 scheduler() -> swtch() -> allocproc() 继承来的锁。
    // 释放这个锁是它的第一要务。
    release(&myproc()->lock);
    // 在这个测试场景下，forkret 之后会返回到 fork_test_main 中 fork() 调用的下一行。
    // fork_test_main();
}

int kill(int pid)
{
    struct proc *p;
    for (p = proc; p < &proc[NPROC]; p++)
    {
        acquire(&p->lock);
        if (p->pid == pid)
        {
            p->killed = 1;
            if (p->state == SLEEPING)
            {
                p->state = RUNNABLE;
            }
            release(&p->lock);
            return 0;
        }
        release(&p->lock);
    }
    return -1;
}

void setkilled(struct proc *p)
{
    acquire(&p->lock);
    p->killed = 1;
    release(&p->lock);
}

int killed(struct proc *p)
{
    int k;
    acquire(&p->lock);
    k = p->killed;
    release(&p->lock);
    return k;
}

void procdump(void)
{
    // static char *states[] = {
    //     [UNUSED] "unused",
    //     [USED] "used",
    //     [SLEEPING] "sleep ",
    //     [RUNNABLE] "runble",
    //     [RUNNING] "run   ",
    //     [ZOMBIE] "zombie"};
    // struct proc *p;
    // char *state;

    // printf("\n");
    // for (p = proc; p < &proc[NPROC]; p++)
    // {
    //     if (p->state == UNUSED)
    //         continue;
    //     if (p->state >= 0 && p->state < NELEM(states) && states[p->state])
    //         state = states[p->state];
    //     else
    //         state = "???";
    //     printf("%d %s %s", p->pid, state, p->name);
    //     printf("\n");
    // }
}
// 内核态的 fork 测试主函数
void fork_test_main(void)
{
    // 注意：这个函数在内核线程上下文中运行
    // 它不能返回，必须在最后调用 exit() 或 panic()

    // 释放从 allocproc() 继承来的锁
    release(&myproc()->lock);

    printf("\n[KERNEL TEST] === fork_test_main started ===\n");

    int pid = fork();

    if (pid < 0)
    {
        panic("fork_test_main: fork failed");
    }

    if (pid == 0)
    {
        // --- 子进程执行的代码 ---
        printf("[KERNEL TEST] I am the child process! My PID is %d.\n", myproc()->pid);
        printf("[KERNEL TEST] Child is exiting.\n");
        exit();                            // 子进程在这里退出
        panic("child should have exited"); // 这行不应该被执行
    }
    else
    {
        // --- 父进程执行的代码 ---
        printf("[KERNEL TEST] I am the parent process! My PID is %d.\n", myproc()->pid);
        printf("[KERNEL TEST] I created a child with PID %d.\n", pid);

        printf("[KERNEL TEST] Parent is waiting for the child...\n");
        int exit_pid = wait(0); // 等待子进程退出

        if (exit_pid == pid)
        {
            printf("[KERNEL TEST] Parent successfully waited for child %d.\n", exit_pid);
        }
        else
        {
            printf("[KERNEL TEST] Parent wait failed! Waited for %d, expected %d\n", exit_pid, pid);
        }
    }

    printf("[KERNEL TEST] === fork_test_main finished ===\n");

    // 测试完成，让 init 进程永远休眠，等待回收孤儿进程
    // 或者直接 panic("Test finished") 来停止系统
    for (;;)
    {
        sleep(&initproc, &wait_lock);
    }
}