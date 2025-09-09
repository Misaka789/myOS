// 机器模式初始化
// 设置机器模式的中断和异常处理，然后切换到监管者模式

#include "types.h"
#include "param.h"
#include "memlayout.h"
#include "riscv.h"

// 每个CPU的启动栈，在entry.S中使用
__attribute__((aligned(16))) char stack0[4096 * NCPU];

// 外部函数声明
extern void main();

// 定时器初始化函数
void timerinit();

// 机器模式异常处理向量（暂时为空）
void kernelvec()
{
    // 这里暂时什么都不做
    // 在后面的阶段会实现完整的异常处理
}

void start()
{
    // 1. 设置机器模式异常处理向量
    // 当发生异常或中断时，CPU会跳转到这个地址
    w_mtvec((uint64)kernelvec);

    // 2. 设置前一个特权模式为监管者模式(Supervisor mode)
    // 这样当我们使用 mret 指令时，会切换到监管者模式
    unsigned long x = r_mstatus();
    x &= ~MSTATUS_MPP_MASK; // 清除MPP字段
    x |= MSTATUS_MPP_S;     // 设置为监管者模式
    w_mstatus(x);

    // 3. 设置监管者模式的异常处理向量
    // （这里暂时还是用同一个向量，后面会分离）
    // w_stvec((uint64)kernelvec);

    // 3. 设置返回地址（重要！）
    w_mepc((uint64)main); // 设置 mret 的跳转目标

    // 4. 启用机器模式定时器中断
    // 这是为了实现进程调度
    w_mie(r_mie() | MIE_MTIE);

    // 5. 配置物理内存保护（PMP），允许监管者模式访问所有内存
    // 这里我们简化处理，允许访问所有地址
    asm volatile("csrw pmpaddr0, %0" : : "r"(0x3fffffffffffffull));
    asm volatile("csrw pmpcfg0, %0" : : "r"(0xf));

    // 6. 初始化定时器
    timerinit();

    // 7. 获取当前CPU的ID
    int id = r_mhartid();

    // 8. 只有CPU 0负责主要的初始化工作
    //    其他CPU等待CPU 0完成初始化后再启动
    if (id == 0)
    {
        main(); // 跳转到内核主初始化函数
    }
    else
    {
        // 其他CPU暂时无限循环等待
        // 后面会实现多核启动机制
        for (;;)
            ;
    }
}

// 定时器初始化 - 设置下一次定时器中断
void timerinit()
{
    // 每个CPU都需要设置自己的定时器
    int id = r_mhartid();

    // 设置时间间隔，大约100Hz (每秒100次中断)
    int interval = 1000000; // 时钟周期数

    // 读取当前时间并设置下一次中断时间
    // CLINT (Core Local Interrupt Controller) 地址布局：
    // - 0x2000000 + 0xbff8: 当前时间寄存器
    // - 0x2000000 + 0x4000 + 8*hartid: 各CPU的时间比较寄存器
    *(uint64 *)(CLINT + 0x4000 + 8 * id) =
        *(uint64 *)(CLINT + 0xbff8) + interval;
}
/*
特权模式管理：RISC-V有三个特权模式（机器模式M、监管者模式S、用户模式U），start.c负责从最高的机器模式切换到监管者模式
中断系统初始化：设置中断向量表，配置哪些中断可以被处理
多核协调：决定哪个CPU核心负责主初始化，其他核心等待
硬件抽象准备：为后续的操作系统功能提供底层硬件访问能力
*/