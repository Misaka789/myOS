# 工具链设置
TOOLPREFIX = riscv64-linux-gnu-
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
CFLAGS += -fno-stack-protector

#目录设置
K = kernel

# 链接选项
LDFLAGS = -z max-page-size=4096

CFLAGS += -fno-pic -fno-pie
LDFLAGS += -no-pie

# 内核目标文件
OBJS = \
  $K/entry.o \
  $K/start.o \
  $K/main.o \
  $K/uart.o \
  $K/printf.o \
  $K/console.o \
  $K/buddy.o	\
  $K/spinlock.o \
  $K/vm.o

# 默认目标
all: $K/kernel

# 编译规则
$K/%.o: $K/%.c
	$(CC) $(CFLAGS) -c -o $@ $<

$K/%.o: $K/%.S
	$(CC) $(CFLAGS) -c -o $@ $<

# 链接内核
$K/kernel: $(OBJS) kernel/kernel.ld
	$(LD) $(LDFLAGS) -T kernel/kernel.ld -o kernel/kernel $(OBJS)
	$(OBJDUMP) -S kernel/kernel > kernel/kernel.asm

# 清理
clean:
	rm -f kernel/*.o kernel/*.d kernel/*.asm kernel/*.sym kernel/kernel

# QEMU运行
QEMUOPTS = -machine virt -bios none -kernel kernel/kernel -m 128M -smp 3 -nographic

qemu: kernel/kernel
	qemu-system-riscv64 $(QEMUOPTS)

# 调试模式
qemu-gdb: kernel/kernel
	qemu-system-riscv64 $(QEMUOPTS) -S -gdb tcp::1234

.PHONY: all clean qemu qemu-gdb
