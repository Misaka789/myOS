// 内核主初始化函数
// 负责初始化各个子系统

#include "types.h"
#include "param.h"
#include "memlayout.h"
#include "riscv.h"
#include "stdarg.h"
#include "file.h"
#include "defs.h" // 包含统一声明
                  // 外部符号，由链接器提供
// 解决编辑器爆红
#ifndef SIE_SSIE
#define SIE_SSIE (1L << 1)
#endif

#define UART0_IRQ 10
#define VIRTIO0_IRQ 1

extern char edata[], end[];

// // 简单的内存清零函数
// void *memset(void *dst, int c, uint n)
// {
//     char *cdst = (char *)dst;
//     int i;
//     for (i = 0; i < n; i++)
//     {
//         cdst[i] = c;
//     }
//     return dst;
// }

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

    kvminit();
    kvminithart(); // 切换到内核页表

    // debug_poll_timer();

    trapinit(); // 初始化陷阱处理
    trapinithart();

    w_sie(r_sie() | SIE_SSIE); // 允许 S 模式软件中断

    printf("stvec = %p\n", r_stvec());

    printf("before intr_on sstatus = %p\n", r_sstatus());
    // intr_on(); // 允许 SIE 中断
    printf("after intr_on sstatus = %p\n", r_sstatus());

    // clockintr_test();
    procinit();
    // userinit(); // 创建第一个用户进程

    // 打印进程状态
    // procdump();
    // printf("hello world");
    // main_proc_init();
    procdump();
    // test_process_creation();
    // test_scheduler();

    binit();
    iinit();
    fileinit();

    consoleinit();
    // === 再次检查 ===
    printf("[main DEBUG] after fileinit: devsw[1].write = %p\n", devsw[1].write);
    // ==================

    // 注册中断，开启对应的中断
    register_interrupt(VIRTIO0_IRQ, virtio_disk_intr);
    plic_enable(VIRTIO0_IRQ);

    printf("[main]: sstatus(before intr_on)=0x%p\n", r_sstatus());
    intr_on();
    printf("[main]: sstatus(after intr_on)=0x%p\n", r_sstatus());
    virtio_disk_init();

    userinit(); // 创建第一个用户进程
    __sync_synchronize();

    // printf("see you again");
    scheduler(); // 让主 CPU 核心进入调度器，永不返回
    // process_creation_test();

    // for (;;)
    // {
    //     // 暂时什么都不做，等待中断
    //     asm volatile("wfi"); // Wait For Interrupt
    // }
}
