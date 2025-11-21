
// filepath: /home/misaka/projects/riscv-os/kernel/trap.c
#include "types.h"
#include "riscv.h"
#include "defs.h"
#include "memlayout.h"

volatile uint64 ticks;
struct spinlock tickslock;
#ifndef interrupt_handler_t
typedef void (*interrupt_handler_t)(void);
#endif
#ifndef MAX_IRQS
#define MAX_IRQS 1024
#endif
static interrupt_handler_t interrupt_handlers[MAX_IRQS];
struct spinlock irq_lock;

extern void
timer_set_next();
extern void kernelvec();
extern char trampoline[], uservec[];

void trapinit()
{
    initlock(&tickslock, "irq_lock");
    acquire(&irq_lock);
    for (int i = 0; i < MAX_IRQS; i++)
    {
        interrupt_handlers[i] = 0; // 初始化所有中断处理函数指针为 NULL
    }
    release(&irq_lock);
    // 初始化 PLIC 硬件
    plicinit();
    printf("Interrupt system initialized.\n");
}
void trapinithart()
{
    plicinithart();
    w_stvec((uint64)kernelvec);
}

void register_interrupt(int irq, interrupt_handler_t handler)
{
    if (irq < 0 || irq >= MAX_IRQS || handler == 0)
    {
        panic("register_interrupt: invalid irq or handler");
    }
    acquire(&irq_lock);
    if (interrupt_handlers[irq] != 0)
    {
        panic("register_interrupt: handler already registered");
    }
    interrupt_handlers[irq] = handler;
    release(&irq_lock);
}

// 外部中断使能
void enable_interrupt(int irq)
{
    if (irq <= 0 || irq >= MAX_IRQS)
    {
        panic("enable_interrupt: invalid irq");
    }
    plic_enable(irq);
}

void disable_interrupt(int irq)
{
    if (irq <= 0 || irq >= MAX_IRQS)
    {
        panic("disable_interrupt: invalid irq");
    }
    plic_disable(irq);
}

static void clockintr() // 定时器中断
{

    // timer_set_next(); // 重新设置下一个时钟中断 这里是 S 态 没有办法设置 time 的值

    // 关键：在 S 模式处理完后，必须清除软件中断挂起位
    w_sip(r_sip() & ~(1 << 1));

    extern volatile int test_flag; // 用于测试中断处理函数是否被调用
    test_flag++;
    // printf("tick    \n");
    //  只让 hart0 维护全局 ticks
    //  if (r_mhartid() == 0)
    //{
    //  acquire(&tickslock);
    ticks++;
    // release(&tickslock);
    if ((ticks % 100) == 0)
        printf("ticks=%d\n", (int)ticks);
    //}
}

void kerneltrap()
{
    // panic("[kerneltrap]: total panic e and i \n");
    uint64 sc = r_scause();
    if (sc >> 63) // 最高位为1 说明了是中断
    {             // interrupt
        // panic("[kerneltrap]: interrupt panic \n");
        printf("[kerneltrap]: enter interrupt handler \n");
        printf("[kerneltrap]: scause=0x%p sepc=0x%p stval=0x%p\n", sc, r_sepc(), r_stval());
        printf("[kerneltrap]: sstatus=0x%p sip=0x%p sie=0x%p\n", r_sstatus(), r_sip(), r_sie());

        uint64 code = sc & 0xff;
        switch (code)
        {       // S-timer
        case 1: // 时钟中断
            printf("enter clockintr successfully\n");
            clockintr();
            return;
        case 9:                     // 外部设备中断
            int irq = plic_claim(); // 从 PLIC 获取中断号
            if (irq < 0 || irq >= MAX_IRQS)
            {
                printf("[kerneltrap]: kerneltrap: invalid irq %d\n", irq);
                panic("[kerneltrap]");
                break;
            }
            printf("kerneltrap: irq %d\n", irq);
            if (interrupt_handlers[irq])
            {
                interrupt_handlers[irq](); // 调用注册的中断处理函数
            }
            else
            {
                printf("No handler for irq %d\n", irq);
            }
            plic_complete(irq); // 向 PLIC 汇报中断处理完成
            return;
        default:
            printf("kerneltrap: unexpected scause %p\n", sc);
            printf("            sepc=%p stval=%p\n", r_sepc(), r_stval());
            panic("kerneltrap");
            break;
        }
    }
    else
    { // 这里处理异常
      // panic("[kerneltrap]: exception panic \n");
      // printf("[kerneltrap]: enter exception handler \n");
        printf("illegal instruction at sepc=%p, stval=%p\n", r_sepc(), r_stval());

        uint64 code = sc & 0xfff;
        switch (code)
        {
        case 2:
            panic("illegal instruction");
            break;
        case 5:  // load page fault
        case 7:  // store page fault
        case 13: // instruction page fault
        {
            uint64 stval = r_stval();
            printf("page fault at %p, sepc=%p, stval=%p\n", stval, r_sepc(), stval);
            // 这里可以尝试处理缺页异常，比如加载页面等
            // 但目前我们直接 panic
            panic("[kerneltrap]: page fault");
            break;
        }
        default:
            printf("[kerneltrap]: exception id = %d", code);
            panic("[kerneltrap]: unknow trap \n");
            break;
        }
    }
    // printf("trap: scause=%p sepc=%p stval=%p", sc, r_sepc(), r_stval());
    // panic("trap");
}

uint64 usertrap(void)
{
    // printf("[usertrap]: scause=0x%p sepc=0x%p stval=0x%p pid=%d\n",
    //        r_scause(), r_sepc(), r_stval(), myproc() ? myproc()->pid : -1);

    int which_dev = 0;
    if ((r_sstatus() & SSTATUS_SPP) != 0)
        panic("usertrap : not frome user mode");
    w_stvec((uint64)kernelvec);
    struct proc *p = myproc();
    p->trapframe->epc = r_sepc();
    if (r_scause() == 8)
    {
        // 说明是系统调用
        if (p->killed)
            exit(-1);
        p->trapframe->epc += 4;
        intr_on();
        syscall();
    }
    else if ((r_scause() == 15 || r_scause() == 13) &&
             vmfault(p->pagetable, r_stval(), (r_scause() == 13) ? 1 : 0) != 0)
    {
        // page fault on lazily-allocated page
    }
    else
    {
        printf("usertrap(): unexpected scause 0x%p pid=%d\n", r_scause(), p->pid);
        printf("            sepc=0x%p stval=0x%p\n", r_sepc(), r_stval());
        setkilled(p);
    }

    if (killed(p))
        exit(-1);

    // give up the CPU if this is a timer interrupt.
    if (which_dev == 2)
        yield();

    prepare_return();

    // the user page table to switch to, for trampoline.S
    uint64 satp = MAKE_SATP(p->pagetable);

    // return to trampoline.S; satp value in a0.
    return satp;
}

// 从内核态返回用户态的准备工作
void prepare_return(void)
{
    struct proc *p = myproc();

    // printf("[prepare_return]: returning to user, sepc=%p, satp=%p\n",
    //      p->trapframe->epc, MAKE_SATP(p->pagetable));

    // we're about to switch the destination of traps from
    // kerneltrap() to usertrap(). because a trap from kernel
    // code to usertrap would be a disaster, turn off interrupts.
    intr_off();

    // send syscalls, interrupts, and exceptions to uservec in trampoline.S

    uint64 trampoline_uservec = TRAMPOLINE + (uservec - trampoline);
    // 设置陷阱向量为 uservec ，从这里开始陷阱进入 uservec 来处理
    w_stvec(trampoline_uservec);

    // 在 当前进程的 trapframe 中保存必要的信息，方便下次陷入时候使用
    p->trapframe->kernel_satp = r_satp();         // 内核太页表
    p->trapframe->kernel_sp = p->kstack + PGSIZE; // 进程的栈空间
    p->trapframe->kernel_trap = (uint64)usertrap;
    p->trapframe->kernel_hartid = r_tp(); // hartid for cpuid()

    // set up the registers that trampoline.S's sret will use
    // to get to user space.

    // set S Previous Privilege mode to User.
    unsigned long x = r_sstatus();
    x &= ~SSTATUS_SPP; // clear SPP to 0 for user mode
    x |= SSTATUS_SPIE; // enable interrupts in user mode
    w_sstatus(x);

    // set S Exception Program Counter to the saved user pc.
    w_sepc(p->trapframe->epc);
}
