
.define KPANIC_TEST                 0x00
.define KPANIC_NOT_ALLOCATED        0x01
.define KPANIC_ALREADY_ALLOCATED    0x02
.define KPANIC_OUT_OF_MEMORY        0x03
.define KPANIC_NOT_IMPLEMENTED        0x04
.define KPANIC_INVALID_ARGUMENT        0x05
.define KPANIC_INDEX_OUT_OF_BOUNDS    0x06
.define KPANIC_INODE_TYPE_MISMATCH    0x07
.define KPANIC_DEADLOCK             0x08
.define KPANIC_IAQ_OVERFLOW         0x09
.define KPANIC_IAQ_UNDERFLOW        0x0A
.define KPANIC_NO_CONSOLE            0x0B
.define KPANIC_NO_CLOCK                0x0C
.define KPANIC_ROOT_THREAD_DIED        0x0D
.define KPANIC_EXECUTION_AT_0        0x0E
.define KPANIC_DRIVER_ERROR            0x0F
.define KPANIC_MAX_ERROR            0x10

; +0 Error Number
kernel_panic:
    IAS 1

    SET A, 0
    SET B, .panic_vram
    HWI 0             ; hardcoded for now

    SET A, 3
    SET B, 0x4
    HWI 0

.ifdef DCPU_MAD
    DMP [SP]
    DMP [SP+1]
.endif

.ifdef HELPFUL_PANICS
    ; if we have a console, try to be more helpful
    IFN [console], 0
        SET PC, .print_msg
.endif

.done:
.ifdef DCPU_MAD
    DAT 0    ; stops execution
.endif
.loop:
    SET PC, .loop

.panic_vram:
    .dat 0x4050
    .dat 0x4041
    .dat 0x404E
    .dat 0x4049
    .dat 0x4043

.ifdef HELPFUL_PANICS
.print_msg:
    SET A, [SP+1]
    SET SP, 0

    dat 0x800
    ; make console scary red
    PUSH 0xC0
    PUSH [console]
        JSR tty_setfmt
    ADD SP, 2

    PUSH .str_kpanic
        JSR debug_print
    POP 0
    IFL A, KPANIC_MAX_ERROR
        SET PC, .valid_msg
    PUSH .str_bad_panic_code
        JSR debug_print
    POP 0
    SET PC, .done

.valid_msg:
    ADD A, .str_table
    PUSH [A]
        JSR debug_print
    POP 0
    SET PC, .done

.str_kpanic:
    .asciiz "KERNEL PANIC"
.str_bad_panic_code:
    .asciiz "BAD PANIC CODE"

.str_table:
    DAT .str_test
    DAT .str_not_allocated
    DAT .str_already_allocated
    DAT .str_oom
    DAT .str_not_implemented
    DAT .str_invalid_arg
    DAT .str_out_of_bounds
    DAT .str_inode_type_mismatch
    DAT .str_deadlock
    DAT .str_iaq_overflow
    DAT .str_iaq_underflow
    DAT .str_iaq_no_console
    DAT .str_no_clock
    DAT .str_root_thread_died
    DAT .str_execution_at_0
    DAT .str_driver_error

.str_test:
    .asciiz "Test"
.str_not_allocated:
    .asciiz "Not Allocated"
.str_already_allocated:
    .asciiz "Already Allocated"
.str_oom:
    .asciiz "Out Of Memory"
.str_not_implemented:
    .asciiz "Not Implemented"
.str_invalid_arg:
    .asciiz "Invalid Argument"
.str_out_of_bounds:
    .asciiz "Index Out Of Bounds"
.str_inode_type_mismatch: ; legacy?
    .asciiz "I-Node Type Mismatch"
.str_deadlock:
    .asciiz "Dead Lock"
.str_iaq_overflow:
    .asciiz "Interrupt Queue Overflow"
.str_iaq_underflow:
    .asciiz "Interrupt Queue Underflow"
.str_iaq_no_console:
    ; somewhat pointless
    DAT 0
.str_no_clock:
    .asciiz "No Clock"
.str_root_thread_died:
    .asciiz "Thread 0 Died"
.str_execution_at_0:
    .asciiz "Execution At 0"
.str_driver_error:
    .asciiz "Generic Driver Error"
.endif
