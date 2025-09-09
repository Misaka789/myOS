// include/defs.h
#ifndef DEFS_H
#define DEFS_H

#include "types.h"

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

// main.c
void main(void);
void *memset(void *dst, int c, uint n);

#endif