// include/defs.h
#ifndef DEFS_H
#define DEFS_H

#include "types.h"
#include "spinlock.h"

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

// main.c
void main(void);
void *memset(void *dst, int c, uint n);

// spinlock.c
void initlock(struct spinlock *lk, char *name);
void acquire(struct spinlock *lk);
void release(struct spinlock *lk);

#endif