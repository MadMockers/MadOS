
; kernel memory management

.define KMEM_PAGE_SIZE    8
.define PAGE_COUNT    (0x10000-kernel_end)/PAGE_SIZE

.define MEM_DEFAULT_ALLOC_SIZE    8
.define MEM_START (kernel_end+PAGE_SIZE-1)&(~(PAGE_SIZE-1))

kmem_start:
kmem_next_free:
kmem_pages:
kmem_table:
kmem_table_end:

memory_spinlock:
    .reserve SPINLOCK_SIZE

mem_root_alloc:
    .reserve KALLOC_SIZE

page_table:
    DAT 0

; initialize kernel memory, and page table
init_kmem:
    PUSH A
    PUSH B

        PUSH memory_spinlock
            JSR spinlock_init
        ADD SP, 1

        SET A, mem_root_alloc
        SET [A+KALLOC_PROCESS], kernel_process
        SET [A+KALLOC_FLAGS], 0x17    ; kernel, not pagable, rwx
        SET [A+KALLOC_STARTPAGE], 0
        SET [A+KALLOC_PAGECOUNT], 3
        SET [A+KALLOC_PAGED_INODE], 0xFFFF
        PUSH A
            ADD A, KALLOC_LIST
            SET [A+LIST_NEXT], A
            SET [A+LIST_PREV], A
        POP A

        SET B, [A+KALLOC_PAGECOUNT]
        MUL B, PAGE_SIZE

        PUSH [A+KALLOC_STARTPAGE]
            JSR get_page_address
        POP A

        SET [A+PAGEDESC_ALLOC_SIZE], KMEM_PAGE_SIZE
        PUSH KMEM_PAGE_SIZE
        PUSH B
            JSR get_max_alloc_count
        POP [A+PAGEDESC_ALLOC_MAX]
        ADD SP, 1
        SET [A+PAGEDESC_ALLOC_COUNT], 0

        PUSH mem_root_alloc
        PUSH PAGE_COUNT
            JSR alloc_in_kalloc
        POP [page_table]
        ADD SP, 1

        SET A, [page_table]
        SET [A+0], mem_root_alloc
        SET [A+1], mem_root_alloc
        SET [A+2], mem_root_alloc
        
    POP B
    POP A
    RET

; +1 Alloc size
; +0 Pool size
; Returns
; +0 Alloc count
get_max_alloc_count:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
    PUSH B
    PUSH C
    PUSH Y
    SUB SP, 2
    SET Y, SP
        SET A, [Z+1]   ; alloc size
        SET C, A
        SET B, [Z+0]   ; total size

        SUB B, PAGEDESC_SIZE

        PUSH A
        PUSH 0
        PUSH B
        PUSH 0
            JSR 32mul
            PUSH 8
            PUSH 0
                JSR 32mul
                MUL A, 8
                ADD A, 1
                SET [SP+3], A
                SET [SP+2], 0
                JSR 32div
                SET [SP+3], C
                SET [SP+2], 0
                JSR 32div
            ADD SP, 1
            POP [Z+0]
    ADD SP, 6
;        ADD SP, 4
;    ADD SP, 2
    POP Y
    POP C
    POP B
    POP A
    POP Z
    RET

; +0 Page index
; Returns:
; +0 Address
get_page_address:
    PUSH A
        SET A, [SP+2]
        MUL A, PAGE_SIZE
        ADD A, MEM_START
        SET [SP+2], A
    POP A
    RET

; +0 Requested Memory
; Returns:
; +0 Kalloc (Locked spinlock)
; kernel mem alloc
;
; Stack:
; +0 scratchpad
mem_find_kalloc:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
    PUSH B
    PUSH C
    PUSH X

        SET A, [current_process]

        ADD A, PROCESS_KALLOC_NEXT-KALLOC_PROC_LIST
        SET B, A
        
.kalloc_loop_top:
            PUSH KALLOC_PROC_LIST
            PUSH A
                JSR list_step
            POP A
            ADD SP, 1
            IFE A, B
                SET PC, .kalloc_loop_break_notfound
            PUSH A
            ADD [SP], KALLOC_SPINLOCK
            JSR acquire_spinlock
                PUSH A
                    JSR kalloc_get_free
                POP X
                IFG [Z], X
                    SET PC, .kalloc_loop_continue
            SET [Z], A
            SET PC, .return
.kalloc_loop_continue:
            JSR free_spinlock
            SET PC, .kalloc_loop_top
.kalloc_loop_break_notfound:
            SET [Z], 0xFFFF
            ; dummy spinlock to remove from stack
            PUSH 0
.return:
        ; spinlock is still on stack
        POP 0
    POP X
    POP C
    POP B
    POP A
    POP Z
    RET

; Inputs
; +1 Alloc Size
; +0 Page Count
; Returns
; +0 Inode
.define ARG_COUNT 0
.define ARG_ALLOC 1
kalloc_page:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
    PUSH B
    PUSH C

        PUSH memory_spinlock
        JSR acquire_spinlock

        IFE [Z], 0
            SET PC, .invalid_arg
        IFG [Z], PAGE_COUNT-1
            SET PC, .out_of_memory

        ; put KALLOC struct on stack to avoid catch 22
        SUB SP, KALLOC_SIZE
            SET A, SP

            PUSH A
                SET A, [page_table]
                SET B, 0
                SET C, 0
.top:
                IFE B, [Z+ARG_COUNT]
                    SET PC, .break

                ADD B, 1
                IFN [A], 0
                    SET B, 0

.continue:
                ADD C, 1
                ADD A, 1
                IFE C, PAGE_COUNT
                    SET PC, .page_out
                SET PC, .top
.break:
                SUB C, [Z+ARG_COUNT]
                SET A, [page_table]
                ADD A, C

                PUSH A
                PUSH [SP]
                PUSH B
                    JSR memset
                ADD SP, 3
            POP A

            SET [A+KALLOC_PROCESS], [current_process]
            SET B, 0x7 ; rwx
            IFE [current_process], kernel_process
                BOR B, 0x10
            SET [A+KALLOC_FLAGS], B
            SET [A+KALLOC_STARTPAGE], C
            SET [A+KALLOC_PAGECOUNT], [Z+ARG_COUNT]
            SET [A+KALLOC_PAGED_INODE], 0

            PUSH A
            ADD [SP], KALLOC_SPINLOCK
                JSR spinlock_init
                JSR acquire_spinlock
            ADD SP, 1

            PUSH PROCESS_KALLOC_NEXT
            PUSH [current_process]
            PUSH KALLOC_PROC_LIST
            PUSH A
                JSR list_insert_behind
            ADD SP, 4

            ; if 'alloc size' is 0, this is an unmanaged page
            IFE [Z+ARG_ALLOC], 0
                SET PC, .skip_pagedesc
            PUSH A
                PUSH C
                    JSR get_page_address
                POP A

                SET [A+PAGEDESC_ALLOC_SIZE], [Z+ARG_ALLOC]
                SET B, [Z+ARG_COUNT]
                MUL B, PAGE_SIZE
                SUB B, PAGEDESC_SIZE

                PUSH [Z+ARG_ALLOC]
                PUSH B
                    JSR get_max_alloc_count
                POP [A+PAGEDESC_ALLOC_MAX]
                ADD SP, 1

                SET [A+PAGEDESC_ALLOC_COUNT], 0

                SET B, [A+PAGEDESC_ALLOC_MAX]
                SHR B, 3    ; divide by 8
                ADD A, PAGEDESC_SIZE

                PUSH A
                PUSH 0
                PUSH B
                    JSR memset
                ADD SP, 3
            POP A

.skip_pagedesc:

            ; finally allocate memory for the KALLOC struct
            PUSH C
                PUSH kernel_process
                    JSR proc_switch
                POP B

                PUSH KALLOC_SIZE
                    JSR kalloc
                POP C

                PUSH C
                PUSH A
                PUSH KALLOC_SIZE
                    JSR memcpy
                ADD SP, 3

                PUSH A
                ADD [SP], KALLOC_SPINLOCK
                    JSR spinlock_to_critical ; cleans up stack

                    ; remove the stack copy from the kalloc list
                    PUSH KALLOC_PROC_LIST
                    PUSH A
                        JSR list_remove
                    ADD SP, 2

                    SET A, C
                    PUSH A
                    ADD [SP], KALLOC_SPINLOCK
                        JSR spinlock_init
                        JSR acquire_spinlock    ; this function returns a locked kalloc struct
                    ADD SP, 1
                JSR leave_critical

                PUSH PROCESS_KALLOC_NEXT
                PUSH [current_process]
                PUSH KALLOC_PROC_LIST
                PUSH A
                    JSR list_insert_behind
                ADD SP, 4

                ; add new allocation to global KALLOC list as well
                PUSH KALLOC_LIST
                PUSH mem_root_alloc
                PUSH KALLOC_LIST
                PUSH A
                    JSR list_insert_behind
                ADD SP, 4

                PUSH B
                    JSR proc_switch
                ADD SP, 1
            POP C

            ; page table needs to be updated (again) this time with the kalloced memory
            ; (instead of the memory on the stack)
            PUSH A
                SET A, [page_table]
                SET B, [Z+ARG_COUNT]
                ADD A, C
.top_set1:
                IFE B, 0
                    SET PC, .break_set1
                SET [A], [SP]   ; kalloc is on top of stack
.continue_set1:
                ADD A, 1
                SUB B, 1
                SET PC, .top_set1
.break_set1:
            POP [Z]

        ADD SP, KALLOC_SIZE

        JSR free_spinlock
        
    POP C
    POP B
    POP A
    POP Z
    RET

.page_out:
    PUSH KPANIC_NOT_IMPLEMENTED
        JSR kernel_panic

.invalid_arg:
    PUSH KPANIC_INVALID_ARGUMENT
        JSR kernel_panic

.out_of_memory:
    PUSH KPANIC_OUT_OF_MEMORY
        JSR kernel_panic
;--------------------------------

;--------------------------------
; +0 Kalloc Struct
; Returns
; None
kalloc_page_free:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
    PUSH B
    PUSH C

        SET A, [Z+0]
        PUSH memory_spinlock
        JSR acquire_spinlock
            PUSH KALLOC_LIST
            PUSH A
                JSR list_remove
            ADD SP, 2
            PUSH KALLOC_PROC_LIST
            PUSH A
                JSR list_remove
            ADD SP, 2

            SET B, [page_table]
            ADD B, [A+KALLOC_STARTPAGE]
            SET C, [A+KALLOC_PAGECOUNT]
.clear_top:
            SET [B], 0
.clear_cont:
            SUB C, 1
            ADD B, 1
            IFN C, 0
                SET PC, .clear_top
.clear_break:
            
            PUSH A
                JSR kfree
            POP 0
        JSR free_spinlock

    POP C
    POP B
    POP A
    POP Z
    RET
;--------------------------------

;--------------------------------
; +1 Alloc Size
; +0 Size
; Returns
; +0 Required Pages
mem_get_required_pages:
    PUSH A
    PUSH B
        SET A, [SP+3]   ; Count
        SET B, A
        DIV B, [SP+4]
        MUL B, 2
        ADD B, 15
        DIV B, 16
        ADD B, PAGEDESC_SIZE+1
        ADD B, A
        DIV B, PAGE_SIZE
        ADD B, 1
        SET [SP+3], B
    POP B
    POP A
    RET
;--------------------------------

;--------------------------------
; +0 Size
; Returns
; +0 address
.define ARG_SIZE 0
kalloc:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
    PUSH B

        SET A, [Z+ARG_SIZE]
        IFE A, 0
            SET PC, .invalid_argument

        PUSH A
            JSR mem_find_kalloc
        POP B

        IFE B, 0xFFFF
            SET PC, .new_inode
.inode_alloc:
        PUSH B
        PUSH A
            JSR alloc_in_kalloc
        POP [Z]
        ADD SP, 1
        ; unlock spinlock
        PUSH B
        ADD [SP], KALLOC_SPINLOCK
        JSR free_spinlock ; free_spinlock cleans up stack

.return:
    POP B
    POP A
    POP Z
    RET

.invalid_argument:
        SET [Z+0], 0
        SET PC, .return

.new_inode:
        PUSH MEM_DEFAULT_ALLOC_SIZE
        PUSH A
            ; if we are currently the kernel process, add enough space for
            ; possible KALLOC struct
            IFE [current_process], kernel_process
                ADD [SP], KALLOC_SIZE
            JSR mem_get_required_pages
            JSR kalloc_page
        POP B
        ADD SP, 1
        SET PC, .inode_alloc
;--------------------------------

;--------------------------------
; Will cause kernel panic if not enough memory (consecutive!) in inode!
; +1 Memory Inode
; +0 Size
; Returns
; +0 Address
.define ARG_SIZE 0
.define ARG_KALLOC 1
alloc_in_kalloc:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
    PUSH B
    PUSH C

        SET A, [Z+ARG_KALLOC]
        PUSH [A+KALLOC_STARTPAGE]
            JSR get_page_address
        POP B

        ; size needs to be in multiples of the alloc size for this set of pages
        ; the following divides by the alloc size, rounding up
        SET A, [Z+ARG_SIZE]
        ADD A, [B+PAGEDESC_ALLOC_SIZE]
        SUB A, 1
        DIV A, [B+PAGEDESC_ALLOC_SIZE]

        PUSH A
        PUSH [Z+1]
            JSR kalloc_find_free_space
        POP C
        POP 0

        IFE C, -1
            SET PC, .out_of_memory

        PUSH A
        PUSH C
            ; SP+3 BitField Address
            ; SP+2 Value Width
            ; SP+1 Index
            ; SP+0 Value
            PUSH B
            ADD [SP], 3
            PUSH 2
.set_top:
                PUSH C
                PUSH 3
                IFE A, 1
                    SUB [SP], 1
                
                    JSR bitfield_set_value
                ADD SP, 2

                ADD C, 1
                SUB A, 1
                IFN A, 0
                    SET PC, .set_top
.set_break:
            ADD SP, 2
        POP C
        POP A
        ADD [B+PAGEDESC_ALLOC_COUNT], A

        SET A, [B+PAGEDESC_ALLOC_MAX]
        ADD A, 7
        DIV A, 8

        MUL C, [B+PAGEDESC_ALLOC_SIZE]
        
        ADD B, PAGEDESC_SIZE
        ADD B, A
        ADD B, C

        SET [Z], B

.return:
    POP C
    POP B
    POP A
    POP Z
    RET

.out_of_memory:
;    SET [Z], 0
;    SET PC, .return
    PUSH KPANIC_OUT_OF_MEMORY
        JSR kernel_panic
;--------------------------------

;--------------------------------
; +0 Kalloc
; Return
; +0 Free Memory (in words)
kalloc_get_free:
    PUSH A
    PUSH B
        SET A, [SP+3]
        SET A, [A+KALLOC_STARTPAGE]
        PUSH A
            JSR get_page_address
        POP A
        SET B, [A+PAGEDESC_ALLOC_MAX]
        SUB B, [A+PAGEDESC_ALLOC_COUNT]
        MUL B, [A+PAGEDESC_ALLOC_SIZE]
        SET [SP+3], B
    POP B
    POP A
    RET
;--------------------------------

;--------------------------------
; +1 Size
; +0 kalloc
; Returns
; +0 Index

; stack:
; -3 Max Alloc
.define ARG_KALLOC 0
.define ARG_SIZE 1
.define VAR_MAX -3
kalloc_find_free_space:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    SUB SP, 1
    PUSH A
    PUSH B
    PUSH C
    PUSH X
    PUSH Y

        SET A, [Z+ARG_KALLOC]

        PUSH [A+KALLOC_STARTPAGE]
            JSR get_page_address
        POP B

        SET [Z+VAR_MAX], [B+PAGEDESC_ALLOC_MAX]

        ; set B to the bitfield describing this piece of memory
        ADD B, PAGEDESC_SIZE

        SET C, 0
        SET X, 0
        SET Y, 0
.find_top:
            SET A, [B]
            SHR A, X
            AND A, 3
            IFB A, MEM_FLAG_ALLOCATED
                SET Y, -1
            ADD Y, 1
.find_continue:
            ADD X, 2
            IFL X, 16
                SET PC, .same_word
            SET X, 0
            ADD B, 1
.same_word:
            ADD C, 1
            IFE Y, [Z+ARG_SIZE]
                SET PC, .find_break_success
            IFE C, [Z+VAR_MAX] ; end of memory
                SET PC, .find_break_failed
            
            SET PC, .find_top

.find_break_failed:
        SET [Z], -1
        SET PC, .return

.find_break_success:
        SUB C, [Z+ARG_SIZE]
        SET [Z], C
    
.return:
    POP Y
    POP X
    POP C
    POP B
    POP A
    ADD SP, 1
    POP Z
    RET
;-----------------

;-----------------
; +0 Address
; Return
; +0 Kalloc struct
kmem_get_kalloc_from_address:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
    PUSH B
    PUSH C

        PUSH memory_spinlock
        JSR acquire_spinlock
            SET A, [Z+0]
            SUB A, MEM_START
            DIV A, PAGE_SIZE
            SET B, mem_root_alloc
            SET C, B

.search_top:
                IFG [C+KALLOC_STARTPAGE], A
                    SET PC, .search_cont
                PUSH B
                    SET B, A
                    SUB A, [C+KALLOC_STARTPAGE]
                    IFL A, [C+KALLOC_PAGECOUNT]
                        SET PC, .found
                POP B
                SET PC, .search_cont
.found:
                POP B
                SET [Z+0], C
                SET PC, .done
.search_cont:
                PUSH KALLOC_LIST
                PUSH C
                    JSR list_step
                POP C
                POP 0
                IFE C, B
                    SET PC, .search_break
                SET PC, .search_top
.search_break:
                SET [Z+0], 0
.done:
        JSR free_spinlock

    POP C
    POP B
    POP A
    POP Z
    RET
;-----------------

;-----------------
; +0 Address
; Return
; None
kfree:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH 0 ; KALLOC var
    PUSH A
    PUSH B
    PUSH C

        SET A, [Z+0]

        ; allow 'freeing' null
        IFE A, 0
            SET PC, .null_free

        PUSH memory_spinlock
        JSR acquire_spinlock

            PUSH A
                JSR kmem_get_kalloc_from_address
            POP A
            SET [Z-3], A
            PUSH [A+KALLOC_STARTPAGE]
                JSR get_page_address
            POP A

            SET C, [A+PAGEDESC_ALLOC_MAX]
            ADD C, 7
            DIV C, 8
            
            SET B, [Z+0]
            SUB B, PAGEDESC_SIZE
            SUB B, C
            SUB B, A

            DIV B, [A+PAGEDESC_ALLOC_SIZE]

            SET C, [A+PAGEDESC_ALLOC_MAX]

            PUSH X
            PUSH A
            ADD [SP], PAGEDESC_SIZE
            PUSH 2      ; bitfield width
.kfree_top:
                IFL B, C
                    SET PC, .kfree_loop
                PUSH KPANIC_INDEX_OUT_OF_BOUNDS
                    JSR kernel_panic
.kfree_loop:
                PUSH B
                    JSR bitfield_get_value
                POP X
                IFC X, 2
                    SET PC, .not_allocated

                SUB [A+PAGEDESC_ALLOC_COUNT], 1

                PUSH B
                PUSH 0
                    JSR bitfield_set_value
                ADD SP, 2
                
                IFC X, 1
                    SET PC, .kfree_break

                ADD B, 1
                SET PC, .kfree_top
.kfree_break:
            ADD SP, 2 ; clean up bitfield stack args
            POP X

            IFN [A+PAGEDESC_ALLOC_COUNT], 0
                SET PC, .keep_kalloc
            PUSH [Z-3]
                JSR kalloc_page_free
            POP 0
.keep_kalloc:
        JSR free_spinlock

.null_free:
    POP C
    POP B
    POP A
    POP 0
    POP Z
    RET

.not_allocated:
    PUSH KPANIC_NOT_ALLOCATED
        JSR kernel_panic

; +2 Dest
; +1 Src
; +0 Size
memcpy:
    PUSH I
    PUSH J
    PUSH A
        SET I, [SP+6]
        SET J, [SP+5]
        SET A, [SP+4]
        ADD A, I
.top:
        IFE I, A
            SET PC, .break
        STI [I], [J]
        SET PC, .top
.break:
    POP A
    POP J
    POP I
    RET

; +2 Dest
; +1 Src
; +0 Size
memmove:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH I
    PUSH J
    PUSH C

        SET I, [Z+2]
        SET J, [Z+1]
        SET C, [Z+0]

        IFE C, 0
            SET PC, .done
        IFL I, J
            SET PC, .fwd
        IFG I, J
            SET PC, .bkwd
        SET PC, .done

.fwd:
        ADD C, I
.fwd_top:
        IFE I, C
            SET PC, .done
        STI [I], [J]
        SET PC, .fwd_top

.bkwd:
        PUSH I
            SUB C, 1
            ADD I, C
            ADD J, C
        POP C
.bkwd_top:
        STD [I], [J]
        IFE I, C
            SET PC, .done
        SET PC, .bkwd_top

.done:
    POP C
    POP J
    POP I
    POP Z
    RET

; +2 Dest
; +1 Value
; +0 Length
memset:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH I
    PUSH J
    PUSH A
        SET I, 0
        SET J, [Z+2]
        SET A, [Z+1]
.top:
        IFE I, [Z]
            SET PC, .break
        SET [J], A
        STI PC, .top
.break:
    POP A
    POP J
    POP I
    POP Z
    RET

; +0 zstring
; Returns
; +0 Len
strlen:
    PUSH A
        SET A, [SP+2]
        PUSH A
.count_top:
            IFE [A], 0
                SET PC, .end
            ADD A, 1
            SET PC, .count_top
.end:
        SUB A, POP
        SET [SP+2], A
    POP A
    RET
