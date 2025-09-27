# 0 "kernel/buddy.c"
# 0 "<built-in>"
# 0 "<command-line>"
# 1 "/usr/riscv64-linux-gnu/include/stdc-predef.h" 1 3
# 0 "<command-line>" 2
# 1 "kernel/buddy.c"
# 1 "./include/defs.h" 1




# 1 "./include/types.h" 1



typedef unsigned int uint;
typedef unsigned short ushort;
typedef unsigned char uchar;

typedef unsigned char uint8;
typedef unsigned short uint16;
typedef unsigned int uint32;
typedef unsigned long uint64;

typedef uint64 pde_t;
# 6 "./include/defs.h" 2
# 1 "./include/spinlock.h" 1






struct spinlock
{
    uint locked;


    char *name;
    struct cpu *cpu;
};
# 7 "./include/defs.h" 2


extern char etext[], edata[], end[], sbss[];


void printf(char *fmt, ...);
void consputc(int c);
void panic(char *s);
int strlen(const char *s);
void hexdump(void *addr, int len);


void uartinit(void);
void uartputc(int c);
void uartputs(char *s);


void consoleinit(void);
void console_clear(void);
void console_set_cursor(int row, int col);
void console_set_color(int fg_color, int bg_color);
void console_reset_color(void);
int consolewrite(int user_src, uint64 src, int n);
int consoleread(int user_dst, uint64 dst, int n);
void console_flush(void);
void console_puts(const char *s);
void console_write_buf(const char *data, int len);
void consoleputc(int c);
void sync_flush(void);


void pmm_init(void);
void *alloc_pages(int);
void free_pages(void *, int);
void *alloc_page(void);
void free_page(void *);
void buddy_add_memory(void *, void *);


void main(void);
void *memset(void *dst, int c, uint n);


void initlock(struct spinlock *lk, char *name);
void acquire(struct spinlock *lk);
void release(struct spinlock *lk);
# 2 "kernel/buddy.c" 2
# 1 "./include/spinlock.h" 1
# 3 "kernel/buddy.c" 2
# 1 "./include/types.h" 1
# 4 "kernel/buddy.c" 2
# 1 "./include/param.h" 1
# 5 "kernel/buddy.c" 2
# 1 "./include/memlayout.h" 1
# 6 "kernel/buddy.c" 2
# 1 "./include/buddy.h" 1




# 1 "./include/param.h" 1
# 6 "./include/buddy.h" 2

# 1 "./include/memlayout.h" 1
# 8 "./include/buddy.h" 2





struct free_block
{
    struct free_block *next;
    struct free_block *prev;
};


struct buddy_system
{
    struct free_block free_lists[10 + 1];

    unsigned long total_pages;
    unsigned long free_pages;
    void *memory_start;
    struct spinlock lock;
};


struct page_info
{
    unsigned int order;
    unsigned int flags;



};

extern struct buddy_system buddy;
extern struct page_info *pages;


struct page_info *pages;

void pmm_init(void);
void *alloc_pages(int order);
void free_pages(void *page, int order);
void buddy_add_memory(void *start, void *end);


void mark_block_allocated(void *page, int order);
void mark_block_free(void *page, int order);


void list_add(struct free_block *list, struct free_block *block);
void list_remove(struct free_block *block);


static inline int is_page_allocated(void *page);
static inline int is_page_free(void *page, int order);
static inline int is_valid_page(void *page);
static inline int is_block_head(void *page);
static inline int list_empty(struct free_block *list);


static void *get_buddy_block(void *page, int order);
static void *merge_buddies(void *page1, void *page2, int order);

static void clear_page_info(void *page, int order);
# 7 "kernel/buddy.c" 2


struct buddy_system buddy;
struct page_info *pages;



void buddy_print_stats(void)
{
    printf("=== Buddy System Stats ===\n");
    printf("Memory start: %p\n", buddy.memory_start);
    printf("Total pages: %lu\n", buddy.total_pages);
    printf("Free pages: %lu\n", buddy.free_pages);
    printf("Used pages: %lu\n", buddy.total_pages - buddy.free_pages);

    printf("\nFree lists:\n");
    for (int i = 0; i <= 10; i++)
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


void pmm_init(void)
{
    printf("buddy init begin ... \n");

    void *mem_start = (void *)((((uint64)end)+4096 -1) & ~(4096 -1));
    void *mem_end = (void *)0x88000000L;
    buddy.total_pages = ((uint64)mem_end - (uint64)mem_start) / 4096;
    buddy.memory_start = mem_start;
    buddy.free_pages = 0;
    printf("debug : end - %p \n", end);
    printf("debug : %p - %p , total pages = %d \n", mem_start, mem_end, buddy.total_pages);

    pages = (struct page_info *)mem_start;

    buddy.memory_start = (void *)((((uint64)pages + buddy.total_pages * sizeof(struct page_info))+4096 -1) & ~(4096 -1));
    buddy.total_pages = ((uint64)mem_end - (uint64)buddy.memory_start) / 4096;
# 70 "kernel/buddy.c"
    for (int i = 0; i <= 10; i++)
    {
        buddy.free_lists[i].next = &buddy.free_lists[i];
        buddy.free_lists[i].prev = &buddy.free_lists[i];
    }


    initlock(&buddy.lock, "buddy");


    buddy_add_memory(buddy.memory_start, mem_end);

    printf("Buddy system initialized: %d pages available\n", buddy.total_pages);
    buddy_print_stats();
}

void *alloc_pages(int order)
{
    if (order < 0 || order > 10)
        panic("alloc_pages: invalid order");

    acquire(&buddy.lock);


    int current_order = order;
    while (current_order <= 10)
    {
        if (!list_empty(&buddy.free_lists[current_order]))
        {

            struct free_block *block = buddy.free_lists[current_order].next;
            list_remove(block);

            void *page = (void *)block;


            while (current_order > order)
            {
                current_order--;
                void *buddy_page = (char *)page + (1UL << current_order) * 4096;


                list_add(&buddy.free_lists[current_order], (struct free_block *)buddy_page);
                mark_block_free(buddy_page, current_order);
            }


            mark_block_allocated(page, order);
            buddy.free_pages -= (1UL << order);

            release(&buddy.lock);
            return page;
        }
        current_order++;
    }

    release(&buddy.lock);
    return 0;
}

void free_pages(void *page, int order)
{
    if (!page || order < 0 || order > 10)
        return;

    acquire(&buddy.lock);


    if (is_block_head(page) == 0)
    {
        panic("free_pages: page is not block head !");
    }
    mark_block_free(page, order);
    buddy.free_pages += (1UL << order);


    while (order < 10)
    {
        void *buddy_page = get_buddy_block(page, order);


        if (!is_valid_page(buddy_page) || !is_page_free(buddy_page, order))
            break;


        list_remove((struct free_block *)buddy_page);
        clear_page_info(buddy_page, order);


        page = merge_buddies(page, buddy_page, order);
        order++;
        mark_block_free(page, order);
    }


    list_add(&buddy.free_lists[order], (struct free_block *)page);

    release(&buddy.lock);
}

static void clear_page_info(void *page, int order)
{
    uint64 start_pfn = ((uint64)page - (uint64)buddy.memory_start) / 4096;
    uint64 count = 1UL << order;

    for (uint64 i = 0; i < count; i++)
    {
        pages[start_pfn + i].flags = 0;
        pages[start_pfn + i].order = 0;
    }
}

void mark_block_allocated(void *page, int order)
{






    uint64 start_pfn = ((uint64)page - (uint64)buddy.memory_start) / 4096;
    uint64 count = 1UL << order;

    for (uint64 i = 0; i < count; i++)
    {
        pages[start_pfn + i].flags &= ~0x01;

        if (i == 0)
        {

            pages[start_pfn].order = order;
            pages[start_pfn].flags |= 0x02;
        }
        else
        {

            pages[start_pfn + i].order = 0;
            pages[start_pfn + i].flags &= ~0x02;
        }
    }
}

void mark_block_free(void *page, int order)
{





    uint64 start_pfn = ((uint64)page - (uint64)buddy.memory_start) / 4096;
    uint64 count = 1UL << order;

    for (uint64 i = 0; i < count; i++)
    {
        pages[start_pfn + i].flags |= 0x01;

        if (i == 0)
        {

            pages[start_pfn].order = order;
            pages[start_pfn].flags |= 0x02;
        }
        else
        {

            pages[start_pfn + i].order = 0;
            pages[start_pfn + i].flags &= ~0x02;
        }
    }
}

void list_add(struct free_block *list, struct free_block *block)
{
    block->next = list->next;
    block->prev = list;
    list->next->prev = block;
    list->next = block;
}
void list_remove(struct free_block *block)
{
    block->prev->next = block->next;
    block->next->prev = block->prev;

}

static inline int is_page_allocated(void *page)
{
    struct page_info *info = &pages[((uint64)page - (uint64)buddy.memory_start) / 4096];
    return (info->flags & 0x01) == 0;
}

static inline int is_page_free(void *page, int order)
{
    struct page_info *info = &pages[((uint64)page - (uint64)buddy.memory_start) / 4096];
    return (info->flags & 0x01) && (info->order == order);
}

static void *get_buddy_block(void *page, int order)
{
    if (is_block_head(page) == 0)
    {
        panic("get_buddy_block: page is not block head !");
    }
    uint64 pfn = ((uint64)page - (uint64)buddy.memory_start) / 4096;


    uint64 buddy_pfn = pfn ^ (1UL << order);

    return (void *)((uint64)buddy.memory_start + buddy_pfn * 4096);
}
# 288 "kernel/buddy.c"
void buddy_add_memory(void *start, void *end)
{
    char *p = (char *)((((uint64)start)+4096 -1) & ~(4096 -1));

    while (p + 4096 <= (char *)end)
    {

        int order = 0;
        uint64 pfn = ((uint64)p - (uint64)buddy.memory_start) / 4096;


        while (order < 10 &&
               (pfn & ((1UL << order) - 1)) == 0 &&
               p + ((1UL << (order + 1)) * 4096) <= (char *)end)
        {
            order++;
        }


        mark_block_free(p, order);
        list_add(&buddy.free_lists[order], (struct free_block *)p);
        buddy.free_pages += (1UL << order);

        p += (1UL << order) * 4096;
    }
}

static inline int list_empty(struct free_block *list)
{
    return list->next == list;
}

static inline int is_valid_page(void *page)
{
    return page >= buddy.memory_start &&
           page < (void *)((uint64)buddy.memory_start + buddy.total_pages * 4096) &&
           ((uint64)page & (4096 - 1)) == 0;
}

static void *merge_buddies(void *page1, void *page2, int order)
{

    return ((uint64)page1 < (uint64)page2) ? page1 : page2;
}

static inline int is_block_head(void *page)
{

    return pages[((uint64)page - (uint64)buddy.memory_start) / 4096].flags & 0x02;
}
