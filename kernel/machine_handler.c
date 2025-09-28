#include "riscv.h"
#include "defs.h"

// M 模式定时器中断处理函数
void machine_timer_handler()
{
    // timer_set_next(); // 设置下一个定时器中断
    // 向 S 模式发送一个软件中断 (置位 sip.SSIP)
    // S 模式的 trap 将会捕获这个 scause=1 的中断
    w_sip(r_sip() | (1 << 1)); // 设置 Supervisor Software Interrupt Pending
}