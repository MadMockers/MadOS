
; .. for reference...
; .define DRIVER_CLASS_STORAGE                0x1002
; .define DVR_STORAGE_PRESENT                 0
; .define DVR_STORAGE_WRITE                   1
; .define DVR_STORAGE_READ                    2
; .define DVR_STORAGE_SET_FLAGS               3
; .define DVR_STORAGE_GET_FLAGS               4
; .define DVR_STORAGE_GET_SUPPORTED_FLAGS     5
; .define DVR_STORAGE_GET_PARAMS              6
; .define DVR_STORAGE_FUNC_COUNT              7


partitioner_driver:
    DAT 0

partitioner_init:
    PUSH A
        
        PUSH 0xFFFF
        PUSH 0xFFFF
        PUSH 0xFFFF
        PUSH DRIVER_CLASS_STORAGE
        PUSH DVR_STORAGE_FUNC_COUNT
            JSR driver_create
        POP A
        ADD SP, 4

        SET [A+DRIVER_CREATE_DEVICE], partitioner_create_device
        SET [A+DRIVER_FUNC+DVR_STORAGE_PRESENT], partitioner_present
        SET [A+DRIVER_FUNC+DVR_STORAGE_WRITE], partitioner_write
        SET [A+DRIVER_FUNC+DVR_STORAGE_READ], partitioner_read
        SET [A+DRIVER_FUNC+DVR_STORAGE_SET_FLAGS], unimplemented
        SET [A+DRIVER_FUNC+DVR_STORAGE_GET_FLAGS], unimplemented
        SET [A+DRIVER_FUNC+DVR_STORAGE_GET_SUPPORTED_FLAGS], unimplemented
        SET [A+DRIVER_FUNC+DVR_STORAGE_GET_PARAMS], partitioner_get_params

        SET [partitioner_driver], A
    
    POP A
    RET

; +1 Driver
; +0 Device (Device that we are operating on)
; Returns
; +0 Device
partitioner_create_device:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A

        PUSH PARTITIONER_SIZE
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

        SET [Z+0], A

    POP A
    POP Z
    RET

; +0 Driver
; Returns
; +0 Is media present
partitioner_present:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
        SET A, [A+DEVICE_HW]
        PUSH A
            SET A, [A+DEVICE_DRIVER]
            JSR [A+DRIVER_FUNC+DVR_STORAGE_PRESENT]
        POP [Z+0]
    POP A
    POP Z
    RET

; +2 Memory start
; +1 Sector
; +0 Device
; Returns
; None
partitioner_write:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
    PUSH B
    PUSH C
        SET A, [Z+0]
        SET B, [Z+1]
        IFL B, [A+PARTITIONER_SECTOR_COUNT]
            SET PC, .valid
        PUSH KPANIC_INDEX_OUT_OF_BOUNDS
            JSR kernel_panic
.valid:
        ADD B, [A+PARTITIONER_SECTOR_START]
        PUSH [Z+2]
        PUSH B
        SET C, [A+DEVICE_HW]
        PUSH C
        SET C, [C+DEVICE_DRIVER]
            JSR [C+DRIVER_FUNC+DVR_STORAGE_WRITE]
        ADD SP, 3
    POP C
    POP B
    POP A
    POP Z
    RET

; +2 Memory start
; +1 Sector
; +0 Device
; Returns
; None
partitioner_read:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
    PUSH B
    PUSH C
        SET A, [Z+0]
        SET B, [Z+1]
        IFL B, [A+PARTITIONER_SECTOR_COUNT]
            SET PC, .valid
        PUSH KPANIC_INDEX_OUT_OF_BOUNDS
            JSR kernel_panic
.valid:
        ADD B, [A+PARTITIONER_SECTOR_START]
        PUSH [Z+2]
        PUSH B
        SET C, [A+DEVICE_HW]
        PUSH C
        SET C, [C+DEVICE_DRIVER]
            JSR [C+DRIVER_FUNC+DVR_STORAGE_READ]
        ADD SP, 3
    POP C
    POP B
    POP A
    POP Z
    RET

; +1 Out ParamsInfo
; +0 Device
; Returns
; None
partitioner_get_params:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
    PUSH B
        SET A, [Z+0]
        SET B, [Z+1]
        PUSH A
            SET A, [A+DEVICE_HW]

            PUSH B
            PUSH A
                SET A, [A+DEVICE_DRIVER]
                JSR [A+DRIVER_FUNC+DVR_STORAGE_GET_PARAMS]
            ADD SP, 2
        POP A
        SET [B+MEDIA_PARAMS_SECTORS], [A+PARTITIONER_SECTOR_COUNT]
    POP B
    POP A
    POP Z
    RET
