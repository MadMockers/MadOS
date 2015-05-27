
root_fs:
    .dat 0

; +0 FSInfo
; Return
; Nothin'
fs_register:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A

        SET A, [Z+0]
        
        IFE [root_fs], 0
            SET PC, .first_time

        PUSH FS_NEXT
        PUSH [root_fs]
        PUSH FS_NEXT
        PUSH A
            JSR list_insert_behind
        ADD SP, 4

        SET PC, .return

.first_time:
        SET [root_fs], A
        ADD A, FS_NEXT
        SET [A], A
        SET [A+1], A

.return:
    POP A
    POP Z
    RET
