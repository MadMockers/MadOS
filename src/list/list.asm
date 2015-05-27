
.define LIST_NEXT    0
.define LIST_PREV    1
.define LIST_SIZE    2

; +0 list
; returns
; none
list_init:
    PUSH A
        SET A, [SP+2]
        SET [A+LIST_NEXT], A
        SET [A+LIST_PREV], A
    POP A
    RET

; +1 List offset
; +0 Object
; Returns
; +0 Next object
list_step:
    PUSH A
        SET A, [SP+2]
        ADD A, [SP+3]
        SET A, [A]
        SUB A, [SP+3]
        SET [SP+2], A
    POP A
    RET

; +3 List offset
; +2 Object
; +1 List offset
; +0 Inserted Object
list_insert_behind:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
    PUSH B

        SET A, [Z+2]
        ADD A, [Z+3]
        SET A, [A]
        PUSH 0
        PUSH A
        PUSH [Z+1]
        PUSH [Z+0]
            JSR list_insert
        ADD SP, 4

    POP B
    POP A
    POP Z
    RET

; +3 List offset
; +2 Object
; +1 List offset
; +0 Inserted Object
.define ARG_OFFS        7
.define ARG_OBJ         6
.define ARG_OFFS_INS    5
.define ARG_INS         4
list_insert:
    PUSH A
    PUSH B
    PUSH C
        SET A, [SP+ARG_OBJ]
        ADD A, [SP+ARG_OFFS]

        SET B, [SP+ARG_INS]
        ADD B, [SP+ARG_OFFS_INS]

        SET C, [A]
        SET [A], B

        SET [B], C

        SET [C+1], B
        SET [B+1], A
    POP C
    POP B
    POP A
    RET

; +1 List Offset
; +0 Object
.define ARG_OFFS    5
.define ARG_OBJ     4
list_remove:
    PUSH A
    PUSH B
    PUSH C
        SET B, [SP+ARG_OBJ]
        ADD B, [SP+ARG_OFFS]

        SET A, [B+1]
        SET C, [B]

        SET [A], C

        SET [C+1], A
    POP C
    POP B
    POP A
    RET


