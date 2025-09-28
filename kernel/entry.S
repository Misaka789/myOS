# 内核启动入口点
# QEMU 将内核加载到 0x80000000，所有 CPU 从这里开始执行

.section .text
.global _entry
_entry:
    # 为每个 CPU 设置独立的启动栈
    # stack0 在 start.c 中定义，每个 CPU 分配 4KB 栈空间
    # 公式: sp = stack0 + (hartid + 1) * 4096
    
    la sp, stack0           # 加载 stack0 基地址到栈指针
    li a0, 1024*4           # a0 = 4096 (每个CPU的栈大小)
    csrr a1, mhartid        # a1 = 当前CPU的hart ID
    addi a1, a1, 1          # a1 = hartid + 1 (避免使用索引0)
    mul a0, a0, a1          # a0 = 4096 * (hartid + 1)
    add sp, sp, a0          # sp = stack0 + 偏移量
    
    # 跳转到 C 语言的 start 函数

     // 调试用，临时写一个字符到uart 
    li t0,0x10000000
    li t1 , 'T'
    sb t1 ,0(t0)
    call start
    
    # 如果 start 函数返回（不应该发生），则无限循环
spin:
    j spin