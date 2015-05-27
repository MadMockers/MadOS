
hardware_info:
    DAT 0

hardware_count:
    DAT 0

init_hardware:
    HWN A
    SET [hardware_count], A
    PUSH A
        MUL A, HW_SIZE
        PUSH A
            JSR kalloc
        POP J
    POP A
    PUSH J
    PUSH A
    PUSH B
.top:
        IFE A, B
            SET PC, .break
        SET [J+HW_PORT], B
        PUSH A
        PUSH B
            HWQ B
            SET [J+HW_ID+0], A
            SET [J+HW_ID+1], B
            SET [J+HW_VERSION], C
            SET [J+HW_MFR+0], X
            SET [J+HW_MFR+1], Y
            PUSH J
                ADD J, HW_NEXT
                SET [J], J
                ADD [J], HW_SIZE
                SET [J+1], J
                SUB [J+1], HW_SIZE
            POP J
        POP B
        POP A
.continue:
        ADD B, 1
        ADD J, HW_SIZE
        SET PC, .top
.break:
    POP B
    POP A
    POP J

    SUB A, 1
    MUL A, HW_SIZE
    ADD A, HW_NEXT
    ADD A, J
    SET [J+HW_PREV], A
    SET [A], J
    ADD [A], HW_NEXT

    SET [hardware_info], J

    RET

; +1 Driver
; +0 Occurrance number
; Returns
; +0 Hw Struct
hardware_get_info:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
    PUSH B
    PUSH C
    PUSH X
    PUSH Y
        
        SET A, [hardware_count]
        SET X, [hardware_info]
        SET B, 0
        SET Y, 0
        SET C, [Z+1]
        SET C, [C+DRIVER_HWTYPE]
        ADD [Z+0], 1
.top:
            IFE A, B
                SET PC, .break_failed

            IFE [C+HWTYPE_ID+LO], [X+HW_ID+LO]
                IFE [C+HWTYPE_ID+HI], [X+HW_ID+HI]
                    IFE [C+HWTYPE_VERSION], [X+HW_VERSION]
                        SET PC, .found
            SET PC, .continue
.found:
            ADD Y, 1
            IFN Y, [Z+0]
                SET PC, .continue
            SET [Z+0], X
            SET PC, .break
.continue:
            ADD B, 1
            ADD X, HW_SIZE
            SET PC, .top
.break_failed:
        SET [Z+0], 0xFFFF
.break:

    POP Y
    POP X
    POP C
    POP B
    POP A
    POP Z
    RET


