// 内核主初始化函数
// 负责初始化各个子系统

#include "types.h"
#include "param.h"
#include "memlayout.h"
#include "riscv.h"
#include "stdarg.h"
#include "defs.h" // 包含统一声明
                  // 外部符号，由链接器提供
extern char edata[], end[];

// 简单的内存清零函数
void *memset(void *dst, int c, uint n)
{
    char *cdst = (char *)dst;
    int i;
    for (i = 0; i < n; i++)
    {
        cdst[i] = c;
    }
    return dst;
}

static inline uint64 r_mip()
{
    uint64 x;
    asm volatile("csrr %0, mip" : "=r"(x));
    return x;
}

void main()
{
    // 1. 清零BSS段
    // BSS段包含未初始化的全局变量，C语言标准要求它们初始化为0
    printf("stvec = %p\n", r_stvec());
    memset(edata, 0, end - edata);

    // 2. 打印启动信息
    uartinit(); // 初始化串口
                //  uint64 hartid = r_mhartid();

    printf("Hello, welcome to RISC-V OS!\n");
    printf("Kernel loaded at %p, BSS from %p to %p\n",
           main, edata, end);

    // printf 相关函数测试
    print_test();

    // buddy 测试
    printf("buddy test:\n");
    printf("end - %p \n", end);
    pmm_init();
    printf("stvec = %p\n", r_stvec());
    // 内存分配测试
    pmm_basic_test();

    // 页表测试
    pagetable_test();
    pagetable_test_enhanced();

    virtual_memory_test();

    // debug_poll_timer();

    trapinit(); // 初始化陷阱处理
    trapinithart();

    w_sie(r_sie() | SIE_SSIE); // 允许 S 模式软件中断

    printf("stvec = %p\n", r_stvec());

    printf("before intr_on sstatus = %p\n", r_sstatus());
    intr_on(); // 允许 SIE 中断
    printf("after intr_on sstatus = %p\n", r_sstatus());

    clockintr_test();

    // uint64 sip = r_sip();
    // printf("sip=%p\n", sip);
    // uint64 mip = r_mip();
    // printf("mip=%p\n", mip);

    for (;;)
    {
        // 暂时什么都不做，等待中断
        asm volatile("wfi"); // Wait For Interrupt
    }
}
/*
系统服务初始化：启动操作系统的各个子系统（内存管理、进程管理、文件系统等）
数据结构初始化：初始化内核的全局数据结构（进程表、文件表、内存分配器等）
第一个进程创建：创建系统的第一个用户进程（通常是init进程）
系统状态转换：从启动状态转换到正常运行状态
*/
