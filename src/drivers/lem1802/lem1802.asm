
lem1802_driver:
    DAT 0

lem1802_displays:
    DAT 0

lem1802_display_count:
    DAT 0

lem1802_init:
    PUSH A

        PUSH 0xf615
        PUSH 0x7349
        PUSH 0x1802
        PUSH DRIVER_CLASS_DISPLAY       ; class
        PUSH DVR_DISPLAY_FUNC_COUNT+3   ; function count
            JSR driver_create
        POP A
        ADD SP, 4

        SET [A+DRIVER_CREATE_DEVICE], lem1802_create_device
        SET [A+DRIVER_FUNC+DVR_DISPLAY_MAP_SCREEN], lem1802_map_screen
        SET [A+DRIVER_FUNC+1], lem1802_set_font
        SET [A+DRIVER_FUNC+2], lem1802_set_palette
        SET [A+DRIVER_FUNC+3], lem1802_set_border

        SET [lem1802_driver], A

    POP A
    RET

; +1 Driver
; +0 Hardware / Device
; Returns
; +0 Device
.define ARG_HW        0
.define ARG_DRIVER    1
lem1802_create_device:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A

        PUSH DISPLAY_SIZE
            JSR kalloc
        POP A

        JSR device_get_uid
        POP [A+DEVICE_ID]
        SET [A+DEVICE_HW], [Z+ARG_HW]
        SET [A+DEVICE_DRIVER], [Z+ARG_DRIVER]
        PUSH A
        ADD [SP], DEVICE_SPINLOCK
            JSR spinlock_init
        POP 0
        SET [Z+0], A

    POP A
    POP Z
    RET

; +0 Device
; Returns
; Nothing
lem1802_map_screen:
    PUSH A
    PUSH B
    PUSH C

        SET B, [SP+4]
        SET C, [B+DEVICE_HW]
        SET C, [C+HW_PORT]

        SET A, 0
        ADD B, DISPLAY_VRAM
        HWI C

    POP C
    POP B
    POP A
    RET

; +1 Font
; +0 Device
; Returns
; Nothing
lem1802_set_font:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
    PUSH B
    PUSH C

        SET C, [Z+0]
        SET C, [C+DEVICE_HW]
        SET C, [C+HW_PORT]

        SET A, 1
        SET B, [Z+1]
        HWI C

    POP C
    POP B
    POP A
    POP Z
    RET

; +1 Palette
; +0 Device
; Returns
; Nothing
lem1802_set_palette:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
    PUSH B
    PUSH C

        SET C, [Z+0]
        SET C, [C+DEVICE_HW]
        SET C, [C+HW_PORT]

        SET A, 2
        SET B, [Z+1]
        HWI C

    POP C
    POP B
    POP A
    POP Z
    RET

; +1 Border
; +0 Device
; Returns
; Nothing
lem1802_set_border:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
    PUSH B
    PUSH C

        SET C, [Z+0]
        SET C, [C+DEVICE_HW]
        SET C, [C+HW_PORT]

        SET A, 3
        SET B, [Z+1]
        HWI C

    POP C
    POP B
    POP A
    POP Z
    RET

