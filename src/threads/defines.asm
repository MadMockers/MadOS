
.define SCHEDULER_INT_RATE  300
.define SCHEDULER_INT_MSG   0xC000

; struct Thread
; +0    ID
.define THREAD_ID               0
; +1    Process
.define THREAD_PROC             1
; +2    Priority | State    State = 2 bits (0 = paused | 1 = running | 2 = waiting | 3 = stopped)
.define THREAD_STATE            2
; +3-6    Spinlock
.define THREAD_SPINLOCK         3
; +7    Global Next
.define THREAD_GLOB_NEXT        7
; +8    Global Prev
.define THREAD_GLOB_PREV        8
; +9    Process Next
.define THREAD_PROC_NEXT        9
; +10    Process Prev
.define THREAD_PROC_PREV        10
; +11    Next Spinlock
.define THREAD_SPINLOCK_NEXT    11
; +12    Prev Spinlock
.define THREAD_SPINLOCK_PREV    12
; +13   Stack Position
.define THREAD_STACK            13
; +14   Ring Mode
.define THREAD_RINGMODE         14
; +14-23 Context
.define THREAD_CONTEXT          15
.define THREAD_CONTEXT_SIZE     10
.define THREAD_CONTEXT_END      THREAD_CONTEXT+THREAD_CONTEXT_SIZE-1

.define THREAD_SIZE             25


; --- states ---
.define THREAD_STATE_PAUSED     0
.define THREAD_STATE_RUNNING    1
.define THREAD_STATE_WAITING    2
.define THREAD_STATE_STOPPED    3
