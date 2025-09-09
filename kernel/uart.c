// UART 串口驱动 - 第一阶段简化版本

#include "types.h"
#include "memlayout.h"

// UART 寄存器偏移
#define RHR 0  // 接收保持寄存器
#define THR 0  // 发送保持寄存器  
#define IER 1  // 中断使能寄存器
#define FCR 2  // FIFO控制寄存器
#define LCR 3  // 线路控制寄存器
#define LSR 5  // 线路状态寄存器

// 寄存器位定义
#define LCR_EIGHT_BITS  (3<<0)
#define LCR_BAUD_LATCH  (1<<7) 
#define FCR_FIFO_ENABLE (1<<0)
#define FCR_FIFO_CLEAR  (3<<1)
#define LSR_TX_IDLE     (1<<5)

// 寄存器访问宏
#define Reg(reg) ((volatile unsigned char *)(UART0 + (reg)))
#define WriteReg(reg, v) (*(Reg(reg)) = (v))
#define ReadReg(reg) (*(Reg(reg)))

// 初始化UART
void uartinit(void) 
{
    // 1. 禁用中断（第一阶段不使用中断）
    WriteReg(IER, 0x00);

    // 2. 设置波特率 38400
    WriteReg(LCR, LCR_BAUD_LATCH);  // 启用波特率设置
    WriteReg(0, 0x03);              // 波特率除数低字节
    WriteReg(1, 0x00);              // 波特率除数高字节

    // 3. 设置8位数据，无奇偶校验，1停止位
    WriteReg(LCR, LCR_EIGHT_BITS);

    // 4. 启用并清空FIFO
    WriteReg(FCR, FCR_FIFO_ENABLE | FCR_FIFO_CLEAR);
}

// 发送一个字符（同步方式）
void uartputc(int c) 
{
    // 等待发送寄存器空闲
    while((ReadReg(LSR) & LSR_TX_IDLE) == 0)
        ;
    
    WriteReg(THR, c);
}

// 发送字符串
void uartputs(char *s) 
{
    while(*s) {
        if(*s == '\n')
            uartputc('\r');  // 换行前先发送回车符
        uartputc(*s);
        s++;
    }
}
/*
硬件抽象：将复杂的UART硬件寄存器操作封装成简单的函数接口
I/O基础设施：为printf、scanf等高级I/O函数提供底层支持
调试支持：提供内核调试输出的基本手段
用户交互：支持用户通过键盘输入命令
*/