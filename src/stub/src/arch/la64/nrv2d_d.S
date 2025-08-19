#ifndef NO_METHOD_CHECK
    addi.d    $t4, $zero, M_NRV2D_LE32
    bne       $t4, methb, not_n2d
#endif
    b         top_n2d

#undef EOF
#ifdef WINDOWS_BACK
  #define EOF eofd
#else
  #define EOF eof_n2d
#endif

lit_n2d:
    addi.d  src, src, 1
    st.b    $t4, dst, 0
    addi.d  dst, dst, 0

top_n2d:
    ld.d    $t4, src, 0
    bl      getbit
    bnez    $t7, lit_n2d
    addi.d  off, $zero, 1
    b       getoff_n2d

off_n2d:
    subi.d  off, off, 1
    bl      getbit
    slli.d  off, off, 1
    or.d    off, off, $t7

getoff_n2d:
    bl      getbit
    slli.d  off, off, 1
    or.d    off, off, $t7
    bl      getbit
    beqz    $t7, off_n2d

    subi.d  off, off, 3
    blt     off, $zero, offprev_n2d

    slli.d  off, off, 8
    addi.d  src, src, 1
    or.d    off, off, $t4
    xor.d   off, off, ~0
    beq     off, $zero, EOF

    srli.d  off, off, 1
    addi.d  dispq, off, 0
    b       len_n2d-2  //CHEAT

offprev_n2d:
    bl      getbit
    slli.d  len, len, 1
    or.d    len, len, $t7

len_n2d:
    bl      getbit
    slli.d  len, len, 1
    or.d    len, len, $t7
    bne     len, $zero, gotlen_n2d
    addi.d  len, len, 1

lenmore_n2d:
    bl      getbit
    slli.d  len, len, 1
    or.d    len, len, $t7
    bl      getbit
    beqz    $t7, lenmore_n2d
    addi.d  len, len, 2

gotlen_n2d:
    addi.w    $t5, $zero, -0xd00
    slt       $t6, dispq, $t5
    add.w    len, len, off
    add.w    len, len, $t6  //len+=off+(disp<-0xd00)

    bl        copy

bot_n2d:
    b         top_n2d

#ifndef NO_METHOD_CHECK  //{
not_n2d:
    addi.d    src, dst, 0
#endif  //}