  ; vim: set syn=650:
  .include "inc/fds.asm"
  .include "inc/nes.asm"

;===============================================================================
; Zero-Page variables
CLRMEM_L .ezp $10
CLRMEM_H .ezp $11

YSCROLL .ezp $12

PLAYER_X .ezp $13
PLAYER_Y .ezp $14

FRAMERDY .ezp $15

BUTTONS1 .ezp $16
BUTTONS2 .ezp $17

;===============================================================================
; Variables, structures

; OAM data page ($0200-$02FF)
OAMDATA = $0200

  .org FDS_PRAM

MAINGAME_START:

;===============================================================================
; Constant Data

; palettes
MARIOPALETTE:
  .db $23, $16, $36, $0F


;===============================================================================
; Main loop

GAMEINIT:
  lda #$00      ; set YSCROLL to zero
  sta YSCROLL

  ; clear OAMDATA
  ldx #$00
:
  sta $0200,x
  inx
  bne :-

  ; write a palette

  bit PPUSTATUS
  ldx #$3F      ; load $3F00 to PPUADDR
  stx PPUADDR
  ldx #$00
  stx PPUADDR
:
  lda MARIOPALETTE,X
  sta PPUDATA
  inx
  cpx #$03
  bcc :-

  ; Set FDS to use vertical mirroring
  lda #%00100110
  sta FDSCTRL

  ; Set PPUMASK to turn on background
  bit PPUSTATUS
  lda #%00011110
  sta PPUMASK

  ; Set PPUCTRL to enable NMI on VBlank
  bit PPUSTATUS
  lda #%10011000
  sta PPUCTRL

main:
; the plan:
;  - grab controller input
;  - do calculations
;  - if main loop finished, set variable to allow NMI handler to set PPU data, etc.
;  - if the main loop didn't finish, let the NMI handler pass control back to
;    the loop to finish processing

  jsr ReadJoypadSub

  lda BUTTONS1
  and #BUTTON_UP
  beq :+
  ; up pressed
  inc YSCROLL
: 
  lda BUTTONS1
  and #BUTTON_DOWN
  beq :+
  ; down pressed
  dec YSCROLL
:

maindone:
  lda #$00
  sta FRAMERDY
  lda #$01
loop:
  bit FRAMERDY
  beq loop
  jmp main

;===============================================================================
; Vector routines

BYPASS:
; the kyodaku bypass method will fire an NMI during disk load. The following
; will be executed when that NMI fires. We need to: disable V-Sync NMIs,
; replace the NMI3 vector with the actual NMI handler address, tell the BIOS to
; use the reset vector at $DFFC on reset, then reset.
  ; disable PPU NMI handling
  lda #$00
  sta PPUSTATUS
  ; replace NMI 3 "bypass" vector at $DFFA
  lda #<NMI
  sta $DFFA
  lda #>NMI
  sta $DFFB
  ; set reset handler for BIOS
  lda #$35
  sta $0102
  lda #$AC
  sta $0103
  ; jump to FDS BIOS reset vector
  jmp ($FFFC)

IRQ:
  rti

NMI:
  ; put away a and x
  pha
  txa
  pha

  ; Copy memory from $0200-$02FF to OAM
  lda #$00     ; write to address $00 of OAM
  sta OAMADDR
  lda #$02     ; write 256 bytes from ($02)00 to OAM
  sta OAMDMA

  ; scroll bg
  bit PPUSTATUS ; reset address latch
  lda #$00
  sta PPUSCROLL
  lda YSCROLL
  sta PPUSCROLL

  ; set FRAMERDY to 1
  lda #$01
  sta FRAMERDY

  ; restore a and x
  pla
  tax
  pla

  rti

;===============================================================================
; subroutines

ClearMemSub:
  ;Inputs
  ;                   Y: Number of bytes to clear
  ;  CLRMEM_L, CLRMEM_H: 16-bit pointer to start of memory to clear
  ;Changes
  ;  A

  lda #$00
:
  dey
  sta (CLRMEM_L),y
  bne :-
  rts

ReadJoypadSub:
  lda #$01
  sta JOYPAD1
  sta BUTTONS2
  lsr a
  sta JOYPAD1
:
  lda JOYPAD1
  and #%00000011
  cmp #$01
  rol BUTTONS1
  lda JOYPAD2
  and #%00000011
  cmp #$01
  rol BUTTONS2
  bcc :-
  rts

;===============================================================================
; interrupt vector table

  .org FDS_PRAM + $7FF6

  .dw NMI
  .dw NMI
  .dw BYPASS
  .dw GAMEINIT
  .dw IRQ
