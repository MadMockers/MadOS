
.define UMEM_PAGE_SIZE  512
.define UMEM_PAGES      104
.define UMEM_START      0x3000

; each entry here will point to an inode
; the first allocation needs to be bootstrapped with kernel memory
umem_table:

; +0 inode
; Returns:
; None
allocate_mem_inode:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
    PUSH B

        SET A, [Z]
        IFN [A], INODE_TYPE_MEMORY
            SET PC, .invalid_argument
        SET B, [A+4]
        SUB B, UMEM_START
        DIV B, UMEM_PAGE_SIZE

        SET A, [A+5]
        DIV A, UMEM_PAGE_SIZE
        
        ADD A, B

        ADD B, umem_table    ; B = start index
        ADD A, umem_table    ; A = end index

.loop_top:
        IFE B, A
            SET PC, .loop_break
        SET [B], [Z]
.loop_continue:
        ADD B, 1
        SET PC, .loop_top
.loop_break:

    POP B
    POP A
    POP Z
    RET

.invalid_argument:
    PUSH KPANIC_INVALID_ARGUMENT
        JSR kernel_panic

malloc:
    PUSH KPANIC_NOT_IMPLEMENTED
        JSR kernel_panic
