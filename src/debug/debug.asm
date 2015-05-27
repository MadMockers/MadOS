
; +0 zString
debug_print:
    PUSH Z
    SET Z, SP
    ADD Z, 2
    PUSH A
    PUSH B

        SET A, [Z+0]
        PUSH A
            JSR strlen
        POP B

        PUSH B
        PUSH A
        PUSH [console]
            JSR tty_write
            JSR tty_newline
        ADD SP, 3

    POP B
    POP A
    POP Z
    RET

str_booting:
    .asciiz "Booting MadOS ..."
str_scheduler_init:
    .asciiz "Initializing Scheduler"
str_booted:
    .asciiz "Boot complete!"
