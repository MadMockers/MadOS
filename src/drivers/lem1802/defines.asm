
.define VRAM_SIZE       32*12

; struct Display
; +0 DEVICE Struct
; +3 Vram
.define DISPLAY_VRAM    DEVICE_SIZE+1

.define DISPLAY_SIZE    DISPLAY_VRAM+32*12 ;VRAM_SIZE
