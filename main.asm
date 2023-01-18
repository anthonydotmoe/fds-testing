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

SCROLLSPEED = $04

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

  lda #$7C      ; set player X/Y to middle of screen
  sta PLAYER_X
  sta PLAYER_Y

  ; clear OAMDATA
  lda #$00
  ldx #$00
:
  sta OAMDATA,x
  inx
  bne :-

  ; set all 64 sprites y-pos to off screen
  lda #$FF
  ldx #$00
  ldy #$00
:
  sta OAMDATA,x
  inx
  inx
  inx
  inx
  iny
  cpy #64
  bne :-


  ; write bg palette

  bit PPUSTATUS
  ldx #$3F      ; load $3F00 to PPUADDR
  stx PPUADDR
  ldx #$00
  stx PPUADDR
:
  lda MARIOPALETTE,X
  sta PPUDATA
  inx
  cpx #$04
  bcc :-

  ; write sprite palette

  bit PPUSTATUS
  ldx #$3F      ; load $3F00 to PPUADDR
  stx PPUADDR
  ldx #$11
  stx PPUADDR
  ldx #$01
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
  lda #%10010000
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
  lda YSCROLL
  clc
  adc #SCROLLSPEED
  sta YSCROLL
: 
  lda BUTTONS1
  and #BUTTON_DOWN
  beq :+
  ; down pressed
  lda YSCROLL
  sec
  sbc #SCROLLSPEED
  sta YSCROLL
:
  lda BUTTONS1
  and #BUTTON_LEFT
  beq :+
  ; left pressed
  lda PLAYER_X
  sec
  sbc #SCROLLSPEED
  sta PLAYER_X
:
  lda BUTTONS1
  and #BUTTON_RIGHT
  beq :+
  ; right pressed
  lda PLAYER_X
  clc
  adc #SCROLLSPEED
  sta PLAYER_X
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

;  lda FRAMERDY
;  cmp #$01
;  beq EndNMI

DrawPlayer:

SPRITE1      = OAMDATA + $04
SPRITE1_Y    = SPRITE1 + $00
SPRITE1_TILE = SPRITE1 + $01
SPRITE1_PAL  = SPRITE1 + $02
SPRITE1_X    = SPRITE1 + $03

SPRITE2      = OAMDATA + $08
SPRITE2_Y    = SPRITE2 + $00
SPRITE2_TILE = SPRITE2 + $01
SPRITE2_PAL  = SPRITE2 + $02
SPRITE2_X    = SPRITE2 + $03

SPRITE3      = OAMDATA + $0C
SPRITE3_Y    = SPRITE3 + $00
SPRITE3_TILE = SPRITE3 + $01
SPRITE3_PAL  = SPRITE3 + $02
SPRITE3_X    = SPRITE3 + $03

SPRITE4      = OAMDATA + $10
SPRITE4_Y    = SPRITE4 + $00
SPRITE4_TILE = SPRITE4 + $01
SPRITE4_PAL  = SPRITE4 + $02
SPRITE4_X    = SPRITE4 + $03
  ; put sprite on screen, there's probably a better way to do this
  ; top left
  lda PLAYER_X
  sta SPRITE1_X
  lda PLAYER_Y
  sta SPRITE1_Y
  lda #$00
  sta SPRITE1_TILE

  ; top right
  lda PLAYER_X
  clc
  adc #$08
  sta SPRITE2_X
  lda PLAYER_Y
  sta SPRITE2_Y
  lda #$01
  sta SPRITE2_TILE

  ; bottom left
  lda PLAYER_X
  sta SPRITE3_X
  lda PLAYER_Y
  clc
  adc #$08
  sta SPRITE3_Y
  lda #$10
  sta SPRITE3_TILE

  ; bottom right
  lda PLAYER_X
  clc
  adc #$08
  sta SPRITE4_X
  lda PLAYER_Y
  clc
  adc #$08
  sta SPRITE4_Y
  lda #$11
  sta SPRITE4_TILE

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

EndNMI:
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
