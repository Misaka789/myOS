#ifndef PARAM_H
#define PARAM_H

#define NCPU 8                    // 最大CPU数量
#define NOFILE 16                 // 每进程打开文件数
#define NFILE 100                 // 系统文件表大小
#define NINODE 50                 // inode 缓存大小
#define NDEV 10                   // 设备数量
#define ROOTDEV 1                 // 根设备号
#define MAXARG 32                 // exec 最大参数数
#define MAXOPBLOCKS 10            // 日志系统最大操作块数
#define LOGSIZE (MAXOPBLOCKS * 3) // 日志大小
#define NBUF (MAXOPBLOCKS * 3)    // 缓冲区数量
#define FSSIZE 2000               // 文件系统大小(块数)
#define MAXPATH 128               // 最大路径长度
#define USERSTACK 1               // 用户栈页数

#define NPROC 64 // 系统最大进程数

#endif