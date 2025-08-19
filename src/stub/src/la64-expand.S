NBPW= 8
#include "arch/la64/macros.S"
#include "arch/la64/regs.h"

// /*************************************************************************
//   C-callable decompressor  f_expand(&b_info, dst, &dstlen)
// **************************************************************************/

.global f_expand
f_expand:
    addi.d    $sp, $sp, -16
    st.d      $fp, $sp, 8
    st.d      $s0, $sp, 0
    addi.d    $fp, $sp, 8

// Calling sequence registers
#define fx_src $a0
#define fx_dst $a1
#define fx_dstlen $a2
#define meth  $a4
#define methb $a4

sz_unc= 0
sz_cpr= 4
b_method= 8
b_ftid=   9
b_cto8=  10
b_extra= 11
sz_binfo= 12

    addi.d    $sp, $sp, -24
    st.d      fx_dstlen, $sp, 16
    st.d      fx_dst, $sp, 8
    st.d      fx_src, $sp, 0
    bl        decompress
    ld.d      $s0, $sp, 0  //fx_src
    ld.d      $a1, $sp, 16 //fx_dstlen
    st.d      $a0, $sp, 16 // MATCH_55  save result from decompress
    ld.d      $a0, $sp, 8  //fx_dst arg1
    addi.d    $sp, $sp, 16

    ld.d      $a3, $s0, b_ftid //arg4
    beqz      $a3, no_unf  // 0==.ftid
    ld.d      $a2, $s0, b_cto8 //arg3
    ld.d      $a1, $a1, 0 //arg2=dstlen
    bl        unfilter

no_unf:
    ld.d      $a0, $sp, 0
    ld.d      $s0, $sp, 8
    ld.d      $fp, $sp, 16
    addi.d    $sp, $sp, 24
    ret

unfilter:
// #include "arch/la64/bxx.S"
//todo:未实现该文件，不是必需功能，暂且忽略

/* NRV2 working registers */
#define off  $t0  /* XXX: 2GB */
#define len  $t1  /* XXX: 2GB */
#define lenq $t1
#define bits $t2
#define src  $a1
#define dst  $a0
#define displ $t3
#define dispq $t3

decompress: // (fx_src= &b_info, fx_dst= dst, fx_dstlen= &dstlen)
    addi.d    $sp, $sp, -8
    st.d      fx_dstlen, $sp, 0
    ld.d      meth, fx_src, b_method
    addi.d    $t1, fx_src, 0
    addi.d    $t2, fx_dst, 0
    addi.d    $src, $t1, 0
    addi.d    $dst, $t2, 0
    ld.d      $t0, src, sz_cpr
    addi.d    $src, $src, sz_binfo
    add.d     $t0, $t0, src
    addi.d    $sp, $sp, -8
    st.d      $t0, $sp, 0
    addi.d    $sp, $sp, -8
    st.d      dst, $sp, 0

        addi.d  bits, $zero, 0
        addi.d  len, $zero, 0
        ori.d   dispq, dispq, ~0
        b       go_meth


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

getbit:
    addi.d    $t7, bits, 0  //bits高位存储32位缓冲区
    srli.d    $t7, %t7, 63
    andi.d    $t7, $t7, 1
    slli.d    bits, bits, 1
    beq       bits, $zero, refill
    jirl      $a0, $a0, 0

copy: // In: len, %rdi, dispq;  Out: 0==len, %rdi, dispq;  trashes %rax, %rdx
    add.d     $t4, dst, dispq // t4表示复制起点
    ld.b      $t5, $t4, 0
    addi.d    $t6, $zero, 6
    blt       len, $t6, copy1
    addi.d    $t6, $zero, -3
    bge       $displ, $t6, copy1 // 4-byte chunks would overlap
    subi.d    len, len, 4

copy4:
    ld.w     $t5, $t4, 0
    addi.d    $t4, $t4, 4
    subi.d    len, len, 4
    st.w      $t5, dst, 0
    addi.d    dst, dst, 4
    bge       len, $zero, copy4
    addi.d    len, len, 4
    ld.b      $t5, $t4, 0
    beq       len, $zero, copy0

copy1:
    addi.d    $t4, $t4, 1
    st.b      $t5, dst, 0
    subi.d    len, len, 1
    ld.b      $t5, $t4, 0
    addi.d    dst, dst, 1
    bneq      len, $zero, copy1
    
copy0:
    jirl      $ra, $ra, 0

go_meth:

#define M_NRV2B_LE32    2
#define M_NRV2D_LE32    5
#define M_NRV2E_LE32    8
#define M_CL1B_LE32     11
#define M_LZMA          14

// Daisy chain of decoding methods that were used
#define NO_METHOD_CHECK 1  /* subsumed here by daisy chain */

    addi.d    $t4, $zero, M_NRV2B_LE32
    bne       $t4, meth, not_nrv2e
#include "arch/la64/nrv2e_d.S"
not_nrv2e:

    addi.d    $t4, $zero, M_NRV2D_LE32
    bne       $t4, meth, not_nrv2d
#include "arch/la64/nrv2d_d.S"
not_nrv2d:

    addi.d    $t4, $zero, M_NRV2E_LE32
    bne       $t4, meth, not_nrv2b
#include "arch/la64/nrv2b_d.S"
not_nrv2b:

#undef off
#undef len
#undef lenq
#undef bits
#undef displ
#undef dispq


    addi.d    $t4, $zero, M_LZMA
    bne       $t4, meth, not_lzma

    addi.d    $sp, $sp, -16
    st.d      dst, $sp, 8
    st.d      src, $sp, 0
#define  arg2d $a1
    ld.d      arg2d, src, sz_cpr-sz_binfo
#undef  src
#undef  dst
    addi.d    $arg4, fx_dstlen, 0
    ld.d      $arg1, $sp, 0
    ld.d      $arg3, $sp, 8
    addi.d    $sp, $sp, 16

#include "arch/la64/lzma_d.S"
not_lzma:

// Fall through: daisy chain had no matching method
//todo,错误处理

eof_lzma:
eof_n2b:
eof_n2d:
eof_n2e:
    ld.d    $t0, $sp, 0
    addi.d  $sp, $sp, 8
    sub.d   $a0, $a0, $t0
    ld.d    $t0, $sp, 0
    addi.d  $sp, $sp, 8
    ld.d    $t1, $sp, 0
    addi.d  $sp, $sp, 8
    st.d    $a0, $t1, 0 //actual length used at dst  XXX: 4GB
    sub.d   $t0, $t0, $a1
    jirl    $ra, $ra, 0