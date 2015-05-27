
.define KERNEL_PID    0
.define PROCESS_LENGTH    10

; process struct
; +0    PID
.define    PROCESS_ID        0
; +1-3    Spinlock
.define    PROCESS_SPINLOCK    1
; +4    Next Process
.define    PROCESS_NEXT        4
; +5    Previous Process
.define    PROCESS_PREV        5
; +6    Next Thread
.define PROCESS_THREAD_NEXT 6
; +7    Prev Thread
.define PROCESS_THREAD_PREV 7
; +8    Inode Next
.define PROCESS_KALLOC_NEXT  8
; +9    Inode Prev
.define PROCESS_KALLOC_PREV  9

