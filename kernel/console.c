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

    // 新增输出缓冲区用来优化性能
    char output_buf[CONSOLE_BUF_SIZE];
    uint output_pos; // 当前输出缓冲区位置

} console;

// 控制台初始化
void consoleinit(void)
{
    // 初始化 UART
    extern void uartinit(void);
    uartinit();

    // 清空控制台缓冲区
    console.r = console.w = console.e = 0;
    console.output_pos = 0;
}

// 输出单个字符到控制台
void consputc(int c)
{
    // 目前直接使用 UART
    extern void uartputc(int c);
    uartputc(c);
}
void sync_flush(void)
{
    console_flush(); // 刷新输出缓冲区
}

void console_flush(void)
{
    for (uint i = 0; i < console.output_pos; i++)
    {
        uartputc(console.output_buf[i]);
    }
    console.output_pos = 0; // 重置缓冲区位置
}

void consoleputc(int c)
{
    if (console.output_pos < CONSOLE_BUF_SIZE - 1)
    {
        console.output_buf[console.output_pos++] = c;
    }

    // 换行或者缓冲区满或者遇到 '\0' 结尾时刷出缓冲区
    if (c == '\n' || console.output_pos >= CONSOLE_BUF_SIZE - 1 || c == '\0')
    {
        console_flush();
    }
}

void console_puts(const char *s)
{
    while (*s)
    {
        // 直接写入缓冲区，然后一并刷出
        if (console.output_pos < CONSOLE_BUF_SIZE - 1)
        {
            console.output_buf[console.output_pos++] = *s;
        }

        // 缓冲区满先刷出
        if (console.output_pos >= CONSOLE_BUF_SIZE - 1)
        {
            console_flush();
            // console.output_pos = 0;
        }
        s++;
    }
    console_flush();
}

void console_write_buf(const char *data, int len)
{
    for (int i = 0; i < len; i++)
    {
        if (console.output_pos < CONSOLE_BUF_SIZE - 1)
        {
            console.output_buf[console.output_pos++] = data[i];
        }

        // 缓冲区满先刷出
        if (console.output_pos >= CONSOLE_BUF_SIZE - 1)
        {
            console_flush();
            // console.output_pos = 0;
        }
    }
    // 批量写入后再次刷新
    console_flush();
}

// 清屏功能
void console_clear(void)
{
    // 发送 ANSI 清屏序列
    console_puts("\033[2J\033[H"); // 清屏并将光标移动到左上角
}

// 设置光标位置
void console_set_cursor(int row, int col)
{
    // printf("\033[%d;%dH", row, col);

    // 先格式化到临时缓冲区，然后批量输出
    char cursor_cmd[32];
    int len = 0;

    cursor_cmd[len++] = '\033';
    cursor_cmd[len++] = '[';

    // 简单的数字转字符串（只处理小数字）
    if (row >= 10)
    {
        cursor_cmd[len++] = '0' + (row / 10);
    }
    cursor_cmd[len++] = '0' + (row % 10);
    cursor_cmd[len++] = ';';

    if (col >= 10)
    {
        cursor_cmd[len++] = '0' + (col / 10);
    }
    cursor_cmd[len++] = '0' + (col % 10);
    cursor_cmd[len++] = 'H';
    cursor_cmd[len] = '\0';

    console_write_buf(cursor_cmd, len);
}

// 设置文本颜色（优化版）
void console_set_color(int fg_color, int bg_color)
{
    char color_cmd[32];
    int len = 0;

    // 构建颜色 ANSI 序列
    color_cmd[len++] = '\033';
    color_cmd[len++] = '[';
    color_cmd[len++] = '3';
    color_cmd[len++] = '0' + fg_color;
    color_cmd[len++] = ';';
    color_cmd[len++] = '4';
    color_cmd[len++] = '0' + bg_color;
    color_cmd[len++] = 'm';
    color_cmd[len] = '\0';

    console_write_buf(color_cmd, len);
}

// 重置文本格式（优化版）
void console_reset_color(void)
{
    console_puts("\033[0m");
}

// 控制台写入函数（优化版）
int consolewrite(int user_src, uint64 src, int n)
{
    // 使用批量写入而不是逐字符输出
    if (user_src)
    {
        // 从用户空间读取（后续实现）
        for (int i = 0; i < n; i++)
        {
            char c = ((char *)src)[i];
            if (console.output_pos < CONSOLE_BUF_SIZE - 1)
            {
                console.output_buf[console.output_pos++] = c;
            }
            if (console.output_pos >= CONSOLE_BUF_SIZE - 1)
            {
                console_flush();
            }
        }
    }
    else
    {
        // 从内核空间读取 - 直接批量处理
        console_write_buf((const char *)src, n);
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