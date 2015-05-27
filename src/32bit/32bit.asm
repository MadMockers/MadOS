
.define HI  1
.define LO  0

; +3 A0
; +2 A1
; +1 B0
; +0 B1
; Returns
; +1 Sum0
; +0 Sum1
32add:
    PUSH Z
    SET Z, SP
    ADD Z, 2
        ADD [Z+1], [Z+3]
        ADX [Z+0], [Z+2]
    POP Z
    RET

; +3 A0
; +2 A1
; +1 B0
; +0 B1
; Returns
; +1 Difference0
; +0 Difference1
32sub:
    PUSH Z
    SET Z, SP
    ADD Z, 2
        SUB [Z+1], [Z+3]
        SBX [Z+0], [Z+2]
    POP Z
    RET


;   A1.A0
; X B1.B0
;--------
;   Y1.Y0
;Y3.Y2.00
; +3 A0
; +2 A1
; +1 B0
; +0 B1
; Returns
; +1 Product0
; +0 Product1
32mul:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH Y
    SUB SP, 3
    SET Y, SP
        SET [Y+0], [Z+1]
        MUL [Y+0], [Z+3]
        PUSH EX
            SET [Y+1], [Z+1]
            MUL [Y+1], [Z+2]
        ADD [Y+1], POP

        SET [Y+2], [Z+0]
        MUL [Y+2], [Z+3]
        ADD [Y+2], [Y+1]

        SET [Z+1], [Y+0]
        SET [Z+0], [Y+2]
    ADD SP, 3
    POP Y
    POP Z
    RET

; +3 A0
; +2 Junk - For chaining
; +1 B0
; +0 B1
; Returns
; +1 Quotient0
; +0 Quotient1
32div:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
    PUSH B

        SET A, [Z+0]
        DIV A, [Z+3]
        SET B, EX
        PUSH B
        PUSH 0
        PUSH [Z+3]
        PUSH 0
            JSR 32mul
            PUSH 0
            PUSH [Z+0]
                JSR 32sub
            ADD SP, 1
            ADD [Z+1], POP
        ADD SP, 4

        SET [Z+0], A
        DIV [Z+1], [Z+3]
        ADD [Z+1], B

    POP B
    POP A
    POP Z
    RET

