#ifndef MEMLAYOUT_H
#define MEMLAYOUT_H

// 物理内存布局 (QEMU virt 机器)
#define KERNBASE 0x80000000L // 内核基地址
#define PHYSTOP 0x88000000L  // 物理内存结束 (128MB)

// 设备内存映射
#define UART0 0x10000000L   // UART
#define VIRTIO0 0x10001000L // virtio 磁盘
#define CLINT 0x02000000L   // 核心本地中断器
#define PLIC 0x0c000000L    // 平台级中断控制器

// 页大小
#define PGSIZE 4096
#define PGSHIFT 12

// 页对齐宏
#ifndef PGROUNDUP
#define PGROUNDUP(sz) (((sz) + PGSIZE - 1) & ~(PGSIZE - 1))
#endif

#ifndef PGROUNDDOWN
#define PGROUNDDOWN(a) (((a)) & ~(PGSIZE - 1))
#endif

// PLIC 处理宏
#define PLIC_PRIORITY (PLIC + 0x0)                               // 优先级寄存器基址
#define PLIC_PENDING (PLIC + 0x1000)                             // 待处理寄存器基址
#define PLIC_SENABLE(hart) (PLIC + 0x2080 + (hart) * 0x100)      // 每个 hart 的使能寄存器
#define PLIC_SPRIORITY(hart) (PLIC + 0x201000 + (hart) * 0x2000) // 每个 hart 的优先级阈值寄存器
#define PLIC_SCLAIM(hart) (PLIC + 0x201004 + (hart) * 0x2000)    // 每个 hart 的中断请求寄存器
#define PTE_FLAGS(pte) ((pte) & 0x3FF)                           // 低10位为标志位
#define MAXVA (1L << 38)                                         // one beyond the highest possible virtual address

#define TRAMPOLINE (MAXVA - PGSIZE)                         // trampoline 映射位置
#define TRAPFRAME (TRAMPOLINE - PGSIZE)                     // trapframe 映射位置
#define KSTACK(proc) (TRAMPOLINE - (proc + 1) * 2 * PGSIZE) // 内核栈位置

#endif