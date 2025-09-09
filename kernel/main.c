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

// 函数声明
/* void uartinit();
void uartputs(char *);
void uartputc(int);
void printf(char *fmt, ...);
void hexdump(void *addr, int len);
void console_clear(void);
void consputc(int); */

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

void main()
{
    // 1. 清零BSS段
    // BSS段包含未初始化的全局变量，C语言标准要求它们初始化为0
    memset(edata, 0, end - edata);

    // 2. 打印启动信息
    uartinit(); // 初始化串口
    uartputs("riscv-os kernel is starting...\n");

    uint64 hartid = r_mhartid();
    uartputs("hart ID :");
    uartputc('0' + (hartid & 0xf)); // 仅打印最低4位，假设CPU数量不超过16
    uartputs(" started\n");
    uartputs("Hart ");
    // 这里可以打印CPU ID，但需要实现数字转字符串函数
    uartputs("started\n");

    // 3. 基础系统初始化
    uartputs("Basic initialization complete\n");

    // 3. 清屏并显示启动信息
    console_clear();
    printf("RISC-V OS Kernel Starting...\n");
    printf("==============================\n");

    // 4. 显示系统信息
    // uint64 hartid = r_mhartid();
    printf("Hart ID: %d\n", (int)hartid);
    printf("Hart started successfully\n");

    // 5. 测试各种 printf 格式
    printf("Testing printf formats:\n");
    printf("Decimal: %d\n", 42);
    printf("Hex: 0x%x\n", 255);
    printf("Pointer: %p\n", (void *)main);
    printf("String: %s\n", "Hello, World!");
    printf("Character: %c\n", 'A');

    // 6. 内存dump示例
    printf("\nMemory dump example:\n");
    // char test_data[] = "Hello, RISC-V OS!";
    char *test_data = "Hello, RISC-V OS!";
    printf("test_data declared\n");
    printf("test_data address: %p\n", (void *)test_data);
    printf("sizeof(test_data): %d\n", (int)sizeof(test_data));

    // hexdump(test_data, sizeof(test_data));

    // 7. 系统状态
    printf("\nSystem Status:\n");
    printf("- UART: OK\n");
    printf("- Console: OK\n");
    printf("- Printf: OK\n");
    console_clear();

    printf("\nKernel initialization complete!\n");
    printf("Entering idle loop...\n");

    // 4. 进入无限循环
    // 在后续阶段，这里会被进程调度器替代
    uartputs("Kernel initialization finished, entering idle loop\n");

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