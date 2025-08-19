#ifndef NO_METHOD_CHECK
    addi.d    $t4, $zero, M_NRV2B_LE32
    bne       $t4, methb, not_n2b
#endif
    b         top_n2b

#undef EOF
#ifdef WINDOWS_BACK
  #define EOF eofb
#else
  #define EOF eof_n2b
#endif

lit_n2b:
    addi.d  src, src, 1
    st.b    %t4, dst, 0
    addi.d  dst, dst, 0

top_n2b:
    ld.b    $t4, src, 0
    bl      getbit
    bnez    $t7, lit_n2b
    addi.d  off, $zero, 1

offmore_n2b:
    bl      getbit
    slli.d  off, off, 1
    or.d    off, off, $t7
    bl      getbit
    beqz    $t7, offmore_n2b

    subi.d  off, off, 3
    blt     off, $zero, len_n2b

    slli.d  off, off, 8
    addi.d  src, src, 1
    or.d    off, off, $t4
    xor.d   off, off, ~0
    beq     off, $zero, EOF

    addi.d  dispq, off, 0

len_n2b:
    addi.d  off, $zero, 1
    bl      getbit
    slli.d  len, len, 1
    or.d    len, len, $t7
    bl      getbit
    slli.d  len, len, 1
    or.d    len, len, $t7 //two bits
    bnez    len, gotlen_n2b
    addi.d  len, off, 0
    addi.d  off, off, 2

lenmore_n2b:
    bl      getbit
    slli.d  len, len, 1
    or.d    len, len, $t7
    bl      getbit
    beqz    $t7, lenmore_n2b

gotlen_n2b:
    addi.w    $t5, $zero, -0xd00
    slt       $t6, dispq, $t5
    add.w    len, len, off
    add.w    len, len, $t6  //len+=off+(disp<-0xd00)

    bl        copy

bot_n2b:
    b         top_n2b

#ifndef NO_METHOD_CHECK  //{
not_n2b:
    addi.d    src, dst, 0
#endif  //}