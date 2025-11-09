.globl swtch

// swtch(struct context *old, struct context *new);
// a0: old context
// a1: new context
swtch:
    // 保存旧的上下文 (callee-saved registers)

      li t0,0x10000000
      li t1 , 'S'
      sb t1 ,0(t0)
    sd ra, 0(a0)
    sd sp, 8(a0)
    sd s0, 16(a0)
    sd s1, 24(a0)
    sd s2, 32(a0)
    sd s3, 40(a0)
    sd s4, 48(a0)
    sd s5, 56(a0)
    sd s6, 64(a0)
    sd s7, 72(a0)
    sd s8, 80(a0)
    sd s9, 88(a0)
    sd s10, 96(a0)
    sd s11, 104(a0)

    // 恢复新的上下文
    ld ra, 0(a1)
    ld sp, 8(a1)
    ld s0, 16(a1)
    ld s1, 24(a1)
    ld s2, 32(a1)
    ld s3, 40(a1)
    ld s4, 48(a1)
    ld s5, 56(a1)
    ld s6, 64(a1)
    ld s7, 72(a1)
    ld s8, 80(a1)
    ld s9, 88(a1)
    ld s10, 96(a1)
    ld s11, 104(a1)
      li t0,0x10000000
      li t1 , 'W'
      sb t1 ,0(t0)

    ret // 返回到新的上下文中 ra 指向的地址