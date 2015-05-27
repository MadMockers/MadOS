
.define LL_FLAG_KERNEL      1

.define LL_ITR_SIZE         4

.define LL_USED_DATA        8

;------------------------------
; LinkedList
; +0 Count
.define LINKEDLIST_COUNT    0
; +1 Page Size
.define LINKEDLIST_PAGESIZE 1
; +2 Flags
.define LINKEDLIST_FLAGS    2
; +3-7 Spinlock
.define LINKEDLIST_SPINLOCK 3
; +8-n Values
; +n Next Page
;------------------------------

;------------------------------
; LinkedListIterator
; +0 LinkedList
.define LL_ITR_LINKEDLIST   0
; +1 CurrentPage
.define LL_ITR_CURRENTPAGE  1
; +2 PageIndex
.define LL_ITR_PAGEINDEX    2
; +3 Index
.define LL_ITR_INDEX        3
;------------------------------

;------------------------------
; +1 Iterator
; +0 LinkedList
; Returns
; None
;------------------------------
linked_list_iterator_init:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
        
        SET A, [Z+1]
        SET [A+LL_ITR_LINKEDLIST], [Z]
        SET [A+LL_ITR_CURRENTPAGE], [Z]
        SET [A+LL_ITR_PAGEINDEX], LL_USED_DATA
        SET [A+LL_ITR_INDEX], 0

    POP A
    POP Z
    RET

;------------------------------
; +0 Iterator
; Returns
; +0 Value
;------------------------------
linked_list_iterator_next:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
    PUSH B
    PUSH C
    PUSH X

        SET A, [Z]
        SET B, [A+LL_ITR_LINKEDLIST]

        IFL [A+LL_ITR_INDEX], [B+LINKEDLIST_COUNT]
            SET PC, .in_bounds
        SET PC, .out_of_bounds
.in_bounds:
        SET C, [A+LL_ITR_PAGEINDEX]
        SET X, C
        ADD X, 1
        IFG [B+LINKEDLIST_PAGESIZE], X
            SET PC, .getnext
; load next page
        SET C, [B+LINKEDLIST_PAGESIZE]
        ADD C, [A+LL_ITR_CURRENTPAGE]
        SET [A+LL_ITR_CURRENTPAGE], [C-1]
        SET C, 0

.getnext:
        SET B, [A+LL_ITR_CURRENTPAGE]
        ADD B, C
        SET [Z], [B]
        ADD C, 1
        SET [A+LL_ITR_PAGEINDEX], C
        ADD [A+LL_ITR_INDEX], 1

    POP X
    POP C
    POP B
    POP A
    POP Z
    RET

.out_of_bounds:
    PUSH KPANIC_INDEX_OUT_OF_BOUNDS
        JSR kernel_panic

;------------------------------
; +1 Address
; +0 Page Size
; Return
; +0 Success (0 = success, non-zero = error)
;
; Errors:
; 1: Given page size is too small
linked_list_init:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
    PUSH B

        IFL [Z], LL_USED_DATA+1        ; +1 for 'next page' value as well
            SET PC, .error_page_too_small
    
        SET A, [Z+1]

        SET [A+LINKEDLIST_COUNT], 0        ; count
        SET [A+LINKEDLIST_PAGESIZE], [Z]    ; page size
        SET [A+LINKEDLIST_FLAGS], 0
        PUSH A
        ADD [SP], LINKEDLIST_SPINLOCK
            JSR spinlock_init
        ADD SP, 1

        SET B, [Z]
        SUB B, LL_USED_DATA
        PUSH A
            ADD A, LL_USED_DATA
.zero_top:
            SUB B, 1
            IFE B, 0
                SET PC, .zero_break

            SET [A], 0
            ADD A, 1
            SET PC, .zero_top
.zero_break:
        POP A

        SET PC, .return
.error_page_too_small:
        SET [Z], 1
.return:
    POP B
    POP A
    POP Z
    RET
;------------------------------

;------------------------------
; +1 Linked List
; +0 Last Page
; Returns
; +0 New Page
linked_list_new_page:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
    PUSH B

        SET B, malloc
        SET A, [Z+1]
        IFB [A+2], LL_FLAG_KERNEL    ; test if it's a kernel based linked list
            SET B, kalloc
        PUSH [A+1]            ; push page size
            JSR B            ; call memory allocating function
        POP B
        SET A, [A+1]
        ADD A, [Z]            ; A = page size (A) + last page address (B)
        SET [A+0xFFFF], B
        SET [Z], B
    POP B
    POP A
    POP Z
    RET
;------------------------------

;------------------------------
; +1 Linked List
; +0 Page Index
; Returns
; +0 Page Address
linked_list_get_page:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
    PUSH B

        SET A, [Z+1]        ; A = linked list
        SET B, [A+1]        ; B = Page Size

.top:
        IFE [Z], 0
            SET PC, .break
        ADD A, B        ; To to end of page + 1
        SET A, [A+0xFFFF]    ; Dereference address at end of page
        SUB [Z], 1        ; Sub 1 from index
        SET PC, .top
.break:
        SET [Z], A

    POP B
    POP A
    POP Z
    RET
;------------------------------

;------------------------------
; +1 Linked List
; +0 Value
; Returns
; None
;===
; Stack:
; +0 Page Idx
; +3 Value
; +4 Linked List
linked_list_put:
    PUSH Z
    SUB SP, 1
    SET Z, SP
    PUSH A
    PUSH B

        ; Find which page we will be putting this value on
        SET A, [Z+4]

        PUSH A
        ADD [SP], LINKEDLIST_SPINLOCK
        JSR acquire_spinlock
            SET B, [A]        ; B = element count
            ADD B, LL_USED_DATA    ; First page uses 3 of the spaces
        
            SET A, [A+1]
            SUB A, 1        ; A = elements per page

            PUSH B
                DIV B, A
                SET [Z], B    ; Page Idx = B / A
            POP B

            ; set b to index in page
            MOD B, A
            ; if index is not 0, we need don't need a new page first...
            IFN B, 0
                SET PC, .new_page_not_required

            PUSH [Z+4]    ; linked list
            PUSH [Z]    ; page index
            SUB [SP], 1    ; (minus 1)
                JSR linked_list_get_page    ; these 2 can be chained
                JSR linked_list_new_page
            POP A        ; A = new page
            ADD SP, 1
            SET PC, .page_resolved
.new_page_not_required:
            PUSH [Z+4]    ; linked list
            PUSH [Z]    ; page index
                JSR linked_list_get_page
            POP A        ; A = page
            ADD SP, 1
.page_resolved:
            ; At this point, the page (new or not) will be in A
            ; Add the local page index to the page address..
            ADD A, B

            ; Set our value..
            SET [A], [Z+3]
            ; Add 1 to our count
            SET A, [Z+4]
            ADD [A], 1
        JSR free_spinlock

    POP B
    POP A
    ADD SP, 1
    POP Z
    RET
;------------------------------
