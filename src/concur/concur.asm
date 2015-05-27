
critical_counter:
    DAT 0

; critical sections are recursive (up to 2^16, anyway)
enter_critical:
    IAQ 1
    ADD [critical_counter], 1
    IFE [critical_counter], 0xFFFF
        SET PC, .overflow
    RET

.overflow:
    PUSH KPANIC_IAQ_OVERFLOW
        JSR kernel_panic

leave_critical:
    SUB [critical_counter], 1
    IFE [critical_counter], 0xFFFF
        SET PC, .underflow
    IFE [critical_counter], 0
        IAQ 0
    RET

.underflow:
    PUSH KPANIC_IAQ_UNDERFLOW
        JSR kernel_panic

; +0 Spinlock
; Returns
; None
spinlock_init:
    PUSH [SP+1]
    PUSH 0
    PUSH SPINLOCK_SIZE
        JSR memset
    ADD SP, 3
    RET

; IMPORTANT NOTE!
; +0 Spinlock
; Returns
; None
acquire_spinlock:
    PUSH A
    PUSH B
        JSR enter_critical
            SET A, [SP+3]
            IFE [A+SPINLOCK_OWNER], [current_thread]
                SET PC, .already_owned
            SET PC, .first_try

.retry:
        JSR enter_critical
.first_try:
            IFN [A+SPINLOCK_OWNER], 0
                SET PC, .failed
            SET PC, .acquired
.failed:
            IFN [critical_counter], 1
                SET PC, .deadlock
        JSR leave_critical
        JSR yield
        SET PC, .retry
.acquired:
            SET [A+SPINLOCK_OWNER], [current_thread]
            ADD [A+SPINLOCK_REFCOUNT], 1

            ; usually we'd use a spinlock for editting this, but that would cause some infinite recursion here
            ; instead we delay leaving the critical section until after we have inserted the new spinlock
            SET B, [current_thread]
            PUSH 0
            PUSH [B+THREAD_SPINLOCK_PREV]
            PUSH SPINLOCK_OWNER_NEXT
            PUSH A
                JSR list_insert
            ADD SP, 4
        JSR leave_critical
        SET PC, .return
.already_owned:
        JSR leave_critical
        ADD [A+SPINLOCK_REFCOUNT], 1
.return:
    POP B
    POP A
    RET

.deadlock:
    PUSH KPANIC_DEADLOCK
        JSR kernel_panic

; +0 Spinlock
; Returns
; None
; NOTE: this function cleans up the stack!
free_spinlock:
    PUSH A
        SET A, [SP+2]
        JSR enter_critical            
            IFL [A+SPINLOCK_REFCOUNT], 2
                SET PC, .complete_free
            SUB [A+SPINLOCK_REFCOUNT], 1
            SET PC, .return

.complete_free:
            PUSH SPINLOCK_OWNER_NEXT
            PUSH A
                JSR list_remove
            POP A
            ADD SP, 1
            SET [A+SPINLOCK_OWNER], 0
            SET [A+SPINLOCK_REFCOUNT], 0
.return:
        JSR leave_critical
    POP A
    ; take top of stack, pop it out, and put it in the new top of stack
    SET [SP], POP
    RET

; this function elevates to critical, while freeing the spinlock
; +0 Spinlock
; Returns
; None
; NOTE: this function cleans up the stack!
spinlock_to_critical:
    JSR enter_critical
    SET PC, free_spinlock

