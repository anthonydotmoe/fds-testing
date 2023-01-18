; vim: set syn=650:

; Constants
;===============================================================================

; Header constants
REVISION    = $00 ; revision number used in the header
SIDE_COUNT  = $01 ; number of disk sides
FILE_COUNT = $04 ; total number of non-hidden files on disk side 1...
                 ; for the kyodaku skip, put n+1 files in the header so the BIOS
		 ; will keep scanning for the next file until NMI

  .include "inc/fds.asm"


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
  .db FILE_COUNT          ; Boot read file code (file code to load upon boot)
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

; File "MAIN    "
;-------------------------------------------------------------------------------
; Main program data

; File header block
  .db $03        ; Block code (3 = file header block)
  .db $00        ; File number
  .db $00        ; File ID
                 ;   This is the number which will decide which file is loaded from
	         ;   disk (instead of the file number). An ID smaller than the boot
	         ;   number means the file is a boot file, and will be loaded on
	         ;   boot.
  .db "MAIN    " ; File name (8 uppercase ASCII characters)
  .dw FDS_PRAM   ; File address (16-bit little endian)
                 ;   The destination address when loading
  .dw (MainEnd - MainStart)      ; File size
  .db $00        ; File type
                 ;   0: Program   (PRAM)
	         ;   1: Character (CRAM)
	         ;   2: Nametable (VRAM)

; File data block
  .db $04            ; Block code (4 = file data block)
MainStart:
  .incbin "main.bin" ; file data
MainEnd:

; File "CHR     "
;-------------------------------------------------------------------------------
; CHR data, contains a sprite

; File header block
  .db $03
  .db $01
  .db $01
  .db "CHR     "
  .dw $0000        ; Pattern Table 0
  .dw (CHREnd - CHRStart)
  .db $01

; File data block
  .db $04
CHRStart:
  .incbin "chr.bin"
CHREnd:

; File "BYPASS--"
;-------------------------------------------------------------------------------
; Write $90 to $2000, this sets PPUCTRL to enable interrupts while the BIOS is
; trying to load the next file. BIOS will handle this by jumping to $DFFA (where
; our file has loaded it's own vectors)

; File header block
  .db $03
  .db $02
  .db $02
  .db "BYPASS--"
  .dw $2000
  .dw $0001
  .db $00

; File data block
  .db $04      ; Block code (4 = file data block)
  .db $90      ; file data


; End of Disk Side 1
;-------------------------------------------------------------------------------

  .db $FF ; End of disk side indicator
  .org 65500

;===============================================================================
