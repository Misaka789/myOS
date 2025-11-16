#include "types.h"
#include "param.h"
#include "memlayout.h"
#include "riscv.h"
#include "defs.h"
#include "proc.h"

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

// 对外导出的内核页表
pagetable_t kernel_pagetable = 0;

// 释放组成页表树的那些物理页
// 在调用 这个函数之前所有的映射已经被 uvmunmap 解除
// 也就是说所有的叶子节点都已经被清除
// 该函数递归地释放所有页表页

extern char trampoline[]; // trampoline.S
static void freewalk(pagetable_t pt)
{
    for (int i = 0; i < 512; i++)
    {
        pte_t pte = pt[i];
        if ((pte & PTE_V) == 0)
            continue;
        // 页表项 pte 中存储的是下一级页表的物理地址
        // 如果不是叶子（没有 R/W/X），它指向下一层页表
        if ((pte & (PTE_R | PTE_W | PTE_X)) == 0)
        {
            pagetable_t child = (pagetable_t)PTE2PA(pte);
            freewalk(child);
            pt[i] = 0;
        }
        else if (pte & PTE_V) // 如果是叶子结点
        {
            panic("freewalk: leaf");
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
        // PX 为取对应级别索引的宏
        pte_t *pte = &pt[PX(level, va)];
        if (*pte & PTE_V) // 页表项有效
        {
            pt = (pagetable_t)PTE2PA(*pte);
        }
        else // 页表项无效 也就是缺页
        {
            if (!alloc)
                return 0;
            // 设置了 alloc 参数，分配物理页
            void *newpg = kalloc();
            if (!newpg)
                return 0;
            memset(newpg, 0, PGSIZE);
            *pte = PA2PTE((uint64)newpg) | PTE_V;
            pt = (pagetable_t)newpg;
        }
    }
    // 返回 L0 页表项的地址
    return &pt[PX(0, va)];
}

// 创建（若缺页表则分配）
pte_t *walk_create(pagetable_t pt, uint64 va) { return walk(pt, va, 1); }
// 查找（不分配）返回 L0 的页表项
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
// 参数 perm 为权限，由多个位组合而成
int mappages(pagetable_t pt, uint64 va, uint64 size, uint64 pa, int perm)
{
    printf("[mappages]: enter fucntion \n");
    printf("[mappages]: argument pt = %p,va = %p,size = %d,pa = %p,perm = %d \n", pt, va, size, pa, perm);
    if (size == 0)
        return 0;
    if (va + size - 1 < va)
        return -1; // 溢出检查
    if ((va | pa | size) & (PGSIZE - 1))
        return -1;
    // panic("mappages: not aligned");
    uint64 a = PGROUNDDOWN(va);
    uint64 last = PGROUNDDOWN(va + size - 1);
    // 使用 PGROUNDDOWN 向下取整， 从包含 va 的页开始映射
    // 映射到包含 va+size-1 的页为止
    // 注意 size 可能不是 PGSIZE 的整数倍
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
void kvmmap(pagetable_t pt, uint64 va, uint64 pa, uint64 sz, int perm)
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

    kvmmap(kpgtbl, TRAMPOLINE, (uint64)trampoline, PGSIZE, PTE_R | PTE_X);

    extern void proc_mapstacks(pagetable_t kpgtbl);
    proc_mapstacks(kpgtbl);

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
    // printf(" 114514 kernel pagetable :%p \n",(uint64)kernel_pagetable);
    printf("make satp : %p\n", MAKE_SATP(kernel_pagetable));
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

// pagetable_t proc_pagetable(struct proc *p)
// {
//     // return (uint64)p->pagetable;
//     pagetable_t pagetable = create_pagetable();
//     if (pagetable == 0)
//         return 0;

// }

pagetable_t uvmcreate() // 为用户进程创建空页表
{
    pagetable_t pagetable = (pagetable_t)kalloc();
    printf("[uvmcreate]: pagetable = %p \n", pagetable);
    if (pagetable == 0)
        return 0;
    memset(pagetable, 0, PGSIZE);
    printf("[uvmcreate]: before return pagetable = %p \n", pagetable);
    return pagetable;
}

void uvmclear(pagetable_t pagetable, uint64 va)
{
    pte_t *pte;

    pte = walk(pagetable, va, 0);
    if (pte == 0)
        panic("uvmclear");
    *pte &= ~PTE_U;
}

uint64 uvmalloc(pagetable_t pagetable, uint64 oldsz, uint64 newsz, int xperm)
{ // 为用户进程分配内存 oldsz 表示旧大小，newsz 表示新大小
    char *mem;
    uint64 a;

    if (newsz < oldsz)
        return oldsz;

    oldsz = PGROUNDUP(oldsz); // 向上取整到页边界
    for (a = oldsz; a < newsz; a += PGSIZE)
    {
        mem = kalloc();
        if (mem == 0) // 分配失败，回滚
        {
            uvmdealloc(pagetable, a, oldsz);
            return 0;
        }
        memset(mem, 0, PGSIZE);
        if (mappages(pagetable, a, PGSIZE, (uint64)mem, PTE_R | PTE_U | xperm) != 0)
        {
            kfree(mem);
            uvmdealloc(pagetable, a, oldsz);
            return 0;
        }
    }
    return newsz;
}

void uvmfree(pagetable_t pagetable, uint64 sz)
{ // 释放用户内存
    if (sz > 0)
        uvmunmap(pagetable, 0, PGROUNDUP(sz) / PGSIZE, 1);
    freewalk(pagetable);
}

uint64 uvmdeadlloc(pagetable_t pagetable, uint64 oldsz, uint64 newsz)
{ // 释放用户内存，oldsz 表示旧大小，newsz 表示新大小
    if (newsz >= oldsz)
        return oldsz;

    if (PGROUNDUP(newsz) < PGROUNDUP(oldsz))
    {
        uint64 a = PGROUNDUP(newsz);
        uvmunmap(pagetable, a, (PGROUNDUP(oldsz) - a) / PGSIZE, 1);
    }
    return newsz;
}

void uvmunmap(pagetable_t pagetable, uint64 va, uint64 npages, int do_free)
{ // 解除映射
    uint64 a;
    pte_t *pte;

    if ((va % PGSIZE) != 0)
        panic("uvmunmap: not aligned");

    for (a = va; a < va + npages * PGSIZE; a += PGSIZE)
    {
        if ((pte = walk_lookup(pagetable, a)) == 0)
            panic("uvmunmap: walk_lookup failed");
        if ((*pte & PTE_V) == 0)
            panic("uvmunmap: not mapped");
        if (PTE_FLAGS(*pte) == PTE_V)
            panic("uvmunmap: not a leaf");
        if (do_free)
        {
            uint64 pa = PTE2PA(*pte);
            kfree((void *)pa);
        }
        *pte = 0;
    }
}

int copyin(pagetable_t pagetable, char *dst, uint64 srcva, uint64 len)
{ // 从用户空间拷贝数据到内核空间
    uint64 n, va0, pa0;
    // pte_t *pte;

    while (len > 0)
    {
        va0 = PGROUNDDOWN(srcva);
        if (va0 >= MAXVA)
            return -1;
        //  walkaddr 函数返回物理地址 并且检查有效位
        pa0 = walkaddr(pagetable, va0);
        if (pa0 == 0)
            return -1;

        // 没有对齐的那部分的数据
        // n = va0 + PGSIZE - srcva;
        n = PGSIZE - (srcva - va0);
        if (n > len) // 判断来保证不会发生跨页
            n = len;

        memmove(dst, (char *)(pa0 + (srcva - va0)), n);

        len -= n;
        dst += n;
        srcva = va0 + PGSIZE;
    }
    return 0;
}

int copyout(pagetable_t pagetable, uint64 dstva, char *src, uint64 len)
{ // 从内核空间拷贝数据到用户空间
    uint64 n, va0, pa0;
    // pte_t *pte;

    while (len > 0)
    {
        va0 = PGROUNDDOWN(dstva);
        if (va0 >= MAXVA)
            return -1;

        pa0 = walkaddr(pagetable, va0);
        if (pa0 == 0)
            return -1;

        n = PGSIZE - (dstva - va0);
        if (n > len)
            n = len;
        memmove((void *)(pa0 + (dstva - va0)), src, n);

        len -= n;
        src += n;
        dstva = va0 + PGSIZE;
    }
    return 0;
}

int copyinstr(pagetable_t pagetable, char *dst, uint64 srcva, uint64 max)
{ // 从用户空间拷贝字符串到内核空间
    uint64 n, va0, pa0;
    int got_null = 0;

    while (got_null == 0 && max > 0)
    {
        va0 = PGROUNDDOWN(srcva);
        pa0 = walkaddr(pagetable, va0);
        if (pa0 == 0)
            return -1;
        n = PGSIZE - (srcva - va0);
        if (n > max)
            n = max;
        // 这里 n 最大为当前页的剩余字节数
        char *p = (char *)(pa0 + (srcva - va0));
        while (n > 0) // 逐字节复制
        {
            if (*p == '\0')
            {
                *dst = '\0';
                got_null = 1;
                break;
            }
            else
            {
                *dst = *p;
            }
            --n;
            --max;
            p++;
            dst++;
        }

        srcva = va0 + PGSIZE;
    }
    if (got_null)
    {
        return 0;
    }
    else
    {
        return -1;
    }
}

// 处理缺页错误的函数 返回0 表示地址越界 失败或者已经映射
// 成功返回分配的物理地址
uint64 vmfault(pagetable_t pagetable, uint64 va, int read)
{
    uint64 ka;
    struct proc *p = myproc();
    ka = 0;

    if (va >= p->sz)
        return 0;
    va = PGROUNDDOWN(va);
    if (ismapped(pagetable, va))
    {
        return 0;
    }
    ka = (uint64)kalloc();
    if (ka == 0)
        return 0;
    memset((void *)ka, 0, PGSIZE);
    if (mappages(p->pagetable, va, PGSIZE, ka, PTE_W | PTE_U | PTE_R) != 0)
    {
        kfree((void *)ka);
        return 0;
    }
    return ka;
}

// 返回 0 表示没有映射，1 表示已映射
int ismapped(pagetable_t pagetable, uint64 va)
{
    pte_t *pte = walk(pagetable, va, 0);
    if (pte == 0)
        return 0;
    if (*pte & PTE_V)
    {
        return 1; // 表示已映射
    }
    return 0;
}

uint64 uvmdealloc(pagetable_t pagetable, uint64 oldsz, uint64 newsz)
{ // 释放用户内存，oldsz 表示旧大小，newsz 表示新大小
    if (newsz >= oldsz)
        return oldsz;

    if (PGROUNDUP(newsz) < PGROUNDUP(oldsz))
    {
        uint64 a = PGROUNDUP(newsz);
        uvmunmap(pagetable, a, (PGROUNDUP(oldsz) - a) / PGSIZE, 1);
    }
    return newsz;
}

int uvmcopy(pagetable_t old, pagetable_t new, uint64 sz)
{ // 复制用户内存
    pte_t *pte;
    uint64 pa, i;
    uint flags;
    for (i = 0; i < sz; i += PGSIZE)
    {
        if ((pte = walk(old, i, 0)) == 0)
            panic("uvmcopy: pte should exist");
        if ((*pte & PTE_V) == 0)
            panic("uvmcopy: page not present");
        pa = PTE2PA(*pte);
        flags = PTE_FLAGS(*pte);
        if (mappages(new, i, PGSIZE, pa, flags) < 0)
        {
            uvmunmap(new, 0, i / PGSIZE, 1);
            return -1;
        }
    }
    return 0;
}