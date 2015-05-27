.define INODE_TYPE_FILE             0
.define INODE_TYPE_UNINITIALIZED    0xFFFF

.define INODE_SIZE_MEMORY   11
.define INODE_SIZE_FILE     14

; inode struct
; +0 type
.define INODE_TYPE      0
; +1 idx
.define INODE_INDEX     1
; +2 next inode
.define INODE_NEXT      2
; +3 prev inode
.define INODE_PREV      3
; ...
.define INODE_BASE_SIZE 4

;--- File
.define INODE_FILE_DRIVER       6
.define INODE_FILE_FS           7
.define INODE_FILE_CLUSTER      8
.define INODE_FILE_BUFFER       9
.define INODE_FILE_BUFFER_SIZE  10
.define INODE_FILE_BUFFER_IDX   11
.define INODE_FILE_RW_IDX       12
.define INODE_FILE_FLAGS        13
