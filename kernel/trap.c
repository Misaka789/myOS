
// filepath: /home/misaka/projects/riscv-os/kernel/trap.c
#include "types.h"
#include "riscv.h"
#include "defs.h"

volatile uint64 ticks;
struct spinlock tickslock;

extern void timer_set_next();
extern void kernelvec();

void trapinit()
{
    initlock(&tickslock, "ticks");
}
void trapinithart()
{
    w_stvec((uint64)kernelvec);
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
    uint64 sc = r_scause();
    if (sc >> 63) // 最高位为1 说明了是中断
    {             // interrupt
        uint64 code = sc & 0xff;
        switch (code)
        {       // S-timer
        case 1: // 时钟中断
            printf("enter clockintr successfully\n");
            clockintr();
            return;
        case 2: //
        }
    }
    else
    { // 这里处理异常
        uint64 code = sc & 0xfff;
        switch (code)
        {
        case 2:
            printf("illegal instruction at sepc=%p, stval=%p\n", r_sepc(), r_stval());
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
            panic("page fault");
            break;
        }
        default:
            break;
        }
    }
    // printf("trap: scause=%p sepc=%p stval=%p", sc, r_sepc(), r_stval());
    // panic("trap");
}