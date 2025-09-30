// include/defs.h
#ifndef DEFS_H
#define DEFS_H

#include "types.h"
#include "spinlock.h"

// 符号声明
extern char etext[], edata[], end[], sbss[]; // 链接器符号

// printf.c
void printf(char *fmt, ...);
void consputc(int c);
void panic(char *s);
int strlen(const char *s);
void hexdump(void *addr, int len);

// uart.c
void uartinit(void);
void uartputc(int c);
void uartputs(char *s);

// console.c
void consoleinit(void);
void console_clear(void);
void console_set_cursor(int row, int col);
void console_set_color(int fg_color, int bg_color);
void console_reset_color(void);
int consolewrite(int user_src, uint64 src, int n);
int consoleread(int user_dst, uint64 dst, int n);
void console_flush(void); // 刷新输出缓冲区
void console_puts(const char *s);
void console_write_buf(const char *data, int len);
void consoleputc(int c); // 输出单个字符到控制台
void sync_flush(void);   // 刷新控制台输出缓冲区

// buddy.c
void pmm_init(void);
void *alloc_pages(int);
void free_pages(void *, int);
void *alloc_page(void);
void free_page(void *);
void buddy_add_memory(void *, void *);
void buddy_self_test(void);
// 对外提供的接口
void *kalloc(void);     // 分配单个页面
void kfree(void *page); // 释放单个页面

// main.c
void main(void);
void *memset(void *dst, int c, uint n);

// spinlock.c
void initlock(struct spinlock *lk, char *name);
void acquire(struct spinlock *lk);
void release(struct spinlock *lk);

// vm.c
pagetable_t create_pagetable(void);
int map_page(pagetable_t pt, uint64 va, uint64 pa, int perm);
void destory_pagetable(pagetable_t pt);
pte_t *walk_lookup(pagetable_t pt, uint64 va);
void kvminit(void);
void kvminithart(void);
uint64 kvmpa(uint64 va);
uint64 walkaddr(pagetable_t pt, uint64 va);
int mappages(pagetable_t pt, uint64 va, uint64 size, uint64 pa, int perm);
extern pagetable_t kernel_pagetable;
// void freewalk(pagetable_t pt);

// timer.c
void timer_set_next();
uint64 get_time();
void set_timer(uint64 when);

// trap.c
void kerneltrap();
void trapinit();
void trapinithart();
void kernelvec(); // 内核异常处理入口
void timervec();  // 定时器中断处理入口

// debug.c
void print_scause();
void print_test();
void pmm_basic_test();
void assert(int condition);
void pagetable_test();
void pagetable_test_enhanced();
void virtual_memory_test();
void timer_interrupt_test(int);

// 全局变量
extern volatile int *test_flag; // 用于测试中断处理函数是否被调用

#endif
