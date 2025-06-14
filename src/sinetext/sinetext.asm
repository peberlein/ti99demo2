* Sinetext.asm

WRKSP  EQU  >8320             ; Workspace memory in fast RAM, 16 registers, 32 bytes

VDPWD  EQU  >8C00             ; VDP write data
VDPWA  EQU  >8C02             ; VDP set read/write address
VDPRD  EQU  >8800             ; VDP read data (don't forget NOP after address)
VDPSTA EQU  >8802             ; VDP status
VDPWM  EQU  >4000             ; VDP address write mask
VDPRM  EQU  >8000             ; VDP address register mask


* VDP RAM layout
CLRTAB EQU >0000  ; Char color table (6KB = >1800)
SCRTAB EQU >1800  ; Screen table (768 bytes = >300)
SPRTAB EQU >1B00  ; Sprite list table (128 bytes)
PATTAB EQU >2000  ; Char pattern table (6KB = >1800)
SPRPAT EQU >3800  ; Sprite patterns (>800 bytes)

R0LB   EQU  WRKSP+1           ; Register low byte address
R1LB   EQU  WRKSP+3           ; Register low byte address
R2LB   EQU  WRKSP+5           ; Register low byte address
R3LB   EQU  WRKSP+7           ; Register low byte address
R4LB   EQU  WRKSP+9           ; Register low byte address
R5LB   EQU  WRKSP+11          ; Register low byte address
R6LB   EQU  WRKSP+13          ; Register low byte address
R7LB   EQU  WRKSP+15          ; Register low byte address
R8LB   EQU  WRKSP+17          ; Register low byte address
R9LB   EQU  WRKSP+19          ; Register low byte address
R10LB  EQU  WRKSP+21          ; Register low byte address
R11LB  EQU  WRKSP+23          ; Register low byte address
R12LB  EQU  WRKSP+25          ; Register low byte address
R13LB  EQU  WRKSP+27          ; Register low byte address


SPRCNT EQU 28  ; sprite count


       AORG >A000

       LWPI WRKSP

       LI R14,VDPWA
       LI R15,VDPWD

       ; Initialize VDP registers
       LI R1,VDPINI
       LI R0,VDPRM     ; Register mask
!      MOVB *R1+,*R14  ; Write register data
       MOVB R0,*R14    ; Write register number
       AI R0,>100
       CI R0,>800+VDPRM
       JL -!



       ; Copy fast VDPW to fast RAM
       LI R0,FSRC     ; src
       LI R1,FVDPW    ; dest
       LI R2,FVDPWS/2 ; count in words
!      MOV *R0+,*R1+
       DEC R2
       JNE -!


       ; Initialize screen table for bitmap
       LI R0,SCRTAB+VDPWM
       MOVB @R0LB,*R14
       MOVB R0,*R14
       CLR R0
       LI R2,768
!      MOVB R0,*R15
       AI R0,>100
       DEC R2
       JNE -!

       BL @FSYNC     ; fast vsync music

       LI R0,PATTAB+VDPWM
       LI R1,TIAP+128  ; skip TIFILES header
       LI R2,6*1024 / 8 ; in 8byte chunks
       BL @FVDPW

       BL @FSYNC     ; fast vsync music

       LI R0,CLRTAB+VDPWM
       LI R1,TIAC+128  ; skip TIFILES header
       LI R2,6*1024 / 8 ; in 8byte chunks
       BL @FVDPW


       ; Setup char pattern strips
       ; NCHARS*4*4*2*8 ; pattern data char*quad*shift*leftright*pixels
; offset calculation:
; char * 256
; + quad(0-3) * 64
; + shift(0-3) * 16
; + (left=0 right=1) * 8 +
; + pixel row(0-7)

       LI R1,TEXTPAT   ; source
       LI R2,NCHARS    ; number of char patterns
       LI R3,STRPAT    ; dest  (will consume 16K)
CHARLP
       BL @FSYNC     ; fast vsync music

       BL @SHIFTC
       DATA ~>8080   ; x0000000
       NOP
       BL @SHIFTC
       DATA ~>4040   ; 0x000000
       NOP
       AI R3,48

       BL @SHIFTC
       DATA ~>2020   ; 00x00000
       SLA R0,2
       BL @SHIFTC
       DATA ~>1010   ; 000x0000
       SLA R0,2
       AI R3,48

       BL @SHIFTC
       DATA ~>0808   ; 0000x000
       SLA R0,4
       BL @SHIFTC
       DATA ~>0404   ; 00000x00
       SLA R0,4
       AI R3,48

       BL @SHIFTC
       DATA ~>0202   ; 000000x0
       SLA R0,6
       BL @SHIFTC
       DATA ~>0101   ; 0000000x
       SLA R0,6
       AI R3,48

       AI R1,8         ; next character pattern
       DEC R2     ; next character
       JNE CHARLP


       ; Setup initial strip pointers
       LI R1,STRIPS
       LI R0,STRPAT+(256*(SPACE-CHAR0))
       LI R2,WIDTH/8
!
       BL @CSTRIP    ; copy strip from R0 to R1
       AI R0,-64*3   ; revert
       DEC R2
       JNE -!

       ; Copy initial sprite table to fast RAM
       LI R0,SPR
       LI R1,SPRDATA
       LI R2,SPRCNT
!      MOV *R1+,*R0+
       MOV *R1+,R4
       ANDI R4,>FFF0
       ORI R4,SPRCLR  ; override sprite color
       MOV R4,*R0+
       DEC R2
       JNE -!


       LI R0,>01E2   ; register 1: 16x16 sprites
       BL @VWTR


       LI R1,STRIPS+WIDTH-8  ; Starting char output pointer
       MOV R1,@OUTPTR
       LI R9,STRIPS   ; Strip pointers offset
       LI R10,MSG     ; Message source pointer
       LI R13,8       ; Message counter

MAINLP
       ; update sprite patterns
       LI R0,SPRPAT+VDPWM   ; point to sprite patterns
       MOVB @R0LB,*R14      ; Send low byte of VDP RAM write address
       MOVB R0,*R14         ; Send high byte of VDP RAM write address

       ; draw strips from R9 into sprite patterns
       JMP RUNSPR  ; modifies R0-R8
RUNSRT ; RUNSPR will branch back to here


       LI R0,SPRTAB+VDPWM   ; point to sprites table
       MOVB @R0LB,*R14      ; Send low byte of VDP RAM write address
       MOVB R0,*R14         ; Send high byte of VDP RAM write address

       LI R1,SPR       ; point to sprites datas
       LI R2,SPRCNT
SPRLP      ; sprite loop
       MOV *R1+,R0  ; get Y,idx
       MOV *R1,R5   ; get X,early clock+color

       ; wrap at edges
       CI R5,>FF00+SPRCLR
       JNE !
       AI R5,>80->F000
!      CI R5,>2080+SPRCLR
       JNE !
       AI R5,->2080
!
       AI R5,>100     ; move sprite right 1 pixel

       MOV R5,*R1+    ; store updated X,early clock+color

       MOVB R0,*R15   ; send Y coord
       MOVB R5,*R15   ; send X coord
       MOVB @R0LB,*R15   ; send pat idx
       MOVB @R5LB,*R15   ; send early clock and color

       DEC R2
       JNE SPRLP


       ; scroll text to the left by incrementing strip pointer
       INCT R9
       CI R9,STRIPS+WIDTH
       JNE !
       LI R9,STRIPS ; wrap around
!

       ; every 8 steps, load 1 new char from R10
       DEC R13
       JNE !!

       CI R10,MSGEND
       JEQ DONE

       LI R0,STRPAT-(CHAR0*256)  ; set base strip address
       AB *R10+,R0   ; add character offset

       MOV @OUTPTR,R1
       BL @CSTRIP   ; copy 4 strip pointers from R0 to R9
       CI R1,STRIPS+WIDTH
       JNE !
       LI R1,STRIPS ; wrap around
!      MOV R1,@OUTPTR
       LI R13,8  ; reset counter
!
       JMP MAINLP

DONE   B @LDNEXT

RUNSPR COPY "sinetext.inc"


CSTRIP ; copy strip from R0 to R1
       MOV R0,@WIDTH(R1)
       MOV R0,*R1+
       AI R0,64      ; next quad
       MOV R0,@WIDTH(R1)
       MOV R0,*R1+
       AI R0,64      ; next quad
       MOV R0,@WIDTH(R1)
       MOV R0,*R1+
       AI R0,64      ; next quad
       MOV R0,@WIDTH(R1)
       MOV R0,*R1+
       RT

; Shift and write: write 4 columns of pixel data in R0, shifted by 2 each time
; R5 inverted column mask
; *R11 shift instruction or NOP
; Modifies R0, R4, R3(+8)
SHIFTC
       MOV *R11+,R5 ; get bit mask
       MOV *R11+,R6 ; get shift instruction
       LI R4,4    ; extract 4 words per character
!      MOV *R1+,R0
       SZC R5,R0    ; mask the word
       X R6         ; shift as needed
       MOVB R0,*R3+
       MOVB @R0LB,*R3+
       SRL R0,2
       MOVB R0,@14(R3)
       MOVB @R0LB,@15(R3)
       SRL R0,2
       MOVB R0,@30(R3)
       MOVB @R0LB,@31(R3)
       SRL R0,2
       MOVB R0,@46(R3)
       MOVB @R0LB,@47(R3)

       DEC R4
       JNE -!
       AI R1,-8   ; return to original pointer
       RT



VDPINI
       BYTE >02          ; VDP Register 0: 02 (Bitmap Mode)
       BYTE >82          ; VDP Register 1: Blank, 16x16 Sprites
       BYTE (SCRTAB/>400); VDP Register 2: Screen Image Table
       BYTE (CLRTAB/>40)+>7F ; VDP Register 3: Color Table
       BYTE (PATTAB/>800)+>3; VDP Register 4: Pattern Table
       BYTE (SPRTAB/>80) ; VDP Register 5: Sprite List Table
       BYTE (SPRPAT/>800); VDP Register 6: Sprite Pattern Table
       BYTE >F1          ; VDP Register 7: White on Black

MSG
       ;TEXT "THIS=IS=A=MESSAGE=HERE"

       TEXT "DID=SOMEONE=SAY=IT<S=TIME=FOR=A=TEAM-UP?=="
       ;TEXT "YOU=BET=YOUR=CUTE=BUTT=IT=IS>=="
       TEXT "THE=CREW=IS=HARD=AT=WORK=CODING=FOR=THE=TI-99/4A=HOME=COMPUTER.=="
       TEXT "SLEEP=IS=FOR=THE=WEAK>=="
       TEXT "COUNT=CYCLES,=NOT=SHEEP.=="
       ;TEXT "SECURELY=FASTEN=YOUR=UTILITY=BELTS=FRENDOS:="
       ;TEXT "WE<RE=ABOUT=TO=KNOCK=YOUR=PANTS=OFF>="
       TEXT "SIT=BACK=AND=ENJOY=THE=SHOW>"

       TEXT "================================"
MSGEND
       EVEN

* exported binary from sine.mag, chars 44',' to 90'Z'
* note: substitutions
SPACE  EQU '='
EXMARK EQU '>'
APOSTR EQU '<'
TEXTPAT BCOPY "textpat.bin"
TIAP   BCOPY "DEADPOOL.TIAP"
TIAC   BCOPY "DEADPOOL.TIAC"

       EVEN

FSRC
       XORG WRKSP+32        ; after workspace registers
* Fast RAM code to copy R2 * 8 bytes from R1 to VDP address R0(must have VDPWM)
FVDPW
       MOV R11,R13
       MOVB @R0LB,*R14      ; Send low byte of VDP RAM write address
       ORI  R0,VDPWM        ; Set read/write bits 14 and 15 to write (01)
       MOVB R0,*R14         ; Send high byte of VDP RAM write address
!      MOVB *R1+,*R15       ; Write byte to VDP RAM
       MOVB *R1+,*R15       ; Write byte to VDP RAM
       MOVB *R1+,*R15       ; Write byte to VDP RAM
       MOVB *R1+,*R15       ; Write byte to VDP RAM
       MOVB *R1+,*R15       ; Write byte to VDP RAM
       MOVB *R1+,*R15       ; Write byte to VDP RAM
       MOVB *R1+,*R15       ; Write byte to VDP RAM
       MOVB *R1+,*R15       ; Write byte to VDP RAM
       BL @FSYNC
       DEC  R2              ; Byte counter
       JNE  -!              ; Check if done
       B *R13               ; Return to saved address
* Fast RAM code to check if VSYNC occurred and play music in a separate workspace
FSYNC  CLR  R12        ; assume we can spare R12
       TB   2
       JEQ !
       MOVB @VDPSTA,R12 ; read status to clear interrupt
       LWPI >8300      ; music player requires this workspace
       BL   @PlaySong  ; play song, etc. (overwrites all regs)
       LWPI WRKSP      ; Return to our own workspace
!      RT

FVDPWS EQU $-FVDPW  ; Size

SPR    BSS SPRCNT*4     ; Y,idx  X,ec+color  in that order
OUTPTR BSS 2            ; current pointer into STRIPS for updating



       DORG TEXTPAT   ; Reuse the same address for data after load

WIDTH  EQU 256+16
STRIPS BSS WIDTH*2 ; pointers to strip patterns


CHAR0  EQU ','        ; base char pattern ',' (not '0')
NCHARS EQU ('Z'+1-CHAR0)   ; number of char patterns
STRPAT BSS NCHARS*4*4*2*8 ; pattern data char*quad*shift*leftright*pixels

ZZLAST EQU $


SPRCLR EQU 4  ; sprite color 5 or 12



       COPY '../ROUTINES.INC'

       END
