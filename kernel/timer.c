#include "types.h"
#include "memlayout.h"
#include "riscv.h"
#include "defs.h"

// 约 100Hz；可调整
#define TIMER_INTERVAL 1000000ULL
// extern CLINT; // 0x2000000
#ifndef CLINT
#define CLINT 0x02000000L // 核心本地中断器

#endif

// 使用 CLINT mtime/mtimecmp （QEMU virt 默认）
// mtime      @ (CLINT + 0xBFF8)
// mtimecmp[h]@ (CLINT + 0x4000 + 8*hart)

// 使用 sbi  调用来获取当前时间
uint64 get_time()
{
    // return *(volatile uint64 *)(CLINT + 0xBFF8);
    // mtime 是一个 64 位的内存映射寄存器，地址为 CLINT + 0xbff8
    return *(volatile uint64 *)(CLINT + 0xbff8);
}

void set_timer(uint64 when)
{
    // mtimecmp 是一个 64 位的内存映射寄存器，每个核心都有一个。
    // 地址为 CLINT + 0x4000 + 8 * hartid
    *(volatile uint64 *)(CLINT + 0x4000 + 8 * r_mhartid()) = when;
}

void timer_set_next()
{
    // 计算下一次中断的时间点 = 当前时间 + 时间间隔
    uint64 next_interrupt_time = get_time() + TIMER_INTERVAL;

    // 将计算出的时间点写入 mtimecmp 寄存器
    set_timer(next_interrupt_time);
}

// 只在 M->S 跳转前 (start.c) 或 S 模式早期调用一次
void timer_init_once()
{
    // 允许 S 定时器中断
    // w_mideleg(w_mideleg(0), w_mideleg(0)); // (占位行, 可删除)
    // 直接设置第一次
    timer_set_next();
}
