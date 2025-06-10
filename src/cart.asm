***************************************************************
* TI-99/4A Megademo II (2025)
***************************************************************

WRKSP  EQU >8300    ; Workspace memory in fast RAM, 16 registers, 32 bytes
BANK0W EQU >6000    ; Bank 0 write address

***************************************************************
* Cartridge header
***************************************************************
       AORG >6000
***************************************************************
       BYTE >AA     ; Standard header
       BYTE >00     ; Version number 1
       BYTE >01     ; Number of programs (optional)
       BYTE >00     ; Reserved (for FG99 this can be G,R,or X)
       DATA >0000   ; Pointer to power-up list
       DATA PRGLST  ; Pointer to program list
       DATA >0000   ; Pointer to DSR list
       ;DATA >0000   ; Pointer to subprogram list  (this doubles as next program list entry)

PRGLST DATA >0000   ; Next program list entry
       DATA START   ; Program start address
       STRI 'MEGADEMO 2'

MSG_32 STRI "32K MEM EXP REQUIRED"
       EVEN


START  CLR @BANK0W  ; switch to bank 0

       LIMI 0       ; interrupts off
       LWPI WRKSP   ; set workspace

       ; Copy the loader into low expansion RAM
       LI R0,ETABLE  ; set the initial effect pointer
       MOV *R0+,R2   ; R2 = length of loader in words
       LI R1,>2000   ; copy the loader to >2000 (assumes all in bank 0)
!      MOV *R0+,*R1+
       DEC R2
       JNE -!

       ; Check to see if the loader is there
       C @>2000,@ETABLE+2
       JNE NO_32K

       ; set variables in loader after copying
       MOV R0,@EFFPTR   ; store the next effect code pointer
       MOV @START+2,@CURBNK  ; store write address for current bank

       B @LDNEXT

NO_32K ; show the error message when no 32K
       LI R14,VDPWA
       LI R15,VDPWD
       LI R1,MSG_32
       LI R0,VDPWM/256  ; pre-SWPB
       MOVB R0,*R14
       SWPB R0
       MOVB R0,*R14
       MOVB *R1+,R2 ; get the length
       SRL R2,8     ; low byte
!      MOVB *R1+,*R15
       DEC R2
       JNE -!

       LIMI 2       ; interrupts on
       JMP $        ; infinite loop


       ; exported symbols from loader.asm
       COPY "ROUTINES.INC"

       ; build.py will append binary data here
ETABLE ; effects table
       ; DATA loader-length (in words)
       ; DATA loader-code...
       ; DATA effect0-length (in words)
       ; DATA effect0-code...
       ; ...
       ; DATA 0  (terminator)

