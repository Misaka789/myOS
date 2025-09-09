/* filepath: /home/misaka/projects/riscv-os/kernel/kernel.ld */
/* 链接器脚本，定义内核在内存中的布局 */

OUTPUT_ARCH(riscv)  /*目标架构 */
ENTRY(_entry)       /*程序 入口点 */

SECTIONS
{
  /* 内核起始地址：QEMU 将内核加载到这里 */
  . = 0x80000000;

  /* 代码段 */
  .text : {
    *(.text .text.*)
    . = ALIGN(0x1000);
    _trampoline = .;
    *(.trampoline)
    . = ALIGN(0x1000);
    PROVIDE(etext = .);
  }

  /* 只读数据段 */
  .rodata : {
    . = ALIGN(16);
    *(.srodata .srodata.*)
    . = ALIGN(16);
    *(.rodata .rodata.*)
  }

  /* 已初始化数据段 */
  .data : {
    . = ALIGN(16);
    *(.sdata .sdata.*)
    . = ALIGN(16);
    *(.data .data.*)
    PROVIDE(edata = .);
  }

  /* 未初始化数据段 */
  .bss : {
    . = ALIGN(16);
    PROVIDE(sbss = .);
    *(.sbss .sbss.*)
    . = ALIGN(16);
    *(.bss .bss.*)
    PROVIDE(end = .);
  }

  PROVIDE(end = .);
}