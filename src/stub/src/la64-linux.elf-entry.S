#include "arch/la64/macros.S"
#include "arch/la64/regs.h"
NBPW= 8

__NR_memfd_create = 279
__NR_ftruncate    = 46
__NR_exit         = 93
__NR_mprotect     = 226
__NR_mmap         = 222
__NR_msync        = 227
__NR_close        = 57
__NR_open         = 56
__NR_write        = 64

sz_Ehdr= 64
e_phnum= 56
sz_Phdr= 56

sz_l_info= 12
  l_lsize= 8

sz_p_info= 12

sz_b_info= 12
  sz_unc= 0
  sz_cpr= 4
  b_method= 8

AT_PAGESZ= 6

PROT_READ=  1
PROT_WRITE= 2
PROT_EXEC=  4

MAP_SHARED=  1
MAP_PRIVATE= 2
MAP_FIXED=     0x10
MAP_ANONYMOUS= 0x20

MFD_EXEC= 0x0010

SYS_mmap= 222

FD_stderr= 2

M_NRV2B_LE32=2
M_NRV2D_LE32=5
M_NRV2E_LE32=8



section ELFMAINX
sz_pack2= .-4

_start: .global _start

    ld.d    $t0, $sp, 0
    addi.d  $sp, $sp, 8  // argc

    mov     $t1, $sp  //argv

    addi.d  $sp, $sp, -8
    st.d    $t0, $sp, 0  //argc

    addi.d  $sp, $sp, -8
    st.d    $a2, $sp, 0  //a2对应rdx?

#define old_sp r22
F_FRAME= 7*NBPW
F_ENTR= 6*NBPW; F_PMASK= F_ENTR
F_RDX=  5*NBPW
F_LENU= 4*NBPW
F_ADRU= 3*NBPW
F_ELFA= 2*NBPW
F_LENX= 1*NBPW
F_ADRX= 0*NBPW

D_FOLD=  1*NBPW  // .data space at start of unfold
D_PMASK= 0*NBPW

//find auxv
    addi.d    $t2, $zero, 0  //0
1:
    ld.d      $t3, $t1, 0
    addi.d    $t1, $t1, 8
    bne       $t3, $t2, 1b  //skip argv
1:
    ld.d      $t3, $t1, 0
    addi.d    $t1, $t1, 8
    bne       $t3, $t2, 1b  //skip env

//find AT_PAGESZ in auxv
    addi.d    $t4, $zero, 1
    slli.d    $t4, $t4, 12  //default PAGE_SIZE

1:
    addi.d    $t5, $zero, AT_PAGESZ
    ld.d      $t3, $t1, 0
    addi.d    $t1, $t1, 8
    beq       $t3, $t2, 2f
    ld.d      $t6, $t1, 0
    addi.d    $t1, $t1, 8
    bne       $t5, $t3, 1b
    addi.d    $t4, $t6, 0

2:
    ld.d      $t3, $sp, 0
    addi.d    $sp, $sp, 8
    sub.d     $t4, $zero, t4  //neg
    addi.d    $sp, $sp, -8
    st.d      $t4, $sp, 0
    addi.d    $sp, $sp, -8
    st.d      $t3, $sp, 0


// create anonymous temporary file
    addi.d    $t3, $zero, 0
    slli.d    $t3, $t3, 8
    addi.d    $t3, $t3, 88
    slli.d    $t3, $t3, 8
    addi.d    $t3, $t3, 112
    slli.d    $t3, $t3, 8
    addi.d    $t3, $t3, 117  //upx/0
    addi.d    $sp, $sp, -8
    st.d      $t3, $sp, 0
    addi.d    $arg1, $sp, 0
    addi.d    $arg2, $zero, MFD_EXEC
0:  //try memfd_create
    addi.d    $a7, $zero, __NR_memfd_create
    syscall 0
    blt       $zero, $a0, ok_memfd  // success
    beq       $zero, $a0, ok_memfd  // success
    beq       $arg2, $zero, no_memfd  // memfd_create failed twice
    addi.d    $arg2, $zero, 0
    b         0b  // try again without MFD_EXEC
no_memfd:   // so try /dev/shm
    //todo,先专注主路径
ok_memfd:
    addi.d    $t8, $a0, 0  // mfd
    addi.d    $sp, $sp, 8  // discard "upx"

    la.pcrel  $t2, sz_pack2  //伪码？
    ld.d      $t1, $t2, 0
    sub.d     $t2, $t1, 0  //t2=elfaddr=&sz_pack2-sz_pack2
    la.pcrel  $t4, o_binfo
    ld.d      $t5, $t4, 0  //t5保存O_BINFO
    addi.d    $t4, $t4, 4
INSURANCE=0x10
    ld.d      $t3, $t4, 0
    addi.d    $t4, $t4, 4
    addi.d    $t3, $t3, INSURANCE
    addi.d    $sp, $sp, -8
    st.d      $t3, $sp, 0  //push F_LENU
    addi.d    $sp, $sp, -8
    addi.d    $t6, $zero, -1
    st.d      $t6, $sp, 0  //push -1,space for F_ADRU
    addi.d    $sp, $sp, -8
    st.d      $t2, $sp, 0  //push F_ELFA
    sub.d     $t1, $t1, $t5
    addi.d    $sp, $sp, -8
    st.d      $t1, $sp, 0  //push F_LENX=sz_pack2-o_binfo
    add.d     $t2, $t2, $t5
    addi.d    $sp, $sp, -8
    st.d      $t2, $sp, 0  //push F_ADRX=elfaddr+O_BINFO

    addi.d    $old_sp, $sp, 0
    sub.d     $sp, $sp, $t3
CACHELINE=8*NBPW
    addi.d    $to, $zero, -CACHELINE
    and.d     $sp, $sp, $t0

// Decompress the rest of this loader, and jump to it.

#define dst $a2
#define src $a3
#define lsrc $a4
    addi.d    src, $t4, 0
    addi.d    dst, $sp, 0
    ld.d      $t0, src, 0
    addi.d    src, src, 4
    addi.d    $sp, $sp, -8
    st.d      $t0, $sp, 0  //push .zs_cpr
    ld.d      $t0, src, 0
    addi.d    src, src, 4
    addi.d    $t1, $zero, M_NRV2B_LE32
    beq       $t0, $t1, 0f
    //todo 格式不对中止运行
0:
    ld.d      $t0, $sp, 0
    addi.d    $sp, $sp, 8
    add.d     $t0, $t0, src
    addi.d    $sp, $sp, -8
    st.d      $t0, $sp, 0
    addi.d    $sp, $sp, -8
    st.d      $old_sp, $sp, 0


// This is nrv2b_d32, inlined and optimized for small space (about 160 bytes).
// The task is to de-compress the folded pieces for shared library init:
// the de-compressor(s) of the PT_LOAD pieces, and the C-code supervisor
// which adjusts the placement and mapping of the address space.
// The output length is a couple KB for NRV, a few KB for Lzma, 64KB for Zstd.
// This is motivated by the possibility of using multiple de-compressors
// depending on the characteristics of each PT_LOAD, and by the increased size
// and compressability of C-coded de-compressors for Lzma and Zstd
// in contrast to the simple and small assembly-coded NRV.

/* Working registers */
#define off  $t0  /* XXX: 2GB */
#define bits $t1
#define len  $t2  /* XXX: 2GB */
#define lenq $t3
#define dispq $t4
#define displ $t5

#define GETBIT jirl $a0, $t6, 0
//t6保存getbit函数地址,读取的比特位于t7最低位
#define jnextb0 

    addi.d    bits, $zero, 0
    addi.d    len, $zero, 0
    la.pcrel  $t6, getbit  //伪码？
    addi.d    dispq, $zero, -1
    b         top_n2b
lit_n2b:
    ld.b      dst, src, 0
    addi.d    src, src, 1
    addi.d    dst, dst, 1
top_n2b:
    GETBIT
    bne       $t7, $zero, lit_n2b
    addi.d    off, $zero, 1
offmore_n2b:
    GETBIT
    slli.d    off, off, 1
    or.d      off, off, $t7
    GETBIT
    beq       $t7, $zero, offmore_n2b

    subi.w    off, off, 3
    blt       off, $zero, len_n2b
    slli.w    off, off, 8
    ld.b      $a0, src, 0
    addi.d    src, src, 1
    or.w      off, off, $a0
    nor.w       off, off, $zero //取反
    beq       off, $zero, eof_n2b
    slli.w    dispq, off, 0  //符号拓展

len_n2b:
    addi.d    off, $zero, 1
    GETBIT
    addi.d    len, $t7, 0
    slli.d    len, len, 1
    GETBIT
    addi.d    len, $t7, 0
    bne       len, $zero, gotlen_n2b
    addi.d    len, off, 0
    addi.d    off, off, 2
lenmore_n2b:
    GETBIT
    slli.d    len, len, 1
    addi.d    len, $t7, 0
    GETBIT
    beq       $t7, $zero, lenmore_n2b
gotlen_n2b:
    addi.w    $a0, $zero, -0xd00
    slt       $a1, dispq, $a0
    addi.w    len, len, off
    addi.w    len, len, $a1

    addi.w    $a0, src, 0
    add.w     src, dispq, dst
copy_start:
    beq       len, $zero, copy_done
    subi.w    len, len, 1
    ld.b      dst, src, 0
    addi.w    dst, dst, 1
    addi.w    src, src, 1
    b         copy_start
copy_done:
    addi.w    src, $a0, 0

    b         top_n2b

eof_n2b:
    ld.d      $old_sp, $sp, 0
    addi.d    $sp, $sp, 8
    ld.d      $a0, $sp, 0
    addi.d    $sp, $sp, 8
    beq       $a0, src, 0f
    //todo,中止执行
    0:

// Write de-compressed 'fold' to file
    ld.d      $a0, $old_sp, F_PMASK
    st.d      $a0, $sp, D_PMASK
    ld.d      $arg3, $old_sp, F_LENU
    subi.d    $arg3, $arg3, INSURANCE
    addi.d    $arg2, $sp, 0
    addi.d    $arg1, $t8, 0
    addi.d    $sp, $sp, -8
    st.d      $arg3, $sp, 0
0:
    addi.d    $a7, $zero, __NR_write
    bl        sys_check
    add.d     $arg2, $arg2, $a0
    sub.d     $arg3, $arg3, $a0
    bne       $arg3, $aero, 0b
    ld.d      $arg2, $sp, 0
    addi.d    $sp, $sp, 8
// de-alloca()
    addi.d    $sp, $old_sp, 0

// Map unfolded code the SELinux way
    addi.d    $arg6, $zero, 0
    addi.d    $arg5, $t8, 0
    addi.d    $arg4, $zero, MAP_SHARED
    addi.d    $arg3, $zero, PROT_READ | PROT_EXEC
    addi.d    $arg1, $zero, 0
    addi.d    $a7, $zero, __NR_mmap
    bl        sys_check
    addi.d    $sp, $sp, -8
    st.d      $a0, $sp, 0
    st.d      $a0, $old_sp, F_ADRU

    addi.d    $arg1, $arg5, 0
    addo.d    $a7, $zero, __NR_close
    syscall   0

// use the copy
    ld.d      $t0, $sp, 0
    addi.d    $sp, $sp, 8
    jirl      $t0, $t0, 0


sys_check:
    syscall   0  //删去amd里的push和pop
    addi.d    $t1, $zero, -4096
    blt       $a0, $t1, 1f
    //todo，中止执行
1:
    jirl      $ra, $ra, 0



//读取的1位比特存在t7最低位
getbit:
    addi.d    $t7, bits, 0  //bits高位存储32位缓冲区
    srli.d    $t7, %t7, 63
    andi.d    $t7, $t7, 1
    slli.d    bits, bits, 1
    beq       bits, $zero, refill
    jirl      $a0, $a0, 0

refill:
    ld.w      bits, src, 0  //读32位
    addi.d    $t7, bits, 0
    srli.d    $t7, %t7, 31
    andi.d    $t7, $t7, 1
    slli.d    bits, bits, 1
    ori.d     bits, bits, 1
    slli.d    bits, bits, 32
    addi.d    src, src, 4
    jirl      $a0, $a0, 0

.section ELFMAINZ
.balign 4
o_binfo:
    .word O_BINFO
FOLD:
// { b_info={sz_unc, sz_cpr, {4 char}}, folded_loader...}