
; interrupt namespaces:
; 0xC*** scheduler
; 0xF*** driver defined

irq_handlers:
    DAT 0
irq_handler_spinlock:
    .reserve SPINLOCK_SIZE

init_interrupts:
    IAS interrupt_handler

    PUSH irq_handler_spinlock
        JSR spinlock_init
    POP 0
    RET

interrupt_handler:
    IFE A, SCHEDULER_INT_MSG
        SET PC, yield_from_interrupt
    
    PUSH B
        SET B, A
        AND B, 0xF000
        IFE B, 0xF000
            JSR custom_irq
    POP B
    RFI

custom_irq:
    IFE [irq_handlers], 0
        RET
    PUSH B
        SET B, [irq_handlers]

.search_top:
        IFE A, [B+IRQ_IRQ]
            SET PC, .found
.search_cont:
        PUSH IRQ_LIST
        PUSH B
            JSR list_step
        POP B
        POP 0
        IFN B, [irq_handlers]
            SET PC, .search_top

.found:
        PUSH [B+IRQ_CONTEXT]
            JSR [B+IRQ_HANDLER]
        POP 0
.search_break:
        ; failed to find hander... do nothing

    POP B
    RET

; +1 Context
; +0 Handler Addr
; Returns
; +0 IRQ Stuct
register_irq_handler:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
    PUSH B
    PUSH C

        PUSH irq_handler_spinlock
        JSR acquire_spinlock

            PUSH IRQ_SIZE
                JSR kalloc
            POP A

            SET B, 0xF000 ; set B to start of custom irq namespace

            IFN [irq_handlers], 0
                SET PC, .do_search

            SET [irq_handlers], A
            PUSH A
            ADD [SP], IRQ_LIST
                JSR list_init
            POP 0
            SET PC, .fill_out

.do_search:
            SET C, [irq_handlers]

.search_top:
            IFN B, [C+IRQ_IRQ]
                SET PC, .search_cont
            SET PC, .found
.search_cont:
            ADD B, 1
            IFE B, 0 ; if B overflows past 0xFFFF..
                SET PC, .search_break
            PUSH IRQ_LIST
            PUSH C
                JSR list_step
            POP C
            POP 0
            IFN C, [irq_handlers]
                SET PC, .search_top
.search_break:
            ; failed to find a free IRQ
            SET [Z+0], 0
            SET PC, .done

.found:
            PUSH IRQ_LIST
            PUSH C
            PUSH IRQ_LIST
            PUSH A
                JSR list_insert
            ADD SP, 4
.fill_out:
            SET [A+IRQ_IRQ], B
            SET [A+IRQ_HANDLER], [Z+0]
            SET [A+IRQ_CONTEXT], [Z+1]
            SET [Z+0], A

.done:
        JSR free_spinlock

    POP C
    POP B
    POP A
    POP Z
    RET
