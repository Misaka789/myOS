#include "riscv.h"
#include "defs.h"
#include "types.h"

void print_scause()
{
    uint64 scause = r_scause();
    printf("scause=%p\n", scause);
}