
; DCPU_MAD = variant of DCPU with various extra features
;.define DCPU_MAD
.define PANIC_TEST
.define HELPFUL_PANICS

SET SP, kernel_stack
SET PC, kernel_start

    .reserve 128
kernel_stack:

.define NULL    0

#include "32bit/32bit.asm"
#include "list/list.asm"
#include "interrupts/defines.asm"
#include "process/defines.asm"
#include "memory/defines.asm"
#include "inode/defines.asm"
#include "concur/defines.asm"
#include "drivers/defines.asm"
#include "fs/defines.asm"
#include "threads/defines.asm"
#include "threads/threads.asm"
#include "panic/panic.asm"
#include "bitfield/bitfield.asm"
#include "memory/memory.asm"
#include "bios/defines.asm"
#include "bios/hardware.asm"
;#include "malloc/malloc.asm"
#include "inode/inode.asm"
;#include "linkedlist/linkedlist.asm"
#include "process/process.asm"
#include "concur/concur.asm"
#include "interrupts/interrupts.asm"
#include "fs/fs.asm"
#include "debug/debug.asm"
#include "ringtable/ringtable.asm"

; ------[ Drivers ]------
#include "drivers/driver.asm"
#include "drivers/lem1802/defines.asm"
#include "drivers/clock/defines.asm"
#include "drivers/hmd2043/defines.asm"
#include "drivers/m35fd/defines.asm"
#include "drivers/tty/defines.asm"
#include "drivers/madfs/defines.asm"

#include "drivers/lem1802/lem1802.asm"
#include "drivers/clock/clock.asm"
#include "drivers/hmd2043/hmd2043.asm"
#include "drivers/m35fd/m35fd.asm"
#include "drivers/tty/tty.asm"
#include "drivers/madfs/madfs.asm"

console:
    DAT 0

system_clock:
    DAT 0

initialize_console:
    PUSH A
    PUSH B
    PUSH C

        PUSH DRIVER_CLASS_DISPLAY
            JSR driver_array_from_class
        
            SET A, [SP]
            ; we're searching for a display driver
.disp_top:
            IFE [A], 0
                SET PC, .disp_break_fail

            PUSH [A]
            PUSH 0
                JSR hardware_get_info
            POP C
            POP 0

            IFN C, 0xFFFF
                SET PC, .disp_break
.disp_cont:
            ADD A, 1
            SET PC, .disp_top
.disp_break_fail:
            PUSH KPANIC_NO_CONSOLE
                JSR kernel_panic
.disp_break:
            SET B, [A]

            JSR kfree
        POP 0
        
        ; B = driver, C = hardware
        PUSH B
        PUSH C
            JSR [B+DRIVER_CREATE_DEVICE]
        POP C
        POP 0

        PUSH [tty_driver]
        PUSH C
            JSR tty_create_device
        POP C
        POP 0

        ; set default format
        PUSH 0xF0 ; white foreground, black background
        PUSH C
            JSR tty_setfmt
        ADD SP, 2

        SET [console], C

    POP C
    POP B
    POP A
    RET

execution_at_0:
    PUSH KPANIC_EXECUTION_AT_0
        JSR kernel_panic

kernel_start:
    ; modify jump at start to cause kpanic
    SET [3], execution_at_0

    ; initialize threads as soon as possible so we can use spinlocks
    JSR init_threads
    JSR init_inodes
    JSR init_process
    JSR init_kmem
    JSR init_hardware
    JSR init_interrupts

.ifdef DCPU_MAD
    JSR init_srt
.endif

    JSR init_drivers

    JSR lem1802_init

    JSR tty_init
    JSR initialize_console

.ifdef PANIC_TEST
    PUSH KPANIC_ROOT_THREAD_DIED
        JSR kernel_panic
.endif

    PUSH str_booting
        JSR debug_print
    POP 0

    JSR m35fd_init
    JSR hmd2043_init
    JSR madfs_init

    PUSH DRIVER_CLASS_STORAGE
        JSR find_driver_hardware_pair
    POP A
    POP B

    PUSH A
    PUSH B
        JSR [A+DRIVER_CREATE_DEVICE]
    POP A
    POP 0

    PUSH A
        JSR madfs_create_device
    POP A

    PUSH A
        JSR madfs_format
    POP 0

    PUSH A
        JSR madfs_mount
    POP 0

    PUSH A
        JSR madfs_create
    POP 0

    PUSH str_booted
        JSR debug_print
    POP 0

loop:
    SET PC, loop

    JSR clock_init

    PUSH DRIVER_CLASS_CLOCK
        JSR find_driver_hardware_pair
    POP A
    POP B

    IFN A, 0xFFFF
        SET PC, .clock_found

    PUSH KPANIC_NO_CLOCK
        JSR kernel_panic

.clock_found:    
    PUSH A
    PUSH B
        JSR clock_create_device
    POP A
    POP 0

    SET [system_clock], A

    PUSH str_scheduler_init
        JSR debug_print
    POP 0

    JSR init_scheduler

.no_clock:

    PUSH str_booted
        JSR debug_print
    POP 0

.loop:
    JSR yield
    SET PC, .loop

unimplemented:
    RET

kernel_end:

