# freverse

`freverse` is a low-level utility written in x86-64 assembly for Linux that reverses the contents of a file **in place**.  
It was developed as a university assignment at the University of Warsaw (MIMUW).

---

## Overview

The program takes one argument: a file path.  
It reverses the file’s content efficiently using memory mapping (mmap) and direct memory manipulation.  

### Behavior
- If the file is smaller than 2 bytes, it is left unchanged.  
- The program works correctly with very large files, including those larger than 4 GiB.  
- All system resources (file descriptors, mapped memory) are explicitly released before exit.  
- On error, the program terminates with exit code `1`. On success, it exits with `0`.  
- Nothing is printed to standard output or error.

---

## Usage

./freverse file

- `file` must be a valid, accessible file.  
- If the argument count is invalid, or a system call fails, the program exits with code `1`.  

---

## Build Instructions

The program builds with NASM and ld. A Makefile is provided.
```
make
make run ARGS=path/to/file
make clean
```
---

## Implementation Details

- Written in x86-64 assembly using the Linux syscall interface.  
- Relies on:
  - open, fstat, mmap, msync, munmap, close, exit  
- Efficient reversal algorithm:
  - Uses qword-by-qword swapping with bswap where possible.  
  - Falls back to byte-by-byte swapping for the tail section.  
- Memory safety and cleanup are prioritized:
  - File descriptors and memory mappings are tracked in registers and closed/unmapped explicitly.

---

## Notes

- This program was created as part of coursework.  
- It is provided as an educational example of systems programming in assembly.  

