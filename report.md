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