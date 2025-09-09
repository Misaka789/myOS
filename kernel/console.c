// 控制台管理
#include "types.h"
#include "param.h"
#include "riscv.h"
#include "defs.h" // 替换各种单独的声明

// 控制台缓冲区
#define CONSOLE_BUF_SIZE 256
struct console
{
    char buf[CONSOLE_BUF_SIZE];
    uint r; // 读位置
    uint w; // 写位置
    uint e; // 编辑位置
} console;

// 控制台初始化
void consoleinit(void)
{
    // 初始化 UART
    extern void uartinit(void);
    uartinit();

    // 清空控制台缓冲区
    console.r = console.w = console.e = 0;
}

// 清屏功能
void console_clear(void)
{
    // 发送 ANSI 清屏序列
    printf("\033[2J"); // 清屏
    printf("\033[H");  // 光标回到左上角
}

// 设置光标位置
void console_set_cursor(int row, int col)
{
    printf("\033[%d;%dH", row, col);
}

// 设置文本颜色
void console_set_color(int fg_color, int bg_color)
{
    printf("\033[%d;%dm", 30 + fg_color, 40 + bg_color);
}

// 重置文本格式
void console_reset_color(void)
{
    printf("\033[0m");
}

// 控制台写入函数
int consolewrite(int user_src, uint64 src, int n)
{
    int i;

    // 简化版：直接输出字符
    for (i = 0; i < n; i++)
    {
        char c;
        if (user_src)
        {
            // 从用户空间读取（后续实现）
            // 现在先简化处理
            c = ((char *)src)[i];
        }
        else
        {
            // 从内核空间读取
            c = ((char *)src)[i];
        }
        consputc(c);
    }

    return n;
}

// 控制台读取函数
int consoleread(int user_dst, uint64 dst, int n)
{
    // TODO: 实现键盘输入读取
    // 这需要中断处理和键盘驱动
    return 0;
}