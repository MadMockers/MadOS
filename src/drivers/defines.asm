
.define DRIVER_CLASS_DISPLAY        0x1000
.define DVR_DISPLAY_MAP_SCREEN      0
.define DVR_DISPLAY_FUNC_COUNT      1

.define DRIVER_CLASS_CLOCK          0x1001
.define DVR_CLOCK_SET               0
.define DVR_CLOCK_GET_TICKS         1
.define DVR_CLOCK_SET_INT           2
.define DVR_CLOCK_FUNC_COUNT        3

.define DRIVER_CLASS_STORAGE                0x1002
.define DVR_STORAGE_PRESENT                 0
.define DVR_STORAGE_WRITE                   1
.define DVR_STORAGE_READ                    2
.define DVR_STORAGE_SET_FLAGS               3
.define DVR_STORAGE_GET_FLAGS               4
.define DVR_STORAGE_GET_SUPPORTED_FLAGS     5
.define DVR_STORAGE_GET_PARAMS              6
.define DVR_STORAGE_FUNC_COUNT              7

; struct ParamsInfo
.define MEDIA_PARAMS_SECTORS        0
.define MEDIA_PARAMS_SECTOR_SIZE    1
.define MEDIA_PARAMS_SIZE           2

.define DRIVER_CLASS_FS             0x1003
.define DVR_FS_FORMAT               0
.define DVR_FS_CREATE               1
.define DVR_FS_DELETE               2
.define DVR_FS_MOVE                 3
.define DVR_FS_OPEN                 4
.define DVR_FS_CLOSE                5
.define DVR_FS_READ                 6
.define DVR_FS_WRITE                7
.define DVR_FS_MOUNT                8
.define DVR_FS_UMOUNT               9
.define DVR_FS_GET_ATTR             10
.define DVR_FS_SET_ATTR             11
.define DVR_FS_FUNC_COUNT           12

.define DRIVER_CLASS_TTY            0x1004
.define DVR_TTY_WRITE               0
.define DVR_TTY_NEWLINE             1
.define DVR_TTY_GETFMT              2
.define DVR_TTY_SETFMT              3
.define DVR_TTY_GETXY               4
.define DVR_TTY_SETXY               5
.define DVR_TTY_FUNC_COUNT          6

; Driver struct
;+0 HardwareType / Child Class
.define DRIVER_HWTYPE           0
;+1 Driver Next in chain
.define DRIVER_CHILD            1
;+2 Class
.define DRIVER_CLASS            2
;+3 Driver next
.define DRIVER_NEXT             3
;+4 Driver prev
.define DRIVER_PREV             4
;+5 Create Device Struct function
.define DRIVER_CREATE_DEVICE    5
;+6 Function Count
.define DRIVER_FUNC_COUNT       6
;+7-* Functions
.define DRIVER_FUNC             7

.define DRIVER_SIZE 7

; a unique ID to the HW type
.define DEVICE_ID               0
.define DEVICE_HW               1
.define DEVICE_DRIVER           2
.define DEVICE_SPINLOCK         3 ; size 4
.define DEVICE_SIZE             DEVICE_SPINLOCK+SPINLOCK_SIZE

