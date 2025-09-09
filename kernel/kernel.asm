
kernel/kernel:     file format elf64-littleriscv


Disassembly of section .text:

0000000080000000 <_entry>:
_entry:
    # 为每个 CPU 设置独立的启动栈
    # stack0 在 start.c 中定义，每个 CPU 分配 4KB 栈空间
    # 公式: sp = stack0 + (hartid + 1) * 4096
    
    la sp, stack0           # 加载 stack0 基地址到栈指针
    80000000:	00002117          	auipc	sp,0x2
    80000004:	8f013103          	ld	sp,-1808(sp) # 800018f0 <_GLOBAL_OFFSET_TABLE_+0x10>
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
    80000074:	7ff70713          	addi	a4,a4,2047 # ffffffffffffe7ff <end+0xffffffff7fff4dd3>
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
    80000086:	00002797          	auipc	a5,0x2
    8000008a:	87a7b783          	ld	a5,-1926(a5) # 80001900 <_GLOBAL_OFFSET_TABLE_+0x20>
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
    800000fa:	00001517          	auipc	a0,0x1
    800000fe:	7ee53503          	ld	a0,2030(a0) # 800018e8 <_GLOBAL_OFFSET_TABLE_+0x8>
    80000102:	00001617          	auipc	a2,0x1
    80000106:	7f663603          	ld	a2,2038(a2) # 800018f8 <_GLOBAL_OFFSET_TABLE_+0x18>
    8000010a:	9e09                	subw	a2,a2,a0
    8000010c:	4581                	li	a1,0
    8000010e:	00000097          	auipc	ra,0x0
    80000112:	fc0080e7          	jalr	-64(ra) # 800000ce <memset>

    // 2. 打印启动信息
    uartinit(); // 初始化串口
    80000116:	00000097          	auipc	ra,0x0
    8000011a:	20c080e7          	jalr	524(ra) # 80000322 <uartinit>
    uartputs("riscv-os kernel is starting...\n");
    8000011e:	00001517          	auipc	a0,0x1
    80000122:	ee250513          	addi	a0,a0,-286 # 80001000 <_trampoline>
    80000126:	00000097          	auipc	ra,0x0
    8000012a:	260080e7          	jalr	608(ra) # 80000386 <uartputs>
    8000012e:	f14024f3          	csrr	s1,mhartid

    uint64 hartid = r_mhartid();
    uartputs("hart ID :");
    80000132:	00001517          	auipc	a0,0x1
    80000136:	eee50513          	addi	a0,a0,-274 # 80001020 <_trampoline+0x20>
    8000013a:	00000097          	auipc	ra,0x0
    8000013e:	24c080e7          	jalr	588(ra) # 80000386 <uartputs>
    uartputc('0' + (hartid & 0xf)); // 仅打印最低4位，假设CPU数量不超过16
    80000142:	00f4f513          	andi	a0,s1,15
    80000146:	03050513          	addi	a0,a0,48
    8000014a:	00000097          	auipc	ra,0x0
    8000014e:	214080e7          	jalr	532(ra) # 8000035e <uartputc>
    uartputs(" started\n");
    80000152:	00001517          	auipc	a0,0x1
    80000156:	ede50513          	addi	a0,a0,-290 # 80001030 <_trampoline+0x30>
    8000015a:	00000097          	auipc	ra,0x0
    8000015e:	22c080e7          	jalr	556(ra) # 80000386 <uartputs>
    uartputs("Hart ");
    80000162:	00001517          	auipc	a0,0x1
    80000166:	ede50513          	addi	a0,a0,-290 # 80001040 <_trampoline+0x40>
    8000016a:	00000097          	auipc	ra,0x0
    8000016e:	21c080e7          	jalr	540(ra) # 80000386 <uartputs>
    // 这里可以打印CPU ID，但需要实现数字转字符串函数
    uartputs("started\n");
    80000172:	00001517          	auipc	a0,0x1
    80000176:	ed650513          	addi	a0,a0,-298 # 80001048 <_trampoline+0x48>
    8000017a:	00000097          	auipc	ra,0x0
    8000017e:	20c080e7          	jalr	524(ra) # 80000386 <uartputs>

    // 3. 基础系统初始化
    uartputs("Basic initialization complete\n");
    80000182:	00001517          	auipc	a0,0x1
    80000186:	ed650513          	addi	a0,a0,-298 # 80001058 <_trampoline+0x58>
    8000018a:	00000097          	auipc	ra,0x0
    8000018e:	1fc080e7          	jalr	508(ra) # 80000386 <uartputs>

    // 3. 清屏并显示启动信息
    console_clear();
    80000192:	00000097          	auipc	ra,0x0
    80000196:	7ba080e7          	jalr	1978(ra) # 8000094c <console_clear>
    printf("RISC-V OS Kernel Starting...\n");
    8000019a:	00001517          	auipc	a0,0x1
    8000019e:	ede50513          	addi	a0,a0,-290 # 80001078 <_trampoline+0x78>
    800001a2:	00000097          	auipc	ra,0x0
    800001a6:	546080e7          	jalr	1350(ra) # 800006e8 <printf>
    printf("==============================\n");
    800001aa:	00001517          	auipc	a0,0x1
    800001ae:	eee50513          	addi	a0,a0,-274 # 80001098 <_trampoline+0x98>
    800001b2:	00000097          	auipc	ra,0x0
    800001b6:	536080e7          	jalr	1334(ra) # 800006e8 <printf>

    // 4. 显示系统信息
    // uint64 hartid = r_mhartid();
    printf("Hart ID: %d\n", (int)hartid);
    800001ba:	0004859b          	sext.w	a1,s1
    800001be:	00001517          	auipc	a0,0x1
    800001c2:	efa50513          	addi	a0,a0,-262 # 800010b8 <_trampoline+0xb8>
    800001c6:	00000097          	auipc	ra,0x0
    800001ca:	522080e7          	jalr	1314(ra) # 800006e8 <printf>
    printf("Hart started successfully\n");
    800001ce:	00001517          	auipc	a0,0x1
    800001d2:	efa50513          	addi	a0,a0,-262 # 800010c8 <_trampoline+0xc8>
    800001d6:	00000097          	auipc	ra,0x0
    800001da:	512080e7          	jalr	1298(ra) # 800006e8 <printf>

    // 5. 测试各种 printf 格式
    printf("Testing printf formats:\n");
    800001de:	00001517          	auipc	a0,0x1
    800001e2:	f0a50513          	addi	a0,a0,-246 # 800010e8 <_trampoline+0xe8>
    800001e6:	00000097          	auipc	ra,0x0
    800001ea:	502080e7          	jalr	1282(ra) # 800006e8 <printf>
    printf("Decimal: %d\n", 42);
    800001ee:	02a00593          	li	a1,42
    800001f2:	00001517          	auipc	a0,0x1
    800001f6:	f1650513          	addi	a0,a0,-234 # 80001108 <_trampoline+0x108>
    800001fa:	00000097          	auipc	ra,0x0
    800001fe:	4ee080e7          	jalr	1262(ra) # 800006e8 <printf>
    printf("Hex: 0x%x\n", 255);
    80000202:	0ff00593          	li	a1,255
    80000206:	00001517          	auipc	a0,0x1
    8000020a:	f1250513          	addi	a0,a0,-238 # 80001118 <_trampoline+0x118>
    8000020e:	00000097          	auipc	ra,0x0
    80000212:	4da080e7          	jalr	1242(ra) # 800006e8 <printf>
    printf("Pointer: %p\n", (void *)main);
    80000216:	00000597          	auipc	a1,0x0
    8000021a:	eda58593          	addi	a1,a1,-294 # 800000f0 <main>
    8000021e:	00001517          	auipc	a0,0x1
    80000222:	f0a50513          	addi	a0,a0,-246 # 80001128 <_trampoline+0x128>
    80000226:	00000097          	auipc	ra,0x0
    8000022a:	4c2080e7          	jalr	1218(ra) # 800006e8 <printf>
    printf("String: %s\n", "Hello, World!");
    8000022e:	00001597          	auipc	a1,0x1
    80000232:	f0a58593          	addi	a1,a1,-246 # 80001138 <_trampoline+0x138>
    80000236:	00001517          	auipc	a0,0x1
    8000023a:	f1250513          	addi	a0,a0,-238 # 80001148 <_trampoline+0x148>
    8000023e:	00000097          	auipc	ra,0x0
    80000242:	4aa080e7          	jalr	1194(ra) # 800006e8 <printf>
    printf("Character: %c\n", 'A');
    80000246:	04100593          	li	a1,65
    8000024a:	00001517          	auipc	a0,0x1
    8000024e:	f0e50513          	addi	a0,a0,-242 # 80001158 <_trampoline+0x158>
    80000252:	00000097          	auipc	ra,0x0
    80000256:	496080e7          	jalr	1174(ra) # 800006e8 <printf>

    // 6. 内存dump示例
    printf("\nMemory dump example:\n");
    8000025a:	00001517          	auipc	a0,0x1
    8000025e:	f0e50513          	addi	a0,a0,-242 # 80001168 <_trampoline+0x168>
    80000262:	00000097          	auipc	ra,0x0
    80000266:	486080e7          	jalr	1158(ra) # 800006e8 <printf>
    // char test_data[] = "Hello, RISC-V OS!";
    char *test_data = "Hello, RISC-V OS!";
    printf("test_data declared\n");
    8000026a:	00001517          	auipc	a0,0x1
    8000026e:	f1650513          	addi	a0,a0,-234 # 80001180 <_trampoline+0x180>
    80000272:	00000097          	auipc	ra,0x0
    80000276:	476080e7          	jalr	1142(ra) # 800006e8 <printf>
    printf("test_data address: %p\n", (void *)test_data);
    8000027a:	00001597          	auipc	a1,0x1
    8000027e:	f1e58593          	addi	a1,a1,-226 # 80001198 <_trampoline+0x198>
    80000282:	00001517          	auipc	a0,0x1
    80000286:	f2e50513          	addi	a0,a0,-210 # 800011b0 <_trampoline+0x1b0>
    8000028a:	00000097          	auipc	ra,0x0
    8000028e:	45e080e7          	jalr	1118(ra) # 800006e8 <printf>
    printf("sizeof(test_data): %d\n", (int)sizeof(test_data));
    80000292:	45a1                	li	a1,8
    80000294:	00001517          	auipc	a0,0x1
    80000298:	f3450513          	addi	a0,a0,-204 # 800011c8 <_trampoline+0x1c8>
    8000029c:	00000097          	auipc	ra,0x0
    800002a0:	44c080e7          	jalr	1100(ra) # 800006e8 <printf>

    // hexdump(test_data, sizeof(test_data));

    // 7. 系统状态
    printf("\nSystem Status:\n");
    800002a4:	00001517          	auipc	a0,0x1
    800002a8:	f3c50513          	addi	a0,a0,-196 # 800011e0 <_trampoline+0x1e0>
    800002ac:	00000097          	auipc	ra,0x0
    800002b0:	43c080e7          	jalr	1084(ra) # 800006e8 <printf>
    printf("- UART: OK\n");
    800002b4:	00001517          	auipc	a0,0x1
    800002b8:	f4450513          	addi	a0,a0,-188 # 800011f8 <_trampoline+0x1f8>
    800002bc:	00000097          	auipc	ra,0x0
    800002c0:	42c080e7          	jalr	1068(ra) # 800006e8 <printf>
    printf("- Console: OK\n");
    800002c4:	00001517          	auipc	a0,0x1
    800002c8:	f4450513          	addi	a0,a0,-188 # 80001208 <_trampoline+0x208>
    800002cc:	00000097          	auipc	ra,0x0
    800002d0:	41c080e7          	jalr	1052(ra) # 800006e8 <printf>
    printf("- Printf: OK\n");
    800002d4:	00001517          	auipc	a0,0x1
    800002d8:	f4450513          	addi	a0,a0,-188 # 80001218 <_trampoline+0x218>
    800002dc:	00000097          	auipc	ra,0x0
    800002e0:	40c080e7          	jalr	1036(ra) # 800006e8 <printf>
    console_clear();
    800002e4:	00000097          	auipc	ra,0x0
    800002e8:	668080e7          	jalr	1640(ra) # 8000094c <console_clear>

    printf("\nKernel initialization complete!\n");
    800002ec:	00001517          	auipc	a0,0x1
    800002f0:	f3c50513          	addi	a0,a0,-196 # 80001228 <_trampoline+0x228>
    800002f4:	00000097          	auipc	ra,0x0
    800002f8:	3f4080e7          	jalr	1012(ra) # 800006e8 <printf>
    printf("Entering idle loop...\n");
    800002fc:	00001517          	auipc	a0,0x1
    80000300:	f5450513          	addi	a0,a0,-172 # 80001250 <_trampoline+0x250>
    80000304:	00000097          	auipc	ra,0x0
    80000308:	3e4080e7          	jalr	996(ra) # 800006e8 <printf>

    // 4. 进入无限循环
    // 在后续阶段，这里会被进程调度器替代
    uartputs("Kernel initialization finished, entering idle loop\n");
    8000030c:	00001517          	auipc	a0,0x1
    80000310:	f5c50513          	addi	a0,a0,-164 # 80001268 <_trampoline+0x268>
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
    800003ea:	00001617          	auipc	a2,0x1
    800003ee:	05e60613          	addi	a2,a2,94 # 80001448 <digits>
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
    uartputc(c);
    8000043e:	fff4c503          	lbu	a0,-1(s1)
    80000442:	00000097          	auipc	ra,0x0
    80000446:	f1c080e7          	jalr	-228(ra) # 8000035e <uartputc>
    while (--i >= 0) // 输出缓冲区中的字符
    8000044a:	14fd                	addi	s1,s1,-1
    8000044c:	ff2499e3          	bne	s1,s2,8000043e <printint+0x6e>
    80000450:	64a6                	ld	s1,72(sp)
        consputc(buf[i]);
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

000000008000048e <consputc>:
{
    8000048e:	1141                	addi	sp,sp,-16
    80000490:	e406                	sd	ra,8(sp)
    80000492:	e022                	sd	s0,0(sp)
    80000494:	0800                	addi	s0,sp,16
    uartputc(c);
    80000496:	00000097          	auipc	ra,0x0
    8000049a:	ec8080e7          	jalr	-312(ra) # 8000035e <uartputc>
}
    8000049e:	60a2                	ld	ra,8(sp)
    800004a0:	6402                	ld	s0,0(sp)
    800004a2:	0141                	addi	sp,sp,16
    800004a4:	8082                	ret

00000000800004a6 <panic>:
    va_end(ap);
}

// panic 函数 - 系统致命错误
void panic(char *s)
{
    800004a6:	1101                	addi	sp,sp,-32
    800004a8:	ec06                	sd	ra,24(sp)
    800004aa:	e822                	sd	s0,16(sp)
    800004ac:	e426                	sd	s1,8(sp)
    800004ae:	1000                	addi	s0,sp,32
    800004b0:	84aa                	mv	s1,a0
    // 1. 禁用中断，防止进一步的中断处理
    // intr_off();  // 后续实现中断管理时添加

    // 2. 显示错误信息
    printf("\n");
    800004b2:	00001517          	auipc	a0,0x1
    800004b6:	d9650513          	addi	a0,a0,-618 # 80001248 <_trampoline+0x248>
    800004ba:	00000097          	auipc	ra,0x0
    800004be:	22e080e7          	jalr	558(ra) # 800006e8 <printf>
    printf("================================\n");
    800004c2:	00001517          	auipc	a0,0x1
    800004c6:	dde50513          	addi	a0,a0,-546 # 800012a0 <_trampoline+0x2a0>
    800004ca:	00000097          	auipc	ra,0x0
    800004ce:	21e080e7          	jalr	542(ra) # 800006e8 <printf>
    printf("KERNEL PANIC: %s\n", s);
    800004d2:	85a6                	mv	a1,s1
    800004d4:	00001517          	auipc	a0,0x1
    800004d8:	df450513          	addi	a0,a0,-524 # 800012c8 <_trampoline+0x2c8>
    800004dc:	00000097          	auipc	ra,0x0
    800004e0:	20c080e7          	jalr	524(ra) # 800006e8 <printf>
    printf("================================\n");
    800004e4:	00001517          	auipc	a0,0x1
    800004e8:	dbc50513          	addi	a0,a0,-580 # 800012a0 <_trampoline+0x2a0>
    800004ec:	00000097          	auipc	ra,0x0
    800004f0:	1fc080e7          	jalr	508(ra) # 800006e8 <printf>
    800004f4:	f14025f3          	csrr	a1,mhartid

    // 3. 显示当前状态信息（调试用）
    printf("Hart ID: %d\n", (int)r_mhartid());
    800004f8:	2581                	sext.w	a1,a1
    800004fa:	00001517          	auipc	a0,0x1
    800004fe:	bbe50513          	addi	a0,a0,-1090 # 800010b8 <_trampoline+0xb8>
    80000502:	00000097          	auipc	ra,0x0
    80000506:	1e6080e7          	jalr	486(ra) # 800006e8 <printf>

    // 4. 显示调用栈（高级功能，后续可添加）
    // print_backtrace();

    // 5. 系统完全停止
    printf("System halted. Please reboot.\n");
    8000050a:	00001517          	auipc	a0,0x1
    8000050e:	dd650513          	addi	a0,a0,-554 # 800012e0 <_trampoline+0x2e0>
    80000512:	00000097          	auipc	ra,0x0
    80000516:	1d6080e7          	jalr	470(ra) # 800006e8 <printf>

    // 死循环，等待硬件重启或调试器介入
    for (;;)
    {
        asm volatile("wfi"); // Wait For Interrupt (省电)
    8000051a:	10500073          	wfi
    for (;;)
    8000051e:	bff5                	j	8000051a <panic+0x74>

0000000080000520 <vprintf>:
{
    80000520:	711d                	addi	sp,sp,-96
    80000522:	ec86                	sd	ra,88(sp)
    80000524:	e8a2                	sd	s0,80(sp)
    80000526:	1080                	addi	s0,sp,96
    if (fmt == 0)
    80000528:	cd1d                	beqz	a0,80000566 <vprintf+0x46>
    8000052a:	e4a6                	sd	s1,72(sp)
    8000052c:	e0ca                	sd	s2,64(sp)
    8000052e:	f852                	sd	s4,48(sp)
    80000530:	892a                	mv	s2,a0
    80000532:	8a2e                	mv	s4,a1
    for (i = 0; (c = fmt[i] & 0xff) != 0; i++)
    80000534:	00054503          	lbu	a0,0(a0)
    80000538:	4481                	li	s1,0
    8000053a:	18050863          	beqz	a0,800006ca <vprintf+0x1aa>
    8000053e:	fc4e                	sd	s3,56(sp)
    80000540:	f456                	sd	s5,40(sp)
    80000542:	f05a                	sd	s6,32(sp)
    80000544:	ec5e                	sd	s7,24(sp)
    80000546:	e862                	sd	s8,16(sp)
    80000548:	e466                	sd	s9,8(sp)
    8000054a:	e06a                	sd	s10,0(sp)
        if (c != '%') // 非占位符，说明为普通字符串，直接打印
    8000054c:	02500993          	li	s3,37
        switch (c)
    80000550:	4b55                	li	s6,21
    80000552:	00001c17          	auipc	s8,0x1
    80000556:	e9ec0c13          	addi	s8,s8,-354 # 800013f0 <_trampoline+0x3f0>
    uartputc(c);
    8000055a:	4cc1                	li	s9,16
        consputc(digits[x >> (sizeof(uint64) * 8 - 4)]);
    8000055c:	00001a97          	auipc	s5,0x1
    80000560:	eeca8a93          	addi	s5,s5,-276 # 80001448 <digits>
    80000564:	a835                	j	800005a0 <vprintf+0x80>
    80000566:	e4a6                	sd	s1,72(sp)
    80000568:	e0ca                	sd	s2,64(sp)
    8000056a:	fc4e                	sd	s3,56(sp)
    8000056c:	f852                	sd	s4,48(sp)
    8000056e:	f456                	sd	s5,40(sp)
    80000570:	f05a                	sd	s6,32(sp)
    80000572:	ec5e                	sd	s7,24(sp)
    80000574:	e862                	sd	s8,16(sp)
    80000576:	e466                	sd	s9,8(sp)
    80000578:	e06a                	sd	s10,0(sp)
        panic("null fmt");
    8000057a:	00001517          	auipc	a0,0x1
    8000057e:	d8e50513          	addi	a0,a0,-626 # 80001308 <_trampoline+0x308>
    80000582:	00000097          	auipc	ra,0x0
    80000586:	f24080e7          	jalr	-220(ra) # 800004a6 <panic>
    uartputc(c);
    8000058a:	00000097          	auipc	ra,0x0
    8000058e:	dd4080e7          	jalr	-556(ra) # 8000035e <uartputc>
    for (i = 0; (c = fmt[i] & 0xff) != 0; i++)
    80000592:	2485                	addiw	s1,s1,1
    80000594:	009907b3          	add	a5,s2,s1
    80000598:	0007c503          	lbu	a0,0(a5)
    8000059c:	12050063          	beqz	a0,800006bc <vprintf+0x19c>
        if (c != '%') // 非占位符，说明为普通字符串，直接打印
    800005a0:	ff3515e3          	bne	a0,s3,8000058a <vprintf+0x6a>
        c = fmt[++i] & 0xff; // 读取到 % 符号时需要向下读取一个符号来判断占位符的类型
    800005a4:	2485                	addiw	s1,s1,1
    800005a6:	009907b3          	add	a5,s2,s1
    800005aa:	0007c783          	lbu	a5,0(a5)
    800005ae:	00078b9b          	sext.w	s7,a5
        if (c == 0)
    800005b2:	12078363          	beqz	a5,800006d8 <vprintf+0x1b8>
        switch (c)
    800005b6:	0f378063          	beq	a5,s3,80000696 <vprintf+0x176>
    800005ba:	f9d7871b          	addiw	a4,a5,-99
    800005be:	0ff77713          	zext.b	a4,a4
    800005c2:	0eeb6063          	bltu	s6,a4,800006a2 <vprintf+0x182>
    800005c6:	f9d7879b          	addiw	a5,a5,-99
    800005ca:	0ff7f713          	zext.b	a4,a5
    800005ce:	0ceb6a63          	bltu	s6,a4,800006a2 <vprintf+0x182>
    800005d2:	00271793          	slli	a5,a4,0x2
    800005d6:	97e2                	add	a5,a5,s8
    800005d8:	439c                	lw	a5,0(a5)
    800005da:	97e2                	add	a5,a5,s8
    800005dc:	8782                	jr	a5
            printint(va_arg(ap, int), 10, 1); // va_arg 获取下一个参数
    800005de:	008a0b93          	addi	s7,s4,8
    800005e2:	4605                	li	a2,1
    800005e4:	45a9                	li	a1,10
    800005e6:	000a2503          	lw	a0,0(s4)
    800005ea:	00000097          	auipc	ra,0x0
    800005ee:	de6080e7          	jalr	-538(ra) # 800003d0 <printint>
    800005f2:	8a5e                	mv	s4,s7
            break;
    800005f4:	bf79                	j	80000592 <vprintf+0x72>
            printint(va_arg(ap, int), 16, 1);
    800005f6:	008a0b93          	addi	s7,s4,8
    800005fa:	4605                	li	a2,1
    800005fc:	85e6                	mv	a1,s9
    800005fe:	000a2503          	lw	a0,0(s4)
    80000602:	00000097          	auipc	ra,0x0
    80000606:	dce080e7          	jalr	-562(ra) # 800003d0 <printint>
    8000060a:	8a5e                	mv	s4,s7
            break;
    8000060c:	b759                	j	80000592 <vprintf+0x72>
            printptr(va_arg(ap, uint64));
    8000060e:	008a0b93          	addi	s7,s4,8
    80000612:	000a3d03          	ld	s10,0(s4)
    uartputc(c);
    80000616:	03000513          	li	a0,48
    8000061a:	00000097          	auipc	ra,0x0
    8000061e:	d44080e7          	jalr	-700(ra) # 8000035e <uartputc>
    80000622:	07800513          	li	a0,120
    80000626:	00000097          	auipc	ra,0x0
    8000062a:	d38080e7          	jalr	-712(ra) # 8000035e <uartputc>
    8000062e:	8a66                	mv	s4,s9
        consputc(digits[x >> (sizeof(uint64) * 8 - 4)]);
    80000630:	03cd5793          	srli	a5,s10,0x3c
    80000634:	97d6                	add	a5,a5,s5
    uartputc(c);
    80000636:	0007c503          	lbu	a0,0(a5)
    8000063a:	00000097          	auipc	ra,0x0
    8000063e:	d24080e7          	jalr	-732(ra) # 8000035e <uartputc>
    for (i = 0; i < (sizeof(uint64) * 2); i++, x <<= 4)
    80000642:	0d12                	slli	s10,s10,0x4
    80000644:	3a7d                	addiw	s4,s4,-1
    80000646:	fe0a15e3          	bnez	s4,80000630 <vprintf+0x110>
            printptr(va_arg(ap, uint64));
    8000064a:	8a5e                	mv	s4,s7
    8000064c:	b799                	j	80000592 <vprintf+0x72>
            if ((s = va_arg(ap, char *)) == 0)
    8000064e:	008a0b93          	addi	s7,s4,8
    80000652:	000a3a03          	ld	s4,0(s4)
    80000656:	000a0f63          	beqz	s4,80000674 <vprintf+0x154>
            for (; *s; s++)
    8000065a:	000a4503          	lbu	a0,0(s4)
    8000065e:	cd29                	beqz	a0,800006b8 <vprintf+0x198>
    uartputc(c);
    80000660:	00000097          	auipc	ra,0x0
    80000664:	cfe080e7          	jalr	-770(ra) # 8000035e <uartputc>
            for (; *s; s++)
    80000668:	0a05                	addi	s4,s4,1
    8000066a:	000a4503          	lbu	a0,0(s4)
    8000066e:	f96d                	bnez	a0,80000660 <vprintf+0x140>
            if ((s = va_arg(ap, char *)) == 0)
    80000670:	8a5e                	mv	s4,s7
    80000672:	b705                	j	80000592 <vprintf+0x72>
                s = "(null)";
    80000674:	00001a17          	auipc	s4,0x1
    80000678:	c8ca0a13          	addi	s4,s4,-884 # 80001300 <_trampoline+0x300>
            for (; *s; s++)
    8000067c:	02800513          	li	a0,40
    80000680:	b7c5                	j	80000660 <vprintf+0x140>
            consputc(va_arg(ap, uint));
    80000682:	008a0b93          	addi	s7,s4,8
    uartputc(c);
    80000686:	000a2503          	lw	a0,0(s4)
    8000068a:	00000097          	auipc	ra,0x0
    8000068e:	cd4080e7          	jalr	-812(ra) # 8000035e <uartputc>
            consputc(va_arg(ap, uint));
    80000692:	8a5e                	mv	s4,s7
}
    80000694:	bdfd                	j	80000592 <vprintf+0x72>
    uartputc(c);
    80000696:	854e                	mv	a0,s3
    80000698:	00000097          	auipc	ra,0x0
    8000069c:	cc6080e7          	jalr	-826(ra) # 8000035e <uartputc>
}
    800006a0:	bdcd                	j	80000592 <vprintf+0x72>
    uartputc(c);
    800006a2:	854e                	mv	a0,s3
    800006a4:	00000097          	auipc	ra,0x0
    800006a8:	cba080e7          	jalr	-838(ra) # 8000035e <uartputc>
    800006ac:	855e                	mv	a0,s7
    800006ae:	00000097          	auipc	ra,0x0
    800006b2:	cb0080e7          	jalr	-848(ra) # 8000035e <uartputc>
}
    800006b6:	bdf1                	j	80000592 <vprintf+0x72>
            if ((s = va_arg(ap, char *)) == 0)
    800006b8:	8a5e                	mv	s4,s7
    800006ba:	bde1                	j	80000592 <vprintf+0x72>
    800006bc:	79e2                	ld	s3,56(sp)
    800006be:	7aa2                	ld	s5,40(sp)
    800006c0:	7b02                	ld	s6,32(sp)
    800006c2:	6be2                	ld	s7,24(sp)
    800006c4:	6c42                	ld	s8,16(sp)
    800006c6:	6ca2                	ld	s9,8(sp)
    800006c8:	6d02                	ld	s10,0(sp)
    800006ca:	64a6                	ld	s1,72(sp)
    800006cc:	6906                	ld	s2,64(sp)
    800006ce:	7a42                	ld	s4,48(sp)
}
    800006d0:	60e6                	ld	ra,88(sp)
    800006d2:	6446                	ld	s0,80(sp)
    800006d4:	6125                	addi	sp,sp,96
    800006d6:	8082                	ret
    800006d8:	79e2                	ld	s3,56(sp)
    800006da:	7aa2                	ld	s5,40(sp)
    800006dc:	7b02                	ld	s6,32(sp)
    800006de:	6be2                	ld	s7,24(sp)
    800006e0:	6c42                	ld	s8,16(sp)
    800006e2:	6ca2                	ld	s9,8(sp)
    800006e4:	6d02                	ld	s10,0(sp)
    800006e6:	b7d5                	j	800006ca <vprintf+0x1aa>

00000000800006e8 <printf>:
{
    800006e8:	711d                	addi	sp,sp,-96
    800006ea:	ec06                	sd	ra,24(sp)
    800006ec:	e822                	sd	s0,16(sp)
    800006ee:	1000                	addi	s0,sp,32
    800006f0:	e40c                	sd	a1,8(s0)
    800006f2:	e810                	sd	a2,16(s0)
    800006f4:	ec14                	sd	a3,24(s0)
    800006f6:	f018                	sd	a4,32(s0)
    800006f8:	f41c                	sd	a5,40(s0)
    800006fa:	03043823          	sd	a6,48(s0)
    800006fe:	03143c23          	sd	a7,56(s0)
    va_start(ap, fmt); // 表示从 fmt 参数之后开始读取参数
    80000702:	00840593          	addi	a1,s0,8
    80000706:	feb43423          	sd	a1,-24(s0)
    vprintf(fmt, ap);
    8000070a:	00000097          	auipc	ra,0x0
    8000070e:	e16080e7          	jalr	-490(ra) # 80000520 <vprintf>
}
    80000712:	60e2                	ld	ra,24(sp)
    80000714:	6442                	ld	s0,16(sp)
    80000716:	6125                	addi	sp,sp,96
    80000718:	8082                	ret

000000008000071a <printbin>:

// 添加更多 printf 功能

// 打印二进制数
void printbin(uint64 x)
{
    8000071a:	1101                	addi	sp,sp,-32
    8000071c:	ec06                	sd	ra,24(sp)
    8000071e:	e822                	sd	s0,16(sp)
    80000720:	e426                	sd	s1,8(sp)
    80000722:	e04a                	sd	s2,0(sp)
    80000724:	1000                	addi	s0,sp,32
    80000726:	892a                	mv	s2,a0
    uartputc(c);
    80000728:	03000513          	li	a0,48
    8000072c:	00000097          	auipc	ra,0x0
    80000730:	c32080e7          	jalr	-974(ra) # 8000035e <uartputc>
    80000734:	06200513          	li	a0,98
    80000738:	00000097          	auipc	ra,0x0
    8000073c:	c26080e7          	jalr	-986(ra) # 8000035e <uartputc>
    consputc('0');
    consputc('b');
    for (int i = 63; i >= 0; i--)
    80000740:	03f00493          	li	s1,63
    80000744:	a801                	j	80000754 <printbin+0x3a>
    uartputc(c);
    80000746:	05f00513          	li	a0,95
    8000074a:	00000097          	auipc	ra,0x0
    8000074e:	c14080e7          	jalr	-1004(ra) # 8000035e <uartputc>
    for (int i = 63; i >= 0; i--)
    80000752:	34fd                	addiw	s1,s1,-1
    {
        consputc((x & (1UL << i)) ? '1' : '0'); // x & (1UL << i) 检查第 i 位是否为1
    80000754:	00995533          	srl	a0,s2,s1
    80000758:	8905                	andi	a0,a0,1
    uartputc(c);
    8000075a:	03050513          	addi	a0,a0,48
    8000075e:	00000097          	auipc	ra,0x0
    80000762:	c00080e7          	jalr	-1024(ra) # 8000035e <uartputc>
        if (i % 4 == 0 && i != 0)
    80000766:	0034f793          	andi	a5,s1,3
    8000076a:	f7e5                	bnez	a5,80000752 <printbin+0x38>
    8000076c:	fce9                	bnez	s1,80000746 <printbin+0x2c>
            consputc('_'); // 分隔符
    }
}
    8000076e:	60e2                	ld	ra,24(sp)
    80000770:	6442                	ld	s0,16(sp)
    80000772:	64a2                	ld	s1,8(sp)
    80000774:	6902                	ld	s2,0(sp)
    80000776:	6105                	addi	sp,sp,32
    80000778:	8082                	ret

000000008000077a <hexdump>:

// 格式化输出内存内容（十六进制dump）
void hexdump(void *addr, int len)
{
    8000077a:	7119                	addi	sp,sp,-128
    8000077c:	fc86                	sd	ra,120(sp)
    8000077e:	f8a2                	sd	s0,112(sp)
    80000780:	f4a6                	sd	s1,104(sp)
    80000782:	f0ca                	sd	s2,96(sp)
    80000784:	0100                	addi	s0,sp,128
    80000786:	892a                	mv	s2,a0
    80000788:	84ae                	mv	s1,a1
    8000078a:	f8b43423          	sd	a1,-120(s0)
    printf("About to call hexdump...\n");
    8000078e:	00001517          	auipc	a0,0x1
    80000792:	b8a50513          	addi	a0,a0,-1142 # 80001318 <_trampoline+0x318>
    80000796:	00000097          	auipc	ra,0x0
    8000079a:	f52080e7          	jalr	-174(ra) # 800006e8 <printf>
    unsigned char *p = (unsigned char *)addr;

    printf("hexdump函数转换后的无符号地址为 : %p\n", p);
    8000079e:	85ca                	mv	a1,s2
    800007a0:	00001517          	auipc	a0,0x1
    800007a4:	b9850513          	addi	a0,a0,-1128 # 80001338 <_trampoline+0x338>
    800007a8:	00000097          	auipc	ra,0x0
    800007ac:	f40080e7          	jalr	-192(ra) # 800006e8 <printf>

    printf("Memory dump at %p:\n", addr);
    800007b0:	85ca                	mv	a1,s2
    800007b2:	00001517          	auipc	a0,0x1
    800007b6:	bbe50513          	addi	a0,a0,-1090 # 80001370 <_trampoline+0x370>
    800007ba:	00000097          	auipc	ra,0x0
    800007be:	f2e080e7          	jalr	-210(ra) # 800006e8 <printf>
    for (int i = 0; i < len; i += 16)
    800007c2:	08905463          	blez	s1,8000084a <hexdump+0xd0>
    800007c6:	ecce                	sd	s3,88(sp)
    800007c8:	e8d2                	sd	s4,80(sp)
    800007ca:	e4d6                	sd	s5,72(sp)
    800007cc:	e0da                	sd	s6,64(sp)
    800007ce:	fc5e                	sd	s7,56(sp)
    800007d0:	f862                	sd	s8,48(sp)
    800007d2:	f466                	sd	s9,40(sp)
    800007d4:	f06a                	sd	s10,32(sp)
    800007d6:	ec6e                	sd	s11,24(sp)
    800007d8:	8c4a                	mv	s8,s2
    800007da:	00048d1b          	sext.w	s10,s1
    800007de:	093d                	addi	s2,s2,15
    800007e0:	fff4879b          	addiw	a5,s1,-1
    800007e4:	9bc1                	andi	a5,a5,-16
    800007e6:	27c1                	addiw	a5,a5,16
    800007e8:	f8f43023          	sd	a5,-128(s0)
    800007ec:	4c81                	li	s9,0
        // 打印ASCII字符
        printf(" |");
        for (int j = 0; j < 16 && i + j < len; j++)
        {
            char c = p[i + j];
            printf("%c", (c >= 32 && c <= 126) ? c : '.');
    800007ee:	05e00b93          	li	s7,94
    800007f2:	00001b17          	auipc	s6,0x1
    800007f6:	bb6b0b13          	addi	s6,s6,-1098 # 800013a8 <_trampoline+0x3a8>
            printf("   ");
    800007fa:	00001a17          	auipc	s4,0x1
    800007fe:	b9ea0a13          	addi	s4,s4,-1122 # 80001398 <_trampoline+0x398>
        for (int j = len - i; j < 16; j++)
    80000802:	49c1                	li	s3,16
            printf("%02x ", p[i + j]);
    80000804:	00001a97          	auipc	s5,0x1
    80000808:	b8ca8a93          	addi	s5,s5,-1140 # 80001390 <_trampoline+0x390>
    8000080c:	a051                	j	80000890 <hexdump+0x116>
            printf("%c", (c >= 32 && c <= 126) ? c : '.');
    8000080e:	855a                	mv	a0,s6
    80000810:	00000097          	auipc	ra,0x0
    80000814:	ed8080e7          	jalr	-296(ra) # 800006e8 <printf>
        for (int j = 0; j < 16 && i + j < len; j++)
    80000818:	05248c63          	beq	s1,s2,80000870 <hexdump+0xf6>
    8000081c:	0485                	addi	s1,s1,1
    8000081e:	05b48963          	beq	s1,s11,80000870 <hexdump+0xf6>
            char c = p[i + j];
    80000822:	0004c583          	lbu	a1,0(s1)
            printf("%c", (c >= 32 && c <= 126) ? c : '.');
    80000826:	fe05879b          	addiw	a5,a1,-32
    8000082a:	0ff7f793          	zext.b	a5,a5
    8000082e:	fefbf0e3          	bgeu	s7,a5,8000080e <hexdump+0x94>
    80000832:	02e00593          	li	a1,46
    80000836:	bfe1                	j	8000080e <hexdump+0x94>
    80000838:	69e6                	ld	s3,88(sp)
    8000083a:	6a46                	ld	s4,80(sp)
    8000083c:	6aa6                	ld	s5,72(sp)
    8000083e:	6b06                	ld	s6,64(sp)
    80000840:	7be2                	ld	s7,56(sp)
    80000842:	7c42                	ld	s8,48(sp)
    80000844:	7ca2                	ld	s9,40(sp)
    80000846:	7d02                	ld	s10,32(sp)
    80000848:	6de2                	ld	s11,24(sp)
        }
        printf("|\n");
    }
    8000084a:	70e6                	ld	ra,120(sp)
    8000084c:	7446                	ld	s0,112(sp)
    8000084e:	74a6                	ld	s1,104(sp)
    80000850:	7906                	ld	s2,96(sp)
    80000852:	6109                	addi	sp,sp,128
    80000854:	8082                	ret
        for (int j = len - i; j < 16; j++)
    80000856:	000d049b          	sext.w	s1,s10
    8000085a:	47bd                	li	a5,15
    8000085c:	0697de63          	bge	a5,s1,800008d8 <hexdump+0x15e>
        printf(" |");
    80000860:	00001517          	auipc	a0,0x1
    80000864:	b4050513          	addi	a0,a0,-1216 # 800013a0 <_trampoline+0x3a0>
    80000868:	00000097          	auipc	ra,0x0
    8000086c:	e80080e7          	jalr	-384(ra) # 800006e8 <printf>
        printf("|\n");
    80000870:	00001517          	auipc	a0,0x1
    80000874:	b4050513          	addi	a0,a0,-1216 # 800013b0 <_trampoline+0x3b0>
    80000878:	00000097          	auipc	ra,0x0
    8000087c:	e70080e7          	jalr	-400(ra) # 800006e8 <printf>
    for (int i = 0; i < len; i += 16)
    80000880:	2cc1                	addiw	s9,s9,16
    80000882:	0c41                	addi	s8,s8,16
    80000884:	3d41                	addiw	s10,s10,-16
    80000886:	0941                	addi	s2,s2,16
    80000888:	f8043783          	ld	a5,-128(s0)
    8000088c:	fafc86e3          	beq	s9,a5,80000838 <hexdump+0xbe>
        printf("%p: ", (void *)(p + i));
    80000890:	85e2                	mv	a1,s8
    80000892:	00001517          	auipc	a0,0x1
    80000896:	af650513          	addi	a0,a0,-1290 # 80001388 <_trampoline+0x388>
    8000089a:	00000097          	auipc	ra,0x0
    8000089e:	e4e080e7          	jalr	-434(ra) # 800006e8 <printf>
        for (int j = 0; j < 16 && i + j < len; j++)
    800008a2:	f8843783          	ld	a5,-120(s0)
    800008a6:	fafcd8e3          	bge	s9,a5,80000856 <hexdump+0xdc>
    800008aa:	020d1d93          	slli	s11,s10,0x20
    800008ae:	020ddd93          	srli	s11,s11,0x20
    800008b2:	9de2                	add	s11,s11,s8
    800008b4:	84e2                	mv	s1,s8
            printf("%02x ", p[i + j]);
    800008b6:	0004c583          	lbu	a1,0(s1)
    800008ba:	8556                	mv	a0,s5
    800008bc:	00000097          	auipc	ra,0x0
    800008c0:	e2c080e7          	jalr	-468(ra) # 800006e8 <printf>
        for (int j = 0; j < 16 && i + j < len; j++)
    800008c4:	01248563          	beq	s1,s2,800008ce <hexdump+0x154>
    800008c8:	0485                	addi	s1,s1,1
    800008ca:	ffb496e3          	bne	s1,s11,800008b6 <hexdump+0x13c>
        for (int j = len - i; j < 16; j++)
    800008ce:	000d049b          	sext.w	s1,s10
    800008d2:	47bd                	li	a5,15
    800008d4:	0297cd63          	blt	a5,s1,8000090e <hexdump+0x194>
            printf("   ");
    800008d8:	8552                	mv	a0,s4
    800008da:	00000097          	auipc	ra,0x0
    800008de:	e0e080e7          	jalr	-498(ra) # 800006e8 <printf>
        for (int j = len - i; j < 16; j++)
    800008e2:	2485                	addiw	s1,s1,1
    800008e4:	ff349ae3          	bne	s1,s3,800008d8 <hexdump+0x15e>
        printf(" |");
    800008e8:	00001517          	auipc	a0,0x1
    800008ec:	ab850513          	addi	a0,a0,-1352 # 800013a0 <_trampoline+0x3a0>
    800008f0:	00000097          	auipc	ra,0x0
    800008f4:	df8080e7          	jalr	-520(ra) # 800006e8 <printf>
        for (int j = 0; j < 16 && i + j < len; j++)
    800008f8:	f8843783          	ld	a5,-120(s0)
    800008fc:	f6fcdae3          	bge	s9,a5,80000870 <hexdump+0xf6>
    80000900:	020d1d93          	slli	s11,s10,0x20
    80000904:	020ddd93          	srli	s11,s11,0x20
    80000908:	9de2                	add	s11,s11,s8
        for (int j = 0; j < 16 && i + j < len; j++)
    8000090a:	84e2                	mv	s1,s8
    8000090c:	bf19                	j	80000822 <hexdump+0xa8>
        printf(" |");
    8000090e:	00001517          	auipc	a0,0x1
    80000912:	a9250513          	addi	a0,a0,-1390 # 800013a0 <_trampoline+0x3a0>
    80000916:	00000097          	auipc	ra,0x0
    8000091a:	dd2080e7          	jalr	-558(ra) # 800006e8 <printf>
        for (int j = 0; j < 16 && i + j < len; j++)
    8000091e:	b7cd                	j	80000900 <hexdump+0x186>

0000000080000920 <consoleinit>:
    uint e; // 编辑位置
} console;

// 控制台初始化
void consoleinit(void)
{
    80000920:	1141                	addi	sp,sp,-16
    80000922:	e406                	sd	ra,8(sp)
    80000924:	e022                	sd	s0,0(sp)
    80000926:	0800                	addi	s0,sp,16
    // 初始化 UART
    extern void uartinit(void);
    uartinit();
    80000928:	00000097          	auipc	ra,0x0
    8000092c:	9fa080e7          	jalr	-1542(ra) # 80000322 <uartinit>

    // 清空控制台缓冲区
    console.r = console.w = console.e = 0;
    80000930:	00009797          	auipc	a5,0x9
    80000934:	ff078793          	addi	a5,a5,-16 # 80009920 <console>
    80000938:	1007a423          	sw	zero,264(a5)
    8000093c:	1007a223          	sw	zero,260(a5)
    80000940:	1007a023          	sw	zero,256(a5)
}
    80000944:	60a2                	ld	ra,8(sp)
    80000946:	6402                	ld	s0,0(sp)
    80000948:	0141                	addi	sp,sp,16
    8000094a:	8082                	ret

000000008000094c <console_clear>:

// 清屏功能
void console_clear(void)
{
    8000094c:	1141                	addi	sp,sp,-16
    8000094e:	e406                	sd	ra,8(sp)
    80000950:	e022                	sd	s0,0(sp)
    80000952:	0800                	addi	s0,sp,16
    // 发送 ANSI 清屏序列
    printf("\033[2J"); // 清屏
    80000954:	00001517          	auipc	a0,0x1
    80000958:	a6450513          	addi	a0,a0,-1436 # 800013b8 <_trampoline+0x3b8>
    8000095c:	00000097          	auipc	ra,0x0
    80000960:	d8c080e7          	jalr	-628(ra) # 800006e8 <printf>
    printf("\033[H");  // 光标回到左上角
    80000964:	00001517          	auipc	a0,0x1
    80000968:	a5c50513          	addi	a0,a0,-1444 # 800013c0 <_trampoline+0x3c0>
    8000096c:	00000097          	auipc	ra,0x0
    80000970:	d7c080e7          	jalr	-644(ra) # 800006e8 <printf>
}
    80000974:	60a2                	ld	ra,8(sp)
    80000976:	6402                	ld	s0,0(sp)
    80000978:	0141                	addi	sp,sp,16
    8000097a:	8082                	ret

000000008000097c <console_set_cursor>:

// 设置光标位置
void console_set_cursor(int row, int col)
{
    8000097c:	1141                	addi	sp,sp,-16
    8000097e:	e406                	sd	ra,8(sp)
    80000980:	e022                	sd	s0,0(sp)
    80000982:	0800                	addi	s0,sp,16
    80000984:	862e                	mv	a2,a1
    printf("\033[%d;%dH", row, col);
    80000986:	85aa                	mv	a1,a0
    80000988:	00001517          	auipc	a0,0x1
    8000098c:	a4050513          	addi	a0,a0,-1472 # 800013c8 <_trampoline+0x3c8>
    80000990:	00000097          	auipc	ra,0x0
    80000994:	d58080e7          	jalr	-680(ra) # 800006e8 <printf>
}
    80000998:	60a2                	ld	ra,8(sp)
    8000099a:	6402                	ld	s0,0(sp)
    8000099c:	0141                	addi	sp,sp,16
    8000099e:	8082                	ret

00000000800009a0 <console_set_color>:

// 设置文本颜色
void console_set_color(int fg_color, int bg_color)
{
    800009a0:	1141                	addi	sp,sp,-16
    800009a2:	e406                	sd	ra,8(sp)
    800009a4:	e022                	sd	s0,0(sp)
    800009a6:	0800                	addi	s0,sp,16
    printf("\033[%d;%dm", 30 + fg_color, 40 + bg_color);
    800009a8:	0285861b          	addiw	a2,a1,40
    800009ac:	01e5059b          	addiw	a1,a0,30
    800009b0:	00001517          	auipc	a0,0x1
    800009b4:	a2850513          	addi	a0,a0,-1496 # 800013d8 <_trampoline+0x3d8>
    800009b8:	00000097          	auipc	ra,0x0
    800009bc:	d30080e7          	jalr	-720(ra) # 800006e8 <printf>
}
    800009c0:	60a2                	ld	ra,8(sp)
    800009c2:	6402                	ld	s0,0(sp)
    800009c4:	0141                	addi	sp,sp,16
    800009c6:	8082                	ret

00000000800009c8 <console_reset_color>:

// 重置文本格式
void console_reset_color(void)
{
    800009c8:	1141                	addi	sp,sp,-16
    800009ca:	e406                	sd	ra,8(sp)
    800009cc:	e022                	sd	s0,0(sp)
    800009ce:	0800                	addi	s0,sp,16
    printf("\033[0m");
    800009d0:	00001517          	auipc	a0,0x1
    800009d4:	a1850513          	addi	a0,a0,-1512 # 800013e8 <_trampoline+0x3e8>
    800009d8:	00000097          	auipc	ra,0x0
    800009dc:	d10080e7          	jalr	-752(ra) # 800006e8 <printf>
}
    800009e0:	60a2                	ld	ra,8(sp)
    800009e2:	6402                	ld	s0,0(sp)
    800009e4:	0141                	addi	sp,sp,16
    800009e6:	8082                	ret

00000000800009e8 <consolewrite>:

// 控制台写入函数
int consolewrite(int user_src, uint64 src, int n)
{
    800009e8:	7179                	addi	sp,sp,-48
    800009ea:	f406                	sd	ra,40(sp)
    800009ec:	f022                	sd	s0,32(sp)
    800009ee:	e052                	sd	s4,0(sp)
    800009f0:	1800                	addi	s0,sp,48
    800009f2:	8a32                	mv	s4,a2
    int i;

    // 简化版：直接输出字符
    for (i = 0; i < n; i++)
    800009f4:	02c05b63          	blez	a2,80000a2a <consolewrite+0x42>
    800009f8:	ec26                	sd	s1,24(sp)
    800009fa:	e84a                	sd	s2,16(sp)
    800009fc:	e44e                	sd	s3,8(sp)
    800009fe:	892a                	mv	s2,a0
    80000a00:	84ae                	mv	s1,a1
    80000a02:	00b609b3          	add	s3,a2,a1
    80000a06:	a811                	j	80000a1a <consolewrite+0x32>
            c = ((char *)src)[i];
        }
        else
        {
            // 从内核空间读取
            c = ((char *)src)[i];
    80000a08:	0004c503          	lbu	a0,0(s1)
        }
        consputc(c);
    80000a0c:	00000097          	auipc	ra,0x0
    80000a10:	a82080e7          	jalr	-1406(ra) # 8000048e <consputc>
    for (i = 0; i < n; i++)
    80000a14:	0485                	addi	s1,s1,1
    80000a16:	01348763          	beq	s1,s3,80000a24 <consolewrite+0x3c>
        if (user_src)
    80000a1a:	fe0907e3          	beqz	s2,80000a08 <consolewrite+0x20>
            c = ((char *)src)[i];
    80000a1e:	0004c503          	lbu	a0,0(s1)
    80000a22:	b7ed                	j	80000a0c <consolewrite+0x24>
    80000a24:	64e2                	ld	s1,24(sp)
    80000a26:	6942                	ld	s2,16(sp)
    80000a28:	69a2                	ld	s3,8(sp)
    }

    return n;
}
    80000a2a:	8552                	mv	a0,s4
    80000a2c:	70a2                	ld	ra,40(sp)
    80000a2e:	7402                	ld	s0,32(sp)
    80000a30:	6a02                	ld	s4,0(sp)
    80000a32:	6145                	addi	sp,sp,48
    80000a34:	8082                	ret

0000000080000a36 <consoleread>:

// 控制台读取函数
int consoleread(int user_dst, uint64 dst, int n)
{
    80000a36:	1141                	addi	sp,sp,-16
    80000a38:	e422                	sd	s0,8(sp)
    80000a3a:	0800                	addi	s0,sp,16
    // TODO: 实现键盘输入读取
    // 这需要中断处理和键盘驱动
    return 0;
    80000a3c:	4501                	li	a0,0
    80000a3e:	6422                	ld	s0,8(sp)
    80000a40:	0141                	addi	sp,sp,16
    80000a42:	8082                	ret
	...
