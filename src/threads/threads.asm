
root_thread:
    .reserve THREAD_SIZE

threads_spinlock:
    .reserve SPINLOCK_SIZE

current_thread:
    DAT 0

thread_id_counter:
    DAT 0

; scheduler needs its own stack
    .reserve 32
scheduler_stack:

scheduler_clock_device:
    DAT 0

scheduler_running:
    DAT 0

next_thread:
    DAT 0xFFFF

init_threads:
    SET [current_thread], root_thread
    PUSH threads_spinlock
        JSR spinlock_init
    ADD SP, 1

    SET [root_thread+THREAD_ID], [thread_id_counter]
    ADD [thread_id_counter], 1
    PUSH root_thread+THREAD_SPINLOCK
        JSR spinlock_init
    ADD SP, 1
    SET [root_thread+THREAD_PROC], kernel_process
    SET [root_thread+THREAD_STATE], THREAD_STATE_RUNNING
    SET [root_thread+THREAD_GLOB_NEXT], root_thread+THREAD_GLOB_NEXT
    SET [root_thread+THREAD_GLOB_PREV], root_thread+THREAD_GLOB_NEXT
    SET [root_thread+THREAD_PROC_NEXT], root_thread+THREAD_PROC_NEXT
    SET [root_thread+THREAD_PROC_PREV], root_thread+THREAD_PROC_NEXT
    SET [root_thread+THREAD_SPINLOCK_NEXT], root_thread+THREAD_SPINLOCK_NEXT
    SET [root_thread+THREAD_SPINLOCK_PREV], root_thread+THREAD_SPINLOCK_NEXT
    RET

init_scheduler:
    PUSH SCHEDULER_INT_RATE
    SET A, [system_clock]
    SET [scheduler_clock_device], A
    PUSH A
        JSR clock_set
        SET [SP+1], SCHEDULER_INT_MSG
        JSR clock_set_interrupt
    ADD SP, 2
    RET

; +2 Thread Context
; +1 Stack Size
; +0 PC
; Returns
; +0 Thread
thread_new:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
    PUSH B
    PUSH C

        PUSH kernel_process
            JSR proc_switch
        POP C

        PUSH THREAD_SIZE
            JSR kalloc
        POP A

        PUSH C
            JSR proc_switch
        POP 0

        PUSH threads_spinlock
        JSR acquire_spinlock
            SET [A+THREAD_ID], [thread_id_counter]
            ADD [thread_id_counter], 1
            SET [A+THREAD_PROC], [current_process]
            SET [A+THREAD_STATE], THREAD_STATE_PAUSED
            PUSH A
            ADD [SP], THREAD_SPINLOCK
                JSR spinlock_init
            ADD SP, 1
            SET B, [root_thread+THREAD_GLOB_PREV]
            PUSH 0
            PUSH B
            PUSH THREAD_GLOB_NEXT
            PUSH A
                JSR list_insert
            ADD SP, 4
            SET B, [current_process]
            SET B, [B+PROCESS_THREAD_PREV]
            PUSH THREAD_PROC_NEXT
            PUSH B
            PUSH THREAD_PROC_NEXT
            PUSH A
                JSR list_insert
            ADD SP, 4
            PUSH A
                ADD A, THREAD_SPINLOCK_NEXT
                SET [A], A
                SET [A+1], A
            POP A
        JSR spinlock_to_critical
        PUSH A
        ADD [SP], THREAD_SPINLOCK
        JSR acquire_spinlock
            JSR leave_critical
            PUSH A
            ADD [SP], THREAD_CONTEXT
            PUSH 0
            PUSH THREAD_CONTEXT_SIZE
                JSR memset
            ADD SP, 3

            PUSH [Z+1]
                JSR kalloc
            POP C
            SET [A+THREAD_STACK], C
            ADD C, [Z+1]
            SUB C, 3

            ; set the threads SP (which is at the end of the thread context)
            SET [A+THREAD_CONTEXT_END], C

            SET [C+2], thread_die
            SET [C+1], [Z+0]
            SET [C+0], [Z+2]
        JSR free_spinlock
        SET [Z], A
    POP C
    POP B
    POP A
    POP Z
    RET

; kills current thread
thread_die:
    JSR enter_critical
        IFE [current_thread], root_thread
            SET PC, .root_thread_died
        ; we can trash registers, because the thread is dying
        SET A, [current_thread]

        PUSH THREAD_GLOB_NEXT
        PUSH A
            JSR list_remove
        ADD SP, 2

        PUSH THREAD_PROC_NEXT
        PUSH A
            JSR list_remove
        ADD SP, 2
        SET C, A
        ADD A, THREAD_SPINLOCK_NEXT-SPINLOCK_OWNER_NEXT
        SET B, A

        ; release spinlocks
.release_top:
            PUSH SPINLOCK_OWNER_NEXT
            PUSH B
                JSR list_step
            POP B
            POP 0
            IFE B, A
                SET PC, .release_break
            PUSH B
            JSR free_spinlock ; cleans up stack
            SET PC, .release_top
.release_break:

        SET SP, scheduler_stack
        PUSH [C+THREAD_STACK]
            JSR kfree
        POP 0

        ; is our host process out of threads?
        SET A, [C+THREAD_PROC]
        IFE [A+PROCESS_THREAD_NEXT], [A+PROCESS_THREAD_PREV]
            JSR process_die

        PUSH C
            JSR kfree
        POP 0
        SET PC, scheduler

.root_thread_died:
    PUSH KPANIC_ROOT_THREAD_DIED
        JSR kernel_panic

yield:
    JSR enter_critical
        PUSH J
            SET J, [current_thread]
.ifdef DCPU_MAD
            GRM [J+THREAD_RINGMODE]
.endif
            ADD J, THREAD_SIZE-1
            SET [J], SP

            SET SP, J

            PUSH EX
            PUSH J
            PUSH I
            PUSH Z
            PUSH Y
            PUSH X
            PUSH C
            PUSH B
            PUSH A
            SET PC, scheduler
restore_point:
            POP A
            POP B
            POP C
            POP X
            POP Y
            POP Z
            POP I
            POP J
            POP EX
            POP SP
        POP J
    JSR leave_critical
    RET

scheduler:
    SET [scheduler_running], 1
    SET SP, scheduler_stack
    SET A, [current_thread]
    SET C, A
.next:
    PUSH THREAD_GLOB_NEXT
    PUSH A
        JSR list_step
    POP A
    ADD SP, 1
    SET B, [A+THREAD_STATE]
    AND B, 0x3
    IFE B, THREAD_STATE_RUNNING
        SET PC, .found
    IFE C, A
        SET PC, .allow_irq
    SET PC, .next

.found:
    SET SP, A
    SET [current_thread], A
    ADD SP, THREAD_CONTEXT
    SET [scheduler_running], 0
    SET PC, restore_point

.allow_irq:
    JSR leave_critical
    JSR enter_critical
    SET PC, .next

yield_from_interrupt:
    IFE [scheduler_running], 1
        RFI
    IAQ 0
    SET A, [SP]
.ifdef DCPU_MAD
    IFN [SP+2], 0
        DRM 0
.endif
    ADD SP, 1
.ifdef DCPU_MAD
    POP [SP]
.endif
    JSR yield
    RET
