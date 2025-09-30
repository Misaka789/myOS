
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
    extern volatile int *test_flag;
    if (test_flag)
        (*test_flag)++;
    // acquire(&tickslock);
    ticks++;
    // release(&tickslock);
    if ((ticks % 100) == 0)
        printf("ticks=%d\n", (int)ticks);
    //}
}

void kerneltrap()
{
    uint64 sc = r_scause();
    printf("entry kernel trap, scause = %p\n", sc);
    if (sc >> 63)
    { // interrupt
        uint64 code = sc & 0xff;
        if (code == 1)
        { // S-timer
            printf("enter clockintr successfully\n");
            clockintr();
            return;
        }
    }
    printf("trap: scause=%p sepc=%p stval=%p", sc, r_sepc(), r_stval());
    panic("trap");
}