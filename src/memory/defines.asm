
.define PAGE_SIZE               512
.define KMEM_MIN_ALLOC          8

; struct PageDescriptor
.define PAGEDESC_ALLOC_SIZE     0
.define PAGEDESC_ALLOC_MAX      1
.define PAGEDESC_ALLOC_COUNT    2

.define PAGEDESC_SIZE           3
; followed by a bitfield with ALLOC_MAX entries, each 2 bits.

.define MEM_FLAG_ALLOCATED      2
.define MEM_FLAG_MORE           1

; struct KALLOC
; process struct
.define KALLOC_PROCESS          0
; flags: 11bits-Unallocated | 1bit-Kernel | 1bit-Pagable | 3bit-Access
.define KALLOC_FLAGS            1
; start page
.define KALLOC_STARTPAGE        2
; page count
.define KALLOC_PAGECOUNT        3
; if swapped, which inode has it
.define KALLOC_PAGED_INODE      4
.define KALLOC_LIST             5   ; size 2
.define KALLOC_PROC_LIST        7   ; size 2
.define KALLOC_SPINLOCK         9   ; size 4
.define KALLOC_SIZE             13
