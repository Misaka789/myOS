#include "types.h"
#include "param.h"
#include "memlayout.h"
#include "riscv.h"
#include "defs.h"

// 基本类型（Sv39 三层页表）
// typedef uint64 pte_t;
// typedef uint64 *pagetable_t;

// #ifndef PTE_V
// #define PTE_V (1L << 0)
// #define PTE_R (1L << 1)
// #define PTE_W (1L << 2)
// #define PTE_X (1L << 3)
// #define PTE_U (1L << 4)
// #define PTE_G (1L << 5)
// #define PTE_A (1L << 6)
// #define PTE_D (1L << 7)
// #endif

// #define PX(level, va) ((((uint64)(va)) >> (12 + 9 * (level))) & 0x1FF)
// #define PTE2PA(pte) (((pte) >> 10) << 12)
// #define PA2PTE(pa) ((((uint64)(pa)) >> 12) << 10)

#ifndef SATP_SV39
#define SATP_SV39 (8ULL << 60)
#endif
#define MAKE_SATP(pgtbl) (SATP_SV39 | (((uint64)(pgtbl)) >> 12))

// 对外导出的内核页表
pagetable_t kernel_pagetable = 0;

static void freewalk(pagetable_t pt)
{
    for (int i = 0; i < 512; i++)
    {
        pte_t pte = pt[i];
        if ((pte & PTE_V) == 0)
            continue;

        // 如果不是叶子（没有 R/W/X），它指向下一层页表
        if ((pte & (PTE_R | PTE_W | PTE_X)) == 0)
        {
            pagetable_t child = (pagetable_t)PTE2PA(pte);
            freewalk(child);
            pt[i] = 0;
        }
        // 叶子：不释放（数据页/设备页），由其它逻辑负责
    }
    kfree(pt);
}
void destory_pagetable(pagetable_t pt)
{
    if (pt)
        freewalk(pt);
}

pagetable_t create_pagetable(void)
{
    pagetable_t pt = (pagetable_t)kalloc();
    if (!pt)
        return 0;
    memset(pt, 0, PGSIZE);
    return pt;
}
int map_page(pagetable_t pt, uint64 va, uint64 pa, int perm)
{
    if ((va & (PGSIZE - 1)) != 0)
        return -1;
    // panic("map_page: va not aligned");
    if ((pa & (PGSIZE - 1)) != 0)

        return -1; // panic("map_page: pa not aligned");
    return mappages(pt, va, PGSIZE, pa, perm);
}

// 内部：为 walk 分配页表页（使用 buddy 封装的 kalloc/kfree）
static pte_t *walk(pagetable_t pt, uint64 va, int alloc)
{
    if (va >= (1ULL << 39))
        return 0; // Sv39 VA 范围保护
    for (int level = 2; level > 0; level--)
    {
        pte_t *pte = &pt[PX(level, va)];
        if (*pte & PTE_V)
        {
            pt = (pagetable_t)PTE2PA(*pte);
        }
        else
        {
            if (!alloc)
                return 0;
            void *newpg = kalloc();
            if (!newpg)
                return 0;
            memset(newpg, 0, PGSIZE);
            *pte = PA2PTE((uint64)newpg) | PTE_V;
            pt = (pagetable_t)newpg;
        }
    }
    return &pt[PX(0, va)];
}

// 创建（若缺页表则分配）
pte_t *walk_create(pagetable_t pt, uint64 va) { return walk(pt, va, 1); }
// 查找（不分配）
pte_t *walk_lookup(pagetable_t pt, uint64 va)
{
    pte_t *pte = walk(pt, va, 0);
    if (pte == 0)
        return 0;
    if ((*pte & PTE_V) == 0)
        return 0;
    return pte;
}

// 在页表中建立 [va, va+sz) -> [pa, pa+sz) 的映射（逐页）
int mappages(pagetable_t pt, uint64 va, uint64 size, uint64 pa, int perm)
{
    if (size == 0)
        return 0;
    if (va + size - 1 < va)
        return -1; // 溢出检查
    if ((va | pa | size) & (PGSIZE - 1))
        return -1;
    // panic("mappages: not aligned");
    uint64 a = PGROUNDDOWN(va);
    uint64 last = PGROUNDDOWN(va + size - 1);
    for (;;)
    {
        pte_t *pte = walk(pt, a, 1);
        if (!pte)
            return -1;
        if (*pte & PTE_V)
            return -1; // 已映射
        *pte = PA2PTE(pa) | perm | PTE_V;
        if (a == last)
            break;
        a += PGSIZE;
        pa += PGSIZE;
    }
    return 0;
}

// 便捷：内核映射（大小按字节）
static void kvmmap(pagetable_t pt, uint64 va, uint64 pa, uint64 sz, int perm)
{
    if (mappages(pt, va, sz, pa, perm) != 0)
        panic("kvmmap");
}

// 内核页表构建：最小可用版本（恒等映射内核与设备）
static pagetable_t kvmmake(void)
{
    pagetable_t kpgtbl = (pagetable_t)kalloc();
    if (!kpgtbl)
        panic("kvmmake: no mem");
    memset(kpgtbl, 0, PGSIZE);

    extern char etext[]; // 链接脚本提供（代码段结束）

    // 设备恒等映射（按需添加）
#ifdef UART0
    kvmmap(kpgtbl, UART0, UART0, PGSIZE, PTE_R | PTE_W);
#endif
#ifdef PLIC
    kvmmap(kpgtbl, PLIC, PLIC, 0x400000, PTE_R | PTE_W); // 4MB 够用
#endif
#ifdef CLINT
    kvmmap(kpgtbl, CLINT, CLINT, 0x10000, PTE_R | PTE_W);
#endif

    // 内核镜像与物理内存（恒等映射）
    // 代码段: 只读+可执行
    kvmmap(kpgtbl, KERNBASE, KERNBASE, (uint64)etext - KERNBASE, PTE_R | PTE_X);
    // 代码段之后到 PHYSTOP: 可读写（含数据/BSS、堆、页框等）
    kvmmap(kpgtbl, (uint64)etext, (uint64)etext, (uint64)PHYSTOP - (uint64)etext, PTE_R | PTE_W);

    return kpgtbl;
}

// 初始化内核页表（仅构建，不切换）
void kvminit(void)
{
    kernel_pagetable = kvmmake();
}

// 让当前 hart 使用 kernel_pagetable
void kvminithart(void)
{
    if (!kernel_pagetable)
        panic("kvminithart: no kernel_pagetable");
    w_satp(MAKE_SATP(kernel_pagetable));
    sfence_vma();
}

// 将内核 VA 转换为 PA（仅用于已映射的区间）
uint64 kvmpa(uint64 va)
{
    pte_t *pte = walk_lookup(kernel_pagetable, va);
    if (!pte || !(*pte & PTE_V))
        return 0;
    uint64 pa = PTE2PA(*pte) | (va & (PGSIZE - 1));
    return pa;
}

// 用户/通用：将 pt 下的 VA 转成 PA（检查 PTE_V/PTE_U）
uint64 walkaddr(pagetable_t pt, uint64 va)
{
    pte_t *pte = walk_lookup(pt, va);
    if (!pte)
        return 0;
    if ((*pte & (PTE_V)) == 0)
        return 0;
    uint64 pa = PTE2PA(*pte);
    return pa | (va & (PGSIZE - 1));
}