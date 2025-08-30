; 'freverse.asm'
; Reverses file contents using memory mapping.
; Author: Agata Kopec.
; Date: Jun 11 2025.
; MIMUW.

;

; Program constants:

; System specifications:

STAT_SIZE_LINUX_64 equ 144

; ABI related constants:

QWORD_SIZE_IN_BYTES equ 8
FILE_NAME_OFFSET_ARGV1 equ 16
FILE_SIZE_OFFSET_STAT equ 48

; Program dependent constants:

ARGUMENT_QUANTITY equ 2
MINIMAL_FILE_SIZE equ 2
MINIMAL_PIVOTS_DISTANCE_FOR_QWORDS equ 15
FIRST_TO_LAST_BYTE_IN_QWORD_DIFF equ QWORD_SIZE_IN_BYTES - 1
FAILURE_CODE equ 1

; System calls' codes:

SYS_OPEN_CODE equ 2
SYS_FSTAT_CODE equ 5
SYS_MMAP_CODE equ 9
SYS_MSYNC_CODE equ 10
SYS_MUNMAP_CODE equ 11
SYS_CLOSE_CODE equ 3
SYS_EXIT_CODE equ 60

; System calls' arguments:

MS_SYNC_FLAG equ 4
READ_WRITE_PERMISSIONS equ 2
PROTECTED_READ_WRITE_PERMISSIONS equ 3
MAP_SHARED_FLAGS equ 1
NO_OFFSET_MAP equ 0
KERNEL_CHOSEN_ADDRESS equ 0

;

section .bss

; Reserve memory for sys_fstat.

memory_for_fstat resb STAT_SIZE_LINUX_64

; 

; Registers purpose (for those with a clear one):

; rbx - file descriptor 
; or if rbx = 0 then file was never open

; r12 - file size

; r13 - mapped address
; or if r13 = 0, then sys_map was not called or not succesfull

;

section .text

global _start

_start:

; Validate the number of program arguments.

check_arguments:

    ; Set rbx and r13 to zero for future use.

    xor rbx, rbx
    xor r13, r13

    ; Check if the program was called with one argument:
    ; if qword [rsp] != 2 exit with code 1.
    ; (Two for program name and single argument.)
    ; Otherwise proceed.

    cmp qword [rsp], ARGUMENT_QUANTITY
    jne exit_on_failure

; Try and open the file.

open_file:

    ; Acquire file name from program arguments.

    mov rdi, [rsp + FILE_NAME_OFFSET_ARGV1]

    ; Prepare sys_open with read and write permissions.

    mov rax, SYS_OPEN_CODE
    mov rsi, READ_WRITE_PERMISSIONS
    syscall

    ; Validate sys_open return code.
    ; If rax < 0, the call failed. Exit with code 1.
    ; Otherwise proceed.

    cmp rax, 0
    jl exit_on_failure

    ; Save file descriptor in rbx for the duration of the program.

    mov rbx, rax

; Obtain file size.

get_size:

    ; Prepare sys_open with file descriptor 
    ; and pointer to memory reserved in section .bss.

    mov rax, SYS_FSTAT_CODE
    mov rdi, rbx
    mov rsi, memory_for_fstat
    syscall

    ; Validate sys_fstat return code.
    ; If rax < 0 close and exit with code 1.
    ; Otherwise proceed.

    cmp rax, 0
    jl exit_on_failure

    ; Validate the file size.
    ; Files of size < 2 bytes are too small to reverse 
    ; meaningfully - close and exit with code 0.
    ; Otherwise proceed.

    mov rax, [memory_for_fstat + FILE_SIZE_OFFSET_STAT]
    cmp rax, MINIMAL_FILE_SIZE
    jl exit_on_success

    ; Save the file size to r12 for the duration of the program.

    mov r12, rax

; Try and map the file to memory.

mmap_file:

    ; Prepare sys_mmap with null address, file size, 
    ; prot. read and write permissions,
    ; map-shared flags, file descriptor and zero offset.

    mov rax, SYS_MMAP_CODE
    mov rdi, KERNEL_CHOSEN_ADDRESS
    mov rsi, r12
    mov rdx, PROTECTED_READ_WRITE_PERMISSIONS
    mov r10, MAP_SHARED_FLAGS
    mov r8, rbx
    mov r9, NO_OFFSET_MAP
    syscall

    ; Validate sys_mmap return code.
    ; If rax < 0 close and exit with code 1.
    ; Otherwise proceed.

    cmp rax, 0
    jl exit_on_failure

    ; Save mapped address to r13 for the duration of the program.

    mov r13, rax

; Reverse the file - prepare for the loop.

reverse:

    ; Reversing logic:
    ; The reversing algorithm is divided into two sections:
    ; The qword-by-qword reversing and the byte-by-byte reversing.

    ; Place two pivots, one at the first byte of the file and one at the last
    ; and if they differ by 15 bytes or more, switch the first and last qword,
    ; by moving the latter pivot 7 bytes down and swapping registers.
    ; Before switching qwords call bswap to reverse their contents.

    ; When the pivots get close enough for clean qword swap to not be possible,
    ; move on to switching the bytes one by one. For that reason the latter 
    ; pivot is first placed at the end of its qword, 
    ; and only in qword loop moved to the first.

    ; Before the loop prepare two pivots:
    ; One for mapped file's first byte and one for file's last byte.

    mov rsi, r13
    lea rdi, [r13 + r12 - 1]

; Begin by reversing the file qword-by-qword in a loop.

reverse_loop_qwords:

    ; Validate the distance between pivots.
    ; If smaller than 15, reverse the remainder byte-by-byte.
    ; Otherwise proceed.

    mov rax, rdi
    sub rax, rsi
    cmp rax, MINIMAL_PIVOTS_DISTANCE_FOR_QWORDS
    jl reverse_loop_bytes
    
    ; In order to swap two 8-byte-long words, 
    ; both pivots should point to the first byte of their qwords.
    ; To achieve that, move rdi down by 7 bytes.

    sub rdi, FIRST_TO_LAST_BYTE_IN_QWORD_DIFF

    ; Load qwords from pivots.

    mov rax, [rsi]
    mov rcx, [rdi]

    ; Reverse the qwords.

    bswap rax
    bswap rcx

    ; Switch the qwords.

    mov [rsi], rcx
    mov [rdi], rax

    ; Move on to the next pair of qwords.
    ; Move rsi to the first byte of her next qword 
    ; and rdi to the last byte of his next qword.
    ; Use it to calculate the distance between them in the next iteration.

    add rsi, QWORD_SIZE_IN_BYTES
    dec rdi

    ; Jump to the next iteration.

    jmp reverse_loop_qwords

; Reverse the remainder byte-by-byte in a loop.

reverse_loop_bytes:

    ; Validate the distance between the pivots.
    ; If rsi caught or surpassed rdi, the file is fully reversed.
    ; Otherwise continue with the loop.

    cmp rsi, rdi
    jge synchronize

    ; Load bytes from pivots.

    mov al, [rsi]
    mov cl, [rdi]

    ; Switch the bytes.

    mov [rsi], cl
    mov [rdi], al

    ; Move the pointers one step closer to each other.

    inc rsi
    dec rdi

    ; Jump to the next iteration.

    jmp reverse_loop_bytes

; Synchronize mapped file with original file.

synchronize:

    ; Prepare sys_msync with mapped address, file size and MS_SYNC flag.

    mov rax, SYS_MSYNC_CODE
    mov rdi, r13
    mov rsi, r12
    mov rdx, MS_SYNC_FLAG
    syscall

    ; Validate sys_msync return code.
    ; If rax < 0 unmap, close and exit with code 1.
    ; Otherwise exit successfully.

    cmp rax, 0
    jl exit_on_failure

    jmp exit_on_success


; Unmap, close file and exit.

clean_up_and_exit:

; Clear mapped memory regions.

munmap:

    ; Inspect r13:
    ; if = 0 the file was never mapped - skip this step.
    ; Otherwise call sys_munmap to clear the memory.

    test r13, r13
    jz close_file

    ; Prepare sys_munmap with mapped address and file size.

    mov rax, SYS_MUNMAP_CODE
    mov rdi, r13
    mov rsi, r12
    syscall

    ; Zero r13 to note that sys_munmap was already called.
    ; (in case of further errors, however unlikely)

    xor r13, r13

    ; Validate sys_munmap return code.
    ; If rax < 0 close file and exit with code 1.
    ; Otherwise proceed.

    cmp rax, 0
    jl exit_on_failure

; Close the opened file.

close_file:

    ; Inspect rbx:
    ; if = 0 the file was never opened - skip this step.
    ; Otherwise close to exit the program properly.

    test rbx, rbx
    jz exit

    ; Prepare sys_close with file descriptor.

    mov rax, SYS_CLOSE_CODE
    mov rdi, rbx
    syscall

    ; Zero rbx to note that sys_close was already called.
    ; (in case of further errors, however unlikely)

    xor rbx, rbx

    ; Validate sys_close return code.
    ; If rax < 0 exit with code 1.
    ; Otherwise proceed.

    cmp rax, 0
    jl exit_on_failure

; Exit the program.

exit:

    ; Pop exit code from stack and save it to rdi.

    pop rdi

    ; Prepare sys_exit.

    mov rax, SYS_EXIT_CODE
    syscall

;

; Free memory, close file and exit program with code 0.

exit_on_success:

    ; Set rdi to 0 and push the value on stack.

    xor rdi, rdi
    push rdi

    ; Clean up and exit with code 0 saved on stack.

    jmp clean_up_and_exit

; Free memory, close file and exit program with code 1.

exit_on_failure:
        
    ; Set rdi to 1 and push the value on stack.

    mov rdi, FAILURE_CODE
    push rdi

    ; Clean up and exit with code 1 saved on stack.

    jmp clean_up_and_exit    