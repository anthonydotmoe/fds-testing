VASM_ARGS=-dotdir -Fbin

all: maingame
	vasm6502_oldstyle $(VASM_ARGS) fds.650 -o hello.fds

maingame: main.650
	vasm6502_oldstyle $(VASM_ARGS) main.650 -o main.bin
