NBPW= 8
#include "arch/la64/macros.S"
#include "arch/la64/regs.h"

PATH_MAX= 4096  // /usr/include/linux/limits.h

sz_b_info= 12
  sz_unc= 0
  sz_cpr= 4

sz_l_info= 12
sz_p_info= 12

MAP_PRIVATE=   0x02
MAP_FIXED=     0x10

PROT_READ=     0x1

O_RDONLY=       0

OVERHEAD=2048

/* 64-bit mode only! */
__NR_read = 63
__NR_write = 64
__NR_open = 56
__NR_close = 57
__NR_exit = 93
__NR_mmap = 222
__NR_mprotect = 226
__NR_munmap = 215
__NR_msync = 227
__NR_brk = 214
__NR_memfd_create = 279
__NR_ftruncate = 46
__NR_readlink = 78

F_FRAME= 7*NBPW
F_ENTR= 6*NBPW; F_UNMAPA= F_ENTR
F_RDX=  5*NBPW
F_LENU= 4*NBPW
F_ADRU= 3*NBPW
F_ELFA= 2*NBPW
F_LENX= 1*NBPW
F_ADRX= 0*NBPW

unmap_all_pages= (1<<1)
is_ptinterp=     (1<<0)

        .balign 8
PAGE_MASK: .quad -1<<12  // default

//在entry.S中，用r21保存o_binfo，对应amd的r13
fold_begin:
    addi.d  $s0, $sp, 0
    st.d    $r21, $sp, F_UNMAPA
    andi.d  $t0, $r21, is_ptinterp
    ld.d    $t1, $sp, F_ELFA
    or.d    $t1, $t0, $t1
    st.d    $t1, $sp, F_ELFA
    addi.d  $a1, $sp, 0
    andi.b  $t2, $r21, unmap_all_pages
    bnez    $t2, 0f
    subi.d  $sp, $sp, PATH_MAX
0:
    addi.d  $a0, $sp, 0
    addi.d  $t3, $zero, 8
copy1:
    ld.d    $t0, $a1, 0
    st.d    $t0, $a0, 0
    addi.d  $a1, $a1, 8
    addi.d  $a0, $a0, 8
    addi.d  $t3, $t3, -1
    bnez    $t3, copy1
    //ADRX,LDRX,ELFA,ADRU,LENU,rdx,%entry,argc

0:
    ld.d    $t0, $a1, 0
    st.d    $t0, $a0, 0
    addi.d  $a1, $a1, 8
    addi.d  $a0, $a0, 8
    bnez    $t0, 0b  // move past argv
    addi.d  $s1, $a0, 0 //remember $new_env[0]
    andi.b  $t2, $r21, unmap_all_pages
    bnez    $t2, 0f
    addi.d  $t0, $zero, 0
    st.d    $t0, $a0, 0
    addi.d  $a0, $a0, 8  //space for new_env[0]

0:
    ld.d    $t0, $a1, 0
    st.d    $t0, $a0, 0
    addi.d  $a1, $a1, 8
    addi.d  $a0, $a0, 8
    bnez    $t0, 0b  // move past env
    addi.d  $s2, $a0, 0  // &old Elf64_auxv
    addi.d  $arg4, $a0, 0  // &auxv in case no_pse_env

0:
    ld.d    $t0, $a1, 0
    ld.d    $t1, $a1, 8
    st.d    $t0, $a0, 0
    st.d    $t1, $a0, 8
    addi.d  $a1, $a1, 16
    addi.d  $a0, $a0, 16
    bnez    $t0, 0b  // move past auxv
    addi.d  $s3, $a0, 0  //beyond auxv
    addi.d  $s4, $a1, 0  //beginning of strings
    sub.d   $s2, $s2, $a0

    andi.b  $t2, $r21, unmap_all_pages
    beqz    $t2, env_pse
    addi.d   $s0, $s0, -1
    addi.d  $s1, $a0, 0
    b       no_env_pse

env_pse:
    addi.d  $sp, $sp, -8
    st.d    $a0, $sp, 0
    la.pcrel  $arg1, proc_self_exe
    addi.d  $arg2, $zero, 0
    bl      open
    addi.d  $s0, %a0, 0
    ld.d    $arg2, $sp, 0
    addi.d  $sp, $sp, 8

    addi.d  $arg3, $arg3, PATH_MAX-1
    addi.d  $a7, $zero, __NR_readlink
    syscall 0
    blt     $zero, $a0, 0f
    beq     $zero, $a0, 0f
    //readlink() failed
    addi.d  $arg2, $arg1, 0
    addi.d  $a0, $zero, 15
0:
    addi.d  $t0, $a0, 0  //t0=byte count
    addi.d  $t1, $s4, -1  //dst
    addi.d  $t2, $zero, 0
    st.d    $t2, $t1, 0
    addi.d  $t1, $t1, -1
    add.d   $t2, $arg2, $t0
    addi.d  $t2, $t2, -1  //src
1:
    ld.b    $t3, $t2, 0
    st.b    $t3, $t1, 0
    addi.d  $t2, $t2, -1
    addi.d  $t1, $t1, -1
    addi.d  $t0, $t0, -1
    bnez    $t0, 1b
    subi.d  $t1, $t1, -3
    addi.d  $t3, $zero, 0x3D202020
    st.w    $t3, $t1, 0  //env var name
    st.d    $t1, $s1, 0  //new_env[0]
    andi.d  $t1, $t1, -NBPW  // align
    addi.d  $t0, $s3, 0
    sub.d   $t0, $t0, $sp  // byte count

    sub.d   $t1, $t1, NBPW  //new auxv
    sub.d   $t2, $s3, NBPW  //old auxv

    //end of auxv must move by even number of NBPW
    addi.d  $a0, $t1, 0
    xor.d   $a0, $a0, $t2
    andi.d  $a0, $a0, NBPW
    sub.d   $t1, $t1, $a0
    addi.d  $s1, $t1, 0 //last qword of new auxv

    srli.d  $t0, $t0, 3
1:
    ld.d    $t3, $t2, 0
    st.d    $t3, $t1, 0
    addi.d  $t2, $t2, -8
    addi.d  $t1, $t1, -8
    addi.d  $t0, $t0, -1
    bnez    $t0, 1b
    addi.d  $sp, $t1, NBPW


    add.d   $arg4, $s1, $s2
    addi.d  $arg4, $arg4, NBPW
no_env_pse:
    ld.d    $arg1, $sp, 0
    addi.d  $sp, $sp, 8
    ld.d    $arg2, $sp, 0
    addi.d  $sp, $sp, 8
    andi.d  $arg1, $arg1, ~(is_ptinterp | unmap_all_pages)

    ld.d    $arg5, $sp, 0
    addi.d  $sp, $sp, 8
    addi.d  $a0, $arg5, 0
    andi.d  $a0, $a0, 1
    or.d    $arg4, $arg4, $a0
    sub.d   $arg5, $arg5, $a0
    addi.d  $s4, %arg5, 0  // save ELFA
    subi.d  $sp, $sp, OVERHEAD
    addi.d  $arg3, $sp, 0
    //todo:call upx_main2
/* entry= upx_main2(
   b_info *arg1,       {%rdi}
   total_size arg2,    {%rsi}
   Elf64_Ehdr *arg3,   {%rdx}
   Elf32_Auxv_t *arg4, {%rcx}
   Elf64_Addr elfaddr  {%r8}
   )
*/
// rsp/ {OVERHEAD},ADRU,LENU,rdx,%entry,  argc,argv,0,envp,0,auxv,0,strings
    addi.d  $sp, $sp, OVERHEAD
    addi.d  $t0, $s0, 0  // fd
    st.d    $a0, $sp, 3*NBPW  // entry

sz_Ehdr= 8*NBPW
e_type= 16
ET_EXEC= 2
sz_Phdr= 7*NBPW
p_memsz= 5*NBPW
// Discard pages of compressed data (includes [ADRX,+LENX) )
    addi.d  $arg2, $s4, p_memsz+sz_Phdr+sz_Ehdr
    addi.d  $arg1, $s4, 0
    bl      brk
    addi.d  $arg1, $s4, 0
    bl      munmap

// Map 1 page of /proc/self/exe so that the symlink does not disappear.
    blt     $t0, $zero, no_pse_map
    addi.d  $arg6, $zero, 0 //0 offset
    addi.d  $arg5, $t0, 0 //fd
    addi.d  $arg4, $zero, MAP_PRIVATE
    addi.d  $arg3, $zero, PROT_READ
    addi.d  $arg2, $zero, 1<<12
    addi.d  $arg1, $zero, 0
    bl      mmap

    addi.d  $arg1, $t0, 0
    bl      close

no_pse_map:
    ld.d    $arg1, $sp, 0
    ld.d    $arg2, $sp, 8
    addi.d  $sp, $sp, 16
    addi.d  $a7, $zero, __NR_munmap
    syscall 0
    ld.d    $arg3, $sp, 0
    addi.d  $sp, $sp, 8
    ld.d    $ra, $sp, 0
    addi.d  $sp, $sp, 8
    jirl    $ra, $ra, 0 //跳转到目标程序



proc_self_exe:
        .asciz "/proc/self/exe"


mmap:
    addi.d    $a7, $zero, __NR_mmap

sys_check:
    syscall   0  //删去amd里的push和pop
    addi.d    $t1, $zero, -4096
    blt       $a0, $t1, 1f
    //todo，中止执行
1:
    jirl      $ra, $ra, 0

munmap:
    addi.d    $a7, $zero, __NR_munmap
    b         sys_check
brk:
    addi.d    $a7, $zero, __NR_brk
    b         sys_check
close:
    addi.d    $a7, $zero, __NR_close
    b         sys_check
open:
    addi.d    $a7, $zero, __NR_open
    b         sys_check