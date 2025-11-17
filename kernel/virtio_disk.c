#include "types.h"
#include "riscv.h"
#include "defs.h"
#include "param.h"
#include "memlayout.h"
#include "spinlock.h"
#include "sleeplock.h"
#include "fs.h"
#include "buf.h"
#include "virtio.h"

#define R(r) ((volatile uint32 *)(VIRTIO0 + (r))) // virtio mmio 寄存器地址

static struct disk
{
    struct virtq_desc *desc;   // DMA 描述符
    struct virtq_avail *avail; // 可用环
    struct virtq_used *used;   // 已使用环
    char free[NUM];            // 描述符是否空闲
    uint16 used_idx;           // 已使用环索引
    struct
    {
        struct buf *b;
        char status;
    } info[NUM];                    // 跟踪正在进行的操作
    struct virtio_blk_req ops[NUM]; // 磁盘命令头
    struct spinlock vdisk_lock;     // 虚拟磁盘锁
} disk;

void virtio_disk_init(void)
{
    printf("[virtio_disk_init]: enter function \n");
    uint64 status = 0;
    initlock(&disk.vdisk_lock, "vdisk");

    // debug
    printf("[virtio_disk_init]: VIRTIO0 base=%p\n", (void *)VIRTIO0);
    uint32 magic = *R(VIRTIO_MMIO_MAGIC_VALUE);
    uint32 version = *R(VIRTIO_MMIO_VERSION);
    uint32 did = *R(VIRTIO_MMIO_DEVICE_ID);
    uint32 vendor = *R(VIRTIO_MMIO_VENDOR_ID);

    printf("[virtio_disk_init]: magic=0x%x version=%d did=%d vendor=0x%x\n",
           magic, version, did, vendor);

    if (magic != 0x74726976 || version != 2 || did != 2 || vendor != 0x554d4551)
    {
        panic("virtio_disk_init: could not find virtio-blk mmio device");
    }

    uint32 status_reg = *R(VIRTIO_MMIO_STATUS);
    uint32 irq_status = *R(VIRTIO_MMIO_INTERRUPT_STATUS);
    uint32 qnum_max = *R(VIRTIO_MMIO_QUEUE_NUM_MAX);

    printf("[virtio_disk_init]: status=0x%x, irq_status=0x%x, qnum_max=%d\n",
           status_reg, irq_status, qnum_max);

    if (*R(VIRTIO_MMIO_MAGIC_VALUE) != 0x74726976 ||
        // *R(VIRTIO_MMIO_VERSION) != 2 ||
        *R(VIRTIO_MMIO_DEVICE_ID) != 2 ||
        *R(VIRTIO_MMIO_VENDOR_ID) != 0x554d4551)
    {
        panic("could not find virtio disk");
    }

    // reset device
    *R(VIRTIO_MMIO_STATUS) = status;

    // set ACKNOWLEDGE status bit
    status |= VIRTIO_CONFIG_S_ACKNOWLEDGE;
    *R(VIRTIO_MMIO_STATUS) = status;

    // set DRIVER status bit
    status |= VIRTIO_CONFIG_S_DRIVER;
    *R(VIRTIO_MMIO_STATUS) = status;

    // negotiate features
    uint64 features = *R(VIRTIO_MMIO_DEVICE_FEATURES);
    features &= ~(1 << VIRTIO_BLK_F_RO);
    features &= ~(1 << VIRTIO_BLK_F_SCSI);
    features &= ~(1 << VIRTIO_BLK_F_CONFIG_WCE);
    features &= ~(1 << VIRTIO_BLK_F_MQ);
    features &= ~(1 << VIRTIO_F_ANY_LAYOUT);
    features &= ~(1 << VIRTIO_RING_F_EVENT_IDX);
    features &= ~(1 << VIRTIO_RING_F_INDIRECT_DESC);
    *R(VIRTIO_MMIO_DRIVER_FEATURES) = features;

    // tell device that feature negotiation is complete.
    status |= VIRTIO_CONFIG_S_FEATURES_OK;
    *R(VIRTIO_MMIO_STATUS) = status;

    // re-read status to ensure FEATURES_OK is set.
    status = *R(VIRTIO_MMIO_STATUS);
    if (!(status & VIRTIO_CONFIG_S_FEATURES_OK))
        panic("virtio disk FEATURES_OK unset");

    // initialize queue 0.
    *R(VIRTIO_MMIO_QUEUE_SEL) = 0;

    // ensure queue 0 is not in use.
    if (*R(VIRTIO_MMIO_QUEUE_READY))
        panic("virtio disk should not be ready");

    // check maximum queue size.
    uint32 max = *R(VIRTIO_MMIO_QUEUE_NUM_MAX);
    if (max == 0)
        panic("virtio disk has no queue 0");
    if (max < NUM)
        panic("virtio disk max queue too short");

    // allocate and zero queue memory.
    disk.desc = kalloc();
    disk.avail = kalloc();
    disk.used = kalloc();
    if (!disk.desc || !disk.avail || !disk.used)
        panic("virtio disk kalloc");
    memset(disk.desc, 0, PGSIZE);
    memset(disk.avail, 0, PGSIZE);
    memset(disk.used, 0, PGSIZE);

    // set queue size.
    *R(VIRTIO_MMIO_QUEUE_NUM) = NUM;

    // write physical addresses.
    *R(VIRTIO_MMIO_QUEUE_DESC_LOW) = (uint64)disk.desc;
    *R(VIRTIO_MMIO_QUEUE_DESC_HIGH) = (uint64)disk.desc >> 32;
    *R(VIRTIO_MMIO_DRIVER_DESC_LOW) = (uint64)disk.avail;
    *R(VIRTIO_MMIO_DRIVER_DESC_HIGH) = (uint64)disk.avail >> 32;
    *R(VIRTIO_MMIO_DEVICE_DESC_LOW) = (uint64)disk.used;
    *R(VIRTIO_MMIO_DEVICE_DESC_HIGH) = (uint64)disk.used >> 32;

    // queue is ready.
    *R(VIRTIO_MMIO_QUEUE_READY) = 0x1;

    // all NUM descriptors start out unused.
    for (int i = 0; i < NUM; i++)
        disk.free[i] = 1;

    // tell device we're completely ready.
    status |= VIRTIO_CONFIG_S_DRIVER_OK;
    *R(VIRTIO_MMIO_STATUS) = status;
    printf("[virtio_disk_init]: virtio disk initialized \n");
    // plic.c and trap.c arrange for interrupts from VIRTIO0_IRQ.
}

// find a free descriptor, mark it non-free, return its index.
static int
alloc_desc()
{
    for (int i = 0; i < NUM; i++)
    {
        if (disk.free[i])
        {
            disk.free[i] = 0;
            return i;
        }
    }
    return -1;
}

// mark a descriptor as free.
static void
free_desc(int i)
{
    if (i >= NUM)
        panic("free_desc 1");
    if (disk.free[i])
        panic("free_desc 2");
    disk.desc[i].addr = 0;
    disk.desc[i].len = 0;
    disk.desc[i].flags = 0;
    disk.desc[i].next = 0;
    disk.free[i] = 1;
    wakeup(&disk.free[0]);
}

// free a chain of descriptors.
static void
free_chain(int i)
{
    while (1)
    {
        int flag = disk.desc[i].flags;
        int nxt = disk.desc[i].next;
        free_desc(i);
        if (flag & VRING_DESC_F_NEXT)
            i = nxt;
        else
            break;
    }
}

// allocate three descriptors (they need not be contiguous).
// disk transfers always use three descriptors.
static int
alloc3_desc(int *idx)
{
    for (int i = 0; i < 3; i++)
    {
        idx[i] = alloc_desc();
        if (idx[i] < 0)
        {
            for (int j = 0; j < i; j++)
                free_desc(idx[j]);
            return -1;
        }
    }
    return 0;
}

void virtio_disk_rw(struct buf *b, int write)
{
    printf("[virtio_disk_rw]: enter function \n");
    printf("[virtio_disk_rw]: enter, b=%p, write=%d\n", b, write);
    uint64 sector = b->blockno * (BSIZE / 512);
    printf("[virtio_disk_rw]: sector=%p\n", sector);
    acquire(&disk.vdisk_lock);

    // the spec's Section 5.2 says that legacy block operations use
    // three descriptors: one for type/reserved/sector, one for the
    // data, one for a 1-byte status result.

    // allocate the three descriptors.
    int idx[3];
    while (1)
    {
        int r = alloc3_desc(idx);
        printf("[virtio_disk_rw]: alloc3_desc returned %d, idx[0]=%d, idx[1]=%d, idx[2]=%d\n",
               r, idx[0], idx[1], idx[2]);
        printf("[virtio_disk_rw]: disk.desc=%p, disk.info=%p, b->data=%p\n",
               disk.desc, disk.info, b->data);
        if (r == 0)
        {
            break;
        }
        sleep(&disk.free[0], &disk.vdisk_lock);
    }

    // format the three descriptors.
    // qemu's virtio-blk.c reads them.

    struct virtio_blk_req *buf0 = &disk.ops[idx[0]];
    printf("[virtio_disk_rw]: buf0=%p\n", buf0);

    if (write)
        buf0->type = VIRTIO_BLK_T_OUT; // write the disk
    else
        buf0->type = VIRTIO_BLK_T_IN; // read the disk
    buf0->reserved = 0;
    buf0->sector = sector;

    // 填 header
    printf("[virtio_disk_rw]: header filled\n");

    disk.desc[idx[0]].addr = (uint64)buf0;
    disk.desc[idx[0]].len = sizeof(struct virtio_blk_req);
    disk.desc[idx[0]].flags = VRING_DESC_F_NEXT;
    disk.desc[idx[0]].next = idx[1];

    // 填 desc[1]
    printf("[virtio_disk_rw]: desc[0] filled\n");

    disk.desc[idx[1]].addr = (uint64)b->data;
    disk.desc[idx[1]].len = BSIZE;
    if (write)
        disk.desc[idx[1]].flags = 0; // device reads b->data
    else
        disk.desc[idx[1]].flags = VRING_DESC_F_WRITE; // device writes b->data
    disk.desc[idx[1]].flags |= VRING_DESC_F_NEXT;
    disk.desc[idx[1]].next = idx[2];

    // 填 desc[2]
    printf("[virtio_disk_rw]: desc[1] filled\n");

    disk.info[idx[0]].status = 0xff; // device writes 0 on success
    disk.desc[idx[2]].addr = (uint64)&disk.info[idx[0]].status;
    disk.desc[idx[2]].len = 1;
    disk.desc[idx[2]].flags = VRING_DESC_F_WRITE; // device writes the status
    disk.desc[idx[2]].next = 0;

    printf("[virtio_disk_rw]: desc[2] filled\n");

    // record struct buf for virtio_disk_intr().
    b->disk = 1;
    disk.info[idx[0]].b = b;
    int avail_idx = disk.avail->idx % NUM;

    printf("[virtio_disk_rw]: before avail, avail->idx=%d, idx_avail=%d\n",
           disk.avail->idx, avail_idx);

    // tell the device the first index in our chain of descriptors.
    disk.avail->ring[disk.avail->idx % NUM] = idx[0];

    __sync_synchronize();

    // tell the device another avail ring entry is available.
    disk.avail->idx += 1; // not % NUM ...

    printf("[virtio_disk_rw]: after avail, avail->idx=%d, ring[%d]=%d\n",
           disk.avail->idx, avail_idx, disk.avail->ring[disk.avail->idx % NUM]);

    __sync_synchronize();
    printf("[virtio_disk_rw]: before notify, QUEUE_NOTIFY addr=%p\n",
           VIRTIO_MMIO_QUEUE_NOTIFY);

    *R(VIRTIO_MMIO_QUEUE_NOTIFY) = 0; // value is queue number

    // 调试：主动看看设备的中断状态（最多等一会儿）
    int i;
    for (i = 0; i < 1000000; i++)
    {
        uint32 isr = *R(VIRTIO_MMIO_INTERRUPT_STATUS);
        if (isr)
        {
            printf("[virtio_disk_rw]: isr (poll)=0x%x (i=%d)\n", isr, i);
            break;
        }
        // 再顺便看一下 used->idx（需要 barrier）
        __sync_synchronize();
        if (disk.used->idx != 0)
        {
            printf("[virtio_disk_rw]: used->idx changed to %d (i=%d)\n",
                   disk.used->idx, i);
            break;
        }
    }
    if (i == 1000000)
    {
        printf("[virtio_disk_rw]: isr==0 & used->idx==%d after polling\n",
               disk.used->idx);
    }

        volatile uint32 *pending = (uint32 *)(PLIC + 0x1000);
    uint32 p0 = pending[0]; // 覆盖 IRQ 1..31 等

    printf("[plic_debug]: pending[0]=0x%x\n", p0);
    printf("[virtio_disk_rw]: after notify, waiting for completion\n");

    // Wait for virtio_disk_intr() to say request has finished.
    printf("[virtio_disk_rw]: before sleep, b->disk=%d\n", b->disk);
    while (b->disk == 1)
    {
        sleep(b, &disk.vdisk_lock);
    }

    disk.info[idx[0]].b = 0;
    free_chain(idx[0]);

    release(&disk.vdisk_lock);
    printf("[virtio_disk_rw]: exit function \n");
}

void virtio_disk_intr()
{
    printf("[virtio_disk_intr]: enter function \n");
    acquire(&disk.vdisk_lock);

    // the device won't raise another interrupt until we tell it
    // we've seen this interrupt, which the following line does.
    // this may race with the device writing new entries to
    // the "used" ring, in which case we may process the new
    // completion entries in this interrupt, and have nothing to do
    // in the next interrupt, which is harmless.
    *R(VIRTIO_MMIO_INTERRUPT_ACK) = *R(VIRTIO_MMIO_INTERRUPT_STATUS) & 0x3;

    __sync_synchronize();

    // the device increments disk.used->idx when it
    // adds an entry to the used ring.

    while (disk.used_idx != disk.used->idx)
    {
        __sync_synchronize();
        int id = disk.used->ring[disk.used_idx % NUM].id;

        if (disk.info[id].status != 0)
            panic("virtio_disk_intr status");

        struct buf *b = disk.info[id].b;
        b->disk = 0; // disk is done with buf
        wakeup(b);

        disk.used_idx += 1;
    }

    release(&disk.vdisk_lock);
}
