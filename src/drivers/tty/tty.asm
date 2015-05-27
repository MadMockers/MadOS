
tty_driver:
    DAT 0

tty_init:
    PUSH A
        
        PUSH 0xFFFF
        PUSH 0xFFFF
        PUSH 0xFFFF
        PUSH DRIVER_CLASS_TTY
        PUSH DVR_TTY_FUNC_COUNT
            JSR driver_create
        POP A
        ADD SP, 4

        SET [A+DRIVER_CREATE_DEVICE], tty_create_device
        SET [A+DRIVER_FUNC_COUNT+DVR_TTY_WRITE], tty_write
        SET [A+DRIVER_FUNC_COUNT+DVR_TTY_NEWLINE], tty_newline
        SET [A+DRIVER_FUNC_COUNT+DVR_TTY_GETFMT], tty_getfmt
        SET [A+DRIVER_FUNC_COUNT+DVR_TTY_SETFMT], tty_setfmt
        SET [A+DRIVER_FUNC_COUNT+DVR_TTY_GETXY], tty_getxy
        SET [A+DRIVER_FUNC_COUNT+DVR_TTY_SETXY], tty_setxy

        SET [tty_driver], A
    
    POP A
    RET


; +1 Driver
; +0 Hardware (Actually a Device)
; Returns
; +0 Device
tty_create_device:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A

        PUSH TTY_SIZE
            JSR kalloc
        POP A

        JSR device_get_uid
        POP [A+DEVICE_ID]
        SET [A+DEVICE_HW], [Z+0]
        SET [A+DEVICE_DRIVER], [Z+1]
        PUSH A
        ADD [SP], DEVICE_SPINLOCK
            JSR spinlock_init
        POP 0
        SET [A+TTY_FMT], 0
        SET [A+TTY_IDX], 0

        SET [Z+0], A

    POP A
    POP Z
    RET

; +1 Line Count
; +0 Device
; Returns
; None
tty_scrollscreen:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
    PUSH B
    PUSH C
    PUSH I

        SET A, [Z+0]
        SET B, [A+DEVICE_HW]
        ADD B, DISPLAY_VRAM

        SET C, [Z+1]
        MUL C, 32

        SUB [A+TTY_IDX], C

        SET I, C
        ADD I, B

        PUSH B
        PUSH I
        PUSH VRAM_SIZE
        SUB [SP], C
            JSR memmove
        ADD SP, 3

        ADD B, VRAM_SIZE
        PUSH B
            SUB B, C
        POP C

        SET I, [A+TTY_FMT]
        AND I, 0x0F00
        PUSH I
            SHL I, 4
        BOR I, POP

.clear_top:
        IFE B, C
            SET PC, .clear_break
        SET [B], I
        ADD B, 1
        SET PC, .clear_top
.clear_break:

    POP I
    POP C
    POP B
    POP A
    POP Z
    RET

; +2 Buf Size
; +1 Buffer
; +0 Device
tty_write:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
    PUSH B

        SET A, [Z+0]
        SET B, VRAM_SIZE
        SUB B, [A+TTY_IDX]

        IFG [Z+2], B
            SET PC, .move_vram
        SET PC, .copy_buffer

.move_vram:
        ; how many lines do we have to move it by..
        ; hard code resolution for now
        PUSH [Z+2]
            SUB [SP], B
        POP B
        DIV B, 32
        ADD B, 1
        PUSH B
        PUSH [Z+0]
            JSR tty_scrollscreen
        ADD SP, 2

.copy_buffer:
        SET B, [A+DEVICE_HW]
        ADD B, DISPLAY_VRAM
        ADD B, [A+TTY_IDX]

        PUSH B
        PUSH [Z+1]
        PUSH [Z+2]
            JSR memcpy
        ADD SP, 3

        ADD [A+TTY_IDX], [Z+2]

.fmt_top:
        IFE [Z+2], 0
            SET PC, .fmt_break
        BOR [B], [A+TTY_FMT]
        ADD B, 1
        SUB [Z+2], 1
        SET PC, .fmt_top
.fmt_break:

        SET A, [A+DEVICE_HW]
        PUSH A
            SET A, [A+DEVICE_DRIVER]
            JSR [A+DRIVER_FUNC+DVR_DISPLAY_MAP_SCREEN]
        POP 0
        
    POP B
    POP A
    POP Z
    RET

; +0 Device
; Returns
; None
tty_newline:
    PUSH Z
    SET Z, SP
    ADD Z, 2

    PUSH A
    PUSH B

        SET A, [Z+0]
        SET B, [A+TTY_IDX]
        DIV B, 32
        ADD B, 1
        MUL B, 32

        SET [A+TTY_IDX], B
        IFL B, VRAM_SIZE
            SET PC, .done

        PUSH 1
        PUSH [Z+0]
            JSR tty_scrollscreen
        ADD SP, 2
.done:
        SET A, [A+DEVICE_HW]
        PUSH A
            SET A, [A+DEVICE_DRIVER]
            JSR [A+DRIVER_FUNC+DVR_DISPLAY_MAP_SCREEN]
        POP 0

    POP B
    POP A
    POP Z
    RET

; +0 Device
; Returns
; +0 Format
tty_getfmt:
    PUSH A
   PUSH B
        SET A, [SP+3]
        SET A, [A+TTY_FMT]
      SET B, A
        SHR A, 8
      SHL B, 1
      AND B, 0x100
      BOR A, B
        SET [SP+3], A
   POP B
    POP A
    RET

; +1 Format
; +0 Device
tty_setfmt:
    PUSH A
   PUSH B
        SET A, [SP+4]
      SET B, A
        SHL A, 8
      AND B, 0x100
      SHR B, 1
      BOR A, B
        PUSH A
            SET A, [SP+4]
        POP [A+TTY_FMT]
   POP B
    POP A
    RET

; +1 Device
; Returns
; +0 X
; +1 Y
tty_getxy:
    SUB SP, 1
    SET [SP], [SP+1]
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A

        SET A, [Z+1]
        SET A, [A+TTY_IDX]
        SET [Z+0], A
        MOD [Z+0], 32
        SET [Z+1], A
        DIV [Z+1], 32

    POP A
    POP Z
    RET

; +2 X
; +1 Y
; +0 Device
tty_setxy:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
        SET A, [Z+1]
        MUL A, 32
        ADD A, [Z+2]
        IFL A, VRAM_SIZE
            SET PC, .set_idx
        SET PC, .out_of_range
.set_idx:
        PUSH A
            SET A, [Z+0]
        POP [A+TTY_IDX]
.out_of_range:
    POP A
    POP Z
    RET
