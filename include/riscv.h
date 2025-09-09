#ifndef RISCV_H
#define RISCV_H

#include "types.h"

// 读取 mhartid CSR (machine hart ID)
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

#endif