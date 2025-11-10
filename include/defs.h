// include/defs.h
#ifndef DEFS_H
#define DEFS_H

#include "types.h"
#include "spinlock.h"
#include "proc.h"

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

// spinlock.c
void acquire(struct spinlock *);
int holding(struct spinlock *);
void initlock(struct spinlock *, char *);
void release(struct spinlock *);
void push_off(void);
void pop_off(void);

// vm.c
pagetable_t create_pagetable(void);
int map_page(pagetable_t pt, uint64 va, uint64 pa, int perm);
void destory_pagetable(pagetable_t pt);
pte_t *walk_lookup(pagetable_t pt, uint64 va);
void kvminit(void);
void kvminithart(void);
uint64 kvmpa(uint64 va);
void kvmmap(pagetable_t pt, uint64 va, uint64 pa, uint64 sz, int perm);
uint64 walkaddr(pagetable_t pt, uint64 va);
int mappages(pagetable_t pt, uint64 va, uint64 size, uint64 pa, int perm);
extern pagetable_t kernel_pagetable;
// void freewalk(pagetable_t pt);
// uint64 proc_pagetable(struct proc *p);
pagetable_t uvmcreate();
uint64 uvmalloc(pagetable_t pagetable, uint64 oldsz, uint64 newsz, int perm);
uint64 uvmdealloc(pagetable_t pagetable, uint64 oldsz, uint64 newsz);
int uvmcopy(pagetable_t old, pagetable_t new, uint64 sz);
void uvmclear(pagetable_t pagetable, uint64 va);
void uvmfree(pagetable_t pagetable, uint64 sz);
int copyout(pagetable_t pagetable, uint64 dstva, char *src, uint64 len);
uint64 vmfault(pagetable_t pagetable, uint64 va, int read);
int ismapped(pagetable_t pagetable, uint64 va);
int copyinstr(pagetable_t pagetable, char *dst, uint64 srcva, uint64 len);
int copyin(pagetable_t pagetable, char *dst, uint64 srcva, uint64 len);
void uvmunmap(pagetable_t pagetable, uint64 va, uint64 npages, int do_free);

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

#define MAX_IRQS 1024

// debug.c
void print_scause();
void print_test();
void pmm_basic_test();
void assert(int condition);
void pagetable_test();
void pagetable_test_enhanced();
void virtual_memory_test();
void clockintr_test();
// void process_creation_test();
void fork_test_main();
void test_process_creation();
void test_scheduler();
// void process_init();

// plic.c
void plicinit(void);
void plicinithart(void);
uint64 plic_claim(void);
void plic_complete(int irq);
void plic_enable(int irq);
void plic_disable(int irq);

// proc.c
void procinit(void);
struct cpu *mycpu(void);
uint64 cpuid(void);
struct proc *myproc(void);
int fork(void);
void exit(int);
int wait(uint64 addr);
void yield(void);
void sleep(void *chan, struct spinlock *lk);
void wakeup(void *chan);
int kill(int pid);
void setkilled(struct proc *p);
int killed(struct proc *p);
void sched(void);
void scheduler(void);
void procdump(void);
void reparent(struct proc *p);
void userinit(void);
int shrinkproc(int);
void main_proc_init();
int create_process(void (*func)(void));
int wait_process(void);
void mapkstacks(pagetable_t kpgtbl);

// string.c
void *memset(void *dst, int c, uint n);
void *memmove(void *dst, const void *src, uint n);
char *safestrcpy(char *dst, const char *src, int n);

// swtch.S
void swtch(struct context *, struct context *);

// trampoline.S
// void trampoline();

// syscall.c
void argint(int, int *);
int argstr(int, char *, int);
void argaddr(int, uint64 *);
int fetchstr(uint64, char *, int);
int fetchaddr(uint64, uint64 *);
void syscall();

#define NELEM(x) (sizeof(x) / sizeof((x)[0]))
void prepare_return(void);

#endif
