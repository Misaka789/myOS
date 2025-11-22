// init: The initial user-level program

#include "types.h"
#include "stat.h"
#include "spinlock.h"
#include "sleeplock.h"
#include "fs.h"
#include "file.h"
#include "user.h"
#include "fcntl.h"
// #include "defs.h"

char *argv[] = {"sh", 0};

void test_filesystem_integrity(void)
{
    printf("[file test]: Testing filesystem integrity...\n");
    int fd = open("testfile.txt", O_CREATE | O_RDWR);
    if (fd < 0)
    {
        printf("[file test]: Failed to create testfile.txt\n");
        return;
    }
    char buffer[] = "Hello,filesystem";
    int bytes = write(fd, buffer, sizeof(buffer));
    if (bytes != sizeof(buffer))
    {
        printf("[file test]: Write failed\n");
        close(fd);
        return;
    }
    close(fd);
    fd = open("testfile.txt", O_RDONLY);
    if (fd < 0)
    {
        printf("[file test]: Failed to open testfile.txt for reading\n");
        return;
    }
    char read_buffer[sizeof(buffer)];
    bytes = read(fd, read_buffer, sizeof(read_buffer));
    read_buffer[bytes] = '\0'; // Null-terminate the string
    if (bytes != sizeof(buffer) || strcmp(buffer, read_buffer) != 0)
    {
        printf("[file test]: Read data does not match written data\n");
    }
    else
    {
        printf("[file test]: Filesystem integrity test passed\n");
    }
}
void fmt_filename(char *buf, int id)
{
    char *p = buf;

    // 1. 复制前缀 "concurrent_"
    char *prefix = "concurrent_";
    while (*prefix)
        *p++ = *prefix++;

    // 2. 将整数转换为字符串
    if (id == 0)
    {
        *p++ = '0';
    }
    else
    {
        char digits[16];
        int k = 0;
        int n = id;
        // 提取每一位
        while (n > 0)
        {
            digits[k++] = (n % 10) + '0';
            n /= 10;
        }
        // 倒序写入 buffer
        while (k > 0)
            *p++ = digits[--k];
    }

    // 3. 复制后缀 ".txt"
    char *suffix = ".txt";
    while (*suffix)
        *p++ = *suffix++;

    // 4. 字符串结束符
    *p = '\0';
}

void process_test(void)
{
    for (int i = 0; i < 3; i++)
    {
        int pid = fork();
        if (pid == 0)
        {
            // child process
            printf("[process test]: child process %d started, pid=%d\n", i, getpid());
            for (int j = 0; j < 5; j++)
            {
                printf("[process test]: child process %d (pid=%d) working %d/5\n", i, getpid(), j + 1);
                // sleep(100);
            }
            printf("[process test]: child process %d (pid=%d) exiting\n", i, getpid());
            exit(0);
        }
    }
    // 释放子进程
    for (int i = 0; i < 3; i++)
    {
        // wait(0);
        int wpid = wait(0);
        printf("[process test]: parent reaped child process pid=%d\n", wpid);
    }
    printf("[process test]: all child processes reaped\n");
}

void test_concurrent_access(void)
{
    printf("[file test]: Testing concurrent access...\n");

    for (int i = 0; i < 4; i++)
    {
        if (fork() == 0)
        {
            char filename[20];
            fmt_filename(filename, i);
            for (int j = 0; j < 100; j++)
            {
                int fd = open(filename, O_CREATE | O_RDWR);
                if (fd >= 0)
                {
                    write(fd, &j, sizeof(j));
                    close(fd);
                    unlink(filename);
                }
            }
            exit(0);
        }
    }
    for (int i = 0; i < 4; i++)
    {
        wait(0);
    }

    printf("[file test]: Concurrent access test completed (placeholder)\n");
}

int global_data = 100;

void cow_test(void)
{
    printf("Running basic COW test...\n");
    int pid = fork();
    if (pid < 0)
    {
        printf("fork failed\n");
        exit(1);
    }

    if (pid == 0)
    {
        // 子进程
        // 1. 读取数据，此时应共享物理页
        if (global_data != 100)
        {
            printf("Child: read error\n");
            exit(1);
        }

        // 2. 写入数据，应触发 COW
        printf("Child: modifying memory...\n");
        global_data = 200;

        if (global_data != 200)
        {
            printf("Child: write error\n");
            exit(1);
        }
        printf("Child: modification success\n");
        exit(0);
    }
    else
    {
        // 父进程
        wait(0);
        // 3. 检查父进程数据是否保持不变
        if (global_data != 100)
        {
            printf("Parent: error! Data modified by child.\n");
            exit(1);
        }
        printf("Parent: Data remains %d (Correct)\n", global_data);
    }
}

int main(void)
{
    int fd;
    if ((fd = open("console", O_RDWR)) < 0)
    {
        mknod("console", CONSOLE, 0);
        fd = open("console", O_RDWR);
    }

    dup(0);
    dup(0);
    printf("init: starting sh\n");
    process_test();
    test_filesystem_integrity();
    cow_test();
    pritnf("init: all tests completed\n");
    //  test_concurrent_access();
    for (;;)
    {
    };
}

// int main(void)
// {
//     // write(1, "INIT START\n", 11);
//     for (;;)
//         ;
//     int pid, wpid;
//     // printf("[init:main]: init started \n");
//     if (open("console", O_RDWR) < 0)
//     {
//         mknod("console", CONSOLE, 0);
//         open("console", O_RDWR);
//     }
//     dup(0); // stdout
//     dup(0); // stderr

//     for (;;)
//     {
//         printf("init: starting sh\n");
//         pid = fork();
//         if (pid < 0)
//         {
//             printf("init: fork failed\n");
//             exit(1);
//         }
//         if (pid == 0)
//         {
//             exec("sh", argv);
//             printf("init: exec sh failed\n");
//             exit(1);
//         }

//         for (;;)
//         {
//             // this call to wait() returns if the shell exits,
//             // or if a parentless process exits.
//             wpid = wait((int *)0);
//             if (wpid == pid)
//             {
//                 // the shell exited; restart it.
//                 break;
//             }
//             else if (wpid < 0)
//             {
//                 printf("init: wait returned an error\n");
//                 exit(1);
//             }
//             else
//             {
//                 // it was a parentless process; do nothing.
//             }
//         }
//     }
// }
