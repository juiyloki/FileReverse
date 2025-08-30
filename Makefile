# Makefile for freverse.asm
# Builds the assembly program into an executable using NASM and ld.

# Assembler and linker (can be overridden from command line).
NASM      ?= nasm
LD        ?= ld

# NASM flags:
# -f elf64: output ELF64 object
# -w+all, -w+error: treat warnings as errors
# -w-unknown-warning: ignore unknown warnings
# -w-reloc-rel: relocation handling
NASMFLAGS := -f elf64 -w+all -w+error -w-unknown-warning -w-reloc-rel

# Linker flags:
# --fatal-warnings: treat linker warnings as errors
LDFLAGS   := --fatal-warnings

# File names
TARGET    := freverse
SRC       := freverse.asm
OBJ       := $(TARGET).o

.PHONY: all clean run

# Default target: build executable
all: $(TARGET)

# Compile assembly to object file
$(OBJ): $(SRC)
	$(NASM) $(NASMFLAGS) -o $@ $<

# Link object file to executable
$(TARGET): $(OBJ)
	$(LD) $(LDFLAGS) -o $@ $<

# Run program with optional ARGS: make run ARGS=file
run: $(TARGET)
	./$(TARGET) $(ARGS)

# Clean build artifacts
clean:
	rm -f $(OBJ) $(TARGET)

