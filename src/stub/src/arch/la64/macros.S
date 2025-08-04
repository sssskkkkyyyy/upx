/*
;  macros.S --
*/

#ifndef __MACROS_S__
#define __MACROS_S__ 1

.macro section name
    .section \name
.endm

.macro endbr64
    /* no-op for LoongArch64 */
.endm

#endif /* __MACROS_S__ */
