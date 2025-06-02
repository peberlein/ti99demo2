*********************************************************************
* VDP RAM Single Byte Read
* Reads the VDP RAM address indicated in Register 0 to the
* most-significant byte of Register 1
* Changes R1 MSB
*********************************************************************
       EVEN
VSBR   SWPB R0
       MOVB R0,@VDPWA
       SWPB R0
       MOVB R0,@VDPWA
       NOP
       MOVB @VDPRD,R1
       RT

*********************************************************************
* VDP RAM Single Byte Write
* Writes the value in the most-significant byte of Register 1 to the
* VDP RAM address indicated in Register 0.
* Trashes: R0
*********************************************************************
       EVEN
VSBW   ORI  R0,>4000
       SWPB R0
       MOVB R0,@VDPWA
       SWPB R0
       MOVB R0,@VDPWA
       MOVB R1,@VDPWD
       RT

*********************************************************************
* VDP RAM Write Register
* Writes the value in the least-significant byte of Register 0 to the
* VDP Register indicated in the most-significant byte of Register 0.
* This is identical in behavior to the VWTR procedure in the E/A
* cart.
* Trashes: R0
*********************************************************************
       EVEN
VWTR   ORI  R0,>8000
       SWPB R0
       MOVB R0,@VDPWA
       SWPB R0
       MOVB R0,@VDPWA
       NOP
       RT

*********************************************************************
* VDP RAM Multibyte Write
* Writes the array at Register 1 to the VDP RAM location in Register
* 0. Writes Register 2 bytes.
* Trashes: R0, R1, R2
*********************************************************************
       EVEN
VMBW   SWPB R0
       MOVB R0,@VDPWA
       SWPB R0
       ORI  R0,>4000
       MOVB R0,@VDPWA
MBWLP  MOVB *R1+,@VDPWD
       DEC  R2
       JNE  MBWLP
       RT

*********************************************************************
* VDP RAM Multibyte Set
* Writes the byte in Register 1 to the VDP RAM location in Register
* 0. Writes Register 2 bytes.
* Trashes: R0, R2
*********************************************************************
       EVEN
VMBS   SWPB R0
       MOVB R0,@VDPWA
       SWPB R0
       ORI  R0,>4000
       MOVB R0,@VDPWA
MBSLP  MOVB *R1,@VDPWD
       DEC  R2
       JNE  MBSLP
       RT

*********************************************************************
* VDP RAM Multibyte Read
* Reads R2 bytes from VDP Ram at address R0 to system RAM at address
* contained in R1.
* Trashes: R0, R1, R2
*********************************************************************
       EVEN
VMBR   SWPB R0
       MOVB R0, @VDPWA
       SWPB R0
       ANDI R0, >3FFF
       MOVB R0, @VDPWA
       NOP                          * added by Tursi - MUST NOP here for some consoles
MBRLP  MOVB @VDPRD, *R1+
       DEC  R2
       JNE  MBRLP
       RT


********************************************************************************
* Set max number of open files (by asmusr)
* R0: Max number of open files
********************************************************************************
       .ifdef DISK
FILES   MOV  R11,@FSAVR11              ; Push return address onto the stack
        MOV  R0,@NFILES                ; Save #files argument
        LI   R0,PAB
        LI   R1,PDATA
        LI   R2,2
        BL   @VMBW                     ; Copy 2 bytes from PDATA (RAM) to PAB (VRAM)
        LI   R0,PAB
        MOV  R0,@>8356                 ; Point to subroutine in DSR
        MOVB @NFILES+1,@>834C          ; #files argument for subroutine 016h
        BLWP @DSRLNK                   ; Call DSR with subprogram option
        DATA 10
*       Return
        MOV  @FSAVR11,R11
        B    *R11

NFILES  DATA >0001                     ; Number of simultaneous files
PDATA   DATA >0116                     ; DSR subprogram to run (FILES)
FSAVR11 DATA >0000

********************************************************************************
* Read a sector from a disk (tursi)
* R0: Sector to read (0-719 in this app)
* R1: VDP address for the sector (256 bytes)
* Reuses some of the buffers from FILES function
********************************************************************************
RSECT   MOV  R11,@FSAVR11              ; Push return address onto the stack
        MOV  R0,@>8350                 ; Save sector index argument
        MOV  R1,@>834E                 ; save VDP buffer address
        LI   R0,PAB
        LI   R1,SDATA
        LI   R2,2
        BL   @VMBW                     ; Copy 2 bytes from SDATA (RAM) to PAB (VRAM)
        LI   R0,PAB
        MOV  R0,@>8356                 ; Point to PAB subroutine
        MOVB @DNAME+3,R0               ; get DSK'n'
        AI   R0,->3000                 ; make index
        MOVB R0,@>834C                 ; save it off
        BLWP @DSRLNK                   ; Call DSR with subprogram option
        DATA 10
*       Return
        MOV  @FSAVR11,R11
        B    *R11
SDATA   DATA >0110                     ; DSR subprogram to run (Read Sector)

       .endif


       .ifdef SAMS

***************************************************************************
*
* Detect AMS
* Banks FF=1024K, 7F=512K, 3F=256K, 1F=128K
*
* On return R0 contains the size in KB, which is also stored in AMSSIZ
*
* This routine is writing:
* >FF to the first byte of bank >FF (for testing 1024K)
* >7F to the first byte of bank >7F (for testing 512K)
* >3F to the first byte of bank >3F (for testing 256K)
* >1F to the first byte of bank >1F (for testing 128K)
*
AMSBUF EQU  >3000
*
AMSDTC MOV  R11,@AMSR11                ; Save return address
*      Write bank numbers to banks
       LI   R2,4                       ; Number of banks to test
       LI   R0,>FF00                   ; Start with AMS bank number 255
AMSDT1 LI   R1,AMSBUF                  ; Map to >3000->3FFF
       BL   @AMSMAP                    ; Set mapping
       BL   @AMSENA                    ; Enable AMS
       MOVB R0,@AMSBUF                 ; Write bank number to bank
       BL   @AMSDIS                    ; Disable AMS
       SRL  R0,1                       ; Next bank to test
       DEC  R2
       JNE  AMSDT1
       CLR  @AMSBUF                    ; Clear ordinary RAM >3000
*      Check bank numbers
       LI   R2,4                       ; Number of banks to test
       LI   R0,>1FFF                   ; Start with last bank in 128K segment
AMSDT2 LI   R1,AMSBUF                  ; Map to >3000->3FFF
       BL   @AMSMAP                    ; Set mapping
       BL   @AMSENA                    ; Enable AMS
       CB   R0,@AMSBUF                 ; Check that bank contains bank number
       JNE  AMSDT3                     ; No - stop
       BL   @AMSDIS                    ; Disable AMS
       SLA  R0,1                       ; Next bank to test
       DEC  R2
       JNE  AMSDT2
*      Passed all
       LI   R0,>0100                   ; Passed all - report 256 banks
       JMP  AMSDT4
*      Failed
AMSDT3 SRL  R0,1                       ; Revert to last bank that passed
       ANDI R0,>FF00
       SWPB R0                         ; Swap bank number to LSB
       INC  R0                         ; Number of banks is one higher
       ANDI R0,>01E0
AMSDT4 SLA  R0,2                       ; Convert to KB
       MOV  R0,@AMSSIZ                 ; Save number of banks
       BL   @AMSDIS                    ; Disable AMS
*      Return
       MOV  @AMSR11,R11                ; Restore return address
       B    *R11
AMSR11 DATA 0
AMSSIZ DATA 0                          ; Number of detected AMS banks
*// AMSDTC

***************************************************************************
*
* Map an AMS bank to a given memory segment
*
* R0 MSB contains the AMS bank number to map
* R1 contains the memory segment to map into (>2000, >3000, >A000, ...)
*
* Call AMSMP1 if R1 contains the register number (>0002, >0003, >000A, ...) instead
*
AMSMAP SRL  R1,12                      ; Top 4 bits select register
AMSMP1 SLA  R1,1                       ; Registers are 2 bytes apart
       LI   R12,>1E00                  ; AMS CRU address
       SBO  0                          ; Enable access to AMS mapping registers
       MOVB R0,@>4000(R1)              ; Write register
       SBZ  0                          ; Disable access to AMS mapping registers
       B    *R11                       ; Return
*// AMSMAP

***************************************************************************
*
* Enable AMS
*
AMSENA LI   R12,>1E00                  ; AMS CRU address
       SBO  1                          ; Enable AMS mapper
       B    *R11                       ; Return
*// AMSENA

***************************************************************************
*
* Disable AMS
*
AMSDIS LI   R12,>1E00                  ; AMS CRU address
       SBZ  1                          ; Disable AMS mapper
       B    *R11                       ; Return
*// AMSDIS
       .endif    ; SAMS