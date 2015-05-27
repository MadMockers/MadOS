
.define SPINLOCK_SIZE    4

; struct Spinlock
; +0 Owner
.define SPINLOCK_OWNER        0
; +1 Ref Count
.define SPINLOCK_REFCOUNT    1
; +2 Owner Next
.define SPINLOCK_OWNER_NEXT    2
; +3 Owner Prev
.define SPINLOCK_OWNER_PREV    3
