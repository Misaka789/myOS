.globl timervec
timervec:
    // 机器模式陷阱处理程序
    // 1. 保存上下文（这里简化，只保存必要的）
    // 调试用，临时写一个字符到uart 
    li t0,0x10000000
    li t1 , 'T'
    sb t1 ,0(t0)
    addi sp, sp, -32
    sd ra, 0(sp)
    sd a0, 8(sp)

    // 2. 检查中断原因，是否是机器定时器中断 (mcause = 0x8000000000000007)
    csrr a0, mcause
    li   a1, (1 << 63) | 7
    bne  a0, a1, mtrap_exit // 如果不是，直接退出

    // 3. 如果是，调用C函数处理
    call machine_timer_handler

mtrap_exit:
    // 4. 恢复上下文并返回
    ld ra, 0(sp)
    ld a0, 8(sp)
    addi sp, sp, 32
    mret