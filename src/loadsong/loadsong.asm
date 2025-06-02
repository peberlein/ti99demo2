* Loads the next code chunk as the current song and sets it to play

       AORG >A000

       LI R1,songData     ; load code at songData
       BL @LDDATA         ; load it

       LI R1,songData     ; r1 = pSbf - pointer to song block data (must be word aligned)
       CLR R2             ; r2 = songNum - which song to play in MSB (byte, starts at 0)
       BL @StartSong      ; Prepare this song to play

       B @LDNEXT          ; Load next effect after song


       ; exported symbols from loader.asm
       COPY "../ROUTINES.INC"
