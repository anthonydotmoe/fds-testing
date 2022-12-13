; vim: set syn=650:

; Constants
;===============================================================================

; Header constants
REVISION    = $00 ; revision number used in the header
SIDE_COUNT  = $01 ; number of disk sides
FILE_COUNT = $02 ; total number of non-hidden files on disk side 1

; FDS defines
FDS_CRAM = $0000 ; where CHR-RAM starts
FDS_PRAM = $6000 ; where PRG-RAM starts
FDS_BIOS = $E000 ; where the FDS BIOS starts

; FDS BIOS calls
FDS_Delay132 = $E149 ; 132 clock cycle delay

; Variables
;===============================================================================

; Zero Page ($0000-$00FF)


; fwNES FDS header
;===============================================================================

; 16 byte header for FDS file
;.org $0000
  .db "FDS",$1A
  .db SIDE_COUNT
  .org 16

; Disk Side 1 (65500 bytes)
;===============================================================================

; Disk header block
  .db $01                 ; Block code (1 = disk header block)
  .db "*NINTENDO-HVC*"    ; Used by BIOS to verify legitimate image
  .db $00                 ; Maker code
  .db "HMB"               ; 3-letter ASCII code for title
  .db " "                 ; Game type
                          ;   $20 " " -- Normal disk
		          ;   $45 "E" -- Event
		          ;   $52 "R" -- Reduction in price
  .db REVISION            ; Revision number
  .db $00                 ; Side number
  .db $00                 ; Disk number
  .db $00                 ; Disk type
                          ;   $00 -- FMC ("normal card")
		          ;   $01 -- FSC ("card with shutter")
  .db $00                 ; Unknown
  .db $01                 ; Boot read file code (file code to load upon boot)
  .db $FF,$FF,$FF,$FF,$FF ; Unknown
  .db $00,$00,$00         ; Manufacturing date
                          ;   Stored in BCD, subtract the Shouwa starting year
			  ;   1925 from the year
  .db $49                 ; Country code ($49 = Japan)
  .db $61                 ; Unknown
  .db $00                 ; Unknown
  .db $00,$02             ; Unknown
  .db $00,$00,$00,$00,$00 ; Unknown
  .db $00,$00,$00         ; "Rewritten disk" date
  .db $00
  .db $80
  .db $00,$00             ; Disk writer serial number
  .db $07
  .db $00                 ; Disk rewrite count (BCD)
  .db $00                 ; Actual disk side
  .db $00                 ; Unknown
  .db $00                 ; Price
; .db $00,$00             ; CRC - not used in the .fds file format

; File amount block
  .db $02         ; Block code (2 = file amount block)
  .db FILE_COUNT ; Total number of files recorded on disk (side?)
; If more files exist on disk they will be considered hidden and the BIOS will
; ignore them. A loading routine on disk is required to load them

; File codes:
; All files with IDs less than or equal to the boot read file code will be
; loaded by BIOS when the game is booting

; File "KYODAKU-"
;-------------------------------------------------------------------------------

; The first file on the disk must be the "KYODAKU-" file. This contains the
; message that scrolls up on the screen at boot, and must match the data stored
; in BIOS at $ED37.

; File header block
  .db $03        ; Block code (3 = file header block)
  .db $00        ; File number
  .db $00        ; File ID
                 ;   This is the number which will decide which file is loaded from
	         ;   disk (instead of the file number). An ID smaller than the boot
	         ;   number means the file is a boot file, and will be loaded on
	         ;   boot.
  .db "KYODAKU-" ; File name (8 uppercase ASCII characters)
  .dw $2800      ; File address (16-bit little endian)
                 ;   The destination address when loading
  .dw $00E0      ; File size
  .db $02        ; File type
                 ;   0: Program   (PRAM)
	         ;   1: Character (CRAM)
	         ;   2: Nametable (VRAM)

; File data block
  .db $04                 ; Block code (4 = file data block)
  .include "kyodaku-.asm" ; file data

; File "MAINGAME"
;-------------------------------------------------------------------------------

; File header block
  .db $03
  .db $01
  .db $01
  .db "MAIN    "
  .dw FDS_PRAM
  .dw (MainEnd - MainStart)
  .db $00

; File data block
  .db $04                 ; Block code (4 = file data block)
MainStart:
  .incbin "main.bin"      ; file data
MainEnd:


; End of Disk Side 1
;-------------------------------------------------------------------------------

  .db $FF ; End of disk side indicator
  .org 65500

;===============================================================================
