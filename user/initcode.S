# user/initcode.S

# exec(init, argv)
.globl start
start:
        # 将 /init 程序的路径地址加载到 a1 寄存器
        la a1, init
        # 将参数列表的地址加载到 a2 寄存器
        la a2, argv
        # 将 exec 系统调用的编号 (SYS_exec) 加载到 a7 寄存器
        li a7, SYS_exec
        # 执行 ecall 指令，陷入内核，请求执行 exec 系统调用
        ecall

# a simple program that runs a shell
init:
  .string "/init\0"

argv:
  .word init  # argv[0] 指向 "/init"
  .word 0     # argv[1] 是一个空指针，表示参数列表结束