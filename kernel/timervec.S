//.globl timervec
//timervec:
//    // 机器模式陷阱处理程序
//    // 1. 保存上下文（这里简化，只保存必要的）
//    addi sp, sp, -32
//    sd ra, 0(sp)
//    sd a0, 8(sp)
//
//    // 2. 检查中断原因，是否是机器定时器中断 (mcause = 0x8000000000000007)
//    csrr a0, mcause
//    li   a1, (1 << 63) | 7
//    bne  a0, a1, mtrap_exit // 如果不是，直接退出
//
//    // 3. 如果是，调用C函数处理
//    call machine_timer_handler
//
//mtrap_exit:
//    // 4. 恢复上下文并返回
//    ld ra, 0(sp)
//    ld a0, 8(sp)
//    addi sp, sp, 32
//    mret

.globl timervec
timervec:
    // 机器模式陷阱处理程序
    // 1. 保存完整的上下文
    // 分配 32 * 8 = 256 字节的栈帧
    addi sp, sp, -256
    sd ra, 0(sp)
    sd gp, 16(sp)
    sd tp, 24(sp)
    sd t0, 32(sp)
    sd t1, 40(sp)
    sd t2, 48(sp)
    sd s0, 56(sp)
    sd s1, 64(sp)
    sd a0, 72(sp)
    sd a1, 80(sp)
    sd a2, 88(sp)
    sd a3, 96(sp)
    sd a4, 104(sp)
    sd a5, 112(sp)
    sd a6, 120(sp)
    sd a7, 128(sp)
    sd s2, 136(sp)
    sd s3, 144(sp)
    sd s4, 152(sp)
    sd s5, 160(sp)
    sd s6, 168(sp)
    sd s7, 176(sp)
    sd s8, 184(sp)
    sd s9, 192(sp)
    sd s10, 200(sp)
    sd s11, 208(sp)
    sd t3, 216(sp)
    sd t4, 224(sp)
    sd t5, 232(sp)
    sd t6, 240(sp)
    // sp 不需要保存，因为它就是基准

    // 2. 检查中断原因，是否是机器定时器中断 (mcause = 0x8000000000000007)
    csrr a0, mcause
    li   a1, (1 << 63) | 7
    bne  a0, a1, mtrap_exit // 如果不是，直接退出

    // 3. 如果是，调用C函数处理
    call machine_timer_handler

mtrap_exit:
    // 4. 恢复完整的上下文并返回
    ld ra, 0(sp)
    ld gp, 16(sp)
    ld tp, 24(sp)
    ld t0, 32(sp)
    ld t1, 40(sp)
    ld t2, 48(sp)
    ld s0, 56(sp)
    ld s1, 64(sp)
    ld a0, 72(sp)
    ld a1, 80(sp)
    ld a2, 88(sp)
    ld a3, 96(sp)
    ld a4, 104(sp)
    ld a5, 112(sp)
    ld a6, 120(sp)
    ld a7, 128(sp)
    ld s2, 136(sp)
    ld s3, 144(sp)
    ld s4, 152(sp)
    ld s5, 160(sp)
    ld s6, 168(sp)
    ld s7, 176(sp)
    ld s8, 184(sp)
    ld s9, 192(sp)
    ld s10, 200(sp)
    ld s11, 208(sp)
    ld t3, 216(sp)
    ld t4, 224(sp)
    ld t5, 232(sp)
    ld t6, 240(sp)
    
    // 释放栈帧
    addi sp, sp, 256
    mret