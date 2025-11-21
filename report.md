## 实验三 ：页表与内存管理

### 系统设计部分

#### 架构 设计说明

​	在 xv6 的页表设计中，虚拟地址位 39 位，并且分为四个部分，使用三节页表来进行管理，其中每一级页表都是占 9 位，最低的 offset 占 12 位，在 xv6 中一页的大小为 4 kb 也就是$2^{12}$ ，所以页内偏移是 12 位，在xv6 中一个页表项大小为 8 字节，所以一个页面可以存放的页表项数目为 $(4 \times 2 ^{10}) \div 64 = 512 = 2 ^{9}$  ，所以每一个级页表使用 9 位可以刚好使用一个物理页来存储页表项

​	在xv6 中，物理页面分配使用的是空闲分区链的形式，按照物理页为单位，用一个链表来串起来，每一个空闲页面的起始位置 存储的是指向下一个空闲页的指针，每次分配或者回收页面的时候就会操作dump 哑结点的头指针

​	这样的缺点是每次只能回收和分配一个物理页，效率低，而且容易产生内存碎片，我采用的改进方法是使用 buddy 伙伴算方法，具体来说就是对物理内存按照二的幂进行分块，然后每次使用的时候分配最小能容纳当前需要大小的块

#### 关键数据结构

```c

// 空闲块链表节点
struct free_block
{
    struct free_block *next;
    struct free_block *prev;
}; 

// 伙伴系统管理结构
struct buddy_system // 这个结构体存储在.bss 段中，永远都不会被释放
{
    struct free_block free_lists[MAX_ORDER + 1]; // 每个order的空闲链表
    // unsigned long *bitmap;                       // 位图，标记块的分配状态 有 pages 就不需要 bitmap 了
    unsigned long total_pages; // 总页数
    unsigned long free_pages;  // 空闲页数
    void *memory_start;        // 内存起始地址
    struct spinlock lock;      // 保护整个伙伴系统
};

// 页面元数据
struct page_info // 页面信息结构体声明 这里没有实例化，后面使用的是指针
{
    unsigned int order; // 该页面所属块的大小（2^order页）
    unsigned int flags; // 页面标志
#define PAGE_FREE 0x01  // 页面空闲
#define PAGE_HEAD 0x02  // 块的首页面
    // #define PAGE_BUDDY 0x04 // 是否可以与伙伴页面合并
};

```

#### 与 xv6 对比分析

​	与xv6仅能管理单个、不连续物理页的简单链式分配器不同，伙伴系统的核心优势体现在其高效处理**连续物理内存**的能力上。它通过按需分裂大内存块来满足不同大小的连续内存请求，这对于驱动程序和DMA等硬件操作至关重要。更关键的是，当内存被释放时，伙伴系统会主动尝试将相邻的空闲“伙伴”块**合并**成一个更大的块。这种独特的合并机制能够持续地对抗外部内存碎片，确保系统在长时间运行后依然有能力提供大块的连续内存，从而在内存利用率和系统稳定性上远超xv6的教学设计。

### 实验过程部分

#### 实验步骤记录

​	在 ld 文件分配好各个内核区的大小和地址之后，在 end 之后进行堆内存分配，通过 `(void *) PGROUNDUP((uint64) end)` 来对内核结束地址进行向上对齐（地址从内核到堆向上增长) ，来保证分配的地址不会破坏内核中的数据，然后分配 pageinfo 数组记录下pages 数组 之后的可分配内存的物理页大小，注意这里的total_pages 实际上会大于实际的物理页面数量

​	`alloc_pages(int order)` 函数中分配内存的是时候, 分配的是满足$2^{order}$ 大小的最小块，具体逻辑为首先遍历 free_lists 数组 (每个order也就是索引对应block 的地址) ，找到空闲块，此时如果发现空闲的块过大，那么就需要对块进行分割，然后将后半块加入对应 order 的空闲链

​	`free_pages(void * page,int order)` 释放物理页面的函数，在释放一个块的时候尝试 和伙伴块合并，具体算法是 

 ```c
 uint64 pfn = ((uint64)page - (uint64)buddy.memory_start) / PGSIZE; //计算出页面偏移数量
 uint64 buddy_pfn = pfn ^ (1UL << order); //计算伙伴块的页面偏移量
 return (void *) ((uint64)buddy.memory_start + buddy_pfn * PGSIZE); // 转换为伙伴地址
 ```

​	得到对应 buddy 块的首地址之后判断是否空闲，如果空闲就进行合并，删除两个小块，得到一个大块加入对应数组的空闲链表

#### 问题与解决方案

| 问题                                     | 根因                            | 解决                           |
| ---------------------------------------- | ------------------------------- | ------------------------------ |
| 重复定义 `freewalk` 链接失败             | 头文件暴露 + 源文件 static 冲突 | 移除头文件声明，内部 static    |
| `walk_lookup` 返回未映射槽位导致断言失败 | 语义不明确                      | 增加有效位检查，未映射返回 0   |
| 未对齐测试触发 panic                     | 实现硬退出                      | 改返回 -1，测试断言返回值      |
| 多页映射连续性假设可能失效               | buddy 不保证连续                | （计划）改成逐页映射独立物理页 |
| `%lx` 打印异常                           | printf 未实现长度修饰           | 改用 `%p` 或扩展解析器         |
| 函数名拼写 `destory_pagetable`           | 打字错误                        | 添加正确别名并计划统一         |

#### 源码理解总结

- 分配/释放核心在“阶平衡”：分裂保证向下递归建立链，合并利用伙伴地址 XOR 特性。
- 页表建立的关键在逐级索引：`PX(2/1/0, va)`；`walk` 在中间层缺失时按需分配（只 Zero 清理保证安全）。
- 安全点：所有映射接口对齐检查 + 越界检查（`va >= 1<<39` 直接拒绝）。
- 释放策略阶段性保守：不释放叶子物理页给后续“用户地址空间”留出明确控制点。

### 测试验证部分

#### 功能测试结果

使用多个测试函数涵盖了多重使用场景，包括异常数据测试以及 多次分配测试

```

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

```



![PixPin_2025-09-27_19-29-57](./PixPin_2025-09-27_19-29-57.png)

所有测试均可通过

---



## 实验四：中断处理与时钟管理

### 系统设计部分

#### 架构设计说明

本次实验旨在实现一个基于 RISC-V 特权级架构的、健壮的时钟中断处理机制。核心架构采用 **“M 模式代理，S 模式执行”** 的模型。

1.  **硬件中断捕获 (M-Mode)**: CPU 的物理定时器（CLINT）触发的中断属于机器模式（M-Mode）。该中断由 M 模式专属的陷阱处理程序 `timervec` 捕获。
2.  **中断代理与重置 (M-Mode)**: M 模式处理程序 `machine_timer_handler` 的职责有二：
    *   **重置闹钟**: 立即调用 `timer_set_next()`，设置下一次硬件中断的时间，避免中断风暴。
    *   **发送信号**: 通过向 `sip` (Supervisor Interrupt Pending) 寄存器写入 `SSIP` 位，向监管者模式（S-Mode）发送一个“软件中断”信号。
3.  **操作系统逻辑处理 (S-Mode)**: S 模式的通用陷阱处理程序 `kernelvec` 在 `mret` 返回后，会立即捕获到待处理的软件中断。
4.  **任务执行与清理 (S-Mode)**: `trap()` 函数根据 `scause` 识别出是软件中断，并调用 S 模式的 `clockintr()` 函数。`clockintr()` 负责执行操作系统层面的任务（如更新 `ticks` 计数器），并在最后**必须**清除 `sip` 寄存器中的 `SSIP` 挂起位，表示“任务已处理完毕”。

这种架构将硬件相关的底层操作（与 CLINT 交互）严格限制在 M 模式，而将操作系统相关的逻辑（进程调度、时间管理）放在 S 模式，实现了清晰的职责分离。

#### 关键数据结构

-   `volatile uint64 ticks`: 全局时钟滴答计数器，由 S 模式的 `clockintr` 维护。
-   `struct spinlock tickslock`: 用于保护 `ticks` 变量在多核环境下的原子性访问。

### 与 xv6 对比分析

-   **中断模型**: xv6 利用 `sstc` 扩展，将定时器中断**完全委托**给 S 模式处理，M 模式完全不参与。本实验采用的**M 模式代理模型**则更具通用性，不依赖 `sstc` 扩展，M 模式扮演了硬件抽象层的角色。
-   **复杂性**: M 模式代理模型需要处理 M/S 两级之间的通信（通过 `sip` 寄存器）和上下文切换，逻辑链条更长，但也更清晰地展示了 RISC-V 的特权级思想。
-   **启动流程**: xv6 在 S 模式的 `main` 函数中开启中断。本实验的最终方案是在 M 模式的 `start.c` 中，利用 `mstatus.MPIE` 位，让 `mret` 指令原子性地开启 M 模式中断，解决了启动过程中的时序问题。

### 设计决策理由

选择 M 模式代理模型，主要基于以下考虑：

1.  **学习价值**: 完整地经历了 M/S 两级中断的设置、委托、代理和处理全过程，能更深刻地理解 RISC-V 特权级架构。
2.  **硬件兼容性**: 该模型不依赖 `sstc` 扩展，在更广泛的 RISC-V 硬件平台上具有更好的兼容性。
3.  **安全性与隔离性**: 将直接操作物理硬件（如 CLINT）的代码严格限制在 M 模式，符合最小权限原则，使 S 模式的内核代码更加安全。

---

### 实验过程部分

#### 实现步骤记录

1.  **M 模式入口**: 在 `start.c` 中设置 `mtvec` 指向 `timervec`，并设置 `mstatus.MPIE` 以便在 `mret` 后安全开启 M 模式中断。
2.  **S 模式入口**: 在 `start.c` 中设置 `stvec` 指向 `kernelvec`。
3.  **中断委托**: 在 `start.c` 中，通过 `mideleg` 寄存器委托除机器定时器中断（`MTI`）外的所有中断给 S 模式。
4.  **首次中断设置**: 在 `start.c` 的 `mret` 之前，调用 `timer_init_once()` 设置一个较长的首次中断间隔，以解决启动竞态问题。
5.  **M 模式处理程序**: 实现 `machine_handler.c`，在其中调用 `timer_set_next()` 重置下一次硬件中断，并通过 `w_sip()` 向 S 模式发送软件中断。
6.  **S 模式处理程序**: 实现 `trap.c` 中的 `trap()` 和 `clockintr()`。`trap()` 负责分发中断，`clockintr()` 负责更新 `ticks` 计数并清除 `sip` 中的 `SSIP` 挂起位。

#### 问题与解决方案

| 问题                        | 根因分析                                                     | 解决方案                                                     |
| :-------------------------- | ------------------------------------------------------------ | :----------------------------------------------------------- |
| **无任何中断**              | 启动时序竞态：S 模式的 `intr_on` 还未执行，M 模式的首次中断就已到来并被忽略。 | 在 `start.c` 中设置一个**超长**的首次中断间隔 (`timer_init_once`)，给 `main` 函数的初始化留出充足时间。 |
|                             |                                                              |                                                              |
| **中断风暴**                | M 模式处理程序 `machine_timer_handler` 未重置下一次硬件中断时间 (`mtimecmp`)，导致 `mtime >= mtimecmp` 条件持续满足。 | 在 `machine_timer_handler` 中，第一件事就是调用 `timer_set_next()` 来安排下一次硬件中断。 |
| **S 模式中断死循环**        | S 模式的 `clockintr` 在处理完中断后，未清除 `sip` 寄存器中的 `SSIP` 挂起位，导致 `sret` 返回后立即再次陷入同一个中断。 | 在 `clockintr` 函数的末尾，调用 `w_sip(r_sip() & ~(1 << 1))` 来“销假”，清除软件中断挂起位。 |
| **非法指令 (`scause=2`)**   | `trap` 函数在 S 模式下运行但是使用了M 模式的寄存器导致发生了异常 | 不在 S 模式下直接读取 M 模式寄存器，改为在 `main` 函数早期判断 `hartid` 并让非主核心休眠。 |
| **kernelvec入口地址未对齐** | kernelvec 函数地址未对齐导致低两位不是0，无法正常写入 stvec ，导致kernel 无法跳转，这里卡了我好久 悲 | 在kernelvec.S 中添加 .align 4 来强制对齐低两位               |

#### 源码理解总结

本次实验深刻揭示了 RISC-V 特权级架构的精髓。`mstatus`, `sstatus`, `mie`, `sie`, `sip`, `mtvec`, `stvec` 等一系列 CSR 共同构成了一个精密的、分层的中断控制系统。任何一个环节的配置错误（如 `FS` 位未开、`MPIE` 与 `MIE` 的混淆、`sip` 未清除），都会导致系统以一种看似“灵异”的方式崩溃。通过本次调试，我们理解到编写操作系统不仅是实现功能，更是对硬件规范的精确理解和对执行时序的严格控制。

---

### 测试验证部分

### 功能测试结果

通过在 `main.c` 和 `trap.c` 中添加一系列 `printf` 调试语句，最终实现了预期的功能：

1.  系统正常启动，`main` 函数打印初始化信息。
2.  在首次长延时后，M 模式中断处理程序被触发，并打印 `mstatus` 等信息。
3.  S 模式中断处理程序 `clockintr` 被成功调用，并稳定地、按 `TIMER_INTERVAL` 定义的间隔（约 0.1 秒）周期性打印 "tick" 信息。
4.  `ticks` 计数器能够正常累加，证明中断处理逻辑正确。

### 实验过程部分

#### 问题与解决方案

​	在一切都正常的情况下，出现没有时钟中断输出的情况，经过仔细排查我发现是M 模式 和 S 模式的中断处理不正确导致的，首先我在 M 模式运行`start.c` 函数时，直接开启了M模式中断的使能信号 `MIE` 以及时钟中断接受信号 `MIE_MTIE` 并且开启了时钟中断，并且时钟中断触发非常频繁导致 M 模式的中断不停被触发，都没有机会跳转到 `main` 函数进行执行，所以会出现控制台没有输出的情况，

+ 解决方案： 延长中断触发的间隔，并且在`start.c` 文件中只设置`MPIE` 保证在执行 `mret` 指令切换到 S 模式的时候才会开启 M 模式的中断

​	注意这里有个大雷，`r_mhartid` 函数只能在 M 模式下执行，所以在 S 状态下执行会报错，这就是我之前每次都会在 trap 函数中产生异常的原因，`kerneltrap` 函数是在 S 模式下执行的，所以试图读取 M 模式下的寄存器就会触发这个异常，同时因为这个异常发生在`trap` 里面，就会导致遗产个无限递归

实验结果，每隔一段时间输出一个tick 来证明 时钟中断可以被正确触发

![PixPin_2025-09-29_18-37-13](./PixPin_2025-09-29_18-37-13.png)



---



## 实验五： 进程管理与调度

### 系统设计部分

#### 架构设计说明

​	每个进程都有一个进程控制块 `PCB` 记录了进程的信息，在程序启动之前静态定义了 64 个元素的进程数组，也就是说这个操作系统最多可以同时存在 64 个用户进程，这个数组会被分配到内核态的数据段中，属于内核空间，只有内核态才能访问

​	每个进程在内核中还有属于自己的内核栈，pcb 中会记录该进程在内核栈中的栈指针，这个栈指针需要使用内核页表才能访问，在 xv6 中，一个进程的内核栈的大小为一个页也就是 4kb , 在创建一个进程的时候，除了进程本身需要的内核页之外，还会分配一个保护页，这个页没有被映射，所以访问到他的时候就会触发缺页错误，导致系统崩溃。

​	一个进程的内核栈的栈顶区域会存放 `trapframe`  用来记录用户态进程的各个寄存器的值，方便在返回的时候恢复现场，并且在内核态中，函数的调用也会使用这个内核栈。

在 `proc.c` 的 `procinit()` 函数中，我们对全局的 `proc` 和 `cpus` 数组进行初始化。

- **初始化 `proc` 数组**: 遍历所有进程槽，初始化每个进程的锁，并将状态设为 `UNUSED`。同时，计算并设置每个进程的内核栈虚拟地址 `p->kstack`。
- **初始化 `cpus` 数组**: 确保每个 CPU 的上下文和当前进程指针被清零。
- **映射内核栈**: 在内核页表初始化阶段，调用 `proc_mapstacks()`，为每个进程的内核栈分配物理页面，并建立虚拟地址到物理地址的映射。

**进程创建 (`allocproc`) **

`allocproc` 负责找到一个 `UNUSED` 的进程槽并为其分配核心资源。

1. 遍历 `proc` 数组，找到一个 `UNUSED` 的进程 `p`，并持有其锁。
2. 分配 PID，并将状态设为 `USED`。
3. 调用 `kalloc()` 为进程的 `trapframe` 分配一个物理页面。
4. 调用 `proc_pagetable()` 为进程创建用户页表，并映射 `TRAMPOLINE` 和 `TRAPFRAME`。

**调度器 (`scheduler`) **

调度器是内核的心跳，它不断寻找可运行的进程并执行。

1. 在一个无限循环 `for(;;)` 中，遍历 `proc` 数组。
2. 对每个进程 `p`，`acquire(&p->lock)`。
3. 如果 `p->state == RUNNABLE`，则： a. 将状态设为 `RUNNING`。 b. 将当前 CPU 的进程指针 `c->proc` 指向 `p`。 c. 调用 `swtch(&c->context, &p->context)`，切换到进程 `p` 执行。 d. 当 `swtch` 返回时（意味着进程 `p` 已让出 CPU），重置 `c->proc = 0`。
4. `release(&p->lock)`。
5. 如果没有找到可运行进程，执行 `wfi` 指令等待中断。

  **进程退出与等待**

- **退出 (`exit`)**: 进程调用 `exit()` 时，将自身状态设为 `ZOMBIE`，唤醒可能在 `wait()` 中等待的父进程，然后调用 `sched()` 永久让出 CPU。
- **等待 (`wait`)**: 父进程调用 `wait()` 遍历其子进程，寻找 `ZOMBIE` 状态的子进程，找到后调用 `freeproc()` 回收其所有资源（内核栈、页表等），并将该 `proc` 结构体状态重置为 `UNUSED`。

#### 关键数据结构

PCB 进程控制块的定义

```c
struct proc
{
    struct spinlock lock;

    // p->lock 必须持有时才能修改的字段
    enum procstate state; // 进程状态
    void *chan;           // 如果非零，表示正在 chan 上睡眠
    int killed;           // 如果非零，表示进程已被标记为杀死
    int xstate;           // 退出状态，由父进程读取
    int pid;              // 进程 ID
    char *name;           // 进程名 (debugging)
    char *cwd;            // 当前工作目录
    // wait_lock 必须持有时才能修改的字段
    struct proc *parent; // 父进程

    // 这些字段通常在进程自己的锁保护下是安全的
    uint64 kstack;               // 此进程的内核栈顶地址
    uint64 sz;                   // 进程内存大小 (bytes)
    pagetable_t pagetable;       // 用户页表
    struct trapframe *trapframe; // 用于保存 S 模式陷阱的上下文
    struct context context;      // 用于在 swtch 中切换的上下文
};
```

- **UNUSED**: 进程结构体可用，未被分配。
- **USED**: 进程结构体已分配，正在初始化。
- **SLEEPING**: 进程正在等待某个事件（如 I/O 完成），暂时让出 CPU。
- **RUNNABLE**: 进程已准备就绪，等待被调度器选中运行。
- **RUNNING**: 进程正在 CPU 上执行。
- **ZOMBIE**: 进程已执行完毕，但其资源尚未被父进程回收，等待父进程处理

### 实验过程部分

#### 实验步骤以及问题解决

在整个实验过程中，我们遇到了多个具有代表性的问题，通过细致的日志分析和调试，最终定位并解决了它们。

### **问题一：`swtch` 后 QEMU 立即终止，无任何错误信息**

- **现象**: 调度器找到第一个 `RUNNABLE` 进程后，调用 `swtch`，QEMU 窗口直接关闭。
- **分析**: 这是典型的上下文未初始化问题。通过在 `scheduler` 中打印 `p->context.ra` 和 `p->context.sp`，发现它们均为 `0`。`swtch` 后 `ret` 指令尝试跳转到地址 `0x0`，引发了致命的指令访问异常。
- **解决**: 在 `allocproc` 函数中，为新分配的进程 `p` 显式初始化上下文，将 `ra` 指向 `forkret`，`sp` 指向其内核栈顶。

### **问题二：`swtch` 后 QEMU 依然终止，但 `ra` 和 `sp` 已有非零值**

- **现象**: 即使 `ra` 和 `sp` 被初始化，`swtch` 后系统仍然崩溃。日志显示 `sp` 的值为 `0x0000003fffffe000`，一个非常高的地址。
- **分析**: 这个地址位于 `TRAMPOLINE` 附近，属于用户空间。问题出在 `KSTACK` 宏的定义上，它错误地将内核栈定位在了用户地址空间。当进程切换后，CPU 尝试访问这个 `sp` 指向的地址，但该地址在进程的页表中并未映射，导致了页故障（Page Fault）。
- **解决**: 修正 `KSTACK` 宏的定义，将其基地址改到内核地址空间（如 `0x80000000`）。同时，确保在内核初始化时调用 `proc_mapstacks()`，为所有内核栈建立正确的虚拟到物理映射。

### **问题三：进程创建失败，`allocproc` 返回 `NULL`**

- **现象**: `test_process_creation` 测试失败，日志显示 `allocproc` 内部的 `proc_pagetable` 返回 `0`。
- **分析**: 进一步在 `proc_pagetable` 中添加日志，发现 `mappages` 函数在映射 `TRAMPOLINE` 时失败。打印 `mappages` 的参数，发现 `pa`（物理地址，即 `trampoline` 符号的地址）为 `0x...400`，不是页对齐的。`mappages` 要求所有地址参数必须页对齐。
- **解决**: 在 `trampoline.S` 文件中，将 `trampoline` 符号的对齐方式从 `.align 4` (16字节) 修改为 `.align 12` (4096字节)，确保其地址是页对齐的。

### **问题四：主进程 `main_proc` 无限重复执行并触发 `panic("release")`**

- **现象**: 主进程在完成一轮子进程的 `wait` 后，日志显示它又从头开始执行，并很快因为重复释放一个未持有的锁而崩溃。
- **分析**: `main_proc` 函数在执行完所有代码后，隐式地执行了 `ret`。由于其 `ra` 在创建时被设置为 `main_proc` 自身的地址，这导致它陷入了无限递归调用。每次重新执行时，它都会尝试 `release` 一个在上一次循环中已经释放的锁，从而触发 panic。
- **解决**: 在 `main_proc` 的任务完成后，不能让它返回。我们通过添加一个无限循环 `for(;;){ yield(); }` 来使其阻塞，持续让出 CPU，扮演一个类似 `init` 进程的角色，等待并处理孤儿进程。

### **问题五：对 `scheduler` 中锁机制的困惑与死锁风险**

- **现象**: `scheduler` 在 `swtch` 之前 `acquire` 锁，在 `swtch` 之后 `release` 锁。如果被调度的进程调用 `yield()`（它内部也会 `acquire` 锁），是否会造成死锁？
- **分析**: 这是 xv6 设计中的一个精妙之处。调度器确实在切换时持有着进程的锁。为了避免死锁，xv6 规定：任何让出 CPU 的函数（如 `yield`, `sleep`, `exit`）在调用 `sched()` 之前，必须**已经持有**该进程的锁。当进程下次被调度并从 `swtch` 返回时，它会继续执行并释放这个锁。这个约定确保了锁状态的一致性和原子性。
- **解决**: 理解并遵循这个设计。在我们的测试函数 `simple_task` 中，我们在调用 `sched()` 之前 `acquire` 了锁，并在 `main_proc` 中通过 `wait_process` 来正确处理子进程的退出，从而避免了死锁。

#### 结果测试

---

## 实验六： 系统调用

### 系统设计部分

#### 架构设计说明

​	当用户程序调用一个系统调用函数的时候，实际会执行一小段汇编桩代码`usys.S`，这段代码的作用是将对一个系统调用的系统调用号存到寄存器 a7 寄存器中，然后程序会执行 ecall 指令陷入内核，cpu 保存所有的用户寄存器的状态到 trapframe 中，在系统调用解决完毕之后，系统调用的返回值会存储到 a0 寄存器中。

​	在这个过程中，系统调用不仅需要系统调用号，还需要参数，如果获取用户提供的参数

> 通过trapframe 中的用户寄存器来获取，根据 RISC-V 的调用约定，函数的前几个参数存放在寄存器 a0 a1 a2 …  中，因此 argint() 函数会通过对应的寄存器来获取参数，这里有几个关键的函数
>
> + `argint(int n,int *ip)` 从 `an` 寄存器中获取参数值，然后存入`ip` 指针指向的位置
> + `argaddr(int n,uint64 * ip)` 用于获取一个指针， 执行对应寄存器的值
> + `argstr(int n,char * buf,int max)` 获取用户空间字符串的起始地址，然后调用一个安全的内存拷贝函数，将字符串从用户空间拷贝到内核空间的缓冲区 buf 中，并且长度不能超过 max

​	在处理系统调用的时候我们有时候需要再内核状态访问用户状态的数据，这时候我们就需要拷贝用户状态的数据到内核状态，同样有几个函数需要留意

+ `copyin(pagetable,src,dst,len)` 从用户态拷贝数据到内核态
+ `copyout()` 与 上面相反

​	注意在内核态不能直接解引用用户传递的指针，原因如下

1. 用户和内核使用的不是同一个页表，如果直接解引用指针，可能会发生未定衣行为
2. 用户可能会在伪造一个指针，并且指向内核的关键数据，导致内核崩溃
3. 缺页异常不好处理，可能导致内核崩溃

​	`trampoline.S` 汇编的作用，定义陷入内核的过程和从内核返回的过程，在进入这个汇编代码的时候，cpu 已经处于内核态了，因为 `trampoline.S` 汇编代码是陷阱处理程序的入口，首先在用户

​	`syscall.h` 中定义了每个系统调用对应的系统调用号，`syscall.c` 中定义了系统调用分发处理函数    `syscall()`，

#### 关键数据结构

在本次实验中，支持系统调用流程的核心数据结构主要涉及进程管理、文件系统接口以及中断上下文。

1. **`struct proc` (进程控制块)**
   - **作用**：维护进程的状态。在系统调用中，最关键的字段是 `struct trapframe *trapframe`。
   - **细节**：`trapframe` 保存了用户态进入内核态时的寄存器现场（如 `a0`-`a7` 用于参数传递，`epc` 用于返回地址，`sp` 用于栈切换）。系统调用的参数通过 `trapframe->a0` 到 `a7` 获取，返回值写入 `trapframe->a0`。
2. **`struct file` (文件结构体)**
   - **作用**：抽象打开的文件、管道或设备。
   - **细节**：包含 `type` (文件类型：FD_INODE, FD_DEVICE, FD_PIPE)、`ref` (引用计数)、`readable/writable` (读写权限) 以及特定类型的指针（如 `ip` 指向 inode，`major` 指向设备号）。`sys_write` 等系统调用通过操作此结构体实现 I/O。
3. **`struct devsw` (设备转换表)**
   - **作用**：实现设备驱动的动态分发，提供统一的设备 I/O 接口。
   - **细节**：这是一个函数指针数组 `struct devsw devsw[NDEV]`。每个元素包含 `read` 和 `write` 函数指针。例如，控制台设备（Console）对应的主设备号索引指向 `consolewrite` 函数。
4. **`syscalls` (系统调用表)**
   - **作用**：将系统调用号映射到具体的内核处理函数。
   - **细节**：通常是一个函数指针数组 `static uint64 (*syscalls[])(void)`。`syscall()` 函数根据 `trapframe->a7` 中的调用号查表执行。

#### 实验过程部分

##### 实验步骤

1. **环境搭建**：配置 RISC-V 交叉编译工具链，编写 Makefile 和链接脚本 `kernel.ld`。
2. **中断入口建立**：编写 `trampoline.S`，实现 `uservec`（保存现场）和 `userret`（恢复现场）。
3. **系统调用分发**：实现 `syscall.c`，根据 `a7` 寄存器的值调用对应的内核函数（如 `sys_write`）。
4. **文件系统接口**：实现 `sysfile.c` 中的 `sys_write`，并通过 `filewrite` 转发给设备驱动。
5. **用户程序测试**：编写 `init.c`，在循环中调用 `printf`（底层调用 `write`）测试输出。

##### 问题解决（调试记录）

在实验过程中，遇到了三个主要阻碍系统调用正常工作的严重 Bug：

**问题 1：Trampoline 映射导致的内核崩溃**

- **现象**：内核启动后，尝试从内核态返回用户态时发生异常，日志显示 Trampoline 的物理地址为 0。
- **分析**：检查 `kvmmap` 调用，发现传入的物理地址参数为 0。进一步检查符号表，发现 `trampoline` 符号地址为 0。
- **根源**：`kernel.ld` 中指定段名为 `.trampoline`，而汇编文件 `trampoline.S` 中使用了 `.section trampsec`。链接器无法匹配，导致段丢失或地址错误。
- **解决**：统一修改汇编文件中的段定义为 `.section .trampsec`，并更新链接脚本以匹配该名称。

**问题 2：系统调用返回 -1，无输出**

- **现象**：`init` 进程成功运行并触发 `sys_write`，但返回值始终为 -1，控制台无字符显示。
- **分析**：在 `sys_write` 和 `filewrite` 中添加 `printf` 调试日志。发现 `filewrite` 报错 `no write func`，检查发现 `devsw[1].write` 为 `NULL`。
- **根源**：`main.c` 初始化顺序错误。`consoleinit()` 正确填充了 `devsw` 表，但随后执行的 `memset(edata, 0, ...)` 清空了 BSS 段，导致 `devsw` 表被重置为 0。
- **解决**：调整 `main.c` 代码，将 `memset` 清零操作移动到所有初始化函数（包括 `consoleinit`）之前。

**问题 3：GDB 调试指令误用**

- **现象**：调试页表时，GDB 报错 `Cannot access memory`。
- **解决**：修正了 GDB 中的指针运算逻辑，正确使用数组索引方式访问页表项。

## 实验七：文件系统

### 关键数据结构

文件系统是操作系统中持久化存储数据的核心组件。本次实验实现了基于 inode 的类 Unix 文件系统，涉及以下关键数据结构：

1. **`struct superblock` (超级块)**
   - **作用**：描述整个文件系统的元数据。
   - **细节**：包含文件系统总块数 (`size`)、数据块数量 (`nblocks`)、inode 数量 (`ninodes`)、日志块起始位置 (`logstart`)、inode 区起始位置 (`inodestart`) 以及位图区起始位置 (`bmapstart`)。它是文件系统挂载时的入口点。
2. **`struct dinode` (磁盘 inode)**
   - **作用**：在磁盘上存储文件的元数据。
   - **细节**：包含文件类型 (`type`: 文件/目录/设备)、主次设备号 (`major`, `minor`)、链接数 (`nlink`)、文件大小 (`size`) 以及数据块索引数组 (`addrs`)。`addrs` 通常包含直接索引（指向具体数据块）和间接索引（指向包含更多块号的块），以支持大文件。
3. **`struct inode` (内存 inode)**
   - **作用**：内核中活动的 inode 缓存。
   - **细节**：除了包含 `dinode` 的所有字段外，还增加了引用计数 (`ref`)、同步锁 (`lock`) 以及设备号 (`dev`) 和 inode 编号 (`inum`)。内核通过 `iget` 和 `iput` 管理其生命周期，确保同一文件在内存中只有一份副本。
4. **`struct buf` (缓冲区)**
   - **作用**：磁盘块在内存中的缓存（Buffer Cache）。
   - **细节**：包含数据缓冲区 (`data`)、块号 (`blockno`)、设备号 (`dev`)、状态标志（`valid`, `disk`）以及用于 LRU（最近最少使用）替换算法的链表指针。所有文件系统操作都通过缓冲区层读写磁盘，以减少 I/O 次数。
5. **`struct file` (文件句柄)**
   - **作用**：进程打开文件的抽象。
   - **细节**：虽然属于进程层，但它持有指向 `inode` 的指针 (`ip`) 和当前读写偏移量 (`off`)。多个进程可以打开同一个文件，拥有不同的 `file` 结构，但共享同一个 `inode`。

### 实验过程部分

#### 实验步骤

1. **底层驱动对接**：确保 `virtio_disk.c` 能正确读写扇区，并测试 `bio.c` (Buffer I/O) 的读写功能。
2. **超级块读取**：在 `fsinit` 中读取超级块，验证魔数 (`magic`) 以确认文件系统格式正确。
3. **inode 操作实现**：实现 `ialloc` (分配 inode)、`iget` (获取/锁定 inode)、`iput` (释放/写入 inode)。
4. **文件读写实现**：实现 `readi` 和 `writei`，处理数据块的映射（`bmap`）和间接块的逻辑。
5. **目录操作实现**：实现 `dirlookup` (查找文件名) 和 `dirlink` (添加目录项)。
6. **系统调用封装**：实现 `sys_open`, `sys_read`, `sys_write`, `sys_mknod`, `sys_mkdir` 等系统调用。

**问题 1：设备文件写入失败 (`sys_write` 返回 -1)**

- **现象**： 在测试文件系统的字符设备支持时，`init` 进程尝试向标准输出（文件描述符 1，对应控制台设备）打印字符串 "init: starting sh"。系统调用 `sys_write` 被触发，但返回值始终为 -1，且 QEMU 终端无任何字符输出。

- 分析过程

  ：

  1. **追踪系统调用**：在 `kernel/sysfile.c` 的 `sys_write` 函数中添加 `printf` 调试日志，确认参数传递正确（fd=1, n=1），但调用 `filewrite` 后返回错误。
  2. **定位错误点**：深入 `kernel/file.c` 的 `filewrite` 函数，发现代码进入了 `FD_DEVICE` 分支，但报错 `bad device major=1 or no write func`。
  3. **检查数据结构**：打印全局设备表 `devsw[1].write` 的值，发现其为 `0x0000000000000000` (NULL)，说明控制台驱动的写函数未被正确注册。

- **根源**： **内核初始化顺序错误**。在 `kernel/main.c` 中，`consoleinit()` 函数首先被调用，它正确地将 `consolewrite` 函数地址填入了 `devsw` 表。然而，紧随其后执行了 `memset(edata, 0, end - edata)` 以清空 BSS 段。由于 `devsw` 数组是未初始化的全局变量，位于 BSS 段中，因此刚填好的函数指针被 `memset` 再次清零。

- **解决**： 调整 `main` 函数的初始化逻辑，将 BSS 段的清零操作 (`memset`) 移动到所有子系统初始化（包括 `consoleinit`）之前执行，确保全局变量在被赋值前已处于干净状态。

**问题 2：用户态文件操作无法触发（Trampoline 映射异常）**

- **现象**： 在尝试运行第一个用户进程以测试文件系统调用时，内核在从内核态返回用户态（`userret`）或处理系统调用陷入（`uservec`）时发生异常。调试日志显示 Trampoline 页面的物理地址解析为 `0x0000000000000000`。

- 分析过程

  ：

  1. **检查页表**：使用 GDB 检查内核页表，发现 `TRAMPOLINE` 虚拟地址对应的 PTE（页表项）异常。
  2. **检查符号地址**：查看内核符号表，发现 `trampoline` 符号的地址被解析为 0。

- **根源**： **链接脚本与汇编段名不匹配**。`kernel.ld` 链接脚本中显式指定了输出段名为 `.trampoline`，但在汇编文件 `trampoline.S` 中，段定义被写为 `.section trampsec`（或不一致的名称）。导致链接器无法正确收集该段代码，默认将其地址置为 0，从而破坏了用户态与内核态切换的“跳板”机制，导致所有文件系统调用无法执行。

- **解决**： 统一修改 `trampoline.S` 中的段定义为 `.section .trampsec`，并同步更新 `kernel.ld` 中的段匹配规则，确保代码段被正确加载到内存高位。

**问题 3：GDB 调试内存访问错误**

- **现象**： 在调试上述映射问题时，尝试使用 GDB 查看页表末尾项以验证文件系统缓冲区的映射情况，GDB 报错 `Cannot access memory at address ...`。
- **根源**： **GDB 命令中的指针运算误区**。在使用 `x` 或 `p` 命令时，直接对 `uint64*` 类型的页表指针进行了错误的算术偏移（例如 `kpgtbl + 511 * 8`），GDB 将其解释为数组索引偏移而非字节偏移，导致访问地址超出了物理内存范围。
- **解决**： 修正调试命令，使用正确的数组索引方式 `p/x kpgtbl[511]` 或显式转换地址类型，成功获取了页表内容，辅助验证了内存映射的正确性

### 实验八

