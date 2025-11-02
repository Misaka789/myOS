// 注册内核实现函数
#include "types.h"
#include "param.h"
#include "memlayout.h"
#include "riscv.h"
#include "spinlock.h"
#include "proc.h"
#include "syscall.h"
#include "defs.h"

// extern uint64 sys_fork(void);
// extern uint64 sys_exit(void);
// extern uint64 sys_wait(void);
// extern uint64 sys_pipe(void);
// extern uint64 sys_read(void);
// extern uint64 sys_kill(void);
// extern uint64 sys_exec(void);
// extern uint64 sys_fstat(void);
// extern uint64 sys_chdir(void);
// extern uint64 sys_dup(void);
// extern uint64 sys_getpid(void);
// extern uint64 sys_sbrk(void);
// extern uint64 sys_sleep(void);
// extern uint64 sys_uptime(void);
// extern uint64 sys_open(void);
// extern uint64 sys_write(void);
// extern uint64 sys_mknod(void);
// extern uint64 sys_unlink(void);
// extern uint64 sys_link(void);
// extern uint64 sys_mkdir(void);
// extern uint64 sys_close(void);

uint64 sys_hello(void)
{
  printf("Hello world");
  return 0;
}
static uint64 (*syscalls[])(void) = {
    [SYS_hello] sys_hello,
};

// static uint64 (*syscalls[])(void) = {
//     [SYS_fork] sys_fork,
//     [SYS_exit] sys_exit,
//     [SYS_wait] sys_wait,
//     [SYS_pipe] sys_pipe,
//     [SYS_read] sys_read,
//     [SYS_kill] sys_kill,
//     [SYS_exec] sys_exec,
//     [SYS_fstat] sys_fstat,
//     [SYS_chdir] sys_chdir,
//     [SYS_dup] sys_dup,
//     [SYS_getpid] sys_getpid,
//     [SYS_sbrk] sys_sbrk,
//     [SYS_sleep] sys_sleep,
//     [SYS_uptime] sys_uptime,
//     [SYS_open] sys_open,
//     [SYS_write] sys_write,
//     [SYS_mknod] sys_mknod,
//     [SYS_unlink] sys_unlink,
//     [SYS_link] sys_link,
//     [SYS_mkdir] sys_mkdir,
//     [SYS_close] sys_close,
// };

/*
从用户空间的 addr 地址出取出一个 64 位整数，存放到内核空间的 ip 指针指向的变量中。
返回 0 表示成功，-1 表示失败（例如地址无效）。
*/
int fetchaddr(uint64 addr, uint64 *ip)
{
  struct proc *p = myproc();
  if (addr >= p->sz || addr + sizeof(uint64) > p->sz)
    return -1;
  if (copyin(p->pagetable, (char *)ip, addr, sizeof(*ip)) != 0)
    return -1;
  return 0;
}

/*
从 用户空间 addr 地址处读取一个以 \0 结尾的字符串，
存放到内核空间的 buf 缓冲区中，最多读取 max 个字节。
*/
int fetchstr(uint64 addr, char *buf, int max)
{
  struct proc *p = myproc();
  if (copyinstr(p->pagetable, buf, addr, max) < 0)
    return -1;
  return strlen(buf);
}

/*
获取第 n 个系统调用参数的原始值（未处理）。
这个值直接从保存在陷阱里的寄存器中读取

*/
static uint64 argraw(int n)
{
  struct proc *p = myproc();
  switch (n)
  {
  case 0:
    return p->trapframe->a0;
  case 1:
    return p->trapframe->a1;
  case 2:
    return p->trapframe->a2;
  case 3:
    return p->trapframe->a3;
  case 4:
    return p->trapframe->a4;
  case 5:
    return p->trapframe->a5;
  }
  panic("argraw");
  return -1;
}

/*
将第 n 个系统调用参数作为整数来获取，
并存放到 ip 指针指向的内核变量中。
*/
void argint(int n, int *ip)
{
  *ip = argraw(n);
}

void argaddr(int n, uint64 *ip)
{
  *ip = argraw(n);
}

int argstr(int n, char *buf, int max)
{
  uint64 addr;
  argaddr(n, &addr);
  return fetchstr(addr, buf, max);
}

void syscall(void) // ecall 发生之后陷阱处理程序会调用这个函数
{
  int num;
  struct proc *p = myproc();

  num = p->trapframe->a7; // 系统调用号存储在 a7 寄存器中
  if (num > 0 && num < NELEM(syscalls) && syscalls[num])
  {
    // 使用 num 查找系统调用函数并调用它
    p->trapframe->a0 = syscalls[num](); // 将返回值存储在 a0 寄存器中
  }
  else
  {
    // 处理无效的系统调用号
    printf("%d %s: unknown sys call %d\n", p->pid, p->name, num);
    p->trapframe->a0 = -1; // 返回错误码
  }
}