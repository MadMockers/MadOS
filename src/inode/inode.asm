
; inode struct
; +0 type
; +1 idx
; +2 next inode
; +3 prev inode
; ...

;--- Memory
; +4 process
; +5 flags: 11bits-Unallocated | 1bit-Kernel | 1bit-Pagable | 3bit-Access
; +6 start page
; +7 page count
; +8 paged file inode (0 = not paged)

inode_spinlock:
    .reserve SPINLOCK_SIZE

root_inode:
    .reserve INODE_BASE_SIZE

inode_index:
    DAT 1

init_inodes:
    PUSH A

        PUSH inode_spinlock
            JSR spinlock_init
        ADD SP, 1

        SET A, root_inode
        SET [A+INODE_TYPE], INODE_TYPE_UNINITIALIZED    ; type
        SET [A+INODE_INDEX], 0                ; index
        SET [A+INODE_NEXT], A               ; next
        ADD [A+INODE_NEXT], INODE_NEXT      ; next
        SET [A+INODE_PREV], A               ; prev
        ADD [A+INODE_PREV], INODE_NEXT      ; prev
        
    POP A
    RET

; +1 Size
; +0 Type
; Return
; +0 Inode

; Stack
; +0 Old Process
inode_allocate:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH Y
    PUSH A
    PUSH B

        SUB SP, 1
        SET Y, SP

            PUSH kernel_process
                JSR proc_switch
            POP [Y]

            PUSH [Z+1]
                JSR kalloc
            POP A

            PUSH inode_spinlock
            JSR acquire_spinlock
                SET B, [root_inode+INODE_PREV]
                PUSH 0
                PUSH B
                PUSH INODE_NEXT
                PUSH A
                    JSR list_insert
                ADD SP, 4
            JSR free_spinlock

            SET [A+INODE_TYPE], [Z]

            SET B, [Y]

            PUSH [Y]
                JSR proc_switch
            ADD SP, 1

            SET [Z], A

        ADD SP, 1

    POP B
    POP A
    POP Y
    POP Z
    RET

; Returns
; +0 available index
inode_get_index:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
    PUSH B

        PUSH inode_spinlock
        JSR acquire_spinlock
.restart:
            SET A, [inode_index]
            ADD [inode_index], 1

            SET B, root_inode

.top:
            IFE A, [B+INODE_INDEX]
                SET PC, .restart
.continue:
            SET B, [B+INODE_NEXT]
            SUB B, INODE_NEXT

            IFE B, root_inode
                SET PC, .break
            SET PC, .top
.break:
        JSR free_spinlock
        SET [Z], A

    POP B
    POP A
    POP Z
    RET


.inode_mismatch:
    PUSH KPANIC_INODE_TYPE_MISMATCH
        JSR kernel_panic
;--------------------------------




