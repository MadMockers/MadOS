
; process struct
; +0    PID

; +1    I-Node List
; +2    Spinlock
; +3    Next Process
; +4    Previous Process

kernel_process:
    .reserve PROCESS_LENGTH

current_process_spinlock:
    .reserve SPINLOCK_SIZE

current_process:
    DAT kernel_process

init_process:

    PUSH current_process_spinlock
        JSR spinlock_init
    ADD SP, 1

    SET A, kernel_process

    PUSH A
    ADD [SP], PROCESS_SPINLOCK
        JSR spinlock_init
    POP 0

    SET [A+PROCESS_ID], KERNEL_PID        ; 0 = kernel process
    PUSH A
        ADD A, PROCESS_KALLOC_NEXT
        SET [A], A
        SET [A+1], A
    POP A
    PUSH A
        ADD A, PROCESS_NEXT
        SET [A], A
        SET [A+1], A
    POP A
    PUSH A
        ADD A, PROCESS_THREAD_NEXT
        SET [A], A
        SET [A+1], A
    POP A

    ; give the root memory allocation to ourselves
    PUSH PROCESS_KALLOC_NEXT
    PUSH A
    PUSH KALLOC_PROC_LIST
    PUSH mem_root_alloc
        JSR list_insert
    ADD SP, 4

    ; attach the root thread to ourselves
    PUSH PROCESS_THREAD_NEXT
    PUSH current_process
    PUSH THREAD_PROC_NEXT
    PUSH root_thread
        JSR list_insert_behind
    ADD SP, 4

    RET

; TODO
process_die:
    RET

; +0 Target Process
; Returns
; +0 Old Process
proc_switch:
    PUSH current_process_spinlock
    JSR acquire_spinlock
        PUSH [current_process]
            SET [current_process], [SP+3]
        POP [SP+2]
    JSR free_spinlock
    RET

