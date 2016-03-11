
.define DRIVER_CLASS_STORAGE                0x1002
.define DVR_STORAGE_PRESENT                 0
.define DVR_STORAGE_WRITE                   1
.define DVR_STORAGE_READ                    2
.define DVR_STORAGE_SET_FLAGS               3
.define DVR_STORAGE_GET_FLAGS               4
.define DVR_STORAGE_GET_SUPPORTED_FLAGS     5
.define DVR_STORAGE_GET_PARAMS              6
.define DVR_STORAGE_FUNC_COUNT              7

m35fd_driver:
    DAT 0

m35fd_init:
    PUSH A

        PUSH 0x24C5
        PUSH 0x4FD5
        PUSH 0x000B
        PUSH DRIVER_CLASS_STORAGE
        PUSH DVR_STORAGE_FUNC_COUNT
            JSR driver_create
        POP A
        ADD SP, 4

        SET [A+DRIVER_CREATE_DEVICE], m35fd_create_device

        SET [A+DRIVER_FUNC+DVR_STORAGE_PRESENT], m35fd_present
        SET [A+DRIVER_FUNC+DVR_STORAGE_WRITE], m35fd_write
        SET [A+DRIVER_FUNC+DVR_STORAGE_READ], m35fd_read
        SET [A+DRIVER_FUNC+DVR_STORAGE_SET_FLAGS], unimplemented
        SET [A+DRIVER_FUNC+DVR_STORAGE_GET_FLAGS], unimplemented
        SET [A+DRIVER_FUNC+DVR_STORAGE_GET_SUPPORTED_FLAGS], unimplemented
        SET [A+DRIVER_FUNC+DVR_STORAGE_GET_PARAMS], m35fd_get_params
        SET [m35fd_driver], A

    POP A
    RET

; +1 Driver
; +0 HWInfo
; Returns
; +0 Device
m35fd_create_device:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
    PUSH B

        PUSH M35FD_SIZE
            JSR kalloc
        POP A

        JSR device_get_uid
        POP [A+DEVICE_ID]
        SET [A+DEVICE_HW], [Z+0]
        SET [A+DEVICE_DRIVER], [Z+1]

        PUSH A
            JSR m35fd_setinterrupt
        POP 0

        SET [Z+0], A

    POP B
    POP A
    POP Z
    RET

; +0 Device
; IRQ CALLBACK
m35fd_callback:
    PUSH A
    PUSH B
    PUSH C ; (set by the HWI)
        SET B, [SP+4]
        SET A, 0 ; 0 == poll state
        SET B, [B+DEVICE_HW]
        HWI [B+HW_PORT]
        IFN B, 1 ; 1 == ready
            SET PC, .not_ready

        SET A, [SP+4]
        SET B, [A+M35FD_WAITING_THREAD]

        IFN B, 0
            SET [B+THREAD_STATE], THREAD_STATE_RUNNING
        SET [A+M35FD_WAITING_THREAD], 0
.not_ready:
    POP C
    POP B
    POP A
    RET

; A = device
m35fd_wait:
    JSR enter_critical
        IFE [A+M35FD_WAITING_THREAD], 0
            SET PC, .raced
        PUSH A
            SET A, [current_thread]
            SET [A+THREAD_STATE], THREAD_STATE_PAUSED
        POP A
    JSR leave_critical

    ; our thread state is now paused
    ; yield will not return until the IRQ callback is called
    JSR yield
    RET
.raced:
    JSR leave_critical
    RET

; +0 device
m35fd_setinterrupt:
    PUSH A
    PUSH B
        
        SET A, [SP+3]
        PUSH A
        PUSH m35fd_callback
            JSR register_irq_handler
        POP B
        POP 0

        PUSH X
            SET X, [B+IRQ_IRQ]
            SET B, [A+DEVICE_HW]
            SET A, 1
            HWI [B+HW_PORT]
        POP X

    POP B
    POP A
    RET

; +0 device
m35fd_present:
    PUSH A
    PUSH B
    PUSH C
        SET A, 0
        SET B, [SP+4]
        SET B, [B+DEVICE_HW]
        HWI [B+HW_PORT]
        SET [SP+4], 0
        IFN B, 0
            SET [SP+3], 1
    POP C
    POP B
    POP A
    RET

; +2 Memory Start
; +1 Sector
; +0 Device
m35fd_write:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
    PUSH B
    PUSH X
    PUSH Y

        SET B, [Z+0]
        PUSH B
        JSR device_lock

            SET [B+M35FD_WAITING_THREAD], [current_thread]
            SET A, 3 ; write
            SET X, [Z+1]
            SET Y, [Z+2]
            HWI [B+HW_PORT]
            SET A, [Z+0]
            JSR m35fd_wait

        JSR free_spinlock

    POP Y
    POP X
    POP B
    POP A
    POP Z
    RET

; +2 Memory Start
; +1 Sector
; +0 Device
m35fd_read:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
    PUSH B
    PUSH X
    PUSH Y

        SET B, [Z+0]
        PUSH B
        JSR device_lock

            SET [B+M35FD_WAITING_THREAD], [current_thread]
            SET A, 2 ; read
            SET X, [Z+1]
            SET Y, [Z+2]
            HWI [B+HW_PORT]
            IFN B, 1
                SET PC, m35fd_panic
            SET A, [Z+0]
            JSR m35fd_wait

        JSR free_spinlock

    POP Y
    POP X
    POP B
    POP A
    POP Z
    RET

m35fd_panic:
    SET B, [Z+0]
    SET B, [B+DEVICE_HW]
    SET A, 0
    HWI [B+HW_PORT]

    PUSH KPANIC_DRIVER_ERROR
        JSR kernel_panic

; +1 Out ParamsInfo
; +0 Device
; Returns
; None
m35fd_get_params:
    PUSH A
        SET A, [SP+3]
        SET [A+MEDIA_PARAMS_SECTORS], 1440
        SET [A+MEDIA_PARAMS_SECTOR_SIZE], 512
    POP A
    RET

