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
extern void kernelvec();
extern void timervec(); // M 模式定时器入口

void start()
{
    // 1. 设置 S M 模式的异常向量
    // w_stvec((uint64)kernelvec);
    w_mtvec((uint64)timervec);
    w_stvec((uint64)kernelvec); // 设置 S 模式的异常向量

    // 设置mstatus.MPP 为 S 模式， 为 mret 切换为 S 模式做准备
    uint64 x = r_mstatus();
    x &= ~MSTATUS_MPP_MASK; // 清除 machine previous privilege 位
    x |= MSTATUS_MPP_S;     // 设置mret 之后的特权级为 S 级
    x |= (1 << 13);         // 设置允许使用浮点指令集
    x |= MSTATUS_MPIE;      // 设置 MPIE 位，让 mret 之后中断可用
                            // x |= MSTATUS_MIE; // 开中断
    w_mstatus(x);

    // 3. 委托：把常见异常与中断交给 S (简化：全委托)
    w_medeleg(0xffff);
    w_mideleg(0xffff & ~(1 << 7)); // 7号中断不委托 (机器模式定时器中断)

    // 5. 开启 M 定时器中断 (mtie)
    w_mie(r_mie() | MIE_MTIE);
    // w_mstatus(r_mstatus() | MSTATUS_MIE); // 开中断

    // 6. 首次设置定时器
    extern void timer_set_next();
    timer_set_next();

    // 允许 S 模式访问时间
    // 允许 S-mode 和 U-mode 访问 time, cycle, instret 计数器
    //
    uint64 val = (1 << 0) | (1 << 1) | (1 << 2); // val = 7
    w_mcounteren(val);

    // 7. 设置 mret 返回地址
    // w_mepc((uint64)main);

    // 8. PMP 全内存访问
    asm volatile("csrw pmpaddr0, %0" : : "r"(0x3fffffffffffffull));
    asm volatile("csrw pmpcfg0, %0" : : "r"(0xf));

    // w_mcounteren(r_mcounteren() | (1L << 2)); // 允许 S 模式 rdtime

    // 暂时禁用分页
    // w_satp(0);
    // asm volatile("sfence.vma");

    // 7. 获取当前CPU的ID
    int id = r_mhartid();
    w_tp(id); // 将 CPU ID 写入 tp 寄存器

    // 8. 只有CPU 0负责主要的初始化工作
    //    其他CPU等待CPU 0完成初始化后再启动
    if (id == 0)
    {
        w_mepc((uint64)main);
        // main(); // 跳转到内核主初始化函数
    }
    else
    {
        // 其他CPU暂时无限循环等待
        // 后面会实现多核启动机制
        for (;;)
            ;
        // w_mepc((uint64)second_main);
    }
    // 9. mret 进入 S 模式 在这之前的都是 M 模式工作的
    asm volatile("mret");
}
/*
特权模式管理：RISC-V有三个特权模式（机器模式M、监管者模式S、用户模式U），start.c负责从最高的机器模式切换到监管者模式
中断系统初始化：设置中断向量表，配置哪些中断可以被处理
多核协调：决定哪个CPU核心负责主初始化，其他核心等待
硬件抽象准备：为后续的操作系统功能提供底层硬件访问能力
*/