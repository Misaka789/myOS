#include "types.h"
#include "defs.h"
#include "riscv.h"
#include "memlayout.h"

// 开启指定 IRQ
void plic_enable(int irq)
{
    // PLIC_SENABLE(hart) 是 PLIC 中断使能寄存器的地址
    // 每个 hart 有自己的使能寄存器
    uint64 reg = PLIC_SENABLE(r_tp());
    *(uint32 *)reg |= (1 << irq);
}

// 关闭指定 IRQ
void plic_disable(int irq)
{
    uint64 reg = PLIC_SENABLE(r_tp());
    *(uint32 *)reg &= ~(1 << irq); // 访问的不是内存地址而是 PLIC 的寄存器
}

uint64 plic_claim()
{
    uint64 reg = PLIC_SCLAIM(r_tp());
    return *(uint32 *)reg;
}
void plic_complete(int irq)
{
    uint64 reg = PLIC_SCLAIM(r_tp());
    *(uint32 *)reg = irq; // 写回中断号以完成中断
    // printf("plic_complete: irq %d completed\n", irq);
}

// 初始化 PLIC
void plicinit(void)
{
    // 设置所有中断源的优先级为 1
    // 0 是最低优先级，这里我们不使用
    for (int irq = 1; irq <= 53; irq++)
    {
        *(uint32 *)(PLIC_PRIORITY + irq * 4) = 1;
    }
    printf("plicinit\n");
}

// 为当前 hart 初始化 PLIC
void plicinithart(void)
{
    int hart = r_tp();

    // 设置当前 hart 的 S 模式优先级阈值为 0
    // 这样任何优先级 > 0 的中断都能被接收
    *(uint32 *)PLIC_SPRIORITY(hart) = 0;

    // 为当前 hart 开启 UART0 和 VIRTIO0 的中断
    // 注意：这里先写死，后续可以由驱动自己开启
    // *(uint32 *)PLIC_SENABLE(hart) |= (1 << UART0_IRQ);
    // *(uint32 *)PLIC_SENABLE(hart) |= (1 << VIRTIO0_IRQ);

    printf("plicinithart\n");
}
