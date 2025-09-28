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
#define PGROUNDUP(sz) (((sz) + PGSIZE - 1) & ~(PGSIZE - 1))
#define PGROUNDDOWN(a) (((a)) & ~(PGSIZE - 1))

#endif