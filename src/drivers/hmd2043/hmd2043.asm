
hmd2043_driver:
    DAT 0

hmd2043_devices:
    DAT 0

hmd2043_device_count:
    DAT 0

hmd2043_init:
    PUSH A

        PUSH 0x4cae
        PUSH 0x74fa
        PUSH 0x07c2
        PUSH DRIVER_CLASS_STORAGE       ; class
        PUSH DVR_STORAGE_FUNC_COUNT     ; function count
            JSR driver_create
        POP A
        ADD SP, 4

        SET [A+DRIVER_CREATE_DEVICE], hmd2043_create_device

        SET [A+DRIVER_FUNC+DVR_STORAGE_PRESENT], hmd2043_present
        SET [A+DRIVER_FUNC+DVR_STORAGE_WRITE], hmd2043_write
        SET [A+DRIVER_FUNC+DVR_STORAGE_READ], hmd2043_read
        SET [A+DRIVER_FUNC+DVR_STORAGE_SET_FLAGS], hmd2043_set_flags
        SET [A+DRIVER_FUNC+DVR_STORAGE_GET_FLAGS], hmd2043_get_flags
        SET [A+DRIVER_FUNC+DVR_STORAGE_GET_SUPPORTED_FLAGS], hmd2043_get_supported_flags
        SET [A+DRIVER_FUNC+DVR_STORAGE_GET_PARAMS], hmd2043_get_params
        SET [hmd2043_driver], A

    POP A
    RET

; +1 Driver
; +0 Hardware
hmd2043_create_device:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A

        PUSH HMD2043_SIZE
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

        SET [A+HMD2043_FLAGS], 0

        SET [Z+0], A

    POP A
    POP Z
    RET

; +0 HwInfo
; Return
; +0 1 = present, 0 = not present
hmd2043_present:
    PUSH A
    PUSH B
        SET A, 0
        SET B, [SP+3]
        SET B, [B+DEVICE_HW]
        HWI [B+HW_PORT]
        SET [SP+3], B
    POP B
    POP A
    RET

; +2 Memory Start
; +1 Sector
; +0 HwInfo
; Return
; None
hmd2043_write:
    PUSH A
    PUSH B
    PUSH C
    PUSH X
        SET B, 0x11
        SET PC, .hmd2043_write_read
hmd2043_read:
    PUSH A
    PUSH B
    PUSH C
    PUSH X
        SET B, 0x10
.hmd2043_write_read:

        SET A, [SP+5]
        SET A, [A+DEVICE_HW]
        PUSH [A+HW_PORT]
            SET A, B
            SET B, [SP+7]   ; sector
            SET C, 1        ; sector count
            SET X, [SP+8]   ; memory addr
        HWI POP

    POP X
    POP C
    POP B
    POP A
    RET

; +1 Flags
; +0 Device
hmd2043_set_flags:
    PUSH A
        SET A, [SP+2]
        SET [A+HMD2043_FLAGS], [SP+3]
    POP A
    RET

; +0 Device
; Returns
; +0 Flags
hmd2043_get_flags:
    PUSH A
        SET A, [SP+2]
        SET [SP+2], [A+HMD2043_FLAGS]
    POP A
    RET

; +0 Device
; Returns
; +0 Flags
hmd2043_get_supported_flags:
    SET [SP+1], HMD2043_SUPPORTED_FLAGS
    RET

; +1 Out ParamsInfo
; +0 Device
; Returns
; None
hmd2043_get_params:
    PUSH A
        SET A, [SP+3]
        SET [A+MEDIA_PARAMS_SECTORS], 1440
        SET [A+MEDIA_PARAMS_SECTOR_SIZE], 512
    POP A
    RET

