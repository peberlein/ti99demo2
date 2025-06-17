* Loader
*
* Lives in >2000 memory region, alongside music player, current song
*
* Has common routines that will be exported to ROUTINES.INC
* Load effects to >A000 memory region, from cartridge (or disk, eventually)
*

       AORG >2000       ; Loader lives in low memory expansion

VDPWD  EQU  >8C00             ; VDP write data
VDPWA  EQU  >8C02             ; VDP set read/write address
VDPRD  EQU  >8800             ; VDP read data (don't forget NOP after address)
VDPSTA EQU  >8802             ; VDP status
VDPWM  EQU  >4000             ; VDP address write mask
VDPRM  EQU  >8000             ; VDP address register mask
SNDREG EQU  >8400             ; Sound register address


BANK0W EQU >6000 ; write address for setting bank 0
HDRLEN EQU 30  ; Cartridge header size in all banks


* Loader Variables
* (First variable must be non-zero initialized for 32K mem exp check)
CURBNK DATA BANK0W  ; Current bank pointer
EFFPTR DATA 0       ; Effect data pointer in cartridge space
FCOUNT DATA 0       ; Frame countdown, when reaching zero jumps to LDNEXT


* Load the next effect and jump to it
LDNEXT
       CLR @FCOUNT    ; Reset frame countdown (can be overridden by effect)
       LI R1,>A000    ; copy effect into upper RAM
       MOV R1,R11     ; jump to >A000 after loading
LDDATA
       MOV R11,R12    ; Save return address

       ;LI R0,>0722    ; background color green
       ;BL @VWTR       ; write register

       MOV @CURBNK,R3   ; R3 = current bank
       CLR *R3          ; Set the bank, before reading from EFFPTR

       ; Copy R2 words from the current EFFPTR to R1
       MOV @EFFPTR,R0 ; R0 = current code pointer
       MOV *R0+,R2    ; read the next length from the effect table
       JEQ DEMOEND    ; table terminator, end of demo

LDLOOP
       ; calculate the minimum until wrapping and tighten the loop
       LI R5,>8000
       S R0,R5        ; R5 = bytes remaining in bank
       SRL R5,1       ; R5 = words remaining in bank

       C R2,R5        ; compare words to copy, to words remaining in bank
       JL !!          ; jump if doesn't cross bank

       ; remaining is greater/equal: copy to end of cart bank
       MOV R5,R4   ; copy R4 words from cart bank to R1
!      MOV *R0+,*R1+
       BL @TRYSYNC     ; Play music if needed
       DEC R4
       JNE -!

       INCT R3         ; next bank
       CLR *R3         ; switch to bank
       LI R0,>6000+HDRLEN  ; resume after cart header

       S R5,R2      ; subtract the number of words copied
       JEQ LDDONE   ; zero? done
       JMP LDLOOP   ; non-zero, keep going

       ; copy R2 words from cart bank to R1
!      MOV *R0+,*R1+
       BL @TRYSYNC     ; Play music if needed
       DEC  R2
       JNE  -!
LDDONE
       MOV  R0,@EFFPTR   ; store updated code pointer
       MOV  R3,@CURBNK   ; store updated bank

       ;LI R0,>0711    ; background color black
       ;BL @VWTR       ; write register

       B *R12            ; return to saved address


* End of demo, quit or loop based on alpha-lock
DEMOEND
* This block added by Tursi for the public release and is not
* in the official presentation for the demo (to avoid accidents!)
* If Alpha Lock is UP (instead of the normal down), then loop instead
* of resettings. This allows easy use at shows. Code from TI ROM.
       CLR  R12
       SBZ  >15     * activate Alpha Lock
       SRC  R12,14  * delay
       TB   >0007   * test return - equal is released
       SBO  >15     * deactivate
       JNE  QUIT    * if pressed, quit

       MOV  @>600C,R11  ; get the PRGLST start address
       B    *R11        ; jump to it

* Quit to title screen
QUIT
       CLR  @>83C4          ; Reset user ISR address
       BLWP @>0000          ; Reboot


* Play the music,
* Detect keyboard spacebar or quit pressed, and
* Decrement frame counter, if zero load next effect.
* (Modifies all registers except R10)
PlaySong
       ; Fast keyboard scan routine. Skip to next effect when spacebar is pressed.
       ; Ripped from http://www.unige.ch/medecine/nouspikel/ti99/tutor1.htm
       LI   R13,>0000       ; keyboard column 0
       LI   R12,>0024       ; CRU address of the decoder
       LDCR R13,3           ; select the column
       LI   R12,>0006       ; address of the first row
       STCR R14,8           ; read 8 rows
       CZC  @KBSPC,R14      ; test spacebar
       JEQ  LDNEXT          ; pressed
       CZC  @KBQUIT,R14     ; test quit
       JEQ  QUIT

       DEC  @FCOUNT         ; Decrement frame counter
       JEQ  LDNEXT          ; if zero, run next effect

       ; TODO Handle song looping in case it stopped

       B    @SongLoop       ; Play music  (tail-call)

* keyboard control bits
KBSPC  DATA >0200
KBQUIT DATA >1100


* Test the VDP interrupt and if set, play song
* (Saves all registers)
TRYSYNC
       MOV  R12,@LI_R12+2 ; Save modified register
       CLR  R12           ; Set CRU base
       TB   2             ; Read VDP interrupt from CRU
       JEQ  LI_R12        ; Return if not set
       JMP VDPINT

* Wait until the VDP interrupt and then play song
* (Saves all registers)
VSYNC
       MOV  R12,@LI_R12+2 ; Save modified register
       CLR  R12           ; Set CRU base
VDPINT
       ; Put as many cycles as we can before the loop that tests for the VDP
       ; interrupt, because we are likely going to be waiting anyway.
       ; When trysync jumps here, it will tb 12 again, but it's probably worth
       ; it to avoid duplicating this register saving code.
       MOV  R0,@LI_R0+2   ; Save all modified registers into LI instructions
       MOV  R1,@LI_R1+2
       MOV  R2,@LI_R2+2
       MOV  R3,@LI_R3+2
       MOV  R4,@LI_R4+2
       MOV  R5,@LI_R5+2
       MOV  R6,@LI_R6+2
       MOV  R7,@LI_R7+2
       MOV  R8,@LI_R8+2
       MOV  R9,@LI_R9+2  
       MOV  R11,@LI_R11+2 ; Note: R10 is saved by CPlayer
       MOV  R13,@LI_R13+2
       MOV  R14,@LI_R14+2
       MOV  R15,@LI_R15+2

!      TB   2             ; Read VDP interrupt from CRU
       JEQ  -!            ; Loop until set
       MOVB @VDPSTA,R12   ; Clear VDP status register

       BL   @PlaySong     ; Play music, etc.

LI_R0  LI   R0,0          ; Restore all modified registers
LI_R1  LI   R1,0
LI_R2  LI   R2,0
LI_R3  LI   R3,0
LI_R4  LI   R4,0
LI_R5  LI   R5,0
LI_R6  LI   R6,0
LI_R7  LI   R7,0
LI_R8  LI   R8,0
LI_R9  LI   R9,0
LI_R11 LI   R11,0
LI_R13 LI   R13,0
LI_R14 LI   R14,0
LI_R15 LI   R15,0
LI_R12 LI   R12,0
       RT


       ; Dummy macros used by CPlayer
       .defm size
       .endm
       .defm section
       .endm

       COPY "CPlayerCommonHandEdit.asm"
       COPY "CPlayerTIHandlers.asm"
       COPY "CPlayerTIHandEdit.asm"

       COPY "utils.asm"

       EVEN
songData ; remaining memory space is current song data

songMax EQU >4000-songData
