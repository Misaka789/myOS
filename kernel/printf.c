// 内核 printf 实现
#include "types.h"
#include "param.h"
#include "riscv.h"
#include "stdarg.h"
#include "defs.h" // 包含统一声明
// #include "string.c"

/* // 前向声明
void consoleputc(int c);
void panic(char *s); */

// 简单的字符串长度函数  遍历字符串直到遇到终止符 \0
// int strlen(const char *s)
// {
//     int n = 0;
//     while (*s++)
//         n++;
//     return n;
// }

// 输出字符串
/* static void puts(char *s)
{
    while (*s)
    {
        consoleputc(*s);
        s++;
    }
} */
static char digits[] = "0123456789abcdef";

// 打印十进制整数 xx : 要打印的数字 base : 进制 sign : 是否有符号
static void printint(long long xx, int base, int sign)
{

    char buf[64];
    int i;
    unsigned long long x;

    // 正数时 sign = 0，xx < 0 为0 走 else
    // 负数时 sign = 1，xx < 0 为1 走 if
    if (sign && (sign = (xx < 0))) // if 判断用来取绝对值
    {
        x = -xx;
    }
    else
    {
        x = xx;
    }

    i = 0;
    do
    {
        buf[i++] = digits[x % base];
    } while ((x /= base) != 0);
    // 取余数得到最低位，然后去掉最低位

    if (sign)
        buf[i++] = '-';

    while (--i >= 0) // 输出缓冲区中的字符
        consoleputc(buf[i]);
}

// 打印指针
static void printptr(uint64 x)
{
    int i;
    consoleputc('0');
    consoleputc('x');
    // sizeof(uint64) * 2 = 8 * 2 = 16 是因为每个字节对应两个十六进制字符
    // x << 4 左移四位在十六进制表示上就是向左移动一位
    for (i = 0; i < (sizeof(uint64) * 2); i++, x <<= 4)
    {
        // sizeof(uint64) * 8 - 4 = 64 - 4 = 60
        // 右移60位得到最高的4位（一个十六进制字符),得到最高4位之后 x << 4 丢掉最高4位继续取
        // 循环取，直到打印完16位
        consoleputc(digits[x >> (sizeof(uint64) * 8 - 4)]);
    }
}

// printf 核心实现 通过状态机来实现
void vprintf(char *fmt, va_list ap) // va_list 为 c 语言的可变参数类型
{
    int i, c;
    char *s;

    if (fmt == 0)
    {
        panic("null fmt");
    }

    for (i = 0; (c = fmt[i] & 0xff) != 0; i++)
    {
        if (c != '%') // 非占位符，说明为普通字符串，直接打印
        {
            consoleputc(c);
            continue;
        }
        c = fmt[++i] & 0xff; // 读取到 % 符号时需要向下读取一个符号来判断占位符的类型
        if (c == 0)
            break;

        switch (c)
        {
        case 'd':                             // 十进制整数
            printint(va_arg(ap, int), 10, 1); // va_arg 获取下一个参数
            break;
        case 'x': // 十六进制整数
            printint(va_arg(ap, int), 16, 1);
            break;
        case 'p': // 指针
            printptr(va_arg(ap, uint64));
            break;
        case 's': // 字符串
            if ((s = va_arg(ap, char *)) == 0)
                s = "(null)";
            for (; *s; s++)
                consoleputc(*s);
            break;
        case 'c': // 字符
            consoleputc(va_arg(ap, uint));
            break;
        case '%': // 百分号
            consoleputc('%');
            break;
        default:
            // 未知格式符，打印原样
            consoleputc('%');
            consoleputc(c);
            break;
        }
    }
}

// printf 函数
void printf(char *fmt, ...)
{
    va_list ap;

    va_start(ap, fmt); // 表示从 fmt 参数之后开始读取参数
    vprintf(fmt, ap);
    sync_flush(); // 刷新输出缓冲区
    va_end(ap);
}

// panic 函数 - 系统致命错误
void panic(char *s)
{
    // 1. 禁用中断，防止进一步的中断处理
    intr_off(); // 后续实现中断管理时添加

    // 2. 显示错误信息
    printf("\n");
    printf("================================\n");
    printf("KERNEL PANIC: %s\n", s);
    printf("================================\n");

    // 3. 显示当前状态信息（调试用）
    // printf("Hart ID: %d\n", (int)r_mhartid());
    // printf("PC: %p\n", (void*)r_sepc());  // 异常PC

    // 4. 显示调用栈（高级功能，后续可添加）
    // print_backtrace();

    // 5. 系统完全停止
    printf("System halted. Please reboot.\n");

    // 死循环，等待硬件重启或调试器介入
    for (;;)
    {
        asm volatile("wfi"); // Wait For Interrupt (省电)
    }
}

// 添加更多 printf 功能

// 打印二进制数
void printbin(uint64 x)
{
    consoleputc('0');
    consoleputc('b');
    for (int i = 63; i >= 0; i--)
    {
        consoleputc((x & (1UL << i)) ? '1' : '0'); // x & (1UL << i) 检查第 i 位是否为1
        if (i % 4 == 0 && i != 0)
            consoleputc('_'); // 分隔符
    }
}

// 格式化输出内存内容（十六进制dump）
void hexdump(void *addr, int len)
{
    printf("About to call hexdump...\n");
    unsigned char *p = (unsigned char *)addr;

    printf("hexdump函数转换后的无符号地址为 : %p\n", p);

    printf("Memory dump at %p:\n", addr);
    for (int i = 0; i < len; i += 16)
    {
        // 打印地址
        printf("%p: ", (void *)(p + i));

        // 打印十六进制数据
        for (int j = 0; j < 16 && i + j < len; j++)
        {
            printf("%02x ", p[i + j]);
        }

        // 补齐空格
        for (int j = len - i; j < 16; j++)
        {
            printf("   ");
        }

        // 打印ASCII字符
        printf(" |");
        for (int j = 0; j < 16 && i + j < len; j++)
        {
            char c = p[i + j];
            printf("%c", (c >= 32 && c <= 126) ? c : '.');
        }
        printf("|\n");
    }
}