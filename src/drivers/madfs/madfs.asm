
madfs_driver:
    DAT 0

madfs_init:
    PUSH Z
    SET Z, SP
    ADD Z, 2

        PUSH 0xFFFF
        PUSH 0xFFFF
        PUSH 0xFFFF
        PUSH DRIVER_CLASS_FS            ; class
        PUSH DVR_FS_FUNC_COUNT     ; function count
            JSR driver_create
        POP A
        ADD SP, 4

        SET [A+DRIVER_CREATE_DEVICE], madfs_create_device

        SET [madfs_driver], A

    POP Z
    RET

; +1 Driver
; +0 Hardware / Device
; Returns
; +0 Device
madfs_create_device:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
        
        PUSH MADFS_DEVICE_SIZE
            JSR kalloc
        POP A

        JSR device_get_uid
        POP [A+DEVICE_ID]
        SET [A+DEVICE_HW], [Z+0]
        SET [A+DEVICE_DRIVER], [Z+1]
        PUSH A
        ADD [SP], DEVICE_SPINLOCK
            JSR spinlock_init
        POP 0
        SET [A+MADFS_INFO], 0
        SET [A+MADFS_TREETABLE], 0

        SET [Z+0], A

    POP A
    POP Z
    RET

; +0 Device
; Returns
; None
.define VAR_PARAMS_INFO     0
madfs_format:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
    PUSH B
    PUSH C
    PUSH Y
    SUB SP, 2
    SET Y, SP

        SET A, [Z+0]

        PUSH A ; saved for 'device lock' coming up

        SET B, [A+DEVICE_HW]
        SET A, [B+DEVICE_DRIVER]

        PUSH Y
        PUSH B
            JSR [A+DRIVER_FUNC+DVR_STORAGE_GET_PARAMS]
        ADD SP, 2

        PUSH [Y+VAR_PARAMS_INFO+MEDIA_PARAMS_SECTOR_SIZE]
            JSR kalloc
        POP C

        ; initialize tree table to 1s
        PUSH C
        PUSH 0xFFFF
        PUSH [Y+VAR_PARAMS_INFO+MEDIA_PARAMS_SECTOR_SIZE]
            JSR memset
        ADD SP, 3

        JSR device_lock

            ; write the tree table to sector 1
            PUSH C
            PUSH 1
            PUSH B
                JSR [A+DRIVER_FUNC+DVR_STORAGE_WRITE]
            ADD SP, 3

            SET [C+MADFS_SB_MAGIC+LO], 0x4D44
            SET [C+MADFS_SB_MAGIC+HI], 0x4653
            SET [C+MADFS_SB_VERSION], 1
            SET [C+MADFS_SB_ROOTCLUSTER], 0
            SET [C+MADFS_SB_CLUSTERSIZE], 2

            PUSH A
                SET A, [Y+VAR_PARAMS_INFO+MEDIA_PARAMS_SECTORS]
                SUB A, 2        ; first data sector
                DIV A, 2
                SET [C+MADFS_SB_CLUSTERCOUNT], A

                PUSH B
                    ADD A, 1
                    SET B, 0
.top_count_bits:
                    IFE A, 0
                        SET PC, .break_count_bits
.continue_count_bits:
                    SHR A, 1
                    ADD B, 1
                    SET PC, .top_count_bits
.break_count_bits:
                    SET [C+MADFS_SB_CLUSTERBITS], B
                POP B
            POP A
            
            SET [C+MADFS_SB_FIRSTDATASECTOR], 2
            SET [C+MADFS_SB_WORDSPERSECTOR], [Y+VAR_PARAMS_INFO+MEDIA_PARAMS_SECTOR_SIZE]
            SET [C+MADFS_SB_TREETABLESECTOR], 1
            SET [C+MADFS_SB_UNIQUEID], 0

            PUSH C
            PUSH 0
            PUSH B
                JSR [A+DRIVER_FUNC+DVR_STORAGE_WRITE]
            ADD SP, 3
        JSR free_spinlock

        PUSH C
            JSR kfree
        POP 0

    ADD SP, 2
    POP Y
    POP C
    POP B
    POP A
    POP Z
    RET

; +3 Parent Inode
; +2 NodeType
; +1 Name
; +0 Device
; Returns
; +0 Error (0 = success)
madfs_create:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
    PUSH B
    PUSH C
    PUSH X
    PUSH Y
    PUSH I

        SET A, [Z+0]

        PUSH A
        JSR device_lock

            SET C, [A+MADFS_TREETABLE]
            SET X, [A+MADFS_INFO]
            SET I, [A+DEVICE_HW]
            SET A, [I+DEVICE_DRIVER]

            SET Y, [X+MADFS_SB_CLUSTERBITS]

            PUSH A
            PUSH C
            PUSH Y

                PUSH Y
                    SET Y, 1
                SHL Y, POP
                SUB Y, 1

                SET B, 0
.top_find_free:
                    IFE B, [X+MADFS_SB_CLUSTERCOUNT]
                        SET PC, .out_of_space
                    PUSH B
                        JSR bitfield_get_value
                    POP A
                    IFE A, Y    ; free cluster :)
                        SET PC, .break_find_free
                    
.continue_find_free:
                    ADD B, 1
                    SET PC, .top_find_free

.out_of_space:
                    SET [Z+0], FS_ERROR_OUT_OF_SPACE
            SUB SP, 4
            SET PC, .return
.break_find_free:

                PUSH B
                PUSH B
                    JSR bitfield_set_value
                ADD SP, 2

            POP Y
            POP C
            POP A

            PUSH C
            PUSH [X+MADFS_SB_TREETABLESECTOR]
            PUSH I
                JSR [A+DRIVER_FUNC+DVR_STORAGE_WRITE]
            ADD SP, 3
.return:
        JSR free_spinlock

    POP I
    POP Y
    POP X
    POP C
    POP B
    POP A
    POP Z
    RET

; +1 Position (Inode)
; +0 Device
; Returns
; +0 FS
madfs_mount:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
    PUSH B
    PUSH C
    PUSH X
    PUSH Y
    PUSH I

        SET I, [Z+0]
        SET B, [I+DEVICE_HW]
        SET A, [B+DEVICE_DRIVER]

        PUSH I
        JSR device_lock
        SUB SP, 2
            SET X, SP
            PUSH SP
            PUSH B
                JSR [A+DRIVER_FUNC+DVR_STORAGE_GET_PARAMS]
            ADD SP, 2

            PUSH [X+MEDIA_PARAMS_SECTOR_SIZE]
                JSR kalloc
            POP Y

            ; Read super block
            PUSH Y
            PUSH 0
            PUSH B
                JSR [A+DRIVER_FUNC+DVR_STORAGE_READ]
            ADD SP, 3

            PUSH MADFS_INFO_SIZE
                JSR kalloc
            POP [I+MADFS_INFO]
            PUSH [I+MADFS_INFO]
            PUSH Y
            PUSH MADFS_SB_SIZE
                JSR memcpy
            ADD SP, 3

            PUSH Y
            PUSH 0
            PUSH B
                JSR [A+DRIVER_FUNC+DVR_STORAGE_READ]
            ADD SP, 3

            PUSH FS_SIZE
                JSR kalloc
            POP C

            SET [C+FS_TYPE], MADFS_FS_TYPE
            SET [C+FS_DEVICE], [Z+0]
            SET [C+FS_MOUNTPOINT], [Z+1]

            PUSH C
                JSR fs_register
            ADD SP 1

            SET [Z+0], C
            SET [I+MADFS_INFO_FS], C

            SET C, [Y+MADFS_SB_CLUSTERCOUNT]
            MUL C, [Y+MADFS_SB_CLUSTERBITS]
            ADD C, 15
            DIV C, 16
            PUSH C
                JSR kalloc
            POP X

            PUSH Y
            PUSH [Y+MADFS_SB_TREETABLESECTOR]
            PUSH B
                JSR [A+DRIVER_FUNC+DVR_STORAGE_READ]
            ADD SP, 3

            PUSH X
            PUSH Y
            PUSH C
                JSR memcpy
            ADD SP, 3

            SET [I+MADFS_TREETABLE], X

            PUSH Y
                JSR kfree
            ADD SP, 1
        ADD SP, 2
        JSR free_spinlock

    POP I
    POP Y
    POP X
    POP C
    POP B
    POP A
    POP Z
    RET

