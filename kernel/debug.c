#include "riscv.h"
#include "defs.h"
#include "types.h"
#include "param.h"
#include "proc.h"

void print_scause()
{
    uint64 scause = r_scause();
    printf("scause=%p\n", scause);
}

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
    // kvminit();
    // kvminithart();
    printf("After enabling paging...\n");
}

// (或者你放置测试代码的文件)

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
    uint64 pa = (uint64)kalloc();
    assert(pa != 0);
    assert((va & (PGSIZE - 1)) == 0 && (pa & (PGSIZE - 1)) == 0);

    // 建立映射
    assert(map_page(pt, va, pa, PTE_R | PTE_W) == 0);

    pte_t *pte = walk_lookup(pt, va);
    assert(pte && (*pte & PTE_V));
    assert(PTE2PA(*pte) == pa);
    assert((*pte & PTE_R) && (*pte & PTE_W) && !(*pte & PTE_X));
    printf("[OK ] single mapping + flags\n");

    // 3. 重复映射应失败
    assert(map_page(pt, va, pa, PTE_R | PTE_W) != 0);
    printf("[OK ] duplicate mapping rejected\n");

    // 解除映射，但不释放物理页 (do_free=0)，因为我们后面还要用 pa
    uvmunmap(pt, va, 1, 0);

    // 4. 未映射地址查询
    uint64 va2 = va + 0x2000; // 没有建立映射
    assert(walk_lookup(pt, va2) == 0);
    printf("[OK ] walk_lookup on unmapped returns NULL\n");

    // 5. 非法参数测试（未对齐）
    uint64 bad_va = va + 123;
    assert(map_page(pt, bad_va, pa, PTE_R) == -1);
    printf("[OK ] unaligned map_page rejected\n");

    // 6. 多页区间映射（mappages）
    // 注意：mappages 假设物理地址连续。
    // 为了安全测试，我们只映射 1 个页面，或者手动确保物理地址连续（这很难）。
    // 这里改为只测试 1 个页面的 mappages，验证其基本功能。
    uint64 va_range = 0x02000000;
    void *pA = alloc_page();
    assert(pA != 0);

    // 只映射 1 页，避免越界访问未知的物理页
    assert(mappages(pt, va_range, PGSIZE, (uint64)pA, PTE_R | PTE_W) == 0);

    pte_t *pteA = walk_lookup(pt, va_range);
    // assert(pteA); // 因为只映射 1 页，pteA 应该等于 pte
    assert(PTE2PA(*pteA) == (uint64)pA);
    printf("[OK ] range mapping 1 page (safe)\n");

    // 还原映射，并释放物理页 pA (do_free=1)
    uvmunmap(pt, va_range, 1, 1);

    // 7. 中间页表未被多余创建：尝试查询一个远地址，walk_lookup 不应分配
    uint64 far_va = 0x4000000000ULL; // 超出 Sv39 (1<<39)
    assert(walk_lookup(pt, far_va) == 0);
    printf("[OK ] out-of-range VA rejected\n");

    // 可选：打印三级索引
    int l2 = PX(2, va), l1 = PX(1, va), l0 = PX(0, va);
    printf("VA 0x%p indices L2=%d L1=%d L0=%d\n", (void *)va, l2, l1, l0);

    // 8. 清理资源
    // 此时 pt 中应该没有有效的映射了（除了中间页表页）
    // 之前分配的 pa 还没有释放，因为步骤 3 中 do_free=0
    kfree((void *)pa);

    // 销毁页表（释放所有页表页）
    destory_pagetable(pt);

    printf("[TEST] pagetable_test OK\n");
}

//  void pagetable_test_enhanced(void)
// {
//     printf("\n[TEST] pagetable_test begin\n");
//     pagetable_t pt = create_pagetable();
//     assert(pt != 0);

//     // 1. 根页表清零性（抽样检查几个槽位）
//     for (int i = 0; i < 8; i++)
//         assert(((uint64 *)pt)[i] == 0);

//     // 2. 基本单页映射
//     uint64 va = 0x01000000; // 16MB 对齐
//     uint64 pa = (uint64)kalloc();
//     assert((va & (PGSIZE - 1)) == 0 && (pa & (PGSIZE - 1)) == 0);
//     assert(map_page(pt, va, pa, PTE_R | PTE_W) == 0);

//     pte_t *pte = walk_lookup(pt, va);
//     assert(pte && (*pte & PTE_V));
//     assert(PTE2PA(*pte) == pa);
//     assert((*pte & PTE_R) && (*pte & PTE_W) && !(*pte & PTE_X));
//     printf("[OK ] single mapping + flags\n");

//     // 3. 重复映射应失败
//     assert(map_page(pt, va, pa, PTE_R | PTE_W) != 0);
//     printf("[OK ] duplicate mapping rejected\n");
//     uvmunmap(pt, va, 1, 0); // 先解除映射，准备后续测试

//     // 4. 未映射地址查询
//     uint64 va2 = va + 0x2000; // 没有建立映射
//     assert(walk_lookup(pt, va2) == 0);
//     printf("[OK ] walk_lookup on unmapped returns NULL\n");

//     // 5. 非法参数测试（未对齐）
//     uint64 bad_va = va + 123;
//     assert(map_page(pt, bad_va, pa, PTE_R) == -1);
//     printf("[OK ] unaligned map_page rejected\n");

//     // 6. 多页区间映射（mappages）
//     uint64 va_range = 0x02000000;
//     void *pA = alloc_page();
//     void *pB = alloc_page();
//     assert(pA && pB);
//     assert(mappages(pt, va_range, 2 * PGSIZE, (uint64)pA, PTE_R | PTE_W) == 0);
//     // 第二页物理应是 pA + PGSIZE（因为我们假设连续页；若 buddy 不保证，改成逐页 map_page）
//     pte_t *pteA = walk_lookup(pt, va_range);
//     pte_t *pteB = walk_lookup(pt, va_range + PGSIZE);
//     assert(pteA && pteB);
//     assert(PTE2PA(*pteA) == (uint64)pA);
//     assert(PTE2PA(*pteB) == ((uint64)pA + PGSIZE)); // 若失败，说明物理不连续
//     printf("[OK ] range mapping 2 pages\n");
//     // 还原映射 方便后续页表销毁
//     uvmunmap(pt, va_range, 2, 1);

//     // 7. 中间页表未被多余创建：尝试查询一个远地址，walk_lookup 不应分配
//     uint64 far_va = 0x4000000000ULL; // 超出 Sv39 (1<<39) → 直接 0
//     assert(walk_lookup(pt, far_va) == 0);
//     printf("[OK ] out-of-range VA rejected\n");

//     // 可选：打印三级索引
//     int l2 = PX(2, va), l1 = PX(1, va), l0 = PX(0, va);
//     printf("VA 0x%p indices L2=%d L1=%d L0=%d\n", (void *)va, l2, l1, l0);

//     // 释放（注意：destroy_pagetable 只应释放页表页，不释放 pA/pB/pa 指代的数据页）
//     destory_pagetable(pt);
//     // free_page(pA);
//     printf("[TEST] pagetable_test OK\n");
// }

volatile int test_flag = 0; // 用于测试中断处理函数是否被调用

void clockintr_test()
{
    printf("[Test] clockintr_test begin\n");
    intr_on(); // 确保中断已开启
    uint64 start = r_time();
    int interrupt_count = 0;
    test_flag = interrupt_count;
    while (test_flag < 5)
    {
        // printf("Waiting for timer interrupts... count=%d\n", test_flag);
        for (volatile int i = 0; i < 10000000; i++)
            asm volatile("nop");
    }
    uint64 end = r_time();
    printf("[Test] clockintr_test end, interrupts=%d, time elapsed=%d ticks\n", test_flag, end - start);
    test_flag = 0;
}

void simple_task(void)
{
    printf("[simple_task]: simple_task started in pid %d\n", myproc()->pid);
    struct proc *p = myproc();
    release(&p->lock);

    // A kernel thread cannot simply return. It must properly exit.
    acquire(&p->lock);
    printf("[simple_task]: pid %d: simple_task running and exiting.\n", p->pid);
    p->state = ZOMBIE;

    // Wake up the parent who might be in wait_process().
    // The real exit() syscall does this.
    if (p->parent)
    {
        // acquire(&p->parent->lock); 这里不应该获取锁
        printf("[simple_task]: pid %d: waking up parent pid %d\n", p->pid, p->parent->pid);
        wakeup(p->parent);
        // release(&p->parent->lock);
    }

    // The scheduler will never choose this process again.
    // It waits to be freed by the parent.
    // We must not release the lock before calling sched().
    sched();

    // sched() should not return.
    panic("zombie exit");
}

// The main test function, as per your image.
void test_process_creation(void)
{
    printf("[test_process_creation]: enter function\n");

    // Test 1: Basic process creation
    printf("[test_process_creation]: Testing basic creation...\n");
    int pid = create_process(simple_task);
    printf("[test_process_creation]: pid = %d \n", pid);
    if (pid <= 0)
        panic("test_process_creation: basic create failed");
    printf("[test_process_creation]: Basic creation OK.\n");

    // Test 2: Process table limit
    printf("[test_process_creation]: Testing process table limit...\n");
    // int pids[NPROC]s;
    int count = 1;
    for (int i = 1; i < NPROC - 1; i++)
    {
        pid = create_process(simple_task);
        if (pid > 0)
        {
            // pids[count++] = pid;
            count++;
        }
        else
        {
            // This is expected when the process table is full.

            break;
        }
    }
    printf("[test_process_creation]: created %d processes \n", count);

    // procdump();
    //  We should have filled up the table, minus the 'main' proc and the first test proc.
    //  Test 3: Cleanup test processes
    //  Wait for the first basic process
    //  wait_process();
    //  Wait for the processes from the limit test
    // printf("[rest_process_creation]:  current process, pid = %d \n", myproc()->pid);

    // for (int i = 1; i < count; i++)
    // {
    //     printf("[test_process_creation]:  enter wait loop \n");
    //     wait_process();
    // }
    // procdump();
    // printf("[test_process_creation]: Cleanup OK.\n");

    // printf("[test_process_creation]: Process creation test finished successfully.\n\n");
    // 因为这里还么有参与调度，所以暂时没有办法释放
}

void cpu_intensive_task(void)
{
    struct proc *p = myproc();
    printf("[cpu_intensive_task]: pid = %d, enter function \n", p->pid);
    for (volatile int i = 0; i < 5; i++)
        ;
    printf("[cpu_intensive_task]: pid = %d, exiting function \n", p->pid);
    wakeup(p->parent);
    p->state = ZOMBIE;
    sched();
    // exit(0);
}

void test_scheduler(void)
{
    printf("[test_scheduler]: Testing scheduler...\n");
    for (int i = 0; i < 3; i++)
    {
        create_process(cpu_intensive_task);
    }
    uint64 start_time = get_time();
    // sleep(myproc(), 1000);
    uint64 end_time = get_time();
    printf("[test_scheduler]: Scheduler test completed in %d cycles \n", end_time - start_time);
}

// The entry point for all kernel tests.
void kernel_test_main(void)
{
    printf("\n======= KERNEL UNIT TESTS START =======\n\n");

    test_process_creation();

    // You can add more test functions here in the future.
    // test_another_feature();

    printf("======= KERNEL UNIT TESTS END =======\n\n");
}

// void test_filesystem_integrity(void)
// {
//     printf("[test_filesystem_integrity]: Testing filesystem integrity...\n");
//     // Implement filesystem integrity checks here.
//     int fd = open("testfile.txt", 0);
//     if (fd < 0)
//     {
//         printf("[test_filesystem_integrity]: Failed to open testfile.txt\n");
//     }
//     else
//     {
//         printf("[test_filesystem_integrity]: Successfully opened testfile.txt\n");
//         close(fd);
//     }
//     printf("[test_filesystem_integrity]: Filesystem integrity test completed.\n");
// }

// void process_creation_test(void)
// {
//     printf("[Test] process_creation_test begin\n");
//     int pid = fork();
//     assert(pid > 0);
//     int pids[NPROC];
//     for (int i = 0; i < NPROC; i++)
//     {
//         pids[i] = fork();
//         assert(pids[i] > 0);
//     }
//     for (int i = 0; i < NPROC; i++)
//     {
//         wait(0);
//     }
//     printf("[Test] process_creation_test end\n");
// }
