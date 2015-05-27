
; Input
; SP+2 BitField Address
; SP+1 Value Width
; SP+0 Index
; Output
; SP+0 Value
:bitfield_get_value
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
    PUSH B
    PUSH C
    PUSH X
    PUSH Y
    
    ; A: Word
    ; B: BitPosition
    ; C: Mask
    ; X: Temp
    ; Y: Value
    
    SET X, [Z]
    MUL X, [Z+1]
    SET A, X
    SHR A, 4 ; Divide by 16
    ADD A, [Z+2]
    ; At this point 'A' has the address of the word
    
    SET B, X
    AND B, 0xF
    ; At this point, B has the bit position of where the value starts
    
    SET X, 1    ; mask = 1 << bitWidth
    SHL X, [Z+1]
    SET C, X
    
    SUB C, 1    ; mask = mask - 1
    
    SET Y, [A]    ; value = [word] >> bitPos & mask
    SHR Y, B
    AND Y, C
    
    SET X, 16
    SUB X, B
    IFL X, [Z+1]    ; if 16 - bitPos < bitWidth
        SET PC, .continue
    SET PC, .done
    :.continue
    
    SET C, [Z+1]    ; mask = bitWidth + bitPos - 16
    ADD C, B
    SUB C, 16
    
    SET X, 1        ; mask = 1 << mask
    SHL X, C
    SET C, X
    
    SUB C, 1        ; mask = mask - 1
    
    PUSH Y
    SET Y, [A+1]    ; value = value | ([word+1] & mask) << (16-bitPos)
    AND Y, C
    SET X, 16
    SUB X, B
    SHL Y, X
    BOR Y, POP
    :.done
    
    SET [Z], Y
    
    POP Y
    POP X
    POP C
    POP B
    POP A
    POP Z
    RET
    
; SP+3 BitField Address
; SP+2 Value Width
; SP+1 Index
; SP+0 Value
:bitfield_set_value
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
    PUSH B
    PUSH C
    PUSH X
    PUSH Y
    
    ; A: Word
    ; B: BitPosition
    ; C: Mask
    ; X: Temp
    ; Y: Value
    
    SET X, [Z+1]
    MUL X, [Z+2]
    SET A, X
    SHR A, 4    ; divide by 16
    ADD A, [Z+3]
    ; at this point, A points at the word in the bitfield
    
    SET B, X
    AND B, 0xF
    ; At this point, B has the bit position of where the index starts
    
    ; Start by clearing the word:
    SET C, 1        ; mask = ~((1 << bitWidth) - 1) << (bitPos)
    SHL C, [Z+2]
    SUB C, 1
    SHL C, B
    XOR C, 0xFFFF
    
    AND [A], C    ; [word] = [word] & mask
    
    SET C, 1    ; mask = (1 << bitWidth) - 1
    SHL C, [Z+2]
    SUB C, 1
    
    SET Y, [Z]
    
    AND Y, C    ; value = value & mask
    
    SHL Y, B    ; [word] = [word] | (value << bitPos)
    BOR [A], Y
    
    SET X, 16
    SUB X, B
    IFL X, [Z+2]    ; if 16 - bitPos < bitWidth
        SET PC, .continue
    SET PC, .done
    :.continue
    
    SET Y, [Z]        ; value = value >> (16 - bitPos)
    SET X, 16
    SUB X, B
    SHR Y, X
    
    BOR [A+1], Y
    
    :.done
    
    POP Y
    POP X
    POP C
    POP B
    POP A
    POP Z
    RET


