// 在 kernel/mm/buddy.h 中定义
#ifndef BUDDY_H
#define BUDDY_H
#include "types.h"
#include "param.h"
#include "spinlock.h"
#include "memlayout.h"

#define MAX_ORDER 10 // 支持最大 2^10 = 1024 页的连续分配
#define MIN_ORDER 0  // 最小分配单位：1页

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
struct page_info // 页面信息结构体声明 这里没有实例化，后面使用的是指针 每个页面都有，用数组存储
{
    unsigned int order; // 该页面所属块的大小（2^order页）
    unsigned int flags; // 页面标志
#define PAGE_FREE 0x01  // 页面空闲
#define PAGE_HEAD 0x02  // 块的首页面
    // #define PAGE_BUDDY 0x04 // 是否可以与伙伴页面合并
};

extern struct buddy_system buddy; // ← 改为 extern 声明
extern struct page_info *pages;   // ← 改为 extern 声明

// extern struct page_info *pages; // 页面信息数组首地址 就是一个指针，存储在 .bss 段
struct page_info *pages; // 页面信息数组首地址 就是一个指针，存储在 .bss 段
// 核心功能函数
void pmm_init(void);                           // 物理内存管理初始化
void *alloc_pages(int order);                  // 分配 2^order 个页面
void free_pages(void *page, int order);        // 释放从 page 开始的 2^order 个页面
void buddy_add_memory(void *start, void *end); // 将内存段加入管理

// 块管理函数
void mark_block_allocated(void *page, int order);
void mark_block_free(void *page, int order);

// 链表操作函数
void list_add(struct free_block *list, struct free_block *block);
void list_remove(struct free_block *block);

// 查询和检查函数
static inline int is_page_allocated(void *page);
static inline int is_page_free(void *page, int order);
static inline int is_valid_page(void *page);
static inline int is_block_head(void *page);
static inline int list_empty(struct free_block *list);

// 内部辅助函数
static void *get_buddy_block(void *page, int order);
static void *merge_buddies(void *page1, void *page2, int order);
// static void *find_block_head(void *page);
static void clear_page_info(void *page, int order);

// 测试函数
void buddy_self_test(void); // 打印伙伴系统状态

#endif