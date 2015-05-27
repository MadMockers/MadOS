
.ifdef DCPU_MAD
init_srt:
	SRT srt
	RET

srt:
	DAT 1
	DAT 6
	DAT 0xFFFF
	DAT 0
.endif
