.globl trampoline
.globl uservec
.globl userret
.align 12 # 修改为 页对齐
trampoline:

#
# uservec --- trap-handler-prologue
#
# 1. `stvec` 指向这里。
# 2. `sscratch` 寄存器中保存着当前进程陷阱帧 (trapframe) 的地址。
#
uservec:  // 这里已经是S 模式了，但是 sp 指针仍然指向用户栈
    # 交换 sp 和 sscratch。
    # 此时，sp 指向了当前进程的陷阱帧 (trapframe) 的顶部。
    # sscratch 中保存了用户的 sp。
    csrrw sp, sscratch, sp  # 交换 sscratch sp 寄存器的值
    # 这里前提是在准备运行一个用户进程的时候，会提前将 进程的trapframe 的地址存到 sscratch 

    # 现在 sp 指向的是当前进程的 trapframe 结构体
    # 保存所有通用寄存器到 trapframe
    sd ra, 40(sp)
    sd gp, 48(sp)
    sd tp, 56(sp)
    sd t0, 64(sp)
    sd t1, 72(sp)
    sd t2, 80(sp)
    sd s0, 88(sp)
    sd s1, 96(sp)
    sd a0, 104(sp)
    sd a1, 112(sp)
    sd a2, 120(sp)
    sd a3, 128(sp)
    sd a4, 136(sp)
    sd a5, 144(sp)
    sd a6, 152(sp)
    sd a7, 160(sp)
    sd s2, 168(sp)
    sd s3, 176(sp)
    sd s4, 184(sp)
    sd s5, 192(sp)
    sd s6, 200(sp)
    sd s7, 208(sp)
    sd s8, 216(sp)
    sd s9, 224(sp)
    sd s10, 232(sp)
    sd s11, 240(sp)
    sd t3, 248(sp)
    sd t4, 256(sp)
    sd t5, 264(sp)
    sd t6, 272(sp)

    # 保存用户的 sp sscratch -> t0
    csrr t0, sscratch
    sd t0, 32(sp)

    # 从陷阱帧中加载内核需要的信息
    ld t0, 0(sp)   # 加载内核栈指针 (kernel_sp)
    ld t1, 16(sp)  # 加载内核陷阱处理函数地址 (kernel_trap)
    ld t2, 8(sp)   # 加载内核页表地址 (kernel_satp)

    # 切换到内核栈
    mv sp, t0

    # 切换到内核页表
    csrw satp, t2
    sfence.vma

    # 跳转到内核的 C 语言陷阱处理函数
    jr t1

#
# userret --- trap-handler-epilogue
#
# a0: 指向用户页表的 satp 值
#
userret:
    # 切换回用户页表
    csrw satp, a0   # 将传入的参数 a0 也就是页表写入页表寄存器 
    sfence.vma #  刷新tlb

    # 再次交换 sp 和 sscratch，让 sp 指向陷阱帧
    csrrw sp, sscratch, sp

    # 从陷阱帧中恢复所有通用寄存器
    ld ra, 40(sp)
    ld gp, 48(sp)
    ld tp, 56(sp)
    ld t0, 64(sp)
    ld t1, 72(sp)
    ld t2, 80(sp)
    ld s0, 88(sp)
    ld s1, 96(sp)
    ld a0, 104(sp)
    ld a1, 112(sp)
    ld a2, 120(sp)
    ld a3, 128(sp)
    ld a4, 136(sp)
    ld a5, 144(sp)
    ld a6, 152(sp)
    ld a7, 160(sp)
    ld s2, 168(sp)
    ld s3, 176(sp)
    ld s4, 184(sp)
    ld s5, 192(sp)
    ld s6, 200(sp)
    ld s7, 208(sp)
    ld s8, 216(sp)
    ld s9, 224(sp)
    ld s10, 232(sp)
    ld s11, 240(sp)
    ld t3, 248(sp)
    ld t4, 256(sp)
    ld t5, 264(sp)
    ld t6, 272(sp)

    # 恢复用户的 sp
    ld sp, 32(sp)

    # 执行 sret 指令，原子性地完成以下操作：
    # 1. 模式切换: S-mode -> U-mode
    # 2. `sepc` -> `pc`: 跳转回用户程序被中断的地方
    # 3. 重新开启中断
    sret