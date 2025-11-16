# 工具链设置
TOOLPREFIX = riscv64-unknown-elf-
CC = $(TOOLPREFIX)gcc
AS = $(TOOLPREFIX)gas
LD = $(TOOLPREFIX)ld
OBJCOPY = $(TOOLPREFIX)objcopy
OBJDUMP = $(TOOLPREFIX)objdump

# 编译选项
CFLAGS = -Wall -Werror -O -fno-omit-frame-pointer -ggdb
CFLAGS += -MD
CFLAGS += -mcmodel=medany
CFLAGS += -ffreestanding -fno-common -nostdlib -mno-relax
CFLAGS += -I./include
CFLAGS += -I./user
CFLAGS += -fno-stack-protector

#目录设置
K = kernel
U = user
ULIB = user/ulib.o user/usys.o user/printf.o user/umalloc.o


# 宿主机编译器 用来编译 mkfs 使用本机的gcc 
HOSTCC     = gcc
HOSTCFLAGS = -Wall -Werror -O2

# 用户程序列表
UPROGS = \
  $U/_init 


# 链接选项
LDFLAGS = -z max-page-size=4096

CFLAGS += -fno-pic -fno-pie
LDFLAGS += -no-pie

# 内核目标文件
OBJS = \
  $K/entry.o \
  $K/start.o \
  $K/kernelvec.o \
  $K/timervec.o \
  $K/uart.o \
  $K/printf.o \
  $K/console.o \
  $K/trap.o \
  $K/machine_handler.o \
  $K/timer.o \
  $K/spinlock.o \
  $K/buddy.o \
  $K/vm.o \
  $K/debug.o \
  $K/main.o \
  $K/plic.o \
  $K/proc.o \
  $K/trampoline.o \
  $K/swtch.o \
  $K/string.o \
  $K/syscall.o \
  $K/sysproc.o \
  $K/file.o \
  $K/fs.o \
  $K/log.o \
  $K/virtio_disk.o \
  $K/pipe.o \
  $K/bio.o \
  $K/sleeplock.o \
  $K/sysfile.o  \
  $K/exec.o

# 默认目标
all: $K/kernel

# 编译规则
$K/%.o: $K/%.c
	$(CC) $(CFLAGS) -c -o $@ $<

$K/%.o: $K/%.S
	$(CC) $(CFLAGS) -c -o $@ $<

# 链接用户程序
# $U/_%: $U/%.c
# 	$(CC) $(CFLAGS) -c -o $@.o $<
# 	$(LD) -Ttext 0 -e main -nostdlib -o $@ $@.o
# 	rm -f $@.o


# 编译单个 user 源文件为 .o
user/%.o: user/%.c
	$(CC) $(CFLAGS) -c -o $@ $<

# 这里假设你有 user/user.ld 链接脚本（可以从 xv6 拷一份）
user/_%: user/%.o $(ULIB) user/user.ld
	$(LD) -T user/user.ld -o $@ $< $(ULIB)

# 链接内核
$K/kernel: $(OBJS) kernel/kernel.ld
	$(LD) $(LDFLAGS) -T kernel/kernel.ld -o kernel/kernel $(OBJS)
	$(OBJDUMP) -S kernel/kernel > kernel/kernel.asm

# 编译 mkfs 工具 （宿主机程序）
mkfs/mkfs: mkfs/mkfs.c include/fs.h include/param.h
	$(HOSTCC) $(HOSTCFLAGS) -I./include -o mkfs/mkfs mkfs/mkfs.c

# 生成 usys.S（系统调用封装）
user/usys.S: user/usys.pl include/syscall.h
	perl user/usys.pl > user/usys.S

# 编译 usys.S 为 usys.o
user/usys.o: user/usys.S
	$(CC) $(CFLAGS) -c -o user/usys.o user/usys.S

# 所有用户程序的路径
UPROGS_BIN = $(UPROGS)

# 生成文件系统镜像 fs.img
fs.img: mkfs/mkfs $(UPROGS_BIN)
	./mkfs/mkfs fs.img $(UPROGS_BIN)

# 清理
clean:
	rm -f kernel/*.o kernel/*.d kernel/*.asm kernel/*.sym kernel/kernel
	rm -f fs.img
	rm -f mkfs/mkfs
	rm -f user/_*
	rm -f user/*.o user/*.d
# QEMU运行
QEMUOPTS = -machine virt -bios none -kernel kernel/kernel -m 128M -smp 1 -nographic

QEMUOPTS += -drive file=fs.img,if=none,format=raw,id=x0
QEMUOPTS += -device virtio-blk-device,drive=x0

qemu: kernel/kernel fs.img
	qemu-system-riscv64 $(QEMUOPTS)

# 调试模式
qemu-gdb: kernel/kernel fs.img
	qemu-system-riscv64 $(QEMUOPTS) -S -gdb tcp::1234

.PHONY: all clean qemu qemu-gdb
