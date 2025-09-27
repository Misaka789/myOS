#include "types.h"
#include "param.h"

/* 明确声明链接器符号，放在最前面，避免被其它宏/声明覆盖 */
extern char etext[], edata[], end[], sbss[];

#include "defs.h"
#include "spinlock.h"
#include "memlayout.h"
#include "buddy.h"

struct buddy_system buddy; // 这个结构体存储在.bss 段中，永远都不会被释放
struct page_info *pages;   // 页面信息数组首地址 就是一个指针，存储在 .bss 段

// =========== Test ===========

void *alloc_page(void)
{
    return alloc_pages(0);
}

void free_page(void *p)
{
    if (p)
        free_pages(p, 0);
}

void buddy_print_stats(void)
{
    printf("=== Buddy System Stats ===\n");
    printf("Memory start: %p\n", buddy.memory_start);
    printf("Total pages: %d\n", buddy.total_pages);
    printf("Free pages: %d\n", buddy.free_pages);
    printf("Used pages: %d\n", buddy.total_pages - buddy.free_pages);

    printf("\nFree lists:\n");
    for (int i = 0; i <= MAX_ORDER; i++)
    {
        int count = 0;
        struct free_block *block = buddy.free_lists[i].next;
        while (block != &buddy.free_lists[i])
        {
            count++;
            block = block->next;
        }
        if (count > 0)
        {
            printf("Order %d: %d blocks (%d pages total)\n",
                   i, count, count * (1 << i));
        }
    }
    printf("========================\n\n");
}
// ===========  Test ============

void *kalloc(void) // 分配单个页面
{
    void *p = alloc_pages(0);
    if (p)
        memset(p, 0, PGSIZE); // 分配的页面清零
    return p;
}

void kfree(void *page) // 释放单个页面
{
    if (page == 0)
        return;
    free_pages(page, 0);
    return;
}

void pmm_init(void)
{
    printf("buddy init begin ... \n");
    // 1. 计算可用内存范围
    void *mem_start = (void *)PGROUNDUP((uint64)end);
    void *mem_end = (void *)PHYSTOP;
    buddy.total_pages = ((uint64)mem_end - (uint64)mem_start) / PGSIZE;
    buddy.memory_start = mem_start;
    buddy.free_pages = 0;
    printf("debug : end - %p \n", end);
    printf("debug : %p - %p , total pages = %d \n", mem_start, mem_end, buddy.total_pages);
    // 2. 分配页面信息数组 在可用物理空间的起始地址分配这个数组 ，之后紧跟着 bitmap 分配
    pages = (struct page_info *)mem_start;

    buddy.memory_start = (void *)PGROUNDUP((uint64)pages + buddy.total_pages * sizeof(struct page_info));
    buddy.total_pages = ((uint64)mem_end - (uint64)buddy.memory_start) / PGSIZE;

    //  void *bitmap_start = (void *)pages + buddy.total_pages * sizeof(struct page_info);

    // 3. 分配位图
    // uint64 bitmap_size = (buddy.total_pages + 7) / 8; // 向上取整
    // buddy.bitmap = (unsigned long *)bitmap_start;

    // 4. 调整可用内存起始地址 在可用物理地址中插入 pages 和 bitmap 的空间 后面才是真正可以用来分配的物理空间
    //  buddy.memory_start = (void *)PGROUNDUP((uint64)bitmap_start + bitmap_size);
    //  buddy.total_pages = ((uint64)mem_end - (uint64)buddy.memory_start) / PGSIZE;

    printf("debug: after pages allocated , %p - %p \n", buddy.memory_start, mem_end);
    printf("debug: total pages = %d \n", buddy.total_pages);

    // 5. 初始化空闲链表
    for (int i = 0; i <= MAX_ORDER; i++)
    {
        buddy.free_lists[i].next = &buddy.free_lists[i];
        buddy.free_lists[i].prev = &buddy.free_lists[i];
    }

    // 6. 初始化锁
    initlock(&buddy.lock, "buddy");

    // 7. 将所有内存加入空闲池
    buddy_add_memory(buddy.memory_start, mem_end);

    printf("Buddy system initialized: %d pages available\n", buddy.total_pages);
    buddy_print_stats();
}

void *alloc_pages(int order)
{
    if (order < 0 || order > MAX_ORDER)
        panic("alloc_pages: invalid order");

    acquire(&buddy.lock);

    // 查找合适的空闲块
    int current_order = order;
    while (current_order <= MAX_ORDER) // 当前 order 对应的块不够大就继续往上查
    {
        if (!list_empty(&buddy.free_lists[current_order]))
        {
            // 找到空闲块，从链表中移除 表示已使用 buddy.free_lists[current_order]
            struct free_block *block = buddy.free_lists[current_order].next;
            list_remove(block);

            void *page = (void *)block;

            // 如果块太大，需要分割  比如现在只需要 2 页的空间，但找到的最小是 4 页的块
            while (current_order > order)
            {
                current_order--;
                void *buddy_page = (char *)page + (1UL << current_order) * PGSIZE;

                // 将分割出的伙伴块加入对应链表
                list_add(&buddy.free_lists[current_order], (struct free_block *)buddy_page);
                mark_block_free(buddy_page, current_order);
            }

            // 标记页面为已分配
            mark_block_allocated(page, order);
            buddy.free_pages -= (1UL << order);

            release(&buddy.lock);
            return page;
        }
        current_order++;
    }

    release(&buddy.lock);
    return 0; // 内存不足
}

void free_pages(void *page, int order)
{
    if (!page || order < 0 || order > MAX_ORDER)
        return;

    acquire(&buddy.lock);

    // 标记页面为空闲
    if (is_block_head(page) == 0)
    {
        panic("free_pages: page is not block head !");
    }
    mark_block_free(page, order);
    buddy.free_pages += (1UL << order);

    // 尝试与伙伴合并
    while (order < MAX_ORDER)
    {
        void *buddy_page = get_buddy_block(page, order);

        // 检查伙伴是否存在且空闲
        if (!is_valid_page(buddy_page) || !is_page_free(buddy_page, order))
            break;

        // 从空闲链表中移除伙伴
        list_remove((struct free_block *)buddy_page);
        clear_page_info(buddy_page, order); // 清除伙伴的 page_info 信息

        // 合并伙伴
        page = merge_buddies(page, buddy_page, order);
        order++;
        mark_block_free(page, order);
    }

    // 将合并后的块加入空闲链表
    list_add(&buddy.free_lists[order], (struct free_block *)page);

    release(&buddy.lock);
}

static void clear_page_info(void *page, int order)
{
    uint64 start_pfn = ((uint64)page - (uint64)buddy.memory_start) / PGSIZE;
    uint64 count = 1UL << order;

    for (uint64 i = 0; i < count; i++)
    {
        pages[start_pfn + i].flags = 0;
        pages[start_pfn + i].order = 0;
    }
}

void mark_block_allocated(void *page, int order) // 标记页面为已分配 操作对应的 page 数组
{
    // if (is_block_head(page) == 0)
    // {
    //     panic("mark_block_allocated: page is not block head !");
    // }
    // 新分配的块可能不是块头

    uint64 start_pfn = ((uint64)page - (uint64)buddy.memory_start) / PGSIZE;
    uint64 count = 1UL << order;

    for (uint64 i = 0; i < count; i++)
    {
        pages[start_pfn + i].flags &= ~PAGE_FREE; // 清除空闲标志

        if (i == 0)
        {
            // 只有第一个页面是块头
            pages[start_pfn].order = order;
            pages[start_pfn].flags |= PAGE_HEAD;
        }
        else
        {
            // 其他页面不是块头
            pages[start_pfn + i].order = 0;
            pages[start_pfn + i].flags &= ~PAGE_HEAD;
        }
    }
}

void mark_block_free(void *page, int order) // 标记页面为空闲 传入的page 必须是块头的page 地址
{

    // if (is_block_head(page) == 0)
    // {
    //     panic("mark_block_free: page is not block head !");
    // }
    uint64 start_pfn = ((uint64)page - (uint64)buddy.memory_start) / PGSIZE;
    uint64 count = 1UL << order;

    for (uint64 i = 0; i < count; i++)
    {
        pages[start_pfn + i].flags |= PAGE_FREE; // 设置空闲标志

        if (i == 0)
        {
            // 只有第一个页面是块头
            pages[start_pfn].order = order;
            pages[start_pfn].flags |= PAGE_HEAD;
        }
        else
        {
            // 其他页面不是块头
            pages[start_pfn + i].order = 0;
            pages[start_pfn + i].flags &= ~PAGE_HEAD;
        }
    }
}

void list_add(struct free_block *list, struct free_block *block) // 将块添加到空闲链表
{
    block->next = list->next;
    block->prev = list;
    list->next->prev = block;
    list->next = block;
}
void list_remove(struct free_block *block) // 从链表中移除块
{
    block->prev->next = block->next;
    block->next->prev = block->prev;
    // 只是断开链表连接，不涉及内存大小
}

static inline int is_page_allocated(void *page)
{
    struct page_info *info = &pages[((uint64)page - (uint64)buddy.memory_start) / PGSIZE];
    return (info->flags & PAGE_FREE) == 0;
}

static inline int is_page_free(void *page, int order)
{
    struct page_info *info = &pages[((uint64)page - (uint64)buddy.memory_start) / PGSIZE];
    return (info->flags & PAGE_FREE) && (info->order == order);
}

static void *get_buddy_block(void *page, int order)
{
    if (is_block_head(page) == 0)
    {
        panic("get_buddy_block: page is not block head !");
    }
    uint64 pfn = ((uint64)page - (uint64)buddy.memory_start) / PGSIZE;

    // 伙伴算法的核心：XOR 操作
    uint64 buddy_pfn = pfn ^ (1UL << order);

    return (void *)((uint64)buddy.memory_start + buddy_pfn * PGSIZE);
}
// 例子：order=2 (4页块)
// 如果块A从页面8开始 (pfn=8, 二进制: 1000)
// 伙伴B的pfn = 8 ^ (1<<2) = 8 ^ 4 = 12 (二进制: 1100)

// 如果块B从页面12开始 (pfn=12, 二进制: 1100)
// 伙伴A的pfn = 12 ^ 4 = 8 (二进制: 1000)
// 互为伙伴！

void buddy_add_memory(void *start, void *end) // 将一段内存加入伙伴系统管理,格式化物理内存
{
    char *p = (char *)PGROUNDUP((uint64)start);

    while (p + PGSIZE <= (char *)end)
    {
        // 计算当前位置能形成的最大块大小
        int order = 0;
        uint64 pfn = ((uint64)p - (uint64)buddy.memory_start) / PGSIZE;

        // 找到最大的对齐块大小
        while (order < MAX_ORDER &&
               (pfn & ((1UL << order) - 1)) == 0 && // 地址对齐检查
               p + ((1UL << (order + 1)) * PGSIZE) <= (char *)end)
        { // 不超出范围
            order++;
        }

        // 标记为空闲并加入链表
        mark_block_free(p, order);
        list_add(&buddy.free_lists[order], (struct free_block *)p);
        buddy.free_pages += (1UL << order);

        p += (1UL << order) * PGSIZE;
    }
}

static inline int list_empty(struct free_block *list)
{
    return list->next == list;
}

static inline int is_valid_page(void *page)
{
    return page >= buddy.memory_start &&
           page < (void *)((uint64)buddy.memory_start + buddy.total_pages * PGSIZE) &&
           ((uint64)page & (PGSIZE - 1)) == 0; // 页面对齐检查
}

static void *merge_buddies(void *page1, void *page2, int order)
{
    // 返回地址较小的页面作为合并后的块头
    return ((uint64)page1 < (uint64)page2) ? page1 : page2;
}

static inline int is_block_head(void *page)
{
    // 检查是否为块头
    return pages[((uint64)page - (uint64)buddy.memory_start) / PGSIZE].flags & PAGE_HEAD;
}
/*
static void *find_block_head(void *page)
{
    if (!is_valid_page(page))
        return 0;

    if (is_block_head(page))
    {
        return page;
    }

    uint64 pfn = ((uint64)page - (uint64)buddy.memory_start) / PGSIZE;

    while (pfn > 0 && !(pages[pfn].flags & PAGE_HEAD))
    {
        pfn--;
    }

    if (pfn < buddy.total_pages && (pages[pfn].flags & PAGE_HEAD))
    {
        return (void *)((uint64)buddy.memory_start + pfn * PGSIZE);
    }
    panic("find_block_head: no block head found!");
    // return 0; // 没找到
} */

void buddy_self_test(void)
{
    void *buf[32];
    int orders[] = {0, 1, 2, 3, 0, 1, 0, 2, 1, 0};
    int n = sizeof(orders) / sizeof(orders[0]);

    printf("=== buddy self test START ===\n");

    // 基本分配/释放
    for (int i = 0; i < n; i++)
    {
        buf[i] = alloc_pages(orders[i]);
        printf("alloc order=%d -> %p\n", orders[i], buf[i]);
        if (buf[i] && (((uint64)buf[i] & (PGSIZE - 1)) != 0))
            panic("buddy_self_test: returned address not page aligned");
    }

    // 检查一致性（free_pages + list counts）
    buddy_print_stats();

    // 释放并验证合并
    for (int i = 0; i < n; i++)
    {
        if (buf[i])
        {
            printf("free order=%d -> %p\n", orders[i], buf[i]);
            free_pages(buf[i], orders[i]);
        }
    }

    // 再次打印并运行完整性检查（手动实现的或查看 pages 内容）
    buddy_print_stats();

    // 压力测试：重复分配释放
    for (int r = 0; r < 200; r++)
    {
        int o = r % (MAX_ORDER + 1);
        void *p = alloc_pages(o);
        if (p)
            free_pages(p, o);
    }
    printf("=== buddy self test END ===\n");
}