
kernel/kernel:     file format elf64-littleriscv


Disassembly of section .text:

0000000080000000 <_entry>:
_entry:
    # 为每个 CPU 设置独立的启动栈
    # stack0 在 start.c 中定义，每个 CPU 分配 4KB 栈空间
    # 公式: sp = stack0 + (hartid + 1) * 4096
    
    la sp, stack0           # 加载 stack0 基地址到栈指针
    80000000:	00003117          	auipc	sp,0x3
    80000004:	d4013103          	ld	sp,-704(sp) # 80002d40 <_GLOBAL_OFFSET_TABLE_+0x10>
    li a0, 1024*4           # a0 = 4096 (每个CPU的栈大小)
    80000008:	6505                	lui	a0,0x1
    csrr a1, mhartid        # a1 = 当前CPU的hart ID
    8000000a:	f14025f3          	csrr	a1,mhartid
    addi a1, a1, 1          # a1 = hartid + 1 (避免使用索引0)
    8000000e:	0585                	addi	a1,a1,1
    mul a0, a0, a1          # a0 = 4096 * (hartid + 1)
    80000010:	02b50533          	mul	a0,a0,a1
    add sp, sp, a0          # sp = stack0 + 偏移量
    80000014:	912a                	add	sp,sp,a0
    
    # 跳转到 C 语言的 start 函数
    call start
    80000016:	00000097          	auipc	ra,0x0
    8000001a:	044080e7          	jalr	68(ra) # 8000005a <start>

000000008000001e <spin>:
    
    # 如果 start 函数返回（不应该发生），则无限循环
spin:
    8000001e:	a001                	j	8000001e <spin>

0000000080000020 <kernelvec>:
// 定时器初始化函数
void timerinit();

// 机器模式异常处理向量（暂时为空）
void kernelvec()
{
    80000020:	1141                	addi	sp,sp,-16
    80000022:	e422                	sd	s0,8(sp)
    80000024:	0800                	addi	s0,sp,16
    // 这里暂时什么都不做
    // 在后面的阶段会实现完整的异常处理
}
    80000026:	6422                	ld	s0,8(sp)
    80000028:	0141                	addi	sp,sp,16
    8000002a:	8082                	ret

000000008000002c <timerinit>:
    }
}

// 定时器初始化 - 设置下一次定时器中断
void timerinit()
{
    8000002c:	1141                	addi	sp,sp,-16
    8000002e:	e422                	sd	s0,8(sp)
    80000030:	0800                	addi	s0,sp,16
// 读取 mhartid CSR (machine hart ID)
static inline uint64
r_mhartid()
{
  uint64 x;
  asm volatile("csrr %0, mhartid" : "=r"(x));
    80000032:	f1402773          	csrr	a4,mhartid

    // 读取当前时间并设置下一次中断时间
    // CLINT (Core Local Interrupt Controller) 地址布局：
    // - 0x2000000 + 0xbff8: 当前时间寄存器
    // - 0x2000000 + 0x4000 + 8*hartid: 各CPU的时间比较寄存器
    *(uint64 *)(CLINT + 0x4000 + 8 * id) =
    80000036:	0037171b          	slliw	a4,a4,0x3
    8000003a:	020047b7          	lui	a5,0x2004
    8000003e:	97ba                	add	a5,a5,a4
        *(uint64 *)(CLINT + 0xbff8) + interval;
    80000040:	0200c737          	lui	a4,0x200c
    80000044:	1761                	addi	a4,a4,-8 # 200bff8 <_entry-0x7dff4008>
    80000046:	6318                	ld	a4,0(a4)
    80000048:	000f46b7          	lui	a3,0xf4
    8000004c:	24068693          	addi	a3,a3,576 # f4240 <_entry-0x7ff0bdc0>
    80000050:	9736                	add	a4,a4,a3
    *(uint64 *)(CLINT + 0x4000 + 8 * id) =
    80000052:	e398                	sd	a4,0(a5)
}
    80000054:	6422                	ld	s0,8(sp)
    80000056:	0141                	addi	sp,sp,16
    80000058:	8082                	ret

000000008000005a <start>:
{
    8000005a:	1141                	addi	sp,sp,-16
    8000005c:	e406                	sd	ra,8(sp)
    8000005e:	e022                	sd	s0,0(sp)
    80000060:	0800                	addi	s0,sp,16

// 写入机器陷阱向量基址寄存器 mtvec
static inline void
w_mtvec(uint64 x)
{
  asm volatile("csrw mtvec, %0" : : "r"(x));
    80000062:	00000797          	auipc	a5,0x0
    80000066:	fbe78793          	addi	a5,a5,-66 # 80000020 <kernelvec>
    8000006a:	30579073          	csrw	mtvec,a5
  asm volatile("csrr %0, mstatus" : "=r"(x));
    8000006e:	300027f3          	csrr	a5,mstatus
    x &= ~MSTATUS_MPP_MASK; // 清除MPP字段
    80000072:	7779                	lui	a4,0xffffe
    80000074:	7ff70713          	addi	a4,a4,2047 # ffffffffffffe7ff <end+0xffffffff7fff3797>
    80000078:	8ff9                	and	a5,a5,a4
    x |= MSTATUS_MPP_S;     // 设置为监管者模式
    8000007a:	6705                	lui	a4,0x1
    8000007c:	80070713          	addi	a4,a4,-2048 # 800 <_entry-0x7ffff800>
    80000080:	8fd9                	or	a5,a5,a4
  asm volatile("csrw mstatus, %0" : : "r"(x));
    80000082:	30079073          	csrw	mstatus,a5
  return x;
}

static inline void w_mepc(uint64 x)
{
  asm volatile("csrw mepc, %0" : : "r"(x));
    80000086:	00003797          	auipc	a5,0x3
    8000008a:	cca7b783          	ld	a5,-822(a5) # 80002d50 <_GLOBAL_OFFSET_TABLE_+0x20>
    8000008e:	34179073          	csrw	mepc,a5
  asm volatile("csrr %0, mie" : "=r"(x));
    80000092:	304027f3          	csrr	a5,mie
    w_mie(r_mie() | MIE_MTIE);
    80000096:	0807e793          	ori	a5,a5,128
  asm volatile("csrw mie, %0" : : "r"(x));
    8000009a:	30479073          	csrw	mie,a5
    asm volatile("csrw pmpaddr0, %0" : : "r"(0x3fffffffffffffull));
    8000009e:	57fd                	li	a5,-1
    800000a0:	83a9                	srli	a5,a5,0xa
    800000a2:	3b079073          	csrw	pmpaddr0,a5
    asm volatile("csrw pmpcfg0, %0" : : "r"(0xf));
    800000a6:	47bd                	li	a5,15
    800000a8:	3a079073          	csrw	pmpcfg0,a5
    timerinit();
    800000ac:	00000097          	auipc	ra,0x0
    800000b0:	f80080e7          	jalr	-128(ra) # 8000002c <timerinit>
  asm volatile("csrr %0, mhartid" : "=r"(x));
    800000b4:	f14027f3          	csrr	a5,mhartid
    if (id == 0)
    800000b8:	2781                	sext.w	a5,a5
    800000ba:	c391                	beqz	a5,800000be <start+0x64>
        for (;;)
    800000bc:	a001                	j	800000bc <start+0x62>
        main(); // 跳转到内核主初始化函数
    800000be:	00000097          	auipc	ra,0x0
    800000c2:	032080e7          	jalr	50(ra) # 800000f0 <main>
}
    800000c6:	60a2                	ld	ra,8(sp)
    800000c8:	6402                	ld	s0,0(sp)
    800000ca:	0141                	addi	sp,sp,16
    800000cc:	8082                	ret

00000000800000ce <memset>:
void console_clear(void);
void consputc(int); */

// 简单的内存清零函数
void *memset(void *dst, int c, uint n)
{
    800000ce:	1141                	addi	sp,sp,-16
    800000d0:	e422                	sd	s0,8(sp)
    800000d2:	0800                	addi	s0,sp,16
    char *cdst = (char *)dst;
    int i;
    for (i = 0; i < n; i++)
    800000d4:	ca19                	beqz	a2,800000ea <memset+0x1c>
    800000d6:	87aa                	mv	a5,a0
    800000d8:	1602                	slli	a2,a2,0x20
    800000da:	9201                	srli	a2,a2,0x20
    800000dc:	00a60733          	add	a4,a2,a0
    {
        cdst[i] = c;
    800000e0:	00b78023          	sb	a1,0(a5)
    for (i = 0; i < n; i++)
    800000e4:	0785                	addi	a5,a5,1
    800000e6:	fee79de3          	bne	a5,a4,800000e0 <memset+0x12>
    }
    return dst;
}
    800000ea:	6422                	ld	s0,8(sp)
    800000ec:	0141                	addi	sp,sp,16
    800000ee:	8082                	ret

00000000800000f0 <main>:

void main()
{
    800000f0:	1101                	addi	sp,sp,-32
    800000f2:	ec06                	sd	ra,24(sp)
    800000f4:	e822                	sd	s0,16(sp)
    800000f6:	e426                	sd	s1,8(sp)
    800000f8:	1000                	addi	s0,sp,32
    // 1. 清零BSS段
    // BSS段包含未初始化的全局变量，C语言标准要求它们初始化为0
    memset(edata, 0, end - edata);
    800000fa:	00003517          	auipc	a0,0x3
    800000fe:	c3e53503          	ld	a0,-962(a0) # 80002d38 <_GLOBAL_OFFSET_TABLE_+0x8>
    80000102:	00003617          	auipc	a2,0x3
    80000106:	c4663603          	ld	a2,-954(a2) # 80002d48 <_GLOBAL_OFFSET_TABLE_+0x18>
    8000010a:	9e09                	subw	a2,a2,a0
    8000010c:	4581                	li	a1,0
    8000010e:	00000097          	auipc	ra,0x0
    80000112:	fc0080e7          	jalr	-64(ra) # 800000ce <memset>

    // 2. 打印启动信息
    uartinit(); // 初始化串口
    80000116:	00000097          	auipc	ra,0x0
    8000011a:	20c080e7          	jalr	524(ra) # 80000322 <uartinit>
    uartputs("riscv-os kernel is starting...\n");
    8000011e:	00002517          	auipc	a0,0x2
    80000122:	ee250513          	addi	a0,a0,-286 # 80002000 <_trampoline>
    80000126:	00000097          	auipc	ra,0x0
    8000012a:	260080e7          	jalr	608(ra) # 80000386 <uartputs>
    8000012e:	f14024f3          	csrr	s1,mhartid

    uint64 hartid = r_mhartid();
    uartputs("hart ID :");
    80000132:	00002517          	auipc	a0,0x2
    80000136:	eee50513          	addi	a0,a0,-274 # 80002020 <_trampoline+0x20>
    8000013a:	00000097          	auipc	ra,0x0
    8000013e:	24c080e7          	jalr	588(ra) # 80000386 <uartputs>
    uartputc('0' + (hartid & 0xf)); // 仅打印最低4位，假设CPU数量不超过16
    80000142:	00f4f513          	andi	a0,s1,15
    80000146:	03050513          	addi	a0,a0,48
    8000014a:	00000097          	auipc	ra,0x0
    8000014e:	214080e7          	jalr	532(ra) # 8000035e <uartputc>
    uartputs(" started\n");
    80000152:	00002517          	auipc	a0,0x2
    80000156:	ede50513          	addi	a0,a0,-290 # 80002030 <_trampoline+0x30>
    8000015a:	00000097          	auipc	ra,0x0
    8000015e:	22c080e7          	jalr	556(ra) # 80000386 <uartputs>
    uartputs("Hart ");
    80000162:	00002517          	auipc	a0,0x2
    80000166:	ede50513          	addi	a0,a0,-290 # 80002040 <_trampoline+0x40>
    8000016a:	00000097          	auipc	ra,0x0
    8000016e:	21c080e7          	jalr	540(ra) # 80000386 <uartputs>
    // 这里可以打印CPU ID，但需要实现数字转字符串函数
    uartputs("started\n");
    80000172:	00002517          	auipc	a0,0x2
    80000176:	ed650513          	addi	a0,a0,-298 # 80002048 <_trampoline+0x48>
    8000017a:	00000097          	auipc	ra,0x0
    8000017e:	20c080e7          	jalr	524(ra) # 80000386 <uartputs>

    // 3. 基础系统初始化
    uartputs("Basic initialization complete\n");
    80000182:	00002517          	auipc	a0,0x2
    80000186:	ed650513          	addi	a0,a0,-298 # 80002058 <_trampoline+0x58>
    8000018a:	00000097          	auipc	ra,0x0
    8000018e:	1fc080e7          	jalr	508(ra) # 80000386 <uartputs>

    // 3. 清屏并显示启动信息
    console_clear();
    80000192:	00001097          	auipc	ra,0x1
    80000196:	97a080e7          	jalr	-1670(ra) # 80000b0c <console_clear>
    printf("RISC-V OS Kernel Starting...\n");
    8000019a:	00002517          	auipc	a0,0x2
    8000019e:	ede50513          	addi	a0,a0,-290 # 80002078 <_trampoline+0x78>
    800001a2:	00000097          	auipc	ra,0x0
    800001a6:	52e080e7          	jalr	1326(ra) # 800006d0 <printf>
    printf("==============================\n");
    800001aa:	00002517          	auipc	a0,0x2
    800001ae:	eee50513          	addi	a0,a0,-274 # 80002098 <_trampoline+0x98>
    800001b2:	00000097          	auipc	ra,0x0
    800001b6:	51e080e7          	jalr	1310(ra) # 800006d0 <printf>

    // 4. 显示系统信息
    // uint64 hartid = r_mhartid();
    printf("Hart ID: %d\n", (int)hartid);
    800001ba:	0004859b          	sext.w	a1,s1
    800001be:	00002517          	auipc	a0,0x2
    800001c2:	efa50513          	addi	a0,a0,-262 # 800020b8 <_trampoline+0xb8>
    800001c6:	00000097          	auipc	ra,0x0
    800001ca:	50a080e7          	jalr	1290(ra) # 800006d0 <printf>
    printf("Hart started successfully\n");
    800001ce:	00002517          	auipc	a0,0x2
    800001d2:	efa50513          	addi	a0,a0,-262 # 800020c8 <_trampoline+0xc8>
    800001d6:	00000097          	auipc	ra,0x0
    800001da:	4fa080e7          	jalr	1274(ra) # 800006d0 <printf>

    // 5. 测试各种 printf 格式
    printf("Testing printf formats:\n");
    800001de:	00002517          	auipc	a0,0x2
    800001e2:	f0a50513          	addi	a0,a0,-246 # 800020e8 <_trampoline+0xe8>
    800001e6:	00000097          	auipc	ra,0x0
    800001ea:	4ea080e7          	jalr	1258(ra) # 800006d0 <printf>
    printf("Decimal: %d\n", 42);
    800001ee:	02a00593          	li	a1,42
    800001f2:	00002517          	auipc	a0,0x2
    800001f6:	f1650513          	addi	a0,a0,-234 # 80002108 <_trampoline+0x108>
    800001fa:	00000097          	auipc	ra,0x0
    800001fe:	4d6080e7          	jalr	1238(ra) # 800006d0 <printf>
    printf("Hex: 0x%x\n", 255);
    80000202:	0ff00593          	li	a1,255
    80000206:	00002517          	auipc	a0,0x2
    8000020a:	f1250513          	addi	a0,a0,-238 # 80002118 <_trampoline+0x118>
    8000020e:	00000097          	auipc	ra,0x0
    80000212:	4c2080e7          	jalr	1218(ra) # 800006d0 <printf>
    printf("Pointer: %p\n", (void *)main);
    80000216:	00000597          	auipc	a1,0x0
    8000021a:	eda58593          	addi	a1,a1,-294 # 800000f0 <main>
    8000021e:	00002517          	auipc	a0,0x2
    80000222:	f0a50513          	addi	a0,a0,-246 # 80002128 <_trampoline+0x128>
    80000226:	00000097          	auipc	ra,0x0
    8000022a:	4aa080e7          	jalr	1194(ra) # 800006d0 <printf>
    printf("String: %s\n", "Hello, World!");
    8000022e:	00002597          	auipc	a1,0x2
    80000232:	f0a58593          	addi	a1,a1,-246 # 80002138 <_trampoline+0x138>
    80000236:	00002517          	auipc	a0,0x2
    8000023a:	f1250513          	addi	a0,a0,-238 # 80002148 <_trampoline+0x148>
    8000023e:	00000097          	auipc	ra,0x0
    80000242:	492080e7          	jalr	1170(ra) # 800006d0 <printf>
    printf("Character: %c\n", 'A');
    80000246:	04100593          	li	a1,65
    8000024a:	00002517          	auipc	a0,0x2
    8000024e:	f0e50513          	addi	a0,a0,-242 # 80002158 <_trampoline+0x158>
    80000252:	00000097          	auipc	ra,0x0
    80000256:	47e080e7          	jalr	1150(ra) # 800006d0 <printf>

    // 6. 内存dump示例
    printf("\nMemory dump example:\n");
    8000025a:	00002517          	auipc	a0,0x2
    8000025e:	f0e50513          	addi	a0,a0,-242 # 80002168 <_trampoline+0x168>
    80000262:	00000097          	auipc	ra,0x0
    80000266:	46e080e7          	jalr	1134(ra) # 800006d0 <printf>
    // char test_data[] = "Hello, RISC-V OS!";
    char *test_data = "Hello, RISC-V OS!";
    printf("test_data declared\n");
    8000026a:	00002517          	auipc	a0,0x2
    8000026e:	f1650513          	addi	a0,a0,-234 # 80002180 <_trampoline+0x180>
    80000272:	00000097          	auipc	ra,0x0
    80000276:	45e080e7          	jalr	1118(ra) # 800006d0 <printf>
    printf("test_data address: %p\n", (void *)test_data);
    8000027a:	00002597          	auipc	a1,0x2
    8000027e:	f1e58593          	addi	a1,a1,-226 # 80002198 <_trampoline+0x198>
    80000282:	00002517          	auipc	a0,0x2
    80000286:	f2e50513          	addi	a0,a0,-210 # 800021b0 <_trampoline+0x1b0>
    8000028a:	00000097          	auipc	ra,0x0
    8000028e:	446080e7          	jalr	1094(ra) # 800006d0 <printf>
    printf("sizeof(test_data): %d\n", (int)sizeof(test_data));
    80000292:	45a1                	li	a1,8
    80000294:	00002517          	auipc	a0,0x2
    80000298:	f3450513          	addi	a0,a0,-204 # 800021c8 <_trampoline+0x1c8>
    8000029c:	00000097          	auipc	ra,0x0
    800002a0:	434080e7          	jalr	1076(ra) # 800006d0 <printf>

    // hexdump(test_data, sizeof(test_data));

    // 7. 系统状态
    printf("\nSystem Status:\n");
    800002a4:	00002517          	auipc	a0,0x2
    800002a8:	f3c50513          	addi	a0,a0,-196 # 800021e0 <_trampoline+0x1e0>
    800002ac:	00000097          	auipc	ra,0x0
    800002b0:	424080e7          	jalr	1060(ra) # 800006d0 <printf>
    printf("- UART: OK\n");
    800002b4:	00002517          	auipc	a0,0x2
    800002b8:	f4450513          	addi	a0,a0,-188 # 800021f8 <_trampoline+0x1f8>
    800002bc:	00000097          	auipc	ra,0x0
    800002c0:	414080e7          	jalr	1044(ra) # 800006d0 <printf>
    printf("- Console: OK\n");
    800002c4:	00002517          	auipc	a0,0x2
    800002c8:	f4450513          	addi	a0,a0,-188 # 80002208 <_trampoline+0x208>
    800002cc:	00000097          	auipc	ra,0x0
    800002d0:	404080e7          	jalr	1028(ra) # 800006d0 <printf>
    printf("- Printf: OK\n");
    800002d4:	00002517          	auipc	a0,0x2
    800002d8:	f4450513          	addi	a0,a0,-188 # 80002218 <_trampoline+0x218>
    800002dc:	00000097          	auipc	ra,0x0
    800002e0:	3f4080e7          	jalr	1012(ra) # 800006d0 <printf>
    console_clear();
    800002e4:	00001097          	auipc	ra,0x1
    800002e8:	828080e7          	jalr	-2008(ra) # 80000b0c <console_clear>

    printf("\nKernel initialization complete!\n");
    800002ec:	00002517          	auipc	a0,0x2
    800002f0:	f3c50513          	addi	a0,a0,-196 # 80002228 <_trampoline+0x228>
    800002f4:	00000097          	auipc	ra,0x0
    800002f8:	3dc080e7          	jalr	988(ra) # 800006d0 <printf>
    printf("Entering idle loop...\n");
    800002fc:	00002517          	auipc	a0,0x2
    80000300:	f5450513          	addi	a0,a0,-172 # 80002250 <_trampoline+0x250>
    80000304:	00000097          	auipc	ra,0x0
    80000308:	3cc080e7          	jalr	972(ra) # 800006d0 <printf>

    // 4. 进入无限循环
    // 在后续阶段，这里会被进程调度器替代
    uartputs("Kernel initialization finished, entering idle loop\n");
    8000030c:	00002517          	auipc	a0,0x2
    80000310:	f5c50513          	addi	a0,a0,-164 # 80002268 <_trampoline+0x268>
    80000314:	00000097          	auipc	ra,0x0
    80000318:	072080e7          	jalr	114(ra) # 80000386 <uartputs>

    for (;;)
    {
        // 暂时什么都不做，等待中断
        asm volatile("wfi"); // Wait For Interrupt
    8000031c:	10500073          	wfi
    for (;;)
    80000320:	bff5                	j	8000031c <main+0x22c>

0000000080000322 <uartinit>:
#define WriteReg(reg, v) (*(Reg(reg)) = (v))
#define ReadReg(reg) (*(Reg(reg)))

// 初始化UART
void uartinit(void) 
{
    80000322:	1141                	addi	sp,sp,-16
    80000324:	e422                	sd	s0,8(sp)
    80000326:	0800                	addi	s0,sp,16
    // 1. 禁用中断（第一阶段不使用中断）
    WriteReg(IER, 0x00);
    80000328:	10000737          	lui	a4,0x10000
    8000032c:	000700a3          	sb	zero,1(a4) # 10000001 <_entry-0x6fffffff>

    // 2. 设置波特率 38400
    WriteReg(LCR, LCR_BAUD_LATCH);  // 启用波特率设置
    80000330:	100007b7          	lui	a5,0x10000
    80000334:	f8000693          	li	a3,-128
    80000338:	00d781a3          	sb	a3,3(a5) # 10000003 <_entry-0x6ffffffd>
    WriteReg(0, 0x03);              // 波特率除数低字节
    8000033c:	468d                	li	a3,3
    8000033e:	10000637          	lui	a2,0x10000
    80000342:	00d60023          	sb	a3,0(a2) # 10000000 <_entry-0x70000000>
    WriteReg(1, 0x00);              // 波特率除数高字节
    80000346:	000700a3          	sb	zero,1(a4)

    // 3. 设置8位数据，无奇偶校验，1停止位
    WriteReg(LCR, LCR_EIGHT_BITS);
    8000034a:	00d781a3          	sb	a3,3(a5)

    // 4. 启用并清空FIFO
    WriteReg(FCR, FCR_FIFO_ENABLE | FCR_FIFO_CLEAR);
    8000034e:	100007b7          	lui	a5,0x10000
    80000352:	471d                	li	a4,7
    80000354:	00e78123          	sb	a4,2(a5) # 10000002 <_entry-0x6ffffffe>
}
    80000358:	6422                	ld	s0,8(sp)
    8000035a:	0141                	addi	sp,sp,16
    8000035c:	8082                	ret

000000008000035e <uartputc>:

// 发送一个字符（同步方式）
void uartputc(int c) 
{
    8000035e:	1141                	addi	sp,sp,-16
    80000360:	e422                	sd	s0,8(sp)
    80000362:	0800                	addi	s0,sp,16
    // 等待发送寄存器空闲
    while((ReadReg(LSR) & LSR_TX_IDLE) == 0)
    80000364:	10000737          	lui	a4,0x10000
    80000368:	0715                	addi	a4,a4,5 # 10000005 <_entry-0x6ffffffb>
    8000036a:	00074783          	lbu	a5,0(a4)
    8000036e:	0207f793          	andi	a5,a5,32
    80000372:	dfe5                	beqz	a5,8000036a <uartputc+0xc>
        ;
    
    WriteReg(THR, c);
    80000374:	0ff57513          	zext.b	a0,a0
    80000378:	100007b7          	lui	a5,0x10000
    8000037c:	00a78023          	sb	a0,0(a5) # 10000000 <_entry-0x70000000>
}
    80000380:	6422                	ld	s0,8(sp)
    80000382:	0141                	addi	sp,sp,16
    80000384:	8082                	ret

0000000080000386 <uartputs>:

// 发送字符串
void uartputs(char *s) 
{
    while(*s) {
    80000386:	00054783          	lbu	a5,0(a0)
    8000038a:	c3b1                	beqz	a5,800003ce <uartputs+0x48>
{
    8000038c:	1101                	addi	sp,sp,-32
    8000038e:	ec06                	sd	ra,24(sp)
    80000390:	e822                	sd	s0,16(sp)
    80000392:	e426                	sd	s1,8(sp)
    80000394:	e04a                	sd	s2,0(sp)
    80000396:	1000                	addi	s0,sp,32
    80000398:	84aa                	mv	s1,a0
        if(*s == '\n')
    8000039a:	4929                	li	s2,10
    8000039c:	a819                	j	800003b2 <uartputs+0x2c>
            uartputc('\r');  // 换行前先发送回车符
        uartputc(*s);
    8000039e:	0004c503          	lbu	a0,0(s1)
    800003a2:	00000097          	auipc	ra,0x0
    800003a6:	fbc080e7          	jalr	-68(ra) # 8000035e <uartputc>
        s++;
    800003aa:	0485                	addi	s1,s1,1
    while(*s) {
    800003ac:	0004c783          	lbu	a5,0(s1)
    800003b0:	cb89                	beqz	a5,800003c2 <uartputs+0x3c>
        if(*s == '\n')
    800003b2:	ff2796e3          	bne	a5,s2,8000039e <uartputs+0x18>
            uartputc('\r');  // 换行前先发送回车符
    800003b6:	4535                	li	a0,13
    800003b8:	00000097          	auipc	ra,0x0
    800003bc:	fa6080e7          	jalr	-90(ra) # 8000035e <uartputc>
    800003c0:	bff9                	j	8000039e <uartputs+0x18>
    }
}
    800003c2:	60e2                	ld	ra,24(sp)
    800003c4:	6442                	ld	s0,16(sp)
    800003c6:	64a2                	ld	s1,8(sp)
    800003c8:	6902                	ld	s2,0(sp)
    800003ca:	6105                	addi	sp,sp,32
    800003cc:	8082                	ret
    800003ce:	8082                	ret

00000000800003d0 <printint>:
} */
static char digits[] = "0123456789abcdef";

// 打印十进制整数 xx : 要打印的数字 base : 进制 sign : 是否有符号
static void printint(long long xx, int base, int sign)
{
    800003d0:	711d                	addi	sp,sp,-96
    800003d2:	ec86                	sd	ra,88(sp)
    800003d4:	e8a2                	sd	s0,80(sp)
    800003d6:	e0ca                	sd	s2,64(sp)
    800003d8:	1080                	addi	s0,sp,96
    int i;
    unsigned long long x;

    // 正数时 sign = 0，xx < 0 为0 走 else
    // 负数时 sign = 1，xx < 0 为1 走 if
    if (sign && (sign = (xx < 0))) // if 判断用来取绝对值
    800003da:	c219                	beqz	a2,800003e0 <printint+0x10>
    800003dc:	08054063          	bltz	a0,8000045c <printint+0x8c>
    {
        x = -xx;
    }
    else
    {
        x = xx;
    800003e0:	4881                	li	a7,0
    }

    i = 0;
    800003e2:	fa040913          	addi	s2,s0,-96
        x = xx;
    800003e6:	86ca                	mv	a3,s2
    i = 0;
    800003e8:	4781                	li	a5,0
    do
    {
        buf[i++] = digits[x % base];
    800003ea:	00002617          	auipc	a2,0x2
    800003ee:	10e60613          	addi	a2,a2,270 # 800024f8 <digits>
    800003f2:	883e                	mv	a6,a5
    800003f4:	2785                	addiw	a5,a5,1
    800003f6:	02b57733          	remu	a4,a0,a1
    800003fa:	9732                	add	a4,a4,a2
    800003fc:	00074703          	lbu	a4,0(a4)
    80000400:	00e68023          	sb	a4,0(a3)
    } while ((x /= base) != 0);
    80000404:	872a                	mv	a4,a0
    80000406:	02b55533          	divu	a0,a0,a1
    8000040a:	0685                	addi	a3,a3,1
    8000040c:	feb773e3          	bgeu	a4,a1,800003f2 <printint+0x22>
    // 取余数得到最低位，然后去掉最低位

    if (sign)
    80000410:	00088a63          	beqz	a7,80000424 <printint+0x54>
        buf[i++] = '-';
    80000414:	1781                	addi	a5,a5,-32
    80000416:	97a2                	add	a5,a5,s0
    80000418:	02d00713          	li	a4,45
    8000041c:	fce78023          	sb	a4,-64(a5)
    80000420:	0028079b          	addiw	a5,a6,2

    while (--i >= 0) // 输出缓冲区中的字符
    80000424:	02f05763          	blez	a5,80000452 <printint+0x82>
    80000428:	e4a6                	sd	s1,72(sp)
    8000042a:	fa040493          	addi	s1,s0,-96
    8000042e:	94be                	add	s1,s1,a5
    80000430:	197d                	addi	s2,s2,-1
    80000432:	993e                	add	s2,s2,a5
    80000434:	37fd                	addiw	a5,a5,-1
    80000436:	1782                	slli	a5,a5,0x20
    80000438:	9381                	srli	a5,a5,0x20
    8000043a:	40f90933          	sub	s2,s2,a5
        consoleputc(buf[i]);
    8000043e:	fff4c503          	lbu	a0,-1(s1)
    80000442:	00000097          	auipc	ra,0x0
    80000446:	58a080e7          	jalr	1418(ra) # 800009cc <consoleputc>
    while (--i >= 0) // 输出缓冲区中的字符
    8000044a:	14fd                	addi	s1,s1,-1
    8000044c:	ff2499e3          	bne	s1,s2,8000043e <printint+0x6e>
    80000450:	64a6                	ld	s1,72(sp)
}
    80000452:	60e6                	ld	ra,88(sp)
    80000454:	6446                	ld	s0,80(sp)
    80000456:	6906                	ld	s2,64(sp)
    80000458:	6125                	addi	sp,sp,96
    8000045a:	8082                	ret
        x = -xx;
    8000045c:	40a00533          	neg	a0,a0
    if (sign && (sign = (xx < 0))) // if 判断用来取绝对值
    80000460:	4885                	li	a7,1
        x = -xx;
    80000462:	b741                	j	800003e2 <printint+0x12>

0000000080000464 <strlen>:
{
    80000464:	1141                	addi	sp,sp,-16
    80000466:	e422                	sd	s0,8(sp)
    80000468:	0800                	addi	s0,sp,16
    while (*s++)
    8000046a:	00054783          	lbu	a5,0(a0)
    8000046e:	cf91                	beqz	a5,8000048a <strlen+0x26>
    80000470:	00150693          	addi	a3,a0,1
    80000474:	87b6                	mv	a5,a3
    80000476:	853e                	mv	a0,a5
    80000478:	0785                	addi	a5,a5,1
    8000047a:	fff7c703          	lbu	a4,-1(a5)
    8000047e:	ff65                	bnez	a4,80000476 <strlen+0x12>
        n++;
    80000480:	9d15                	subw	a0,a0,a3
    80000482:	2505                	addiw	a0,a0,1
}
    80000484:	6422                	ld	s0,8(sp)
    80000486:	0141                	addi	sp,sp,16
    80000488:	8082                	ret
    int n = 0;
    8000048a:	4501                	li	a0,0
    8000048c:	bfe5                	j	80000484 <strlen+0x20>

000000008000048e <panic>:
    va_end(ap);
}

// panic 函数 - 系统致命错误
void panic(char *s)
{
    8000048e:	1101                	addi	sp,sp,-32
    80000490:	ec06                	sd	ra,24(sp)
    80000492:	e822                	sd	s0,16(sp)
    80000494:	e426                	sd	s1,8(sp)
    80000496:	1000                	addi	s0,sp,32
    80000498:	84aa                	mv	s1,a0
    // 1. 禁用中断，防止进一步的中断处理
    // intr_off();  // 后续实现中断管理时添加

    // 2. 显示错误信息
    printf("\n");
    8000049a:	00002517          	auipc	a0,0x2
    8000049e:	e0650513          	addi	a0,a0,-506 # 800022a0 <_trampoline+0x2a0>
    800004a2:	00000097          	auipc	ra,0x0
    800004a6:	22e080e7          	jalr	558(ra) # 800006d0 <printf>
    printf("================================\n");
    800004aa:	00002517          	auipc	a0,0x2
    800004ae:	dfe50513          	addi	a0,a0,-514 # 800022a8 <_trampoline+0x2a8>
    800004b2:	00000097          	auipc	ra,0x0
    800004b6:	21e080e7          	jalr	542(ra) # 800006d0 <printf>
    printf("KERNEL PANIC: %s\n", s);
    800004ba:	85a6                	mv	a1,s1
    800004bc:	00002517          	auipc	a0,0x2
    800004c0:	e1450513          	addi	a0,a0,-492 # 800022d0 <_trampoline+0x2d0>
    800004c4:	00000097          	auipc	ra,0x0
    800004c8:	20c080e7          	jalr	524(ra) # 800006d0 <printf>
    printf("================================\n");
    800004cc:	00002517          	auipc	a0,0x2
    800004d0:	ddc50513          	addi	a0,a0,-548 # 800022a8 <_trampoline+0x2a8>
    800004d4:	00000097          	auipc	ra,0x0
    800004d8:	1fc080e7          	jalr	508(ra) # 800006d0 <printf>
    800004dc:	f14025f3          	csrr	a1,mhartid

    // 3. 显示当前状态信息（调试用）
    printf("Hart ID: %d\n", (int)r_mhartid());
    800004e0:	2581                	sext.w	a1,a1
    800004e2:	00002517          	auipc	a0,0x2
    800004e6:	bd650513          	addi	a0,a0,-1066 # 800020b8 <_trampoline+0xb8>
    800004ea:	00000097          	auipc	ra,0x0
    800004ee:	1e6080e7          	jalr	486(ra) # 800006d0 <printf>

    // 4. 显示调用栈（高级功能，后续可添加）
    // print_backtrace();

    // 5. 系统完全停止
    printf("System halted. Please reboot.\n");
    800004f2:	00002517          	auipc	a0,0x2
    800004f6:	df650513          	addi	a0,a0,-522 # 800022e8 <_trampoline+0x2e8>
    800004fa:	00000097          	auipc	ra,0x0
    800004fe:	1d6080e7          	jalr	470(ra) # 800006d0 <printf>

    // 死循环，等待硬件重启或调试器介入
    for (;;)
    {
        asm volatile("wfi"); // Wait For Interrupt (省电)
    80000502:	10500073          	wfi
    for (;;)
    80000506:	bff5                	j	80000502 <panic+0x74>

0000000080000508 <vprintf>:
{
    80000508:	711d                	addi	sp,sp,-96
    8000050a:	ec86                	sd	ra,88(sp)
    8000050c:	e8a2                	sd	s0,80(sp)
    8000050e:	1080                	addi	s0,sp,96
    if (fmt == 0)
    80000510:	cd1d                	beqz	a0,8000054e <vprintf+0x46>
    80000512:	e4a6                	sd	s1,72(sp)
    80000514:	e0ca                	sd	s2,64(sp)
    80000516:	f852                	sd	s4,48(sp)
    80000518:	892a                	mv	s2,a0
    8000051a:	8a2e                	mv	s4,a1
    for (i = 0; (c = fmt[i] & 0xff) != 0; i++)
    8000051c:	00054503          	lbu	a0,0(a0)
    80000520:	4481                	li	s1,0
    80000522:	18050863          	beqz	a0,800006b2 <vprintf+0x1aa>
    80000526:	fc4e                	sd	s3,56(sp)
    80000528:	f456                	sd	s5,40(sp)
    8000052a:	f05a                	sd	s6,32(sp)
    8000052c:	ec5e                	sd	s7,24(sp)
    8000052e:	e862                	sd	s8,16(sp)
    80000530:	e466                	sd	s9,8(sp)
    80000532:	e06a                	sd	s10,0(sp)
        if (c != '%') // 非占位符，说明为普通字符串，直接打印
    80000534:	02500993          	li	s3,37
        switch (c)
    80000538:	4b55                	li	s6,21
    8000053a:	00002c17          	auipc	s8,0x2
    8000053e:	f66c0c13          	addi	s8,s8,-154 # 800024a0 <_trampoline+0x4a0>
    consoleputc('x');
    80000542:	4cc1                	li	s9,16
        consoleputc(digits[x >> (sizeof(uint64) * 8 - 4)]);
    80000544:	00002a97          	auipc	s5,0x2
    80000548:	fb4a8a93          	addi	s5,s5,-76 # 800024f8 <digits>
    8000054c:	a835                	j	80000588 <vprintf+0x80>
    8000054e:	e4a6                	sd	s1,72(sp)
    80000550:	e0ca                	sd	s2,64(sp)
    80000552:	fc4e                	sd	s3,56(sp)
    80000554:	f852                	sd	s4,48(sp)
    80000556:	f456                	sd	s5,40(sp)
    80000558:	f05a                	sd	s6,32(sp)
    8000055a:	ec5e                	sd	s7,24(sp)
    8000055c:	e862                	sd	s8,16(sp)
    8000055e:	e466                	sd	s9,8(sp)
    80000560:	e06a                	sd	s10,0(sp)
        panic("null fmt");
    80000562:	00002517          	auipc	a0,0x2
    80000566:	dae50513          	addi	a0,a0,-594 # 80002310 <_trampoline+0x310>
    8000056a:	00000097          	auipc	ra,0x0
    8000056e:	f24080e7          	jalr	-220(ra) # 8000048e <panic>
            consoleputc(c);
    80000572:	00000097          	auipc	ra,0x0
    80000576:	45a080e7          	jalr	1114(ra) # 800009cc <consoleputc>
    for (i = 0; (c = fmt[i] & 0xff) != 0; i++)
    8000057a:	2485                	addiw	s1,s1,1
    8000057c:	009907b3          	add	a5,s2,s1
    80000580:	0007c503          	lbu	a0,0(a5)
    80000584:	12050063          	beqz	a0,800006a4 <vprintf+0x19c>
        if (c != '%') // 非占位符，说明为普通字符串，直接打印
    80000588:	ff3515e3          	bne	a0,s3,80000572 <vprintf+0x6a>
        c = fmt[++i] & 0xff; // 读取到 % 符号时需要向下读取一个符号来判断占位符的类型
    8000058c:	2485                	addiw	s1,s1,1
    8000058e:	009907b3          	add	a5,s2,s1
    80000592:	0007c783          	lbu	a5,0(a5)
    80000596:	00078b9b          	sext.w	s7,a5
        if (c == 0)
    8000059a:	12078363          	beqz	a5,800006c0 <vprintf+0x1b8>
        switch (c)
    8000059e:	0f378063          	beq	a5,s3,8000067e <vprintf+0x176>
    800005a2:	f9d7871b          	addiw	a4,a5,-99
    800005a6:	0ff77713          	zext.b	a4,a4
    800005aa:	0eeb6063          	bltu	s6,a4,8000068a <vprintf+0x182>
    800005ae:	f9d7879b          	addiw	a5,a5,-99
    800005b2:	0ff7f713          	zext.b	a4,a5
    800005b6:	0ceb6a63          	bltu	s6,a4,8000068a <vprintf+0x182>
    800005ba:	00271793          	slli	a5,a4,0x2
    800005be:	97e2                	add	a5,a5,s8
    800005c0:	439c                	lw	a5,0(a5)
    800005c2:	97e2                	add	a5,a5,s8
    800005c4:	8782                	jr	a5
            printint(va_arg(ap, int), 10, 1); // va_arg 获取下一个参数
    800005c6:	008a0b93          	addi	s7,s4,8
    800005ca:	4605                	li	a2,1
    800005cc:	45a9                	li	a1,10
    800005ce:	000a2503          	lw	a0,0(s4)
    800005d2:	00000097          	auipc	ra,0x0
    800005d6:	dfe080e7          	jalr	-514(ra) # 800003d0 <printint>
    800005da:	8a5e                	mv	s4,s7
            break;
    800005dc:	bf79                	j	8000057a <vprintf+0x72>
            printint(va_arg(ap, int), 16, 1);
    800005de:	008a0b93          	addi	s7,s4,8
    800005e2:	4605                	li	a2,1
    800005e4:	85e6                	mv	a1,s9
    800005e6:	000a2503          	lw	a0,0(s4)
    800005ea:	00000097          	auipc	ra,0x0
    800005ee:	de6080e7          	jalr	-538(ra) # 800003d0 <printint>
    800005f2:	8a5e                	mv	s4,s7
            break;
    800005f4:	b759                	j	8000057a <vprintf+0x72>
            printptr(va_arg(ap, uint64));
    800005f6:	008a0b93          	addi	s7,s4,8
    800005fa:	000a3d03          	ld	s10,0(s4)
    consoleputc('0');
    800005fe:	03000513          	li	a0,48
    80000602:	00000097          	auipc	ra,0x0
    80000606:	3ca080e7          	jalr	970(ra) # 800009cc <consoleputc>
    consoleputc('x');
    8000060a:	07800513          	li	a0,120
    8000060e:	00000097          	auipc	ra,0x0
    80000612:	3be080e7          	jalr	958(ra) # 800009cc <consoleputc>
    80000616:	8a66                	mv	s4,s9
        consoleputc(digits[x >> (sizeof(uint64) * 8 - 4)]);
    80000618:	03cd5793          	srli	a5,s10,0x3c
    8000061c:	97d6                	add	a5,a5,s5
    8000061e:	0007c503          	lbu	a0,0(a5)
    80000622:	00000097          	auipc	ra,0x0
    80000626:	3aa080e7          	jalr	938(ra) # 800009cc <consoleputc>
    for (i = 0; i < (sizeof(uint64) * 2); i++, x <<= 4)
    8000062a:	0d12                	slli	s10,s10,0x4
    8000062c:	3a7d                	addiw	s4,s4,-1
    8000062e:	fe0a15e3          	bnez	s4,80000618 <vprintf+0x110>
            printptr(va_arg(ap, uint64));
    80000632:	8a5e                	mv	s4,s7
    80000634:	b799                	j	8000057a <vprintf+0x72>
            if ((s = va_arg(ap, char *)) == 0)
    80000636:	008a0b93          	addi	s7,s4,8
    8000063a:	000a3a03          	ld	s4,0(s4)
    8000063e:	000a0f63          	beqz	s4,8000065c <vprintf+0x154>
            for (; *s; s++)
    80000642:	000a4503          	lbu	a0,0(s4)
    80000646:	cd29                	beqz	a0,800006a0 <vprintf+0x198>
                consoleputc(*s);
    80000648:	00000097          	auipc	ra,0x0
    8000064c:	384080e7          	jalr	900(ra) # 800009cc <consoleputc>
            for (; *s; s++)
    80000650:	0a05                	addi	s4,s4,1
    80000652:	000a4503          	lbu	a0,0(s4)
    80000656:	f96d                	bnez	a0,80000648 <vprintf+0x140>
            if ((s = va_arg(ap, char *)) == 0)
    80000658:	8a5e                	mv	s4,s7
    8000065a:	b705                	j	8000057a <vprintf+0x72>
                s = "(null)";
    8000065c:	00002a17          	auipc	s4,0x2
    80000660:	caca0a13          	addi	s4,s4,-852 # 80002308 <_trampoline+0x308>
            for (; *s; s++)
    80000664:	02800513          	li	a0,40
    80000668:	b7c5                	j	80000648 <vprintf+0x140>
            consoleputc(va_arg(ap, uint));
    8000066a:	008a0b93          	addi	s7,s4,8
    8000066e:	000a2503          	lw	a0,0(s4)
    80000672:	00000097          	auipc	ra,0x0
    80000676:	35a080e7          	jalr	858(ra) # 800009cc <consoleputc>
    8000067a:	8a5e                	mv	s4,s7
            break;
    8000067c:	bdfd                	j	8000057a <vprintf+0x72>
            consoleputc('%');
    8000067e:	854e                	mv	a0,s3
    80000680:	00000097          	auipc	ra,0x0
    80000684:	34c080e7          	jalr	844(ra) # 800009cc <consoleputc>
            break;
    80000688:	bdcd                	j	8000057a <vprintf+0x72>
            consoleputc('%');
    8000068a:	854e                	mv	a0,s3
    8000068c:	00000097          	auipc	ra,0x0
    80000690:	340080e7          	jalr	832(ra) # 800009cc <consoleputc>
            consoleputc(c);
    80000694:	855e                	mv	a0,s7
    80000696:	00000097          	auipc	ra,0x0
    8000069a:	336080e7          	jalr	822(ra) # 800009cc <consoleputc>
            break;
    8000069e:	bdf1                	j	8000057a <vprintf+0x72>
            if ((s = va_arg(ap, char *)) == 0)
    800006a0:	8a5e                	mv	s4,s7
    800006a2:	bde1                	j	8000057a <vprintf+0x72>
    800006a4:	79e2                	ld	s3,56(sp)
    800006a6:	7aa2                	ld	s5,40(sp)
    800006a8:	7b02                	ld	s6,32(sp)
    800006aa:	6be2                	ld	s7,24(sp)
    800006ac:	6c42                	ld	s8,16(sp)
    800006ae:	6ca2                	ld	s9,8(sp)
    800006b0:	6d02                	ld	s10,0(sp)
    800006b2:	64a6                	ld	s1,72(sp)
    800006b4:	6906                	ld	s2,64(sp)
    800006b6:	7a42                	ld	s4,48(sp)
}
    800006b8:	60e6                	ld	ra,88(sp)
    800006ba:	6446                	ld	s0,80(sp)
    800006bc:	6125                	addi	sp,sp,96
    800006be:	8082                	ret
    800006c0:	79e2                	ld	s3,56(sp)
    800006c2:	7aa2                	ld	s5,40(sp)
    800006c4:	7b02                	ld	s6,32(sp)
    800006c6:	6be2                	ld	s7,24(sp)
    800006c8:	6c42                	ld	s8,16(sp)
    800006ca:	6ca2                	ld	s9,8(sp)
    800006cc:	6d02                	ld	s10,0(sp)
    800006ce:	b7d5                	j	800006b2 <vprintf+0x1aa>

00000000800006d0 <printf>:
{
    800006d0:	711d                	addi	sp,sp,-96
    800006d2:	ec06                	sd	ra,24(sp)
    800006d4:	e822                	sd	s0,16(sp)
    800006d6:	1000                	addi	s0,sp,32
    800006d8:	e40c                	sd	a1,8(s0)
    800006da:	e810                	sd	a2,16(s0)
    800006dc:	ec14                	sd	a3,24(s0)
    800006de:	f018                	sd	a4,32(s0)
    800006e0:	f41c                	sd	a5,40(s0)
    800006e2:	03043823          	sd	a6,48(s0)
    800006e6:	03143c23          	sd	a7,56(s0)
    va_start(ap, fmt); // 表示从 fmt 参数之后开始读取参数
    800006ea:	00840593          	addi	a1,s0,8
    800006ee:	feb43423          	sd	a1,-24(s0)
    vprintf(fmt, ap);
    800006f2:	00000097          	auipc	ra,0x0
    800006f6:	e16080e7          	jalr	-490(ra) # 80000508 <vprintf>
    sync_flush(); // 刷新输出缓冲区
    800006fa:	00000097          	auipc	ra,0x0
    800006fe:	2ba080e7          	jalr	698(ra) # 800009b4 <sync_flush>
}
    80000702:	60e2                	ld	ra,24(sp)
    80000704:	6442                	ld	s0,16(sp)
    80000706:	6125                	addi	sp,sp,96
    80000708:	8082                	ret

000000008000070a <printbin>:

// 添加更多 printf 功能

// 打印二进制数
void printbin(uint64 x)
{
    8000070a:	1101                	addi	sp,sp,-32
    8000070c:	ec06                	sd	ra,24(sp)
    8000070e:	e822                	sd	s0,16(sp)
    80000710:	e426                	sd	s1,8(sp)
    80000712:	e04a                	sd	s2,0(sp)
    80000714:	1000                	addi	s0,sp,32
    80000716:	892a                	mv	s2,a0
    consoleputc('0');
    80000718:	03000513          	li	a0,48
    8000071c:	00000097          	auipc	ra,0x0
    80000720:	2b0080e7          	jalr	688(ra) # 800009cc <consoleputc>
    consoleputc('b');
    80000724:	06200513          	li	a0,98
    80000728:	00000097          	auipc	ra,0x0
    8000072c:	2a4080e7          	jalr	676(ra) # 800009cc <consoleputc>
    for (int i = 63; i >= 0; i--)
    80000730:	03f00493          	li	s1,63
    80000734:	a801                	j	80000744 <printbin+0x3a>
    {
        consoleputc((x & (1UL << i)) ? '1' : '0'); // x & (1UL << i) 检查第 i 位是否为1
        if (i % 4 == 0 && i != 0)
            consoleputc('_'); // 分隔符
    80000736:	05f00513          	li	a0,95
    8000073a:	00000097          	auipc	ra,0x0
    8000073e:	292080e7          	jalr	658(ra) # 800009cc <consoleputc>
    for (int i = 63; i >= 0; i--)
    80000742:	34fd                	addiw	s1,s1,-1
        consoleputc((x & (1UL << i)) ? '1' : '0'); // x & (1UL << i) 检查第 i 位是否为1
    80000744:	00995533          	srl	a0,s2,s1
    80000748:	8905                	andi	a0,a0,1
    8000074a:	03050513          	addi	a0,a0,48
    8000074e:	00000097          	auipc	ra,0x0
    80000752:	27e080e7          	jalr	638(ra) # 800009cc <consoleputc>
        if (i % 4 == 0 && i != 0)
    80000756:	0034f793          	andi	a5,s1,3
    8000075a:	f7e5                	bnez	a5,80000742 <printbin+0x38>
    8000075c:	fce9                	bnez	s1,80000736 <printbin+0x2c>
    }
}
    8000075e:	60e2                	ld	ra,24(sp)
    80000760:	6442                	ld	s0,16(sp)
    80000762:	64a2                	ld	s1,8(sp)
    80000764:	6902                	ld	s2,0(sp)
    80000766:	6105                	addi	sp,sp,32
    80000768:	8082                	ret

000000008000076a <hexdump>:

// 格式化输出内存内容（十六进制dump）
void hexdump(void *addr, int len)
{
    8000076a:	7119                	addi	sp,sp,-128
    8000076c:	fc86                	sd	ra,120(sp)
    8000076e:	f8a2                	sd	s0,112(sp)
    80000770:	f4a6                	sd	s1,104(sp)
    80000772:	f0ca                	sd	s2,96(sp)
    80000774:	0100                	addi	s0,sp,128
    80000776:	892a                	mv	s2,a0
    80000778:	84ae                	mv	s1,a1
    8000077a:	f8b43423          	sd	a1,-120(s0)
    printf("About to call hexdump...\n");
    8000077e:	00002517          	auipc	a0,0x2
    80000782:	ba250513          	addi	a0,a0,-1118 # 80002320 <_trampoline+0x320>
    80000786:	00000097          	auipc	ra,0x0
    8000078a:	f4a080e7          	jalr	-182(ra) # 800006d0 <printf>
    unsigned char *p = (unsigned char *)addr;

    printf("hexdump函数转换后的无符号地址为 : %p\n", p);
    8000078e:	85ca                	mv	a1,s2
    80000790:	00002517          	auipc	a0,0x2
    80000794:	bb050513          	addi	a0,a0,-1104 # 80002340 <_trampoline+0x340>
    80000798:	00000097          	auipc	ra,0x0
    8000079c:	f38080e7          	jalr	-200(ra) # 800006d0 <printf>

    printf("Memory dump at %p:\n", addr);
    800007a0:	85ca                	mv	a1,s2
    800007a2:	00002517          	auipc	a0,0x2
    800007a6:	bd650513          	addi	a0,a0,-1066 # 80002378 <_trampoline+0x378>
    800007aa:	00000097          	auipc	ra,0x0
    800007ae:	f26080e7          	jalr	-218(ra) # 800006d0 <printf>
    for (int i = 0; i < len; i += 16)
    800007b2:	08905463          	blez	s1,8000083a <hexdump+0xd0>
    800007b6:	ecce                	sd	s3,88(sp)
    800007b8:	e8d2                	sd	s4,80(sp)
    800007ba:	e4d6                	sd	s5,72(sp)
    800007bc:	e0da                	sd	s6,64(sp)
    800007be:	fc5e                	sd	s7,56(sp)
    800007c0:	f862                	sd	s8,48(sp)
    800007c2:	f466                	sd	s9,40(sp)
    800007c4:	f06a                	sd	s10,32(sp)
    800007c6:	ec6e                	sd	s11,24(sp)
    800007c8:	8c4a                	mv	s8,s2
    800007ca:	00048d1b          	sext.w	s10,s1
    800007ce:	093d                	addi	s2,s2,15
    800007d0:	fff4879b          	addiw	a5,s1,-1
    800007d4:	9bc1                	andi	a5,a5,-16
    800007d6:	27c1                	addiw	a5,a5,16
    800007d8:	f8f43023          	sd	a5,-128(s0)
    800007dc:	4c81                	li	s9,0
        // 打印ASCII字符
        printf(" |");
        for (int j = 0; j < 16 && i + j < len; j++)
        {
            char c = p[i + j];
            printf("%c", (c >= 32 && c <= 126) ? c : '.');
    800007de:	05e00b93          	li	s7,94
    800007e2:	00002b17          	auipc	s6,0x2
    800007e6:	bceb0b13          	addi	s6,s6,-1074 # 800023b0 <_trampoline+0x3b0>
            printf("   ");
    800007ea:	00002a17          	auipc	s4,0x2
    800007ee:	bb6a0a13          	addi	s4,s4,-1098 # 800023a0 <_trampoline+0x3a0>
        for (int j = len - i; j < 16; j++)
    800007f2:	49c1                	li	s3,16
            printf("%02x ", p[i + j]);
    800007f4:	00002a97          	auipc	s5,0x2
    800007f8:	ba4a8a93          	addi	s5,s5,-1116 # 80002398 <_trampoline+0x398>
    800007fc:	a051                	j	80000880 <hexdump+0x116>
            printf("%c", (c >= 32 && c <= 126) ? c : '.');
    800007fe:	855a                	mv	a0,s6
    80000800:	00000097          	auipc	ra,0x0
    80000804:	ed0080e7          	jalr	-304(ra) # 800006d0 <printf>
        for (int j = 0; j < 16 && i + j < len; j++)
    80000808:	05248c63          	beq	s1,s2,80000860 <hexdump+0xf6>
    8000080c:	0485                	addi	s1,s1,1
    8000080e:	05b48963          	beq	s1,s11,80000860 <hexdump+0xf6>
            char c = p[i + j];
    80000812:	0004c583          	lbu	a1,0(s1)
            printf("%c", (c >= 32 && c <= 126) ? c : '.');
    80000816:	fe05879b          	addiw	a5,a1,-32
    8000081a:	0ff7f793          	zext.b	a5,a5
    8000081e:	fefbf0e3          	bgeu	s7,a5,800007fe <hexdump+0x94>
    80000822:	02e00593          	li	a1,46
    80000826:	bfe1                	j	800007fe <hexdump+0x94>
    80000828:	69e6                	ld	s3,88(sp)
    8000082a:	6a46                	ld	s4,80(sp)
    8000082c:	6aa6                	ld	s5,72(sp)
    8000082e:	6b06                	ld	s6,64(sp)
    80000830:	7be2                	ld	s7,56(sp)
    80000832:	7c42                	ld	s8,48(sp)
    80000834:	7ca2                	ld	s9,40(sp)
    80000836:	7d02                	ld	s10,32(sp)
    80000838:	6de2                	ld	s11,24(sp)
        }
        printf("|\n");
    }
    8000083a:	70e6                	ld	ra,120(sp)
    8000083c:	7446                	ld	s0,112(sp)
    8000083e:	74a6                	ld	s1,104(sp)
    80000840:	7906                	ld	s2,96(sp)
    80000842:	6109                	addi	sp,sp,128
    80000844:	8082                	ret
        for (int j = len - i; j < 16; j++)
    80000846:	000d049b          	sext.w	s1,s10
    8000084a:	47bd                	li	a5,15
    8000084c:	0697de63          	bge	a5,s1,800008c8 <hexdump+0x15e>
        printf(" |");
    80000850:	00002517          	auipc	a0,0x2
    80000854:	b5850513          	addi	a0,a0,-1192 # 800023a8 <_trampoline+0x3a8>
    80000858:	00000097          	auipc	ra,0x0
    8000085c:	e78080e7          	jalr	-392(ra) # 800006d0 <printf>
        printf("|\n");
    80000860:	00002517          	auipc	a0,0x2
    80000864:	b5850513          	addi	a0,a0,-1192 # 800023b8 <_trampoline+0x3b8>
    80000868:	00000097          	auipc	ra,0x0
    8000086c:	e68080e7          	jalr	-408(ra) # 800006d0 <printf>
    for (int i = 0; i < len; i += 16)
    80000870:	2cc1                	addiw	s9,s9,16
    80000872:	0c41                	addi	s8,s8,16
    80000874:	3d41                	addiw	s10,s10,-16
    80000876:	0941                	addi	s2,s2,16
    80000878:	f8043783          	ld	a5,-128(s0)
    8000087c:	fafc86e3          	beq	s9,a5,80000828 <hexdump+0xbe>
        printf("%p: ", (void *)(p + i));
    80000880:	85e2                	mv	a1,s8
    80000882:	00002517          	auipc	a0,0x2
    80000886:	b0e50513          	addi	a0,a0,-1266 # 80002390 <_trampoline+0x390>
    8000088a:	00000097          	auipc	ra,0x0
    8000088e:	e46080e7          	jalr	-442(ra) # 800006d0 <printf>
        for (int j = 0; j < 16 && i + j < len; j++)
    80000892:	f8843783          	ld	a5,-120(s0)
    80000896:	fafcd8e3          	bge	s9,a5,80000846 <hexdump+0xdc>
    8000089a:	020d1d93          	slli	s11,s10,0x20
    8000089e:	020ddd93          	srli	s11,s11,0x20
    800008a2:	9de2                	add	s11,s11,s8
    800008a4:	84e2                	mv	s1,s8
            printf("%02x ", p[i + j]);
    800008a6:	0004c583          	lbu	a1,0(s1)
    800008aa:	8556                	mv	a0,s5
    800008ac:	00000097          	auipc	ra,0x0
    800008b0:	e24080e7          	jalr	-476(ra) # 800006d0 <printf>
        for (int j = 0; j < 16 && i + j < len; j++)
    800008b4:	01248563          	beq	s1,s2,800008be <hexdump+0x154>
    800008b8:	0485                	addi	s1,s1,1
    800008ba:	ffb496e3          	bne	s1,s11,800008a6 <hexdump+0x13c>
        for (int j = len - i; j < 16; j++)
    800008be:	000d049b          	sext.w	s1,s10
    800008c2:	47bd                	li	a5,15
    800008c4:	0297cd63          	blt	a5,s1,800008fe <hexdump+0x194>
            printf("   ");
    800008c8:	8552                	mv	a0,s4
    800008ca:	00000097          	auipc	ra,0x0
    800008ce:	e06080e7          	jalr	-506(ra) # 800006d0 <printf>
        for (int j = len - i; j < 16; j++)
    800008d2:	2485                	addiw	s1,s1,1
    800008d4:	ff349ae3          	bne	s1,s3,800008c8 <hexdump+0x15e>
        printf(" |");
    800008d8:	00002517          	auipc	a0,0x2
    800008dc:	ad050513          	addi	a0,a0,-1328 # 800023a8 <_trampoline+0x3a8>
    800008e0:	00000097          	auipc	ra,0x0
    800008e4:	df0080e7          	jalr	-528(ra) # 800006d0 <printf>
        for (int j = 0; j < 16 && i + j < len; j++)
    800008e8:	f8843783          	ld	a5,-120(s0)
    800008ec:	f6fcdae3          	bge	s9,a5,80000860 <hexdump+0xf6>
    800008f0:	020d1d93          	slli	s11,s10,0x20
    800008f4:	020ddd93          	srli	s11,s11,0x20
    800008f8:	9de2                	add	s11,s11,s8
        for (int j = 0; j < 16 && i + j < len; j++)
    800008fa:	84e2                	mv	s1,s8
    800008fc:	bf19                	j	80000812 <hexdump+0xa8>
        printf(" |");
    800008fe:	00002517          	auipc	a0,0x2
    80000902:	aaa50513          	addi	a0,a0,-1366 # 800023a8 <_trampoline+0x3a8>
    80000906:	00000097          	auipc	ra,0x0
    8000090a:	dca080e7          	jalr	-566(ra) # 800006d0 <printf>
        for (int j = 0; j < 16 && i + j < len; j++)
    8000090e:	b7cd                	j	800008f0 <hexdump+0x186>

0000000080000910 <consoleinit>:

} console;

// 控制台初始化
void consoleinit(void)
{
    80000910:	1141                	addi	sp,sp,-16
    80000912:	e406                	sd	ra,8(sp)
    80000914:	e022                	sd	s0,0(sp)
    80000916:	0800                	addi	s0,sp,16
    // 初始化 UART
    extern void uartinit(void);
    uartinit();
    80000918:	00000097          	auipc	ra,0x0
    8000091c:	a0a080e7          	jalr	-1526(ra) # 80000322 <uartinit>

    // 清空控制台缓冲区
    console.r = console.w = console.e = 0;
    80000920:	0000a797          	auipc	a5,0xa
    80000924:	45078793          	addi	a5,a5,1104 # 8000ad70 <console>
    80000928:	1007a423          	sw	zero,264(a5)
    8000092c:	1007a223          	sw	zero,260(a5)
    80000930:	1007a023          	sw	zero,256(a5)
    console.output_pos = 0;
    80000934:	2007a623          	sw	zero,524(a5)
}
    80000938:	60a2                	ld	ra,8(sp)
    8000093a:	6402                	ld	s0,0(sp)
    8000093c:	0141                	addi	sp,sp,16
    8000093e:	8082                	ret

0000000080000940 <consputc>:

// 输出单个字符到控制台
void consputc(int c)
{
    80000940:	1141                	addi	sp,sp,-16
    80000942:	e406                	sd	ra,8(sp)
    80000944:	e022                	sd	s0,0(sp)
    80000946:	0800                	addi	s0,sp,16
    // 目前直接使用 UART
    extern void uartputc(int c);
    uartputc(c);
    80000948:	00000097          	auipc	ra,0x0
    8000094c:	a16080e7          	jalr	-1514(ra) # 8000035e <uartputc>
}
    80000950:	60a2                	ld	ra,8(sp)
    80000952:	6402                	ld	s0,0(sp)
    80000954:	0141                	addi	sp,sp,16
    80000956:	8082                	ret

0000000080000958 <console_flush>:
    console_flush(); // 刷新输出缓冲区
}

void console_flush(void)
{
    for (uint i = 0; i < console.output_pos; i++)
    80000958:	0000a797          	auipc	a5,0xa
    8000095c:	6247a783          	lw	a5,1572(a5) # 8000af7c <console+0x20c>
    80000960:	c7a9                	beqz	a5,800009aa <console_flush+0x52>
{
    80000962:	1101                	addi	sp,sp,-32
    80000964:	ec06                	sd	ra,24(sp)
    80000966:	e822                	sd	s0,16(sp)
    80000968:	e426                	sd	s1,8(sp)
    8000096a:	e04a                	sd	s2,0(sp)
    8000096c:	1000                	addi	s0,sp,32
    for (uint i = 0; i < console.output_pos; i++)
    8000096e:	4481                	li	s1,0
    {
        uartputc(console.output_buf[i]);
    80000970:	0000a917          	auipc	s2,0xa
    80000974:	40090913          	addi	s2,s2,1024 # 8000ad70 <console>
    80000978:	009907b3          	add	a5,s2,s1
    8000097c:	10c7c503          	lbu	a0,268(a5)
    80000980:	00000097          	auipc	ra,0x0
    80000984:	9de080e7          	jalr	-1570(ra) # 8000035e <uartputc>
    for (uint i = 0; i < console.output_pos; i++)
    80000988:	0485                	addi	s1,s1,1
    8000098a:	20c92703          	lw	a4,524(s2)
    8000098e:	0004879b          	sext.w	a5,s1
    80000992:	fee7e3e3          	bltu	a5,a4,80000978 <console_flush+0x20>
    }
    console.output_pos = 0; // 重置缓冲区位置
    80000996:	0000a797          	auipc	a5,0xa
    8000099a:	5e07a323          	sw	zero,1510(a5) # 8000af7c <console+0x20c>
}
    8000099e:	60e2                	ld	ra,24(sp)
    800009a0:	6442                	ld	s0,16(sp)
    800009a2:	64a2                	ld	s1,8(sp)
    800009a4:	6902                	ld	s2,0(sp)
    800009a6:	6105                	addi	sp,sp,32
    800009a8:	8082                	ret
    console.output_pos = 0; // 重置缓冲区位置
    800009aa:	0000a797          	auipc	a5,0xa
    800009ae:	5c07a923          	sw	zero,1490(a5) # 8000af7c <console+0x20c>
    800009b2:	8082                	ret

00000000800009b4 <sync_flush>:
{
    800009b4:	1141                	addi	sp,sp,-16
    800009b6:	e406                	sd	ra,8(sp)
    800009b8:	e022                	sd	s0,0(sp)
    800009ba:	0800                	addi	s0,sp,16
    console_flush(); // 刷新输出缓冲区
    800009bc:	00000097          	auipc	ra,0x0
    800009c0:	f9c080e7          	jalr	-100(ra) # 80000958 <console_flush>
}
    800009c4:	60a2                	ld	ra,8(sp)
    800009c6:	6402                	ld	s0,0(sp)
    800009c8:	0141                	addi	sp,sp,16
    800009ca:	8082                	ret

00000000800009cc <consoleputc>:

void consoleputc(int c)
{
    if (console.output_pos < CONSOLE_BUF_SIZE - 1)
    800009cc:	0000a797          	auipc	a5,0xa
    800009d0:	5b07a783          	lw	a5,1456(a5) # 8000af7c <console+0x20c>
    800009d4:	0fe00713          	li	a4,254
    800009d8:	02f76963          	bltu	a4,a5,80000a0a <consoleputc+0x3e>
    {
        console.output_buf[console.output_pos++] = c;
    800009dc:	0017869b          	addiw	a3,a5,1
    800009e0:	0006861b          	sext.w	a2,a3
    800009e4:	0000a717          	auipc	a4,0xa
    800009e8:	38c70713          	addi	a4,a4,908 # 8000ad70 <console>
    800009ec:	20d72623          	sw	a3,524(a4)
    800009f0:	1782                	slli	a5,a5,0x20
    800009f2:	9381                	srli	a5,a5,0x20
    800009f4:	973e                	add	a4,a4,a5
    800009f6:	10a70623          	sb	a0,268(a4)
    }

    // 换行或者缓冲区满或者遇到 '\0' 结尾时刷出缓冲区
    if (c == '\n' || console.output_pos >= CONSOLE_BUF_SIZE - 1 || c == '\0')
    800009fa:	47a9                	li	a5,10
    800009fc:	00f50763          	beq	a0,a5,80000a0a <consoleputc+0x3e>
    80000a00:	0fe00793          	li	a5,254
    80000a04:	00c7e363          	bltu	a5,a2,80000a0a <consoleputc+0x3e>
    80000a08:	ed09                	bnez	a0,80000a22 <consoleputc+0x56>
{
    80000a0a:	1141                	addi	sp,sp,-16
    80000a0c:	e406                	sd	ra,8(sp)
    80000a0e:	e022                	sd	s0,0(sp)
    80000a10:	0800                	addi	s0,sp,16
    {
        console_flush();
    80000a12:	00000097          	auipc	ra,0x0
    80000a16:	f46080e7          	jalr	-186(ra) # 80000958 <console_flush>
    }
}
    80000a1a:	60a2                	ld	ra,8(sp)
    80000a1c:	6402                	ld	s0,0(sp)
    80000a1e:	0141                	addi	sp,sp,16
    80000a20:	8082                	ret
    80000a22:	8082                	ret

0000000080000a24 <console_puts>:

void console_puts(const char *s)
{
    80000a24:	7179                	addi	sp,sp,-48
    80000a26:	f406                	sd	ra,40(sp)
    80000a28:	f022                	sd	s0,32(sp)
    80000a2a:	1800                	addi	s0,sp,48
    while (*s)
    80000a2c:	00054783          	lbu	a5,0(a0)
    80000a30:	cbb9                	beqz	a5,80000a86 <console_puts+0x62>
    80000a32:	ec26                	sd	s1,24(sp)
    80000a34:	e84a                	sd	s2,16(sp)
    80000a36:	e44e                	sd	s3,8(sp)
    80000a38:	84aa                	mv	s1,a0
    {
        // 直接写入缓冲区，然后一并刷出
        if (console.output_pos < CONSOLE_BUF_SIZE - 1)
    80000a3a:	0000a917          	auipc	s2,0xa
    80000a3e:	33690913          	addi	s2,s2,822 # 8000ad70 <console>
    80000a42:	0fe00993          	li	s3,254
    80000a46:	a025                	j	80000a6e <console_puts+0x4a>
        {
            console.output_buf[console.output_pos++] = *s;
    80000a48:	0017871b          	addiw	a4,a5,1
    80000a4c:	0007069b          	sext.w	a3,a4
    80000a50:	20e92623          	sw	a4,524(s2)
    80000a54:	0004c703          	lbu	a4,0(s1)
    80000a58:	1782                	slli	a5,a5,0x20
    80000a5a:	9381                	srli	a5,a5,0x20
    80000a5c:	97ca                	add	a5,a5,s2
    80000a5e:	10e78623          	sb	a4,268(a5)
        }

        // 缓冲区满先刷出
        if (console.output_pos >= CONSOLE_BUF_SIZE - 1)
    80000a62:	00d9ea63          	bltu	s3,a3,80000a76 <console_puts+0x52>
        {
            console_flush();
            // console.output_pos = 0;
        }
        s++;
    80000a66:	0485                	addi	s1,s1,1
    while (*s)
    80000a68:	0004c783          	lbu	a5,0(s1)
    80000a6c:	cb91                	beqz	a5,80000a80 <console_puts+0x5c>
        if (console.output_pos < CONSOLE_BUF_SIZE - 1)
    80000a6e:	20c92783          	lw	a5,524(s2)
    80000a72:	fcf9fbe3          	bgeu	s3,a5,80000a48 <console_puts+0x24>
            console_flush();
    80000a76:	00000097          	auipc	ra,0x0
    80000a7a:	ee2080e7          	jalr	-286(ra) # 80000958 <console_flush>
    80000a7e:	b7e5                	j	80000a66 <console_puts+0x42>
    80000a80:	64e2                	ld	s1,24(sp)
    80000a82:	6942                	ld	s2,16(sp)
    80000a84:	69a2                	ld	s3,8(sp)
    }
    console_flush();
    80000a86:	00000097          	auipc	ra,0x0
    80000a8a:	ed2080e7          	jalr	-302(ra) # 80000958 <console_flush>
}
    80000a8e:	70a2                	ld	ra,40(sp)
    80000a90:	7402                	ld	s0,32(sp)
    80000a92:	6145                	addi	sp,sp,48
    80000a94:	8082                	ret

0000000080000a96 <console_write_buf>:

void console_write_buf(const char *data, int len)
{
    80000a96:	7179                	addi	sp,sp,-48
    80000a98:	f406                	sd	ra,40(sp)
    80000a9a:	f022                	sd	s0,32(sp)
    80000a9c:	1800                	addi	s0,sp,48
    for (int i = 0; i < len; i++)
    80000a9e:	04b05f63          	blez	a1,80000afc <console_write_buf+0x66>
    80000aa2:	ec26                	sd	s1,24(sp)
    80000aa4:	e84a                	sd	s2,16(sp)
    80000aa6:	e44e                	sd	s3,8(sp)
    80000aa8:	e052                	sd	s4,0(sp)
    80000aaa:	84aa                	mv	s1,a0
    80000aac:	00b50a33          	add	s4,a0,a1
    {
        if (console.output_pos < CONSOLE_BUF_SIZE - 1)
    80000ab0:	0000a917          	auipc	s2,0xa
    80000ab4:	2c090913          	addi	s2,s2,704 # 8000ad70 <console>
    80000ab8:	0fe00993          	li	s3,254
    80000abc:	a01d                	j	80000ae2 <console_write_buf+0x4c>
        {
            console.output_buf[console.output_pos++] = data[i];
    80000abe:	0017871b          	addiw	a4,a5,1
    80000ac2:	0007069b          	sext.w	a3,a4
    80000ac6:	20e92623          	sw	a4,524(s2)
    80000aca:	0004c703          	lbu	a4,0(s1)
    80000ace:	1782                	slli	a5,a5,0x20
    80000ad0:	9381                	srli	a5,a5,0x20
    80000ad2:	97ca                	add	a5,a5,s2
    80000ad4:	10e78623          	sb	a4,268(a5)
        }

        // 缓冲区满先刷出
        if (console.output_pos >= CONSOLE_BUF_SIZE - 1)
    80000ad8:	00d9e963          	bltu	s3,a3,80000aea <console_write_buf+0x54>
    for (int i = 0; i < len; i++)
    80000adc:	0485                	addi	s1,s1,1
    80000ade:	01448b63          	beq	s1,s4,80000af4 <console_write_buf+0x5e>
        if (console.output_pos < CONSOLE_BUF_SIZE - 1)
    80000ae2:	20c92783          	lw	a5,524(s2)
    80000ae6:	fcf9fce3          	bgeu	s3,a5,80000abe <console_write_buf+0x28>
        {
            console_flush();
    80000aea:	00000097          	auipc	ra,0x0
    80000aee:	e6e080e7          	jalr	-402(ra) # 80000958 <console_flush>
    80000af2:	b7ed                	j	80000adc <console_write_buf+0x46>
    80000af4:	64e2                	ld	s1,24(sp)
    80000af6:	6942                	ld	s2,16(sp)
    80000af8:	69a2                	ld	s3,8(sp)
    80000afa:	6a02                	ld	s4,0(sp)
            // console.output_pos = 0;
        }
    }
    // 批量写入后再次刷新
    console_flush();
    80000afc:	00000097          	auipc	ra,0x0
    80000b00:	e5c080e7          	jalr	-420(ra) # 80000958 <console_flush>
}
    80000b04:	70a2                	ld	ra,40(sp)
    80000b06:	7402                	ld	s0,32(sp)
    80000b08:	6145                	addi	sp,sp,48
    80000b0a:	8082                	ret

0000000080000b0c <console_clear>:

// 清屏功能
void console_clear(void)
{
    80000b0c:	1141                	addi	sp,sp,-16
    80000b0e:	e406                	sd	ra,8(sp)
    80000b10:	e022                	sd	s0,0(sp)
    80000b12:	0800                	addi	s0,sp,16
    // 发送 ANSI 清屏序列
    console_puts("\033[2J\033[H"); // 清屏并将光标移动到左上角
    80000b14:	00002517          	auipc	a0,0x2
    80000b18:	8ac50513          	addi	a0,a0,-1876 # 800023c0 <_trampoline+0x3c0>
    80000b1c:	00000097          	auipc	ra,0x0
    80000b20:	f08080e7          	jalr	-248(ra) # 80000a24 <console_puts>
}
    80000b24:	60a2                	ld	ra,8(sp)
    80000b26:	6402                	ld	s0,0(sp)
    80000b28:	0141                	addi	sp,sp,16
    80000b2a:	8082                	ret

0000000080000b2c <console_set_cursor>:

// 设置光标位置
void console_set_cursor(int row, int col)
{
    80000b2c:	7179                	addi	sp,sp,-48
    80000b2e:	f406                	sd	ra,40(sp)
    80000b30:	f022                	sd	s0,32(sp)
    80000b32:	1800                	addi	s0,sp,48

    // 先格式化到临时缓冲区，然后批量输出
    char cursor_cmd[32];
    int len = 0;

    cursor_cmd[len++] = '\033';
    80000b34:	47ed                	li	a5,27
    80000b36:	fcf40823          	sb	a5,-48(s0)
    cursor_cmd[len++] = '[';
    80000b3a:	05b00793          	li	a5,91
    80000b3e:	fcf408a3          	sb	a5,-47(s0)

    // 简单的数字转字符串（只处理小数字）
    if (row >= 10)
    80000b42:	47a5                	li	a5,9
    cursor_cmd[len++] = '[';
    80000b44:	4709                	li	a4,2
    if (row >= 10)
    80000b46:	00a7da63          	bge	a5,a0,80000b5a <console_set_cursor+0x2e>
    {
        cursor_cmd[len++] = '0' + (row / 10);
    80000b4a:	47a9                	li	a5,10
    80000b4c:	02f547bb          	divw	a5,a0,a5
    80000b50:	0307879b          	addiw	a5,a5,48
    80000b54:	fcf40923          	sb	a5,-46(s0)
    80000b58:	470d                	li	a4,3
    }
    cursor_cmd[len++] = '0' + (row % 10);
    80000b5a:	47a9                	li	a5,10
    80000b5c:	02f5653b          	remw	a0,a0,a5
    80000b60:	0305051b          	addiw	a0,a0,48
    80000b64:	ff070793          	addi	a5,a4,-16
    80000b68:	97a2                	add	a5,a5,s0
    80000b6a:	fea78023          	sb	a0,-32(a5)
    cursor_cmd[len++] = ';';
    80000b6e:	00270793          	addi	a5,a4,2
    80000b72:	03b00613          	li	a2,59
    80000b76:	ff070693          	addi	a3,a4,-16
    80000b7a:	96a2                	add	a3,a3,s0
    80000b7c:	fec680a3          	sb	a2,-31(a3)

    if (col >= 10)
    80000b80:	46a5                	li	a3,9
    80000b82:	00b6dd63          	bge	a3,a1,80000b9c <console_set_cursor+0x70>
    {
        cursor_cmd[len++] = '0' + (col / 10);
    80000b86:	17c1                	addi	a5,a5,-16
    80000b88:	97a2                	add	a5,a5,s0
    80000b8a:	46a9                	li	a3,10
    80000b8c:	02d5c6bb          	divw	a3,a1,a3
    80000b90:	0306869b          	addiw	a3,a3,48
    80000b94:	fed78023          	sb	a3,-32(a5)
    80000b98:	00370793          	addi	a5,a4,3
    }
    cursor_cmd[len++] = '0' + (col % 10);
    80000b9c:	ff078713          	addi	a4,a5,-16
    80000ba0:	9722                	add	a4,a4,s0
    80000ba2:	46a9                	li	a3,10
    80000ba4:	02d5e5bb          	remw	a1,a1,a3
    80000ba8:	0305859b          	addiw	a1,a1,48
    80000bac:	feb70023          	sb	a1,-32(a4)
    cursor_cmd[len++] = 'H';
    80000bb0:	0027859b          	addiw	a1,a5,2
    80000bb4:	2785                	addiw	a5,a5,1
    80000bb6:	17c1                	addi	a5,a5,-16
    80000bb8:	97a2                	add	a5,a5,s0
    80000bba:	04800713          	li	a4,72
    80000bbe:	fee78023          	sb	a4,-32(a5)
    cursor_cmd[len] = '\0';
    80000bc2:	ff058793          	addi	a5,a1,-16
    80000bc6:	97a2                	add	a5,a5,s0
    80000bc8:	fe078023          	sb	zero,-32(a5)

    console_write_buf(cursor_cmd, len);
    80000bcc:	fd040513          	addi	a0,s0,-48
    80000bd0:	00000097          	auipc	ra,0x0
    80000bd4:	ec6080e7          	jalr	-314(ra) # 80000a96 <console_write_buf>
}
    80000bd8:	70a2                	ld	ra,40(sp)
    80000bda:	7402                	ld	s0,32(sp)
    80000bdc:	6145                	addi	sp,sp,48
    80000bde:	8082                	ret

0000000080000be0 <console_set_color>:

// 设置文本颜色（优化版）
void console_set_color(int fg_color, int bg_color)
{
    80000be0:	7179                	addi	sp,sp,-48
    80000be2:	f406                	sd	ra,40(sp)
    80000be4:	f022                	sd	s0,32(sp)
    80000be6:	1800                	addi	s0,sp,48
    char color_cmd[32];
    int len = 0;

    // 构建颜色 ANSI 序列
    color_cmd[len++] = '\033';
    80000be8:	47ed                	li	a5,27
    80000bea:	fcf40823          	sb	a5,-48(s0)
    color_cmd[len++] = '[';
    80000bee:	05b00793          	li	a5,91
    80000bf2:	fcf408a3          	sb	a5,-47(s0)
    color_cmd[len++] = '3';
    80000bf6:	03300793          	li	a5,51
    80000bfa:	fcf40923          	sb	a5,-46(s0)
    color_cmd[len++] = '0' + fg_color;
    80000bfe:	0305051b          	addiw	a0,a0,48
    80000c02:	fca409a3          	sb	a0,-45(s0)
    color_cmd[len++] = ';';
    80000c06:	03b00793          	li	a5,59
    80000c0a:	fcf40a23          	sb	a5,-44(s0)
    color_cmd[len++] = '4';
    80000c0e:	03400793          	li	a5,52
    80000c12:	fcf40aa3          	sb	a5,-43(s0)
    color_cmd[len++] = '0' + bg_color;
    80000c16:	0305859b          	addiw	a1,a1,48
    80000c1a:	fcb40b23          	sb	a1,-42(s0)
    color_cmd[len++] = 'm';
    80000c1e:	06d00793          	li	a5,109
    80000c22:	fcf40ba3          	sb	a5,-41(s0)
    color_cmd[len] = '\0';
    80000c26:	fc040c23          	sb	zero,-40(s0)

    console_write_buf(color_cmd, len);
    80000c2a:	45a1                	li	a1,8
    80000c2c:	fd040513          	addi	a0,s0,-48
    80000c30:	00000097          	auipc	ra,0x0
    80000c34:	e66080e7          	jalr	-410(ra) # 80000a96 <console_write_buf>
}
    80000c38:	70a2                	ld	ra,40(sp)
    80000c3a:	7402                	ld	s0,32(sp)
    80000c3c:	6145                	addi	sp,sp,48
    80000c3e:	8082                	ret

0000000080000c40 <console_reset_color>:

// 重置文本格式（优化版）
void console_reset_color(void)
{
    80000c40:	1141                	addi	sp,sp,-16
    80000c42:	e406                	sd	ra,8(sp)
    80000c44:	e022                	sd	s0,0(sp)
    80000c46:	0800                	addi	s0,sp,16
    console_puts("\033[0m");
    80000c48:	00001517          	auipc	a0,0x1
    80000c4c:	78050513          	addi	a0,a0,1920 # 800023c8 <_trampoline+0x3c8>
    80000c50:	00000097          	auipc	ra,0x0
    80000c54:	dd4080e7          	jalr	-556(ra) # 80000a24 <console_puts>
}
    80000c58:	60a2                	ld	ra,8(sp)
    80000c5a:	6402                	ld	s0,0(sp)
    80000c5c:	0141                	addi	sp,sp,16
    80000c5e:	8082                	ret

0000000080000c60 <consolewrite>:

// 控制台写入函数（优化版）
int consolewrite(int user_src, uint64 src, int n)
{
    80000c60:	7139                	addi	sp,sp,-64
    80000c62:	fc06                	sd	ra,56(sp)
    80000c64:	f822                	sd	s0,48(sp)
    80000c66:	f426                	sd	s1,40(sp)
    80000c68:	e456                	sd	s5,8(sp)
    80000c6a:	0080                	addi	s0,sp,64
    80000c6c:	84ae                	mv	s1,a1
    80000c6e:	8ab2                	mv	s5,a2
    // 使用批量写入而不是逐字符输出
    if (user_src)
    80000c70:	c525                	beqz	a0,80000cd8 <consolewrite+0x78>
    {
        // 从用户空间读取（后续实现）
        for (int i = 0; i < n; i++)
    80000c72:	04c05c63          	blez	a2,80000cca <consolewrite+0x6a>
    80000c76:	f04a                	sd	s2,32(sp)
    80000c78:	ec4e                	sd	s3,24(sp)
    80000c7a:	e852                	sd	s4,16(sp)
    80000c7c:	00b60a33          	add	s4,a2,a1
        {
            char c = ((char *)src)[i];
            if (console.output_pos < CONSOLE_BUF_SIZE - 1)
    80000c80:	0000a917          	auipc	s2,0xa
    80000c84:	0f090913          	addi	s2,s2,240 # 8000ad70 <console>
    80000c88:	0fe00993          	li	s3,254
    80000c8c:	a00d                	j	80000cae <consolewrite+0x4e>
            {
                console.output_buf[console.output_pos++] = c;
    80000c8e:	0017871b          	addiw	a4,a5,1
    80000c92:	0007081b          	sext.w	a6,a4
    80000c96:	20e92623          	sw	a4,524(s2)
    80000c9a:	1782                	slli	a5,a5,0x20
    80000c9c:	9381                	srli	a5,a5,0x20
    80000c9e:	97ca                	add	a5,a5,s2
    80000ca0:	10d78623          	sb	a3,268(a5)
            }
            if (console.output_pos >= CONSOLE_BUF_SIZE - 1)
    80000ca4:	0109eb63          	bltu	s3,a6,80000cba <consolewrite+0x5a>
        for (int i = 0; i < n; i++)
    80000ca8:	0485                	addi	s1,s1,1
    80000caa:	01448d63          	beq	s1,s4,80000cc4 <consolewrite+0x64>
            char c = ((char *)src)[i];
    80000cae:	0004c683          	lbu	a3,0(s1)
            if (console.output_pos < CONSOLE_BUF_SIZE - 1)
    80000cb2:	20c92783          	lw	a5,524(s2)
    80000cb6:	fcf9fce3          	bgeu	s3,a5,80000c8e <consolewrite+0x2e>
            {
                console_flush();
    80000cba:	00000097          	auipc	ra,0x0
    80000cbe:	c9e080e7          	jalr	-866(ra) # 80000958 <console_flush>
    80000cc2:	b7dd                	j	80000ca8 <consolewrite+0x48>
    80000cc4:	7902                	ld	s2,32(sp)
    80000cc6:	69e2                	ld	s3,24(sp)
    80000cc8:	6a42                	ld	s4,16(sp)
        // 从内核空间读取 - 直接批量处理
        console_write_buf((const char *)src, n);
    }

    return n;
}
    80000cca:	8556                	mv	a0,s5
    80000ccc:	70e2                	ld	ra,56(sp)
    80000cce:	7442                	ld	s0,48(sp)
    80000cd0:	74a2                	ld	s1,40(sp)
    80000cd2:	6aa2                	ld	s5,8(sp)
    80000cd4:	6121                	addi	sp,sp,64
    80000cd6:	8082                	ret
        console_write_buf((const char *)src, n);
    80000cd8:	85b2                	mv	a1,a2
    80000cda:	8526                	mv	a0,s1
    80000cdc:	00000097          	auipc	ra,0x0
    80000ce0:	dba080e7          	jalr	-582(ra) # 80000a96 <console_write_buf>
    80000ce4:	b7dd                	j	80000cca <consolewrite+0x6a>

0000000080000ce6 <consoleread>:

// 控制台读取函数
int consoleread(int user_dst, uint64 dst, int n)
{
    80000ce6:	1141                	addi	sp,sp,-16
    80000ce8:	e422                	sd	s0,8(sp)
    80000cea:	0800                	addi	s0,sp,16
    // TODO: 实现键盘输入读取
    // 这需要中断处理和键盘驱动
    return 0;
    80000cec:	4501                	li	a0,0
    80000cee:	6422                	ld	s0,8(sp)
    80000cf0:	0141                	addi	sp,sp,16
    80000cf2:	8082                	ret

0000000080000cf4 <mark_block_allocated>:
        pages[start_pfn + i].order = 0;
    }
}

void mark_block_allocated(void *page, int order) // 标记页面为已分配 操作对应的 page 数组
{
    80000cf4:	1141                	addi	sp,sp,-16
    80000cf6:	e422                	sd	s0,8(sp)
    80000cf8:	0800                	addi	s0,sp,16
    //     panic("mark_block_allocated: page is not block head !");
    // }
    // 新分配的块可能不是块头

    uint64 start_pfn = ((uint64)page - (uint64)buddy.memory_start) / PGSIZE;
    uint64 count = 1UL << order;
    80000cfa:	4885                	li	a7,1
    80000cfc:	00b898b3          	sll	a7,a7,a1
    uint64 start_pfn = ((uint64)page - (uint64)buddy.memory_start) / PGSIZE;
    80000d00:	0000a797          	auipc	a5,0xa
    80000d04:	3407b783          	ld	a5,832(a5) # 8000b040 <buddy+0xc0>
    80000d08:	40f50833          	sub	a6,a0,a5
    80000d0c:	00c85813          	srli	a6,a6,0xc
        pages[start_pfn + i].flags &= ~PAGE_FREE; // 清除空闲标志

        if (i == 0)
        {
            // 只有第一个页面是块头
            pages[start_pfn].order = order;
    80000d10:	080e                	slli	a6,a6,0x3
    80000d12:	8742                	mv	a4,a6
    for (uint64 i = 0; i < count; i++)
    80000d14:	4681                	li	a3,0
        pages[start_pfn + i].flags &= ~PAGE_FREE; // 清除空闲标志
    80000d16:	0000a517          	auipc	a0,0xa
    80000d1a:	26a50513          	addi	a0,a0,618 # 8000af80 <buddy>
    80000d1e:	a831                	j	80000d3a <mark_block_allocated+0x46>
            pages[start_pfn].order = order;
    80000d20:	717c                	ld	a5,224(a0)
    80000d22:	97c2                	add	a5,a5,a6
    80000d24:	c38c                	sw	a1,0(a5)
            pages[start_pfn].flags |= PAGE_HEAD;
    80000d26:	717c                	ld	a5,224(a0)
    80000d28:	97c2                	add	a5,a5,a6
    80000d2a:	43d0                	lw	a2,4(a5)
    80000d2c:	00266613          	ori	a2,a2,2
    80000d30:	c3d0                	sw	a2,4(a5)
    for (uint64 i = 0; i < count; i++)
    80000d32:	0685                	addi	a3,a3,1
    80000d34:	0721                	addi	a4,a4,8
    80000d36:	02d88263          	beq	a7,a3,80000d5a <mark_block_allocated+0x66>
        pages[start_pfn + i].flags &= ~PAGE_FREE; // 清除空闲标志
    80000d3a:	717c                	ld	a5,224(a0)
    80000d3c:	97ba                	add	a5,a5,a4
    80000d3e:	43d0                	lw	a2,4(a5)
    80000d40:	9a79                	andi	a2,a2,-2
    80000d42:	c3d0                	sw	a2,4(a5)
        if (i == 0)
    80000d44:	def1                	beqz	a3,80000d20 <mark_block_allocated+0x2c>
        }
        else
        {
            // 其他页面不是块头
            pages[start_pfn + i].order = 0;
    80000d46:	717c                	ld	a5,224(a0)
    80000d48:	97ba                	add	a5,a5,a4
    80000d4a:	0007a023          	sw	zero,0(a5)
            pages[start_pfn + i].flags &= ~PAGE_HEAD;
    80000d4e:	717c                	ld	a5,224(a0)
    80000d50:	97ba                	add	a5,a5,a4
    80000d52:	43d0                	lw	a2,4(a5)
    80000d54:	9a75                	andi	a2,a2,-3
    80000d56:	c3d0                	sw	a2,4(a5)
    80000d58:	bfe9                	j	80000d32 <mark_block_allocated+0x3e>
        }
    }
}
    80000d5a:	6422                	ld	s0,8(sp)
    80000d5c:	0141                	addi	sp,sp,16
    80000d5e:	8082                	ret

0000000080000d60 <mark_block_free>:

void mark_block_free(void *page, int order) // 标记页面为空闲 传入的page 必须是块头的page 地址
{
    80000d60:	1141                	addi	sp,sp,-16
    80000d62:	e422                	sd	s0,8(sp)
    80000d64:	0800                	addi	s0,sp,16
    // if (is_block_head(page) == 0)
    // {
    //     panic("mark_block_free: page is not block head !");
    // }
    uint64 start_pfn = ((uint64)page - (uint64)buddy.memory_start) / PGSIZE;
    uint64 count = 1UL << order;
    80000d66:	4885                	li	a7,1
    80000d68:	00b898b3          	sll	a7,a7,a1
    uint64 start_pfn = ((uint64)page - (uint64)buddy.memory_start) / PGSIZE;
    80000d6c:	0000a797          	auipc	a5,0xa
    80000d70:	2d47b783          	ld	a5,724(a5) # 8000b040 <buddy+0xc0>
    80000d74:	40f50833          	sub	a6,a0,a5
    80000d78:	00c85813          	srli	a6,a6,0xc
        pages[start_pfn + i].flags |= PAGE_FREE; // 设置空闲标志

        if (i == 0)
        {
            // 只有第一个页面是块头
            pages[start_pfn].order = order;
    80000d7c:	080e                	slli	a6,a6,0x3
    80000d7e:	8742                	mv	a4,a6
    for (uint64 i = 0; i < count; i++)
    80000d80:	4681                	li	a3,0
        pages[start_pfn + i].flags |= PAGE_FREE; // 设置空闲标志
    80000d82:	0000a517          	auipc	a0,0xa
    80000d86:	1fe50513          	addi	a0,a0,510 # 8000af80 <buddy>
    80000d8a:	a831                	j	80000da6 <mark_block_free+0x46>
            pages[start_pfn].order = order;
    80000d8c:	717c                	ld	a5,224(a0)
    80000d8e:	97c2                	add	a5,a5,a6
    80000d90:	c38c                	sw	a1,0(a5)
            pages[start_pfn].flags |= PAGE_HEAD;
    80000d92:	717c                	ld	a5,224(a0)
    80000d94:	97c2                	add	a5,a5,a6
    80000d96:	43d0                	lw	a2,4(a5)
    80000d98:	00266613          	ori	a2,a2,2
    80000d9c:	c3d0                	sw	a2,4(a5)
    for (uint64 i = 0; i < count; i++)
    80000d9e:	0685                	addi	a3,a3,1
    80000da0:	0721                	addi	a4,a4,8
    80000da2:	02d88363          	beq	a7,a3,80000dc8 <mark_block_free+0x68>
        pages[start_pfn + i].flags |= PAGE_FREE; // 设置空闲标志
    80000da6:	717c                	ld	a5,224(a0)
    80000da8:	97ba                	add	a5,a5,a4
    80000daa:	43d0                	lw	a2,4(a5)
    80000dac:	00166613          	ori	a2,a2,1
    80000db0:	c3d0                	sw	a2,4(a5)
        if (i == 0)
    80000db2:	dee9                	beqz	a3,80000d8c <mark_block_free+0x2c>
        }
        else
        {
            // 其他页面不是块头
            pages[start_pfn + i].order = 0;
    80000db4:	717c                	ld	a5,224(a0)
    80000db6:	97ba                	add	a5,a5,a4
    80000db8:	0007a023          	sw	zero,0(a5)
            pages[start_pfn + i].flags &= ~PAGE_HEAD;
    80000dbc:	717c                	ld	a5,224(a0)
    80000dbe:	97ba                	add	a5,a5,a4
    80000dc0:	43d0                	lw	a2,4(a5)
    80000dc2:	9a75                	andi	a2,a2,-3
    80000dc4:	c3d0                	sw	a2,4(a5)
    80000dc6:	bfe1                	j	80000d9e <mark_block_free+0x3e>
        }
    }
}
    80000dc8:	6422                	ld	s0,8(sp)
    80000dca:	0141                	addi	sp,sp,16
    80000dcc:	8082                	ret

0000000080000dce <list_add>:

void list_add(struct free_block *list, struct free_block *block) // 将块添加到空闲链表
{
    80000dce:	1141                	addi	sp,sp,-16
    80000dd0:	e422                	sd	s0,8(sp)
    80000dd2:	0800                	addi	s0,sp,16
    block->next = list->next;
    80000dd4:	611c                	ld	a5,0(a0)
    80000dd6:	e19c                	sd	a5,0(a1)
    block->prev = list;
    80000dd8:	e588                	sd	a0,8(a1)
    list->next->prev = block;
    80000dda:	611c                	ld	a5,0(a0)
    80000ddc:	e78c                	sd	a1,8(a5)
    list->next = block;
    80000dde:	e10c                	sd	a1,0(a0)
}
    80000de0:	6422                	ld	s0,8(sp)
    80000de2:	0141                	addi	sp,sp,16
    80000de4:	8082                	ret

0000000080000de6 <list_remove>:
void list_remove(struct free_block *block) // 从链表中移除块
{
    80000de6:	1141                	addi	sp,sp,-16
    80000de8:	e422                	sd	s0,8(sp)
    80000dea:	0800                	addi	s0,sp,16
    block->prev->next = block->next;
    80000dec:	6518                	ld	a4,8(a0)
    80000dee:	611c                	ld	a5,0(a0)
    80000df0:	e31c                	sd	a5,0(a4)
    block->next->prev = block->prev;
    80000df2:	6518                	ld	a4,8(a0)
    80000df4:	e798                	sd	a4,8(a5)
    // 只是断开链表连接，不涉及内存大小
}
    80000df6:	6422                	ld	s0,8(sp)
    80000df8:	0141                	addi	sp,sp,16
    80000dfa:	8082                	ret

0000000080000dfc <alloc_pages>:
{
    80000dfc:	7139                	addi	sp,sp,-64
    80000dfe:	fc06                	sd	ra,56(sp)
    80000e00:	f822                	sd	s0,48(sp)
    80000e02:	f04a                	sd	s2,32(sp)
    80000e04:	e456                	sd	s5,8(sp)
    80000e06:	0080                	addi	s0,sp,64
    if (order < 0 || order > MAX_ORDER)
    80000e08:	8aaa                	mv	s5,a0
    80000e0a:	47a9                	li	a5,10
    80000e0c:	04a7ed63          	bltu	a5,a0,80000e66 <alloc_pages+0x6a>
    80000e10:	f426                	sd	s1,40(sp)
    acquire(&buddy.lock);
    80000e12:	0000a517          	auipc	a0,0xa
    80000e16:	23650513          	addi	a0,a0,566 # 8000b048 <buddy+0xc8>
    80000e1a:	00000097          	auipc	ra,0x0
    80000e1e:	45e080e7          	jalr	1118(ra) # 80001278 <acquire>
    while (current_order <= MAX_ORDER) // 当前 order 对应的块不够大就继续往上查
    80000e22:	004a9713          	slli	a4,s5,0x4
    80000e26:	0000a797          	auipc	a5,0xa
    80000e2a:	15a78793          	addi	a5,a5,346 # 8000af80 <buddy>
    80000e2e:	97ba                	add	a5,a5,a4
    int current_order = order;
    80000e30:	84d6                	mv	s1,s5
    while (current_order <= MAX_ORDER) // 当前 order 对应的块不够大就继续往上查
    80000e32:	472d                	li	a4,11
    }
}

static inline int list_empty(struct free_block *list)
{
    return list->next == list;
    80000e34:	0007b903          	ld	s2,0(a5)
        if (!list_empty(&buddy.free_lists[current_order]))
    80000e38:	04f91c63          	bne	s2,a5,80000e90 <alloc_pages+0x94>
        current_order++;
    80000e3c:	2485                	addiw	s1,s1,1
    while (current_order <= MAX_ORDER) // 当前 order 对应的块不够大就继续往上查
    80000e3e:	07c1                	addi	a5,a5,16
    80000e40:	fee49ae3          	bne	s1,a4,80000e34 <alloc_pages+0x38>
    80000e44:	74a2                	ld	s1,40(sp)
    release(&buddy.lock);
    80000e46:	0000a517          	auipc	a0,0xa
    80000e4a:	20250513          	addi	a0,a0,514 # 8000b048 <buddy+0xc8>
    80000e4e:	00000097          	auipc	ra,0x0
    80000e52:	44c080e7          	jalr	1100(ra) # 8000129a <release>
    return 0; // 内存不足
    80000e56:	4901                	li	s2,0
}
    80000e58:	854a                	mv	a0,s2
    80000e5a:	70e2                	ld	ra,56(sp)
    80000e5c:	7442                	ld	s0,48(sp)
    80000e5e:	7902                	ld	s2,32(sp)
    80000e60:	6aa2                	ld	s5,8(sp)
    80000e62:	6121                	addi	sp,sp,64
    80000e64:	8082                	ret
        panic("alloc_pages: invalid order");
    80000e66:	00001517          	auipc	a0,0x1
    80000e6a:	56a50513          	addi	a0,a0,1386 # 800023d0 <_trampoline+0x3d0>
    80000e6e:	fffff097          	auipc	ra,0xfffff
    80000e72:	620080e7          	jalr	1568(ra) # 8000048e <panic>
    acquire(&buddy.lock);
    80000e76:	0000a517          	auipc	a0,0xa
    80000e7a:	1d250513          	addi	a0,a0,466 # 8000b048 <buddy+0xc8>
    80000e7e:	00000097          	auipc	ra,0x0
    80000e82:	3fa080e7          	jalr	1018(ra) # 80001278 <acquire>
    while (current_order <= MAX_ORDER) // 当前 order 对应的块不够大就继续往上查
    80000e86:	47a9                	li	a5,10
    80000e88:	fb57cfe3          	blt	a5,s5,80000e46 <alloc_pages+0x4a>
    80000e8c:	f426                	sd	s1,40(sp)
    80000e8e:	bf51                	j	80000e22 <alloc_pages+0x26>
            list_remove(block);
    80000e90:	854a                	mv	a0,s2
    80000e92:	00000097          	auipc	ra,0x0
    80000e96:	f54080e7          	jalr	-172(ra) # 80000de6 <list_remove>
            while (current_order > order)
    80000e9a:	049ad463          	bge	s5,s1,80000ee2 <alloc_pages+0xe6>
    80000e9e:	ec4e                	sd	s3,24(sp)
    80000ea0:	e852                	sd	s4,16(sp)
    80000ea2:	e05a                	sd	s6,0(sp)
    80000ea4:	fff48793          	addi	a5,s1,-1
    80000ea8:	0792                	slli	a5,a5,0x4
    80000eaa:	0000aa17          	auipc	s4,0xa
    80000eae:	0d6a0a13          	addi	s4,s4,214 # 8000af80 <buddy>
    80000eb2:	9a3e                	add	s4,s4,a5
                void *buddy_page = (char *)page + (1UL << current_order) * PGSIZE;
    80000eb4:	6b05                	lui	s6,0x1
                current_order--;
    80000eb6:	34fd                	addiw	s1,s1,-1
                void *buddy_page = (char *)page + (1UL << current_order) * PGSIZE;
    80000eb8:	009b19b3          	sll	s3,s6,s1
    80000ebc:	99ca                	add	s3,s3,s2
                list_add(&buddy.free_lists[current_order], (struct free_block *)buddy_page);
    80000ebe:	85ce                	mv	a1,s3
    80000ec0:	8552                	mv	a0,s4
    80000ec2:	00000097          	auipc	ra,0x0
    80000ec6:	f0c080e7          	jalr	-244(ra) # 80000dce <list_add>
                mark_block_free(buddy_page, current_order);
    80000eca:	85a6                	mv	a1,s1
    80000ecc:	854e                	mv	a0,s3
    80000ece:	00000097          	auipc	ra,0x0
    80000ed2:	e92080e7          	jalr	-366(ra) # 80000d60 <mark_block_free>
            while (current_order > order)
    80000ed6:	1a41                	addi	s4,s4,-16
    80000ed8:	fc9a9fe3          	bne	s5,s1,80000eb6 <alloc_pages+0xba>
    80000edc:	69e2                	ld	s3,24(sp)
    80000ede:	6a42                	ld	s4,16(sp)
    80000ee0:	6b02                	ld	s6,0(sp)
            mark_block_allocated(page, order);
    80000ee2:	85d6                	mv	a1,s5
    80000ee4:	854a                	mv	a0,s2
    80000ee6:	00000097          	auipc	ra,0x0
    80000eea:	e0e080e7          	jalr	-498(ra) # 80000cf4 <mark_block_allocated>
            buddy.free_pages -= (1UL << order);
    80000eee:	0000a697          	auipc	a3,0xa
    80000ef2:	09268693          	addi	a3,a3,146 # 8000af80 <buddy>
    80000ef6:	4705                	li	a4,1
    80000ef8:	01571733          	sll	a4,a4,s5
    80000efc:	7edc                	ld	a5,184(a3)
    80000efe:	8f99                	sub	a5,a5,a4
    80000f00:	fedc                	sd	a5,184(a3)
            release(&buddy.lock);
    80000f02:	0000a517          	auipc	a0,0xa
    80000f06:	14650513          	addi	a0,a0,326 # 8000b048 <buddy+0xc8>
    80000f0a:	00000097          	auipc	ra,0x0
    80000f0e:	390080e7          	jalr	912(ra) # 8000129a <release>
            return page;
    80000f12:	74a2                	ld	s1,40(sp)
    80000f14:	b791                	j	80000e58 <alloc_pages+0x5c>

0000000080000f16 <free_pages>:
    if (!page || order < 0 || order > MAX_ORDER)
    80000f16:	1e050163          	beqz	a0,800010f8 <free_pages+0x1e2>
{
    80000f1a:	711d                	addi	sp,sp,-96
    80000f1c:	ec86                	sd	ra,88(sp)
    80000f1e:	e8a2                	sd	s0,80(sp)
    80000f20:	fc4e                	sd	s3,56(sp)
    80000f22:	f852                	sd	s4,48(sp)
    80000f24:	1080                	addi	s0,sp,96
    80000f26:	8a2a                	mv	s4,a0
    80000f28:	89ae                	mv	s3,a1
    if (!page || order < 0 || order > MAX_ORDER)
    80000f2a:	0005879b          	sext.w	a5,a1
    80000f2e:	4729                	li	a4,10
    80000f30:	18f76663          	bltu	a4,a5,800010bc <free_pages+0x1a6>
    80000f34:	e4a6                	sd	s1,72(sp)
    acquire(&buddy.lock);
    80000f36:	0000a497          	auipc	s1,0xa
    80000f3a:	04a48493          	addi	s1,s1,74 # 8000af80 <buddy>
    80000f3e:	0000a517          	auipc	a0,0xa
    80000f42:	10a50513          	addi	a0,a0,266 # 8000b048 <buddy+0xc8>
    80000f46:	00000097          	auipc	ra,0x0
    80000f4a:	332080e7          	jalr	818(ra) # 80001278 <acquire>
}

static inline int is_block_head(void *page)
{
    // 检查是否为块头
    return pages[((uint64)page - (uint64)buddy.memory_start) / PGSIZE].flags & PAGE_HEAD;
    80000f4e:	60fc                	ld	a5,192(s1)
    80000f50:	40fa07b3          	sub	a5,s4,a5
    80000f54:	83b1                	srli	a5,a5,0xc
    80000f56:	70f8                	ld	a4,224(s1)
    80000f58:	078e                	slli	a5,a5,0x3
    80000f5a:	97ba                	add	a5,a5,a4
    if (is_block_head(page) == 0)
    80000f5c:	43dc                	lw	a5,4(a5)
    80000f5e:	8b89                	andi	a5,a5,2
    80000f60:	c7a9                	beqz	a5,80000faa <free_pages+0x94>
    mark_block_free(page, order);
    80000f62:	85ce                	mv	a1,s3
    80000f64:	8552                	mv	a0,s4
    80000f66:	00000097          	auipc	ra,0x0
    80000f6a:	dfa080e7          	jalr	-518(ra) # 80000d60 <mark_block_free>
    buddy.free_pages += (1UL << order);
    80000f6e:	0000a697          	auipc	a3,0xa
    80000f72:	01268693          	addi	a3,a3,18 # 8000af80 <buddy>
    80000f76:	4705                	li	a4,1
    80000f78:	01371733          	sll	a4,a4,s3
    80000f7c:	7edc                	ld	a5,184(a3)
    80000f7e:	97ba                	add	a5,a5,a4
    80000f80:	fedc                	sd	a5,184(a3)
    while (order < MAX_ORDER)
    80000f82:	47a5                	li	a5,9
    80000f84:	1137c863          	blt	a5,s3,80001094 <free_pages+0x17e>
    80000f88:	e0ca                	sd	s2,64(sp)
    80000f8a:	f456                	sd	s5,40(sp)
    80000f8c:	f05a                	sd	s6,32(sp)
    80000f8e:	ec5e                	sd	s7,24(sp)
    80000f90:	e862                	sd	s8,16(sp)
    80000f92:	e466                	sd	s9,8(sp)
    80000f94:	e06a                	sd	s10,0(sp)
    return pages[((uint64)page - (uint64)buddy.memory_start) / PGSIZE].flags & PAGE_HEAD;
    80000f96:	84b6                	mv	s1,a3
        panic("get_buddy_block: page is not block head !");
    80000f98:	00001c97          	auipc	s9,0x1
    80000f9c:	480c8c93          	addi	s9,s9,1152 # 80002418 <_trampoline+0x418>
    uint64 buddy_pfn = pfn ^ (1UL << order);
    80000fa0:	4b05                	li	s6,1
           ((uint64)page & (PGSIZE - 1)) == 0; // 页面对齐检查
    80000fa2:	6c05                	lui	s8,0x1
    80000fa4:	1c7d                	addi	s8,s8,-1 # fff <_entry-0x7ffff001>
    while (order < MAX_ORDER)
    80000fa6:	4ba9                	li	s7,10
    80000fa8:	a8bd                	j	80001026 <free_pages+0x110>
        panic("free_pages: page is not block head !");
    80000faa:	00001517          	auipc	a0,0x1
    80000fae:	44650513          	addi	a0,a0,1094 # 800023f0 <_trampoline+0x3f0>
    80000fb2:	fffff097          	auipc	ra,0xfffff
    80000fb6:	4dc080e7          	jalr	1244(ra) # 8000048e <panic>
    80000fba:	b765                	j	80000f62 <free_pages+0x4c>
        panic("get_buddy_block: page is not block head !");
    80000fbc:	8566                	mv	a0,s9
    80000fbe:	fffff097          	auipc	ra,0xfffff
    80000fc2:	4d0080e7          	jalr	1232(ra) # 8000048e <panic>
    80000fc6:	a89d                	j	8000103c <free_pages+0x126>
    struct page_info *info = &pages[((uint64)page - (uint64)buddy.memory_start) / PGSIZE];
    80000fc8:	078e                	slli	a5,a5,0x3
    80000fca:	70f8                	ld	a4,224(s1)
    80000fcc:	97ba                	add	a5,a5,a4
    return (info->flags & PAGE_FREE) && (info->order == order);
    80000fce:	43d8                	lw	a4,4(a5)
    80000fd0:	8b05                	andi	a4,a4,1
    80000fd2:	10070363          	beqz	a4,800010d8 <free_pages+0x1c2>
        if (!is_valid_page(buddy_page) || !is_page_free(buddy_page, order))
    80000fd6:	439c                	lw	a5,0(a5)
    80000fd8:	11379863          	bne	a5,s3,800010e8 <free_pages+0x1d2>
        list_remove((struct free_block *)buddy_page);
    80000fdc:	854a                	mv	a0,s2
    80000fde:	00000097          	auipc	ra,0x0
    80000fe2:	e08080e7          	jalr	-504(ra) # 80000de6 <list_remove>
    uint64 start_pfn = ((uint64)page - (uint64)buddy.memory_start) / PGSIZE;
    80000fe6:	60f8                	ld	a4,192(s1)
    80000fe8:	40e90733          	sub	a4,s2,a4
    80000fec:	8331                	srli	a4,a4,0xc
    for (uint64 i = 0; i < count; i++)
    80000fee:	00371793          	slli	a5,a4,0x3
    80000ff2:	00ed06b3          	add	a3,s10,a4
    80000ff6:	068e                	slli	a3,a3,0x3
        pages[start_pfn + i].flags = 0;
    80000ff8:	70f8                	ld	a4,224(s1)
    80000ffa:	973e                	add	a4,a4,a5
    80000ffc:	00072223          	sw	zero,4(a4)
        pages[start_pfn + i].order = 0;
    80001000:	70f8                	ld	a4,224(s1)
    80001002:	973e                	add	a4,a4,a5
    80001004:	00072023          	sw	zero,0(a4)
    for (uint64 i = 0; i < count; i++)
    80001008:	07a1                	addi	a5,a5,8
    8000100a:	fed797e3          	bne	a5,a3,80000ff8 <free_pages+0xe2>
    return ((uint64)page1 < (uint64)page2) ? page1 : page2;
    8000100e:	012ae363          	bltu	s5,s2,80001014 <free_pages+0xfe>
    80001012:	8a4a                	mv	s4,s2
        order++;
    80001014:	2985                	addiw	s3,s3,1
        mark_block_free(page, order);
    80001016:	85ce                	mv	a1,s3
    80001018:	8552                	mv	a0,s4
    8000101a:	00000097          	auipc	ra,0x0
    8000101e:	d46080e7          	jalr	-698(ra) # 80000d60 <mark_block_free>
    while (order < MAX_ORDER)
    80001022:	05798a63          	beq	s3,s7,80001076 <free_pages+0x160>
    return pages[((uint64)page - (uint64)buddy.memory_start) / PGSIZE].flags & PAGE_HEAD;
    80001026:	8ad2                	mv	s5,s4
    80001028:	60fc                	ld	a5,192(s1)
    8000102a:	40fa07b3          	sub	a5,s4,a5
    8000102e:	83b1                	srli	a5,a5,0xc
    80001030:	70f8                	ld	a4,224(s1)
    80001032:	078e                	slli	a5,a5,0x3
    80001034:	97ba                	add	a5,a5,a4
    if (is_block_head(page) == 0)
    80001036:	43dc                	lw	a5,4(a5)
    80001038:	8b89                	andi	a5,a5,2
    8000103a:	d3c9                	beqz	a5,80000fbc <free_pages+0xa6>
    uint64 pfn = ((uint64)page - (uint64)buddy.memory_start) / PGSIZE;
    8000103c:	60f8                	ld	a4,192(s1)
    uint64 buddy_pfn = pfn ^ (1UL << order);
    8000103e:	013b1d33          	sll	s10,s6,s3
    uint64 pfn = ((uint64)page - (uint64)buddy.memory_start) / PGSIZE;
    80001042:	40ea87b3          	sub	a5,s5,a4
    80001046:	83b1                	srli	a5,a5,0xc
    uint64 buddy_pfn = pfn ^ (1UL << order);
    80001048:	01a7c7b3          	xor	a5,a5,s10
    return (void *)((uint64)buddy.memory_start + buddy_pfn * PGSIZE);
    8000104c:	00c79913          	slli	s2,a5,0xc
    80001050:	993a                	add	s2,s2,a4
           page < (void *)((uint64)buddy.memory_start + buddy.total_pages * PGSIZE) &&
    80001052:	02e96a63          	bltu	s2,a4,80001086 <free_pages+0x170>
    80001056:	78d4                	ld	a3,176(s1)
    80001058:	06b2                	slli	a3,a3,0xc
    8000105a:	9736                	add	a4,a4,a3
    return page >= buddy.memory_start &&
    8000105c:	06e97663          	bgeu	s2,a4,800010c8 <free_pages+0x1b2>
           ((uint64)page & (PGSIZE - 1)) == 0; // 页面对齐检查
    80001060:	01897733          	and	a4,s2,s8
        if (!is_valid_page(buddy_page) || !is_page_free(buddy_page, order))
    80001064:	d335                	beqz	a4,80000fc8 <free_pages+0xb2>
    80001066:	6906                	ld	s2,64(sp)
    80001068:	7aa2                	ld	s5,40(sp)
    8000106a:	7b02                	ld	s6,32(sp)
    8000106c:	6be2                	ld	s7,24(sp)
    8000106e:	6c42                	ld	s8,16(sp)
    80001070:	6ca2                	ld	s9,8(sp)
    80001072:	6d02                	ld	s10,0(sp)
    80001074:	a005                	j	80001094 <free_pages+0x17e>
    80001076:	6906                	ld	s2,64(sp)
    80001078:	7aa2                	ld	s5,40(sp)
    8000107a:	7b02                	ld	s6,32(sp)
    8000107c:	6be2                	ld	s7,24(sp)
    8000107e:	6c42                	ld	s8,16(sp)
    80001080:	6ca2                	ld	s9,8(sp)
    80001082:	6d02                	ld	s10,0(sp)
    80001084:	a801                	j	80001094 <free_pages+0x17e>
    80001086:	6906                	ld	s2,64(sp)
    80001088:	7aa2                	ld	s5,40(sp)
    8000108a:	7b02                	ld	s6,32(sp)
    8000108c:	6be2                	ld	s7,24(sp)
    8000108e:	6c42                	ld	s8,16(sp)
    80001090:	6ca2                	ld	s9,8(sp)
    80001092:	6d02                	ld	s10,0(sp)
    list_add(&buddy.free_lists[order], (struct free_block *)page);
    80001094:	0992                	slli	s3,s3,0x4
    80001096:	85d2                	mv	a1,s4
    80001098:	0000a517          	auipc	a0,0xa
    8000109c:	ee850513          	addi	a0,a0,-280 # 8000af80 <buddy>
    800010a0:	954e                	add	a0,a0,s3
    800010a2:	00000097          	auipc	ra,0x0
    800010a6:	d2c080e7          	jalr	-724(ra) # 80000dce <list_add>
    release(&buddy.lock);
    800010aa:	0000a517          	auipc	a0,0xa
    800010ae:	f9e50513          	addi	a0,a0,-98 # 8000b048 <buddy+0xc8>
    800010b2:	00000097          	auipc	ra,0x0
    800010b6:	1e8080e7          	jalr	488(ra) # 8000129a <release>
    800010ba:	64a6                	ld	s1,72(sp)
}
    800010bc:	60e6                	ld	ra,88(sp)
    800010be:	6446                	ld	s0,80(sp)
    800010c0:	79e2                	ld	s3,56(sp)
    800010c2:	7a42                	ld	s4,48(sp)
    800010c4:	6125                	addi	sp,sp,96
    800010c6:	8082                	ret
    800010c8:	6906                	ld	s2,64(sp)
    800010ca:	7aa2                	ld	s5,40(sp)
    800010cc:	7b02                	ld	s6,32(sp)
    800010ce:	6be2                	ld	s7,24(sp)
    800010d0:	6c42                	ld	s8,16(sp)
    800010d2:	6ca2                	ld	s9,8(sp)
    800010d4:	6d02                	ld	s10,0(sp)
    800010d6:	bf7d                	j	80001094 <free_pages+0x17e>
    800010d8:	6906                	ld	s2,64(sp)
    800010da:	7aa2                	ld	s5,40(sp)
    800010dc:	7b02                	ld	s6,32(sp)
    800010de:	6be2                	ld	s7,24(sp)
    800010e0:	6c42                	ld	s8,16(sp)
    800010e2:	6ca2                	ld	s9,8(sp)
    800010e4:	6d02                	ld	s10,0(sp)
    800010e6:	b77d                	j	80001094 <free_pages+0x17e>
    800010e8:	6906                	ld	s2,64(sp)
    800010ea:	7aa2                	ld	s5,40(sp)
    800010ec:	7b02                	ld	s6,32(sp)
    800010ee:	6be2                	ld	s7,24(sp)
    800010f0:	6c42                	ld	s8,16(sp)
    800010f2:	6ca2                	ld	s9,8(sp)
    800010f4:	6d02                	ld	s10,0(sp)
    800010f6:	bf79                	j	80001094 <free_pages+0x17e>
    800010f8:	8082                	ret

00000000800010fa <buddy_add_memory>:
{
    800010fa:	711d                	addi	sp,sp,-96
    800010fc:	ec86                	sd	ra,88(sp)
    800010fe:	e8a2                	sd	s0,80(sp)
    80001100:	e4a6                	sd	s1,72(sp)
    80001102:	1080                	addi	s0,sp,96
    char *p = (char *)PGROUNDUP((uint64)start);
    80001104:	6785                	lui	a5,0x1
    80001106:	fff78713          	addi	a4,a5,-1 # fff <_entry-0x7ffff001>
    8000110a:	953a                	add	a0,a0,a4
    8000110c:	777d                	lui	a4,0xfffff
    8000110e:	00e574b3          	and	s1,a0,a4
    while (p + PGSIZE <= (char *)end)
    80001112:	97a6                	add	a5,a5,s1
    80001114:	0af5e363          	bltu	a1,a5,800011ba <buddy_add_memory+0xc0>
    80001118:	e0ca                	sd	s2,64(sp)
    8000111a:	fc4e                	sd	s3,56(sp)
    8000111c:	f852                	sd	s4,48(sp)
    8000111e:	f456                	sd	s5,40(sp)
    80001120:	f05a                	sd	s6,32(sp)
    80001122:	ec5e                	sd	s7,24(sp)
    80001124:	e862                	sd	s8,16(sp)
    80001126:	e466                	sd	s9,8(sp)
    80001128:	89ae                	mv	s3,a1
        uint64 pfn = ((uint64)p - (uint64)buddy.memory_start) / PGSIZE;
    8000112a:	0000ab17          	auipc	s6,0xa
    8000112e:	e56b0b13          	addi	s6,s6,-426 # 8000af80 <buddy>
        int order = 0;
    80001132:	4c01                	li	s8,0
               (pfn & ((1UL << order) - 1)) == 0 && // 地址对齐检查
    80001134:	5a7d                	li	s4,-1
               p + ((1UL << (order + 1)) * PGSIZE) <= (char *)end)
    80001136:	6905                	lui	s2,0x1
               (pfn & ((1UL << order) - 1)) == 0 && // 地址对齐检查
    80001138:	4aa9                	li	s5,10
        buddy.free_pages += (1UL << order);
    8000113a:	4b85                	li	s7,1
    8000113c:	a081                	j	8000117c <buddy_add_memory+0x82>
    8000113e:	8cba                	mv	s9,a4
    80001140:	a011                	j	80001144 <buddy_add_memory+0x4a>
    80001142:	8cba                	mv	s9,a4
        mark_block_free(p, order);
    80001144:	85e6                	mv	a1,s9
    80001146:	8526                	mv	a0,s1
    80001148:	00000097          	auipc	ra,0x0
    8000114c:	c18080e7          	jalr	-1000(ra) # 80000d60 <mark_block_free>
        list_add(&buddy.free_lists[order], (struct free_block *)p);
    80001150:	004c9513          	slli	a0,s9,0x4
    80001154:	85a6                	mv	a1,s1
    80001156:	955a                	add	a0,a0,s6
    80001158:	00000097          	auipc	ra,0x0
    8000115c:	c76080e7          	jalr	-906(ra) # 80000dce <list_add>
        buddy.free_pages += (1UL << order);
    80001160:	019b9733          	sll	a4,s7,s9
    80001164:	0b8b3783          	ld	a5,184(s6)
    80001168:	97ba                	add	a5,a5,a4
    8000116a:	0afb3c23          	sd	a5,184(s6)
        p += (1UL << order) * PGSIZE;
    8000116e:	01991cb3          	sll	s9,s2,s9
    80001172:	94e6                	add	s1,s1,s9
    while (p + PGSIZE <= (char *)end)
    80001174:	012487b3          	add	a5,s1,s2
    80001178:	02f9e963          	bltu	s3,a5,800011aa <buddy_add_memory+0xb0>
        uint64 pfn = ((uint64)p - (uint64)buddy.memory_start) / PGSIZE;
    8000117c:	0c0b3683          	ld	a3,192(s6)
    80001180:	40d486b3          	sub	a3,s1,a3
    80001184:	82b1                	srli	a3,a3,0xc
        int order = 0;
    80001186:	8762                	mv	a4,s8
               (pfn & ((1UL << order) - 1)) == 0 && // 地址对齐检查
    80001188:	00ea17b3          	sll	a5,s4,a4
    8000118c:	fff7c793          	not	a5,a5
    80001190:	8ff5                	and	a5,a5,a3
        while (order < MAX_ORDER &&
    80001192:	fbc5                	bnez	a5,80001142 <buddy_add_memory+0x48>
               p + ((1UL << (order + 1)) * PGSIZE) <= (char *)end)
    80001194:	00170c9b          	addiw	s9,a4,1 # fffffffffffff001 <end+0xffffffff7fff3f99>
    80001198:	019917b3          	sll	a5,s2,s9
    8000119c:	97a6                	add	a5,a5,s1
               (pfn & ((1UL << order) - 1)) == 0 && // 地址对齐检查
    8000119e:	faf9e0e3          	bltu	s3,a5,8000113e <buddy_add_memory+0x44>
    800011a2:	fb5c81e3          	beq	s9,s5,80001144 <buddy_add_memory+0x4a>
    800011a6:	8766                	mv	a4,s9
    800011a8:	b7c5                	j	80001188 <buddy_add_memory+0x8e>
    800011aa:	6906                	ld	s2,64(sp)
    800011ac:	79e2                	ld	s3,56(sp)
    800011ae:	7a42                	ld	s4,48(sp)
    800011b0:	7aa2                	ld	s5,40(sp)
    800011b2:	7b02                	ld	s6,32(sp)
    800011b4:	6be2                	ld	s7,24(sp)
    800011b6:	6c42                	ld	s8,16(sp)
    800011b8:	6ca2                	ld	s9,8(sp)
}
    800011ba:	60e6                	ld	ra,88(sp)
    800011bc:	6446                	ld	s0,80(sp)
    800011be:	64a6                	ld	s1,72(sp)
    800011c0:	6125                	addi	sp,sp,96
    800011c2:	8082                	ret

00000000800011c4 <pmm_init>:
{
    800011c4:	1101                	addi	sp,sp,-32
    800011c6:	ec06                	sd	ra,24(sp)
    800011c8:	e822                	sd	s0,16(sp)
    800011ca:	e426                	sd	s1,8(sp)
    800011cc:	1000                	addi	s0,sp,32
    void *mem_start = (void *)PGROUNDUP((uint64)end);
    800011ce:	6585                	lui	a1,0x1
    800011d0:	15fd                	addi	a1,a1,-1 # fff <_entry-0x7ffff001>
    800011d2:	00002717          	auipc	a4,0x2
    800011d6:	b7673703          	ld	a4,-1162(a4) # 80002d48 <_GLOBAL_OFFSET_TABLE_+0x18>
    800011da:	972e                	add	a4,a4,a1
    800011dc:	757d                	lui	a0,0xfffff
    800011de:	8f69                	and	a4,a4,a0
    buddy.free_pages = 0;
    800011e0:	0000a797          	auipc	a5,0xa
    800011e4:	da078793          	addi	a5,a5,-608 # 8000af80 <buddy>
    800011e8:	0a07bc23          	sd	zero,184(a5)
    pages = (struct page_info *)mem_start;
    800011ec:	f3f8                	sd	a4,224(a5)
    buddy.total_pages = ((uint64)mem_end - (uint64)mem_start) / PGSIZE;
    800011ee:	46c5                	li	a3,17
    800011f0:	06ee                	slli	a3,a3,0x1b
    800011f2:	40e68633          	sub	a2,a3,a4
    buddy.memory_start = (void *)PGROUNDUP((uint64)pages + buddy.total_pages * sizeof(struct page_info));
    800011f6:	8225                	srli	a2,a2,0x9
    800011f8:	972e                	add	a4,a4,a1
    800011fa:	9732                	add	a4,a4,a2
    800011fc:	8f69                	and	a4,a4,a0
    800011fe:	e3f8                	sd	a4,192(a5)
    buddy.total_pages = ((uint64)mem_end - (uint64)buddy.memory_start) / PGSIZE;
    80001200:	8e99                	sub	a3,a3,a4
    80001202:	82b1                	srli	a3,a3,0xc
    80001204:	fbd4                	sd	a3,176(a5)
    for (int i = 0; i <= MAX_ORDER; i++)
    80001206:	0000a717          	auipc	a4,0xa
    8000120a:	e2a70713          	addi	a4,a4,-470 # 8000b030 <buddy+0xb0>
        buddy.free_lists[i].next = &buddy.free_lists[i];
    8000120e:	e39c                	sd	a5,0(a5)
        buddy.free_lists[i].prev = &buddy.free_lists[i];
    80001210:	e79c                	sd	a5,8(a5)
    for (int i = 0; i <= MAX_ORDER; i++)
    80001212:	07c1                	addi	a5,a5,16
    80001214:	fee79de3          	bne	a5,a4,8000120e <pmm_init+0x4a>
    initlock(&buddy.lock, "buddy");
    80001218:	0000a497          	auipc	s1,0xa
    8000121c:	d6848493          	addi	s1,s1,-664 # 8000af80 <buddy>
    80001220:	00001597          	auipc	a1,0x1
    80001224:	22858593          	addi	a1,a1,552 # 80002448 <_trampoline+0x448>
    80001228:	0000a517          	auipc	a0,0xa
    8000122c:	e2050513          	addi	a0,a0,-480 # 8000b048 <buddy+0xc8>
    80001230:	00000097          	auipc	ra,0x0
    80001234:	032080e7          	jalr	50(ra) # 80001262 <initlock>
    buddy_add_memory(buddy.memory_start, mem_end);
    80001238:	45c5                	li	a1,17
    8000123a:	05ee                	slli	a1,a1,0x1b
    8000123c:	60e8                	ld	a0,192(s1)
    8000123e:	00000097          	auipc	ra,0x0
    80001242:	ebc080e7          	jalr	-324(ra) # 800010fa <buddy_add_memory>
    printf("Buddy system initialized: %d pages available\n", buddy.total_pages);
    80001246:	78cc                	ld	a1,176(s1)
    80001248:	00001517          	auipc	a0,0x1
    8000124c:	20850513          	addi	a0,a0,520 # 80002450 <_trampoline+0x450>
    80001250:	fffff097          	auipc	ra,0xfffff
    80001254:	480080e7          	jalr	1152(ra) # 800006d0 <printf>
}
    80001258:	60e2                	ld	ra,24(sp)
    8000125a:	6442                	ld	s0,16(sp)
    8000125c:	64a2                	ld	s1,8(sp)
    8000125e:	6105                	addi	sp,sp,32
    80001260:	8082                	ret

0000000080001262 <initlock>:
#include "riscv.h"
// #include "proc.h"
#include "defs.h"

void initlock(struct spinlock *lk, char *name)
{
    80001262:	1141                	addi	sp,sp,-16
    80001264:	e422                	sd	s0,8(sp)
    80001266:	0800                	addi	s0,sp,16
    lk->name = name;
    80001268:	e50c                	sd	a1,8(a0)
    lk->locked = 0;
    8000126a:	00052023          	sw	zero,0(a0)
    lk->cpu = 0;
    8000126e:	00053823          	sd	zero,16(a0)
}
    80001272:	6422                	ld	s0,8(sp)
    80001274:	0141                	addi	sp,sp,16
    80001276:	8082                	ret

0000000080001278 <acquire>:

void acquire(struct spinlock *lk)
{
    80001278:	1141                	addi	sp,sp,-16
    8000127a:	e406                	sd	ra,8(sp)
    8000127c:	e022                	sd	s0,0(sp)
    8000127e:	0800                	addi	s0,sp,16
    printf("lock : %s \n", lk->name);
    80001280:	650c                	ld	a1,8(a0)
    80001282:	00001517          	auipc	a0,0x1
    80001286:	1fe50513          	addi	a0,a0,510 # 80002480 <_trampoline+0x480>
    8000128a:	fffff097          	auipc	ra,0xfffff
    8000128e:	446080e7          	jalr	1094(ra) # 800006d0 <printf>
}
    80001292:	60a2                	ld	ra,8(sp)
    80001294:	6402                	ld	s0,0(sp)
    80001296:	0141                	addi	sp,sp,16
    80001298:	8082                	ret

000000008000129a <release>:
void release(struct spinlock *lk)
{
    8000129a:	1141                	addi	sp,sp,-16
    8000129c:	e406                	sd	ra,8(sp)
    8000129e:	e022                	sd	s0,0(sp)
    800012a0:	0800                	addi	s0,sp,16
    printf("unlock : %s \n", lk->name);
    800012a2:	650c                	ld	a1,8(a0)
    800012a4:	00001517          	auipc	a0,0x1
    800012a8:	1ec50513          	addi	a0,a0,492 # 80002490 <_trampoline+0x490>
    800012ac:	fffff097          	auipc	ra,0xfffff
    800012b0:	424080e7          	jalr	1060(ra) # 800006d0 <printf>
}
    800012b4:	60a2                	ld	ra,8(sp)
    800012b6:	6402                	ld	s0,0(sp)
    800012b8:	0141                	addi	sp,sp,16
    800012ba:	8082                	ret
	...
