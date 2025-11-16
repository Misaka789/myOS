#ifndef __FS_H__ // 如果 __FS_H__ 这个宏还没有被定义...
#define __FS_H__ // ...那么就定义它，并处理下面的内容。

#include "types.h"

#define ROOTINO 1  // root 计数器
#define BSIZE 1024 // 块大小

struct superblock
{
    uint magic;      // 必须是 FSMAGIC
    uint size;       // 文件系统镜像大小（块数）
    uint nblocks;    // 数据块数量
    uint ninodes;    // inode 数量
    uint nlog;       // 日志块数量
    uint logstart;   // 第一个日志块的块号
    uint inodestart; // 第一个 inode 块的块号
    uint bmapstart;  // 第一个空闲映射块的块号
};

#define FSMAGIC 0x10203040 // 文件系统魔数

#define NDIRECT 12                       // 直接块数量
#define NINDIRECT (BSIZE / sizeof(uint)) // 间接块数量
#define MAXFILE (NDIRECT + NINDIRECT)    // 最大文件大小（块数）

struct dinode // 每个文件在磁盘上都对应一个dinode 结构
{
    short type;              // 文件类型
    short major;             // 主设备号（仅 T_DEVICE）
    short minor;             // 次设备号（仅 T_DEVICE）
    short nlink;             // 文件系统中指向该 inode 的链接数
    uint size;               // 文件大小（字节）
    uint addrs[NDIRECT + 1]; // 数据块地址
};

#define IPB (BSIZE / sizeof(struct dinode))       // 每块 inode 数量
#define IBLOCK(i, sb) ((i) / IPB + sb.inodestart) // 包含 inode i 的块号
#define BPB (BSIZE * 8)                           // 每块位图位数
#define BBLOCK(b, sb) ((b) / BPB + sb.bmapstart)  // 包含块 b 的位图块号
#define DIRSIZ 14                                 // 目录名称大小
// #define DENTRIESIZE (sizeof(struct dirent)) // 目录项大小
struct dirent // 目录项结构
{
    ushort inum;       // inode 号
    char name[DIRSIZ]; // 文件名
};

#endif // 结束条件编译