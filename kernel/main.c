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

void print_test();
void pmm_basic_test();
void assert(int condition);
void pagetable_test();
void pagetable_test_enhanced();
void virtual_memory_test();

static inline uint64 r_mip()
{
    uint64 x;
    asm volatile("csrr %0, mip" : "=r"(x));
    return x;
}

void debug_poll_timer()
{
    printf("[dbg] poll timer pending...\n");
    // uint64 start = 0;
    for (volatile uint64 i = 0; i < 5000000; i++)
    {
        uint64 mip;
        // asm volatile("csrr %0, sip" : "=r"(sip));
        mip = r_mip();
        if (mip & (1ULL << 7))
        { // STIP
            printf("[dbg] STIP observed mip=0x%lx\n", mip);
            return;
        }
    }
    printf("[dbg] NO STIP (maybe mtimecmp未写 or mideleg 未含bit5)\n");
}

void main()
{
    // 1. 清零BSS段
    // BSS段包含未初始化的全局变量，C语言标准要求它们初始化为0
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

    // 内存分配测试
    pmm_basic_test();

    // 页表测试
    pagetable_test();
    pagetable_test_enhanced();

    virtual_memory_test();

    debug_poll_timer();

    trapinit(); // 初始化陷阱处理
    trapinithart();

    w_sie(r_sie() | SIE_SSIE); // 允许 S 模式软件中断
    // w_mstatus(r_mstatus() | MSTATUS_MIE); // 开中断
    //  允许 S 级中断
    intr_on();

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

void assert(int condition)
{
    if (!condition) // 如果条件为假那么就会触发 panic 函数
    {
        panic("assert failed");
    }
}

void print_test()
{
    // printf 打印测试
    printf("Testing integer: %d\n", 42);
    printf("Testing negative: %d\n", -123);
    printf("Testing zero: %d\n", 0);
    printf("Testing hex: 0x%x\n", 0xABC);
    printf("Testing string: %s\n", "Hello");
    printf("Testing char: %c\n", 'X');
    printf("Testing percent: %%\n");
    console_clear();
    // uartputs("\033[2J\033[H"); // 清屏并将光标移动到左上角

    // ... 在合适位置（consoleinit/printf 后）临时插入：
    extern void uartputs(char *s);
    uartputs("BEFORE-CLEAR\n");
    uartputs("\033[2J\033[H"); // 直接通过 uart 发送
    uartputs("AFTER-CLEAR\n");
    // 在 console_clear 前临时加入调试（不要递归使用 console_puts）
    extern void uartputc(int c);
    uartputc(27);
    uartputc('[');
    uartputc('2');
    uartputc('J');
    uartputc(27);
    uartputc('[');
    uartputc('H');
    // 强制刷新/短延时，避免被随后的内核打印立即覆盖
    // for (volatile int i = 0; i < 2000000; i++)
    // {
    //     asm volatile("nop");
    // }

    uartputs("Console cleared!\n");
    // edge case printf
    printf("INT_MAX: %d\n", 2147483647);
    printf("INT_MIN: %d\n", -2147483648);
    printf("NULL string: %s\n", (char *)0);
    printf("Empty string: %s\n", "");

    // 6. 内存dump示例
    printf("\nMemory dump example:\n");
    // char test_data[] = "Hello, RISC-V OS!";
    char *test_data = "Hello, RISC-V OS!";
    printf("test_data declared\n");
    printf("test_data address: %p\n", (void *)test_data);
    printf("sizeof(test_data): %d\n", (int)sizeof(test_data));

    // hexdump(test_data, sizeof(test_data));
}

void pmm_basic_test()
{
    printf("PMM basic test:\n");
    void *p1 = alloc_page();
    void *p2 = alloc_page();
    void *p3 = alloc_page();
    printf("Allocated pages: %p, %p, %p\n", p1, p2, p3);
    assert((uint64)p1 % PGSIZE == 0);
    assert((uint64)p2 % PGSIZE == 0);
    assert((uint64)p3 % PGSIZE == 0);
    printf("Pages are page-aligned.\n");

    // 测试数据写入
    *(int *)p1 = 0x12345678;
    assert(*(int *)p1 == 0x12345678);
    printf("Data write/read test passed on page %p.\n", p1);

    // 测试释放和重新分配
    free_page(p2);
    printf("Freed page: %p\n", p2);
    void *p4 = alloc_page();
    printf("Allocated page: %p , %p)\n", p4, p2);
    // assert(p4 != p2); // 分配到的页面地址不一定和刚释放的相同

    free_page(p1);
    free_page(p3);
    free_page(p4);
    printf("Freed all allocated pages.\n");
}

void pagetable_test(void)
{
    pagetable_t pt = create_pagetable();

    // 测试基本映射
    uint64 va = 0x1000000;
    uint64 pa = (uint64)alloc_page();
    assert(map_page(pt, va, pa, PTE_R | PTE_W) == 0);

    // 测试地址转换
    pte_t *pte = walk_lookup(pt, va);
    assert(pte != 0 && (*pte & PTE_V));
    assert(PTE2PA(*pte) == pa);
    printf("Page table basic mapping test passed.\n");

    // 测试权限位
    assert(*pte & PTE_R);
    assert(*pte & PTE_W);
    assert(!(*pte & PTE_X));
    printf("Page table permission bits test passed.\n");
}

void virtual_memory_test()
{
    printf("Before enabling paging...\n");
    kvminit();
    kvminithart();
    printf("After enabling paging...\n");
}

void pagetable_test_enhanced(void)
{
    printf("\n[TEST] pagetable_test begin\n");
    pagetable_t pt = create_pagetable();
    assert(pt != 0);

    // 1. 根页表清零性（抽样检查几个槽位）
    for (int i = 0; i < 8; i++)
        assert(((uint64 *)pt)[i] == 0);

    // 2. 基本单页映射
    uint64 va = 0x01000000; // 16MB 对齐
    uint64 pa = (uint64)alloc_page();
    assert((va & (PGSIZE - 1)) == 0 && (pa & (PGSIZE - 1)) == 0);
    assert(map_page(pt, va, pa, PTE_R | PTE_W) == 0);

    pte_t *pte = walk_lookup(pt, va);
    assert(pte && (*pte & PTE_V));
    assert(PTE2PA(*pte) == pa);
    assert((*pte & PTE_R) && (*pte & PTE_W) && !(*pte & PTE_X));
    printf("[OK ] single mapping + flags\n");

    // 3. 重复映射应失败
    assert(map_page(pt, va, pa, PTE_R | PTE_W) != 0);
    printf("[OK ] duplicate mapping rejected\n");

    // 4. 未映射地址查询
    uint64 va2 = va + 0x2000; // 没有建立映射
    assert(walk_lookup(pt, va2) == 0);
    printf("[OK ] walk_lookup on unmapped returns NULL\n");

    // 5. 非法参数测试（未对齐）
    uint64 bad_va = va + 123;
    assert(map_page(pt, bad_va, pa, PTE_R) == -1);
    printf("[OK ] unaligned map_page rejected\n");

    // 6. 多页区间映射（mappages）
    uint64 va_range = 0x02000000;
    void *pA = alloc_page();
    void *pB = alloc_page();
    assert(pA && pB);
    assert(mappages(pt, va_range, 2 * PGSIZE, (uint64)pA, PTE_R | PTE_W) == 0);
    // 第二页物理应是 pA + PGSIZE（因为我们假设连续页；若 buddy 不保证，改成逐页 map_page）
    pte_t *pteA = walk_lookup(pt, va_range);
    pte_t *pteB = walk_lookup(pt, va_range + PGSIZE);
    assert(pteA && pteB);
    assert(PTE2PA(*pteA) == (uint64)pA);
    assert(PTE2PA(*pteB) == ((uint64)pA + PGSIZE)); // 若失败，说明物理不连续
    printf("[OK ] range mapping 2 pages\n");

    // 7. 中间页表未被多余创建：尝试查询一个远地址，walk_lookup 不应分配
    uint64 far_va = 0x4000000000ULL; // 超出 Sv39 (1<<39) → 直接 0
    assert(walk_lookup(pt, far_va) == 0);
    printf("[OK ] out-of-range VA rejected\n");

    // 可选：打印三级索引
    int l2 = PX(2, va), l1 = PX(1, va), l0 = PX(0, va);
    printf("VA 0x%p indices L2=%d L1=%d L0=%d\n", (void *)va, l2, l1, l0);

    // 释放（注意：destroy_pagetable 只应释放页表页，不释放 pA/pB/pa 指代的数据页）
    destory_pagetable(pt);
    free_page((void *)pa);
    free_page(pA);
    free_page(pB);

    printf("[TEST] pagetable_test OK\n");
}
