
clock_init:
    PUSH A

        PUSH 0xb402
        PUSH 0x12d0
        PUSH 0x0001
        PUSH DRIVER_CLASS_CLOCK         ; class
        PUSH DVR_CLOCK_FUNC_COUNT       ; function count
            JSR driver_create
        POP A
        ADD SP, 4

        SET [A+DRIVER_CREATE_DEVICE],                clock_create_device
        SET [A+DRIVER_FUNC+DVR_CLOCK_SET],          clock_set
        SET [A+DRIVER_FUNC+DVR_CLOCK_GET_TICKS],    clock_get_ticks
        SET [A+DRIVER_FUNC+DVR_CLOCK_SET_INT],      clock_set_interrupt

    POP A
    PUSH A

        PUSH 0xb402
        PUSH 0x12d0
        PUSH 0x8008
        PUSH DRIVER_CLASS_CLOCK         ; class
        PUSH DVR_CLOCK_FUNC_COUNT       ; function count
            JSR driver_create
        POP A
        ADD SP, 4

        SET [A+DRIVER_CREATE_DEVICE],                clock_create_device
        SET [A+DRIVER_FUNC+DVR_CLOCK_SET],          clock_set
        SET [A+DRIVER_FUNC+DVR_CLOCK_GET_TICKS],    clock_get_ticks
        SET [A+DRIVER_FUNC+DVR_CLOCK_SET_INT],      clock_set_interrupt

    POP A
    RET

; +1 Driver
; +0 Hardware
; Returns
; +0 Device
clock_create_device:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A

        PUSH CLOCK_SIZE
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

; +1 Rate
; +0 Device
; Returns
; None
clock_set:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
    PUSH B
    PUSH C

        SET C, [Z+0]
        SET C, [C+DEVICE_HW]
        SET C, [C+HW_PORT]

        SET A, 0
        SET B, [Z+1]
        HWI C

    POP C
    POP B
    POP A
    POP Z
    RET

; +0 Device
; Returns
; +0 TickCount
clock_get_ticks:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
    PUSH C

        SET C, [Z+0]
        SET C, [C+DEVICE_HW]
        SET C, [C+HW_PORT]

        SET A, 1
        HWI C
        SET [Z], C

    POP C
    POP A
    POP Z
    RET


; +1 Message
; +0 Device
; Returns
; None
clock_set_interrupt:
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
    

