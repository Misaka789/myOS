#include "types.h"
#include "riscv.h"
#include "defs.h"
#include "param.h"
#include "stat.h"
#include "spinlock.h"
#include "proc.h"
#include "sleeplock.h"
#include "fs.h"
#include "buf.h"
#include "file.h"

#define min(a, b) ((a) < (b) ? (a) : (b)) // 作用是返回两个值中较小的一个

struct superblock sb; // 全局超级块变量，表示文件系统的超级块信息

static void readsb(int dev, struct superblock *sb) // 读取超级块的函数声明
{
    printf("[readsb]: readsb started \n");
    struct buf *bp;
    bp = bread(dev, 1); // 读取包含块 b 的位图块
    printf("[readsb]: bread completed \n");
    memmove(sb, bp->data, sizeof(*sb)); // 将读取的数据复制到超级块结构中
    // brelse(bp);                              // 释放缓冲区
    printf("[readsb]: readsb completed \n"); // 调试：打印前 16 字节看看
    uint32 *p = (uint32 *)bp->data;
    printf("[readsb]: raw super block: %x %x %x %x\n",
           p[0], p[1], p[2], p[3]);

    memmove(sb, bp->data, sizeof(*sb));
    brelse(bp);
    printf("[readsb]: readsb completed, sb.magic=%x\n", sb->magic);
}

void fsinit(int dev)
{
    printf("[fsinit]: fsinit started \n");
    readsb(dev, &sb); // 读取超级块信息
    printf("[fsinit]: superblock magic number: %x \n", sb.magic);
    if (sb.magic != FSMAGIC)          // 检查超级块的魔数是否正确
        panic("invalid file system"); // 如果不正确，触发内核恐慌
    initlog(dev, &sb);                // 初始化日志
    printf("[fsinit]: fsinit completed \n");
}

static void bzero(int dev, int bno)
{
    struct buf *bp;
    bp = bread(dev, bno);       // 读取指定块
    memset(bp->data, 0, BSIZE); // 将块数据清零
    log_write(bp);              // 写入日志
    brelse(bp);                 // 释放缓冲区
}

// 在 磁盘的位图中找到一个空闲的数据快，标记为占用，返回块号
static uint balloc(uint dev)
{
    int b, bi, m;
    struct buf *bp;
    for (b = 0; b < sb.size; b += BPB)
    {                                   //   遍历所有块
        bp = bread(dev, BBLOCK(b, sb)); // 读取包含块 b 的位图块
        for (bi = 0; bi < BPB && b + bi < sb.size; bi++)
        { // 遍历位图块中的每个位
            m = 1 << (bi % 8);
            if ((bp->data[bi / 8] & m) == 0)
            {                          // 检查块是否空闲
                bp->data[bi / 8] |= m; // 标记块为已使用
                log_write(bp);         // 写入日志
                brelse(bp);            // 释放缓冲区
                bzero(dev, b + bi);    // 清零新分配的块
                return b + bi;         // 返回分配的块号
            }
        }
        brelse(bp); // 释放缓冲区
    }
    printf("balloc: out of blocks\n"); // 如果没有可用块，打印错误信息
    return 0;                          // 返回0表示分配失败
}

// 把块号 b 对应的位图位清零，表示该块空闲
static void bfree(int dev, uint b)
{
    struct buf *bp;
    int bi, m;
    bp = bread(dev, BBLOCK(b, sb)); // 读取包含块 b 的位图块
    bi = b % BPB;
    m = 1 << (bi % 8);
    if ((bp->data[bi / 8] & m) == 0) // 检查块是否已经是空闲的
        panic("freeing free block"); // 如果是，触发内核恐慌
    bp->data[bi / 8] &= ~m;          // 标记块为未使用
    log_write(bp);                   // 写入日志
    brelse(bp);                      // 释放缓冲区
}

struct
{
    struct spinlock lock;       // 自旋锁，用于保护 inode 表的并发访问
    struct inode inode[NINODE]; // inode 表，存储所有内存中的 inode 结构
} itable;

void iinit()
{
    int i = 0;
    initlock(&itable.lock, "itable"); // 初始化自旋锁
    for (i = 0; i < NINODE; i++)
    {
        initsleeplock(&itable.inode[i].lock, "inode"); // 初始化每个 inode 的睡眠锁
    }
    printf("[iinit]: iinit completed \n");
}

// 从内存 inode 表中找到制定的 dev + inum 的inode , 如果没有则从磁盘加载
static struct inode *iget(uint dev, uint inum);

struct inode *ialloc(uint dev, short type)
{
    int inum;
    struct buf *bp;
    struct dinode *dip;
    for (inum = 1; inum < sb.ninodes; inum++)
    {                                                 // 遍历所有 inode
        bp = bread(dev, IBLOCK(inum, sb));            // 读取包含该 inode 的块
        dip = (struct dinode *)bp->data + inum % IPB; // 定位到具体的 dinode 结构
        if (dip->type == 0)
        {                                 // 检查是否为自由 inode
            memset(dip, 0, sizeof(*dip)); // 清零 dinode 结构
            dip->type = type;             // 设置 inode 类型
            log_write(bp);                // 在磁盘上标记为已分配
            brelse(bp);                   // 释放缓冲区
            return iget(dev, inum);       // 返回分配的 inode
        }
        brelse(bp); // 释放缓冲区
    }
    printf("ialloc: no inodes\n"); // 如果没有可用 inode，打印错误信息
    return 0;                      // 返回 NULL 表示分配失败
}

// 将数据从内存 inode 结构同步到磁盘上的 dinode 结构
void iupdate(struct inode *ip)
{
    struct buf *bp;
    struct dinode *dip;
    bp = bread(ip->dev, IBLOCK(ip->inum, sb));        // 读取包含该 inode 的块
    dip = (struct dinode *)bp->data + ip->inum % IPB; // 定位到具体的 dinode 结构
    dip->type = ip->type;
    dip->major = ip->major;
    dip->minor = ip->minor;
    dip->nlink = ip->nlink;
    dip->size = ip->size;
    memmove(dip->addrs, ip->addrs, sizeof(ip->addrs));
    log_write(bp); // 写入日志
    brelse(bp);    // 释放缓冲区
}

// 获取 inode, 如果已经在内存中则增加引用计数并返回, 否则从磁盘加载
static struct inode *iget(uint dev, uint inum)
{
    struct inode *ip, *empty;
    acquire(&itable.lock);
    empty = 0;
    for (ip = &itable.inode[0]; ip < &itable.inode[NINODE]; ip++)
    {
        if (ip->ref > 0 && ip->dev == dev && ip->inum == inum)
        {
            ip->ref++; // 计数引用
            release(&itable.lock);
            return ip;
        }
        if (empty == 0 && ip->ref == 0)
            empty = ip;
    }
    if (empty)
    {
        ip = empty;
        ip->dev = dev;
        ip->inum = inum;
        ip->ref = 1;
        ip->valid = 0;
        release(&itable.lock);
        return ip;
    }
    else
        panic("iget: no inodes");
    release(&itable.lock);
    return 0;
}

// 增加 inode 引用计数
struct inode *idup(struct inode *ip)
{
    acquire(&itable.lock);
    ip->ref++;
    release(&itable.lock);
    return ip;
}

// 从硬盘中读取对应的磁盘块到 inode 结构中
void ilock(struct inode *ip)
{
    struct buf *bp;
    struct dinode *dip;
    if (ip == 0 || ip->ref < 1)
        panic("ilock");
    acquiresleep(&ip->lock);
    if (ip->valid == 0)
    {
        bp = bread(ip->dev, IBLOCK(ip->inum, sb));
        dip = (struct dinode *)bp->data + ip->inum % IPB;
        ip->type = dip->type;
        ip->major = dip->major;
        ip->minor = dip->minor;
        ip->nlink = dip->nlink;
        ip->size = dip->size;
        memmove(ip->addrs, dip->addrs, sizeof(ip->addrs));
        brelse(bp);
        ip->valid = 1;
        if (ip->type == 0)
            panic("ilock: no type");
    }
}

void iunlock(struct inode *ip)
{
    if (ip == 0 || !holdingsleep(&ip->lock))
        panic("iunlock");
    releasesleep(&ip->lock);
}

// 释放 inode, 在某些情况下需要释放 inode 所占用的磁盘空间
void iput(struct inode *ip)
{
    acquire(&itable.lock);
    if (ip->ref == 1 && ip->valid && ip->nlink == 0)
    {
        acquiresleep(&ip->lock);
        release(&itable.lock);
        itrunc(ip);
        ip->type = 0;
        iupdate(ip);
        ip->valid = 0;
        releasesleep(&ip->lock);
        acquire(&itable.lock);
    }
    ip->ref--;
    release(&itable.lock);
}

void iunlockput(struct inode *ip)
{
    iunlock(ip);
    iput(ip);
}

// 返回inode 的第bn  块数据对应的磁盘块号, 如果没有则分配一个新块
static uint bmap(struct inode *ip, uint bn)
{
    uint addr, *a;
    struct buf *bp;
    if (bn < NDIRECT) // 说明是直接块，那么直接从数组中读取数据
    {
        if ((addr = ip->addrs[bn]) == 0)
        {
            addr = balloc(ip->dev); // 分配一个新块
            if (addr == 0)
                return 0; // 说明分配失败
            ip->addrs[bn] = addr;
        }
        return addr;
    }
    //  说明是间接块，需要先读取间接块
    bn -= NDIRECT;
    if (bn < NINDIRECT)
    {
        if ((addr = ip->addrs[NDIRECT]) == 0)
        {
            addr = balloc(ip->dev);
            if (addr == 0)
                return 0;
            ip->addrs[NDIRECT] = addr;
        }
        bp = bread(ip->dev, addr);
        a = (uint *)bp->data;
        if ((addr = a[bn]) == 0)
        {
            addr = balloc(ip->dev);
            if (addr)
            {
                a[bn] = addr;
                log_write(bp);
            }
        }
        brelse(bp);
        return addr;
    }
    panic("bmap: out of range");
    return 0;
}
void itrunc(struct inode *ip)
{
    int i, j;
    struct buf *bp;
    uint *a;
    for (i = 0; i < NDIRECT; i++)
    {
        if (ip->addrs[i])
        {
            bfree(ip->dev, ip->addrs[i]);
            ip->addrs[i] = 0;
        }
    }
    if (ip->addrs[NDIRECT])
    {
        bp = bread(ip->dev, ip->addrs[NDIRECT]);
        a = (uint *)bp->data;
        for (j = 0; j < NINDIRECT; j++)
        {
            if (a[j])
                bfree(ip->dev, a[j]);
        }
        brelse(bp);
        bfree(ip->dev, ip->addrs[NDIRECT]);
        ip->addrs[NDIRECT] = 0;
    }
    ip->size = 0;
    iupdate(ip);
}

void stati(struct inode *ip, struct stat *st)
{
    st->dev = ip->dev;
    st->ino = ip->inum;
    st->type = ip->type;
    st->nlink = ip->nlink;
    st->size = ip->size;
}
int readi(struct inode *ip, int user_dst, uint64 dst, uint off, uint n)
{
    uint tot, m;
    struct buf *bp;
    if (off > ip->size || off + n < off)
        return -1;
    if (off + n > ip->size)
        n = ip->size - off;
    for (tot = 0; tot < n; tot += m, off += m, dst += m)
    {
        uint addr = bmap(ip, off / BSIZE);
        if (addr == 0)
            break;
        bp = bread(ip->dev, addr);
        m = min(n - tot, BSIZE - off % BSIZE);
        if (either_copyout(user_dst, dst, bp->data + (off % BSIZE), m) == -1)
        {
            brelse(bp);
            break;
        }
        brelse(bp);
    }
    return tot;
}

int writei(struct inode *ip, int user_src, uint64 src, uint off, uint n)
{
    uint tot, m;
    struct buf *bp;
    if (off > ip->size || off + n < off)
        return -1;
    if (off + n > MAXFILE * BSIZE)
        return -1;
    for (tot = 0; tot < n; tot += m, off += m, src += m)
    {
        uint addr = bmap(ip, off / BSIZE);
        if (addr == 0)
            break;
        bp = bread(ip->dev, addr);
        m = min(n - tot, BSIZE - off % BSIZE);
        if (either_copyin(bp->data + (off % BSIZE), user_src, src, m) == -1)
        {
            brelse(bp);
            break;
        }
        log_write(bp);
        brelse(bp);
    }
    if (off > ip->size)
        ip->size = off;
    iupdate(ip);
    return tot;
}

int namecmp(const char *s, const char *t)
{
    return strncmp(s, t, DIRSIZ);
}
struct inode *dirlookup(struct inode *dp, char *name, uint *poff)
{
    uint off, inum;
    struct dirent de;
    if (dp->type != T_DIR)
        panic("dirlookup not DIR");
    for (off = 0; off < dp->size; off += sizeof(de))
    {
        if (readi(dp, 0, (uint64)&de, off, sizeof(de)) != sizeof(de))
            panic("dirlookup read");
        if (de.inum == 0)
            continue;
        if (namecmp(name, de.name) == 0)
        {
            if (poff)
                *poff = off;
            inum = de.inum;
            return iget(dp->dev, inum);
        }
    }
    return 0;
}
int dirlink(struct inode *dp, char *name, uint inum)
{
    int off;
    struct dirent de;
    struct inode *ip;
    if ((ip = dirlookup(dp, name, 0)) != 0)
    {
        iput(ip);
        return -1;
    }
    for (off = 0; off < dp->size; off += sizeof(de))
    {
        if (readi(dp, 0, (uint64)&de, off, sizeof(de)) != sizeof(de))
            panic("dirlink read");
        if (de.inum == 0)
            break;
    }
    strncpy(de.name, name, DIRSIZ);
    de.inum = inum;
    if (writei(dp, 0, (uint64)&de, off, sizeof(de)) != sizeof(de))
        return -1;
    return 0;
}

static char *skipelem(char *path, char *name)
{
    char *s;
    int len;
    while (*path == '/')
        path++;
    if (*path == 0)
        return 0;
    s = path;
    while (*path != '/' && *path != 0)
        path++;
    len = path - s;
    if (len >= DIRSIZ)
        memmove(name, s, DIRSIZ);
    else
    {
        memmove(name, s, DIRSIZ);
        name[len] = 0;
    }
    while (*path == '/')
        path++;
    return path;
}

static struct inode *namex(char *path, int nameiparent, char *name)
{
    struct inode *ip, *next;
    if (*path == '/')
        ip = iget(ROOTDEV, ROOTINO);
    else
        ip = idup(myproc()->cwd);
    while ((path = skipelem(path, name)) != 0)
    {
        ilock(ip);
        if (ip->type != T_DIR)
        {
            iunlockput(ip);
            return 0;
        }
        if (nameiparent && *path == '\0')
        {
            iunlock(ip);
            return ip;
        }
        if ((next = dirlookup(ip, name, 0)) == 0)
        {
            iunlockput(ip);
            return 0;
        }
        iunlockput(ip);
        ip = next;
    }
    if (nameiparent)
    {
        iput(ip);
        return 0;
    }
    return ip;
}

struct inode *namei(char *path)
{
    char name[DIRSIZ];
    return namex(path, 0, name);
}

struct inode *nameiparent(char *path, char *name)
{
    return namex(path, 1, name);
}
