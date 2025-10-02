#ifndef RISCV_H
#define RISCV_H

#include "types.h"

#ifndef PGSIZE
#define PGSIZE 4096
#endif
#ifndef PGSHIFT
#define PGSHIFT 12
#endif
#ifndef PGROUNDUP
#define PGROUNDUP(sz) (((sz) + PGSIZE - 1) & ~(PGSIZE - 1))
#endif
#ifndef PGROUNDDOWN
#define PGROUNDDOWN(a) ((a) & ~(PGSIZE - 1))
#endif

#ifndef PTE_V
#define PTE_V (1L << 0)
#define PTE_R (1L << 1)
#define PTE_W (1L << 2)
#define PTE_X (1L << 3)
#define PTE_U (1L << 4)
#endif

#ifndef PA2PTE
#define PA2PTE(pa) ((((uint64)(pa)) >> 12) << 10)
#endif
#ifndef PTE2PA
#define PTE2PA(pte) (((pte) >> 10) << 12)
#endif

#ifndef PX
#define PXMASK 0x1FF
#define PXSHIFT(level) (PGSHIFT + 9 * (level))
#define PX(level, va) ((((uint64)(va)) >> PXSHIFT(level)) & PXMASK)
#endif

// 读取 mhartid CSR (machine hart ID)

static inline uint64
r_tp()
{
  uint64 x;
  asm volatile("mv %0, tp" : "=r"(x));
  return x;
}

static inline void
w_tp(uint64 x)
{
  asm volatile("mv tp, %0" : : "r"(x));
}

static inline uint64
r_mhartid()
{
  uint64 x;
  asm volatile("csrr %0, mhartid" : "=r"(x));
  return x;
}

// 读取机器状态寄存器 mstatus
static inline uint64
r_mstatus()
{
  uint64 x;
  asm volatile("csrr %0, mstatus" : "=r"(x));
  return x;
}

// 写入机器状态寄存器 mstatus
static inline void
w_mstatus(uint64 x)
{
  asm volatile("csrw mstatus, %0" : : "r"(x));
}

// 机器状态寄存器位定义
#define MSTATUS_MPP_MASK (3L << 11) // 之前的特权模式
#define MSTATUS_MPP_M (3L << 11)    // 机器模式
#define MSTATUS_MPP_S (1L << 11)    // 监管者模式
#define MSTATUS_MIE (1L << 3)       // 机器中断使能
#define MSTATUS_MPIE (1L << 7)      // 机器中断使能位的前一个值

// 读取机器中断使能寄存器 mie
static inline uint64
r_mie()
{
  uint64 x;
  asm volatile("csrr %0, mie" : "=r"(x));
  return x;
}

// 写入机器中断使能寄存器 mie
static inline void
w_mie(uint64 x)
{
  asm volatile("csrw mie, %0" : : "r"(x));
}

#define MIE_MEIE (1L << 11) // 机器外部中断
#define MIE_MTIE (1L << 7)  // 机器定时器中断
#define MIE_MSIE (1L << 3)  // 机器软件中断

// 写入机器陷阱向量基址寄存器 mtvec
static inline void
w_mtvec(uint64 x)
{
  asm volatile("csrw mtvec, %0" : : "r"(x));
}

// 读取和写入 mepc 寄存器
static inline uint64 r_mepc()
{
  uint64 x;
  asm volatile("csrr %0, mepc" : "=r"(x));
  return x;
}

static inline void w_mepc(uint64 x)
{
  asm volatile("csrw mepc, %0" : : "r"(x));
}

static inline void w_satp(uint64 x)
{
  asm volatile("csrw satp, %0" : : "r"(x));
}

static inline uint64 r_satp()
{
  uint64 x;
  asm volatile("csrr %0, satp" : "=r"(x));
  return x;
}

static inline void sfence_vma()
{
  asm volatile("sfence.vma zero, zero");
}

// 中断处理
static inline uint64 r_scause()
{
  uint64 x;
  asm volatile("csrr %0, scause" : "=r"(x));
  return x;
}
static inline uint64 r_mcause()
{
  uint64 x;
  asm volatile("csrr %0, mcause" : "=r"(x));
  return x;
}

static inline uint64 r_sepc()
{
  uint64 x;
  asm volatile("csrr %0, sepc" : "=r"(x));
  return x;
}
static inline void w_sepc(uint64 x) { asm volatile("csrw sepc, %0" ::"r"(x)); }
static inline uint64 r_stval()
{
  uint64 x;
  asm volatile("csrr %0, stval" : "=r"(x));
  return x;
}
static inline uint64 r_sstatus()
{
  uint64 x;
  asm volatile("csrr %0, sstatus" : "=r"(x));
  return x;
}
static inline void w_sstatus(uint64 x) { asm volatile("csrw sstatus, %0" ::"r"(x)); }
static inline void w_stvec(uint64 x) { asm volatile("csrw stvec, %0" ::"r"(x)); }
static inline uint64 r_stvec()
{
  uint64 x;
  asm volatile("csrr %0, stvec" : "=r"(x));
  return x;
}
#define SSTATUS_SIE (1 << 1)
static inline void intr_on() { w_sstatus(r_sstatus() | SSTATUS_SIE); }
static inline void intr_off() { w_sstatus(r_sstatus() & ~SSTATUS_SIE); }
static inline int
intr_get()
{
  uint64 x = r_sstatus();
  return (x & SSTATUS_SIE) != 0;
}
// 监管者模式中断处理
static inline void w_medeleg(uint64 x) { asm volatile("csrw medeleg, %0" ::"r"(x)); }
static inline void w_mideleg(uint64 x) { asm volatile("csrw mideleg, %0" ::"r"(x)); }
static inline uint64 r_sie()
{
  uint64 x;
  asm volatile("csrr %0, sie" : "=r"(x));
  return x;
}
static inline void w_sie(uint64 x) { asm volatile("csrw sie, %0" ::"r"(x)); }
static inline uint64 r_sip()
{
  uint64 x;
  asm volatile("csrr %0, sip" : "=r"(x));
  return x;
}
static inline void w_sip(uint64 x) { asm volatile("csrw sip, %0" ::"r"(x)); }
static inline uint64 r_time()
{
  uint64 x;
  asm volatile("csrr %0, time" : "=r"(x));
  return x;
}
#define SIE_STIE (1 << 5)
#define SIE_SSIE (1 << 1)
#define SIE_SEIE (1 << 9)

static inline void w_mcounteren(uint64 x) { asm volatile("csrw mcounteren, %0" : : "r"(x)); }
static inline uint64 r_mcounteren()
{
  uint64 x;
  asm volatile("csrr %0, mcounteren" : "=r"(x));
  return x;
}
#ifndef SSTATUS_SIE
#define SSTATUS_SIE (1 << 1)
#endif
#endif