  ; vim: set syn=650:
  .include "inc/fds.asm"
  .include "inc/nes.asm"

YSCROLL .ezp $10

  .org FDS_PRAM

MAINGAME_START:

; the kyodaku bypass method will fire an NMI during disk load. The following
; will be executed when that NMI fires. We need to: disable V-Sync NMIs,
; replace the NMI3 vector with the actual NMI handler address, tell the BIOS to
; use the reset vector at $DFFC on reset, then reset.
BYPASS:
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
  jsr FDS_HOOK
  rti

NMI:
  jsr FDS_HOOK

  ; put away a and x
  pha
  txa
  pha

  ; scroll bg
  bit PPUSTATUS ; reset address latch
  ldx #$00
  stx PPUSCROLL
  ldx YSCROLL
  stx PPUSCROLL
  inx 
  stx YSCROLL

  ; restore a and x
  pla
  tax
  pla


  ; Copy memory from $0200-$02FF to OAM
  lda #$00     ; write to address $00 of OAM
  sta OAMADDR
  lda #$02     ; write 256 bytes from ($02)00 to OAM
  sta OAMDMA
  rti

RESET:
  jsr FDS_HOOK

gameinit:
  lda #$00      ; set YSCROLL to zero
  sta YSCROLL

main:
  ; write a palette

  bit PPUSTATUS
  ldx #$3F      ; load $3F00 to PPUADDR
  stx PPUADDR
  ldx #$00
  stx PPUADDR

  lda #$29      ; write the palette data
  sta PPUDATA
  lda #$19
  sta PPUDATA
  lda #$09
  sta PPUDATA
  lda #$0F
  sta PPUDATA

  ; write nametable

  bit PPUSTATUS
  lda #$20      ; load $2020 to PPUADDR
  sta PPUADDR
  sta PPUADDR

  ldx #$00
:
  lda nametabledata, x
  inx
  sta PPUDATA
  cpx #64
  bne :-

  ; Set FDS to use vertical mirroring
  lda #%00101110
  sta $4025

  ; Set PPUMASK to turn on background
  bit PPUSTATUS
  lda #%00011110
  sta PPUMASK

  ; Set PPUCTRL to enable NMI on VBlank
  bit PPUSTATUS
  lda #%10011000
  sta PPUCTRL

loop:

  jmp loop

FDS_HOOK:
  pha
  lda #$C0
  sta $0100
  lda #$80
  sta $0101
  lda #$35
  sta $0102
  lda #$53
  sta $0103
  pla
  rts

nametabledata:
  .include "nametable.asm"

; interrupt vector table

  .org FDS_PRAM + $7FF6

  .dw NMI
  .dw NMI
  .dw BYPASS
  .dw RESET
  .dw IRQ
