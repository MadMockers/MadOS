
drivers:
    DAT 0xFFFF

drivers_spinlock:
.reserve SPINLOCK_SIZE

driver_id_counter:
    DAT 0
driver_id_spinlock:
.reserve SPINLOCK_SIZE

init_drivers:
    PUSH drivers_spinlock
        JSR spinlock_init
    SET [SP], driver_id_spinlock
        JSR spinlock_init
    ADD SP, 1
    RET

;+4 Hardware ID Low
;+3 Hardware ID High
;+2 Hardware Version
;+1 Class
;+0 Function Count
.define VAR_HASCHILD 0
driver_create:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
    PUSH B
    PUSH Y
    PUSH 0  ; initialize HASCHILD to 0
    SET Y, SP

        ; if HW id is 0xFFFFFFFF
        IFE [Z+4], 0xFFFF
            IFE [Z+3], 0xFFFF
                SET [Y+VAR_HASCHILD], 1

        PUSH [Z+0]
        ADD [SP], DRIVER_SIZE
        IFE [Y+VAR_HASCHILD], 0
            ADD [SP], HWTYPE_SIZE

            JSR kalloc
        POP A

        IFE [Y+VAR_HASCHILD], 1
            SET PC, .skip_hwtype

        ; set HWTYPE
        SET B, A
        ADD B, DRIVER_SIZE
        ADD B, [Z+0]
        SET [A+DRIVER_HWTYPE], B
        SET [B+HWTYPE_ID+0], [Z+4]
        SET [B+HWTYPE_ID+1], [Z+3]
        SET [B+HWTYPE_VERSION], [Z+2]
        SET PC, .skip_child
.skip_hwtype:
        SET [A+DRIVER_HWTYPE], 0xFFFF
.skip_child:
        SET [A+DRIVER_CLASS], [Z+1]
        SET [A+DRIVER_FUNC_COUNT], [Z+0]
        PUSH A
            ADD A, DRIVER_NEXT
            SET [A], A
            SET [A+1], A
        POP A

        SET [Z+0], A

        IFN [drivers], 0xFFFF
            SET PC, .not_first
        SET [drivers], A
        SET PC, .return

.not_first:
        PUSH B
            SET B, [drivers]
            SET B, [B+DRIVER_PREV]
            PUSH drivers_spinlock
            JSR acquire_spinlock
                PUSH 0
                PUSH B
                PUSH DRIVER_NEXT
                PUSH A
                    JSR list_insert
                ADD SP, 4
            JSR free_spinlock
        POP B

.return:
    ADD SP, 1
    POP Y
    POP B
    POP A
    POP Z
    RET

; Gets a unique driver ID, and leaves it on stack
device_get_uid:
    PUSH 0
    SET [SP], [SP+1]
    PUSH driver_id_spinlock
    JSR acquire_spinlock
        SET [SP+2], [driver_id_counter]
        ADD [driver_id_counter], 1
    JSR free_spinlock
    RET

; +0 Driver Class
; Returns
; +0 Null terminated driver* array
driver_array_from_class:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
    PUSH B
    PUSH C
    PUSH X

        PUSH drivers_spinlock
        JSR acquire_spinlock
            SET A, [Z+0]
            SET B, [drivers]
            SET C, B

            SET X, 0
.count_top:
            IFE [C+DRIVER_CLASS], A
                ADD X, 1
.count_cont:
            PUSH DRIVER_NEXT
            PUSH C
                JSR list_step
            POP C
            POP 0
            IFE C, B
                SET PC, .count_break
            SET PC, .count_top
.count_break:
            IFN X, 0
                SET PC, .found_some

            ; we didn't find any :(
            SET [Z+0], 0
            SET PC, .done
.found_some:
            ; allocate an array for the result
            ADD X, 1
            PUSH X
                JSR kalloc
            POP X

            PUSH X
                SET B, [drivers]
                SET C, B
.fill_top:
                IFN [C+DRIVER_CLASS], A
                    SET PC, .fill_cont
                SET [X], C
                ADD X, 1
.fill_cont:
                PUSH DRIVER_NEXT
                PUSH C
                    JSR list_step
                POP C
                POP 0
                IFE C, B
                    SET PC, .fill_break
                SET PC, .fill_top
.fill_break:
                ; null terminate array
                SET [X], 0
            ; store array in return value
            POP [Z+0]
.done:
        JSR free_spinlock

    POP X
    POP C
    POP B
    POP A
    POP Z
    RET
    
; +3 Device Array
; +2 Device Struct Size
; +1 Device Count
; +0 HwInfo
; Returns
; +0 Display
;driver_get_device_from_port:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
    PUSH B
    PUSH C

        SET A, [Z+0]
        SET B, [Z+3]
        SET C, [Z+1]

.top:
        IFN [B+DEVICE_HW], A
            SET PC, .continue

        SET [Z], B
        SET PC, .break
.continue:
        IFE C, 0
            SET PC, .break_failed
        SUB C, 1
        ADD B, [Z+2]
        SET PC, .top
.break_failed:
        SET [Z], 0xFFFF
.break:

    POP C
    POP B
    POP A
    POP Z
    RET

; +0 driver class
; returns
; +0 Driver
; +1 Hardware
find_driver_hardware_pair:
    PUSH [SP]
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
    PUSH B

        PUSH [Z+1]
            JSR driver_array_from_class
            SET A, [SP]
.find_top:
            IFE [A], 0
                SET PC, .find_break_failed

            PUSH [A]
            PUSH 0
                JSR hardware_get_info
            POP B
            POP 0

            IFN B, 0xFFFF
                SET PC, .find_break
.find_cont:
            ADD A, 1
            SET PC, .find_top
.find_break_failed:
            SET [Z+0], 0xFFFF
            SET [Z+1], 0xFFFF

            SET PC, .done
.find_break:
            SET [Z+0], [A]
            SET [Z+1], B
.done:
            JSR kfree
        POP 0
    POP B
    POP A
    POP Z
    RET

; +0 Device
device_lock:
    ADD [SP+1], DEVICE_SPINLOCK
    SET PC, acquire_spinlock
