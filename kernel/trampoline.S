# #include "riscv.h"
# #include "memlayout.h"

# .globl trampoline
# .globl usertrap
# .globl uservec
# .globl userret
# .align 12 # 修改为 页对齐
# trampoline:

# #
# # uservec --- trap-handler-prologue
# #
# # 1. `stvec` 指向这里。
# # 2. `sscratch` 寄存器中保存着当前进程陷阱帧 (trapframe) 的地址。
# #
# uservec:  // 这里已经是S 模式了，但是 sp 指针仍然指向用户栈
#     # 交换 sp 和 sscratch。
#     # 此时，sp 指向了当前进程的陷阱帧 (trapframe) 的顶部。
#     # sscratch 中保存了用户的 sp。
#     //csrrw sp, sscratch, sp  # 交换 sscratch sp 寄存器的值
#     # 这里前提是在准备运行一个用户进程的时候，会提前将 进程的trapframe 的地址存到 sscratch 

#    csrw sscratch ,a0  # 将 a0 也就是 trapframe 地址 写入 sscratch
#    li a0, TRAPFRAME

#     # 现在 sp 指向的是当前进程的 trapframe 结构体
#     # 保存所有通用寄存器到 trapframe
#     sd ra, 40(sp)
#     sd gp, 48(sp)
#     sd tp, 56(sp)
#     sd t0, 64(sp)
#     sd t1, 72(sp)
#     sd t2, 80(sp)
#     sd s0, 88(sp)
#     sd s1, 96(sp)
#     sd a0, 104(sp)
#     sd a1, 112(sp)
#     sd a2, 120(sp)
#     sd a3, 128(sp)
#     sd a4, 136(sp)
#     sd a5, 144(sp)
#     sd a6, 152(sp)
#     sd a7, 160(sp)
#     sd s2, 168(sp)
#     sd s3, 176(sp)
#     sd s4, 184(sp)
#     sd s5, 192(sp)
#     sd s6, 200(sp)
#     sd s7, 208(sp)
#     sd s8, 216(sp)
#     sd s9, 224(sp)
#     sd s10, 232(sp)
#     sd s11, 240(sp)
#     sd t3, 248(sp)
#     sd t4, 256(sp)
#     sd t5, 264(sp)
#     sd t6, 272(sp)

#     # 保存用户的 sp sscratch -> t0
#     csrr t0, sscratch
#     sd t0, 32(sp)

#     # 从陷阱帧中加载内核需要的信息
#     ld t0, 0(sp)   # 加载内核栈指针 (kernel_sp)
#     ld t1, 16(sp)  # 加载内核陷阱处理函数地址 (kernel_trap)
#     ld t2, 8(sp)   # 加载内核页表地址 (kernel_satp)

#     # 切换到内核栈
#     mv sp, t0

#     # 切换到内核页表
#     csrw satp, t2
#     sfence.vma

#     # 跳转到内核的 C 语言陷阱处理函数
#     jr t1

# #
# # userret --- trap-handler-epilogue
# #
# # a0: 指向用户页表的 satp 值
# #
# userret:
#     # 切换回用户页表

#  # test ===== 
#     #j .
#  #test === 

#     csrw satp, a0   # 将传入的参数 a0 也就是页表写入页表寄存器 
#     sfence.vma #  刷新tlb

#     # test === 
#     #j .
#     # test ===

#     # 再次交换 sp 和 sscratch，让 sp 指向陷阱帧
#     csrrw sp, sscratch, sp

#     # 从陷阱帧中恢复所有通用寄存器
#     ld ra, 40(sp)
#     ld gp, 48(sp)
#     ld tp, 56(sp)
#     ld t0, 64(sp)
#     ld t1, 72(sp)
#     ld t2, 80(sp)
#     ld s0, 88(sp)
#     ld s1, 96(sp)
#     ld a0, 104(sp)
#     ld a1, 112(sp)
#     ld a2, 120(sp)
#     ld a3, 128(sp)
#     ld a4, 136(sp)
#     ld a5, 144(sp)
#     ld a6, 152(sp)
#     ld a7, 160(sp)
#     ld s2, 168(sp)
#     ld s3, 176(sp)
#     ld s4, 184(sp)
#     ld s5, 192(sp)
#     ld s6, 200(sp)
#     ld s7, 208(sp)
#     ld s8, 216(sp)
#     ld s9, 224(sp)
#     ld s10, 232(sp)
#     ld s11, 240(sp)
#     ld t3, 248(sp)
#     ld t4, 256(sp)
#     ld t5, 264(sp)
#     ld t6, 272(sp)

#     # 恢复用户的 sp
#     ld sp, 32(sp)

#     # 执行 sret 指令，原子性地完成以下操作：
#     # 1. 模式切换: S-mode -> U-mode
#     # 2. `sepc` -> `pc`: 跳转回用户程序被中断的地方
#     # 3. 重新开启中断
#     sret


        #
        # low-level code to handle traps from user space into
        # the kernel, and returns from kernel to user.
        #
        # the kernel maps the page holding this code
        # at the same virtual address (TRAMPOLINE)
        # in user and kernel space so that it continues
        # to work when it switches page tables.
        # kernel.ld causes this code to start at 
        # a page boundary.
        #

 #include "riscv.h"
 #include "memlayout.h"

.section .trampsec
.globl trampoline
.globl userret
.globl uservec
trampoline:
.align 12  # 页对齐
uservec:    
	#
        # trap.c sets stvec to point here, so
        # traps from user space start here,
        # in supervisor mode, but with a
        # user page table.
        #

        # save user a0 in sscratch so
        # a0 can be used to get at TRAPFRAME.
        csrw sscratch, a0

        # each process has a separate p->trapframe memory area,
        # but it's mapped to the same virtual address
        # (TRAPFRAME) in every process's user page table.
        li a0, TRAPFRAME
        
        # save the user registers in TRAPFRAME
        sd ra, 40(a0)
        sd sp, 48(a0)
        sd gp, 56(a0)
        sd tp, 64(a0)
        sd t0, 72(a0)
        sd t1, 80(a0)
        sd t2, 88(a0)
        sd s0, 96(a0)
        sd s1, 104(a0)
        sd a1, 120(a0)
        sd a2, 128(a0)
        sd a3, 136(a0)
        sd a4, 144(a0)
        sd a5, 152(a0)
        sd a6, 160(a0)
        sd a7, 168(a0)
        sd s2, 176(a0)
        sd s3, 184(a0)
        sd s4, 192(a0)
        sd s5, 200(a0)
        sd s6, 208(a0)
        sd s7, 216(a0)
        sd s8, 224(a0)
        sd s9, 232(a0)
        sd s10, 240(a0)
        sd s11, 248(a0)
        sd t3, 256(a0)
        sd t4, 264(a0)
        sd t5, 272(a0)
        sd t6, 280(a0)

	# save the user a0 in p->trapframe->a0
        csrr t0, sscratch
        sd t0, 112(a0)

        # initialize kernel stack pointer, from p->trapframe->kernel_sp
        ld sp, 8(a0)

        # make tp hold the current hartid, from p->trapframe->kernel_hartid
        ld tp, 32(a0)

        # load the address of usertrap(), from p->trapframe->kernel_trap
        ld t0, 16(a0)

        # fetch the kernel page table address, from p->trapframe->kernel_satp.
        ld t1, 0(a0)

        # wait for any previous memory operations to complete, so that
        # they use the user page table.
        sfence.vma zero, zero

        # install the kernel page table.
        csrw satp, t1

        # flush now-stale user entries from the TLB.
        sfence.vma zero, zero

        # call usertrap()
        jalr t0

.globl userret
userret:
        # usertrap() returns here, with user satp in a0.
        # return from kernel to user.

        # switch to the user page table.
        sfence.vma zero, zero
        csrw satp, a0
        sfence.vma zero, zero

        li a0, TRAPFRAME

        # restore all but a0 from TRAPFRAME
        ld ra, 40(a0)
        ld sp, 48(a0)
        ld gp, 56(a0)
        ld tp, 64(a0)
        ld t0, 72(a0)
        ld t1, 80(a0)
        ld t2, 88(a0)
        ld s0, 96(a0)
        ld s1, 104(a0)
        ld a1, 120(a0)
        ld a2, 128(a0)
        ld a3, 136(a0)
        ld a4, 144(a0)
        ld a5, 152(a0)
        ld a6, 160(a0)
        ld a7, 168(a0)
        ld s2, 176(a0)
        ld s3, 184(a0)
        ld s4, 192(a0)
        ld s5, 200(a0)
        ld s6, 208(a0)
        ld s7, 216(a0)
        ld s8, 224(a0)
        ld s9, 232(a0)
        ld s10, 240(a0)
        ld s11, 248(a0)
        ld t3, 256(a0)
        ld t4, 264(a0)
        ld t5, 272(a0)
        ld t6, 280(a0)

	# restore user a0
        ld a0, 112(a0)
        
        # return to user mode and user pc.
        # usertrapret() set up sstatus and sepc.
        sret
