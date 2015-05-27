
; struct HardwareInfo
; +0 Port
.define HW_PORT         0
; +1-2 Hardware ID
.define HW_ID           1
; +3 Hardware Version
.define HW_VERSION      3
; +4-5 Manufacturer ID
.define HW_MFR          4
; +7 Hardware Next
.define HW_NEXT         6
; +8 Hardware Prev
.define HW_PREV         7

.define HW_SIZE         8

; struct HardwareType
.define HWTYPE_ID       0
.define HWTYPE_VERSION  2
.define HWTYPE_SIZE     3

.define HWTYPE_VIRTUAL  0xFFFF
