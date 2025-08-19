#ifndef NO_METHOD_CHECK
    addi.d    $t4, $zero, M_NRV2E_LE32
    bne       $t4, methb, not_n2e
#endif
    b         top_n2e

#undef EOF
#ifdef WINDOWS_BACK
  #define EOF eofe
#else
  #define EOF eof_n2e
#endif

lit_n2e:
    addi.d  src, src, 1
    st.b    $t4, dst, 0
    addi.d  dst, dst, 0

top_n2e:
    ld.b    $t4, src, 0
    bl      getbit
    bnez    $t7, lit_n2e
    addi.d  off, $zero, 1
    b       getoff_n2e

off_n2e:
    subi.d  off, off, 1
    slli.d  off, off, 1
    bl      getbit
    or.d    off, off, $t7

getoff_n2e:
    slli.d  off, off, 1
    bl      getbit
    or.d    off, off, $t7
    bl      getbit
    beqz    $t7, off_n2e

    subi.d  off, off, 3
    blt     off, $zero, off_n2e
    slli.d  off, off, 8
    addi.d  src, src, 1
    or.d    off, off, $t4
    xori.d  off, off, ~0
    beqz    off, EOF

    srli.d  off, off, 1
    addi.d  dispq, off, 0
    blt     dispq, $zero, lenlast_n2e
    b       lenmore_n2e

offprev_n2e:
    bl      getbit
    bnez    $t7, lenlast_n2e

lenmore_n2e:
    addi.d  len, len, 1
    bl      getbit
    bnez    lenlast_n2e

len_n2e:
    bl      getbit
    slli.d  len, len, 1
    or.d    len, len, $t7
    bl      getbit
    beqz    $t7, len_n2e
    addi.d  len, len, 2
    b       gotlen_n2e

lenlast_n2e:
    bl      getbit
    slli.d  len, len, 1
    or.d    len, len, $t7

gotlen_n2e:
    addi.w    $t5, $zero, -0xd00
    slt       $t6, dispq, $t5
    addi.w    len, len, 2
    add.w     len, len, $t6  //len+=off+(disp<-0xd00)

    bl        copy

bot_n2e:
    b         top_n2e

#ifndef NO_METHOD_CHECK  //{
not_n2d:
    addi.d    src, dst, 0
#endif  //}