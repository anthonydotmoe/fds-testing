VASM_ARGS=-dotdir -Fbin

all: maingame
	vasm6502_oldstyle $(VASM_ARGS) fds.asm -o hello.fds

maingame: main.asm
	vasm6502_oldstyle $(VASM_ARGS) main.asm -o main.bin
