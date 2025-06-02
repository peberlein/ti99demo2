# TI-99/4A Megademo II (2025)

To build the megademo, run the `build.py` script (requires Python 3.)
It will build effects using xas99.py in the tools directory. Hopefully this will work cross-platform.

To build a subset of effects for testing, add the effect names to the command-line: `build.py effect1 effect2 ...`
The default set of effects is in `build.py` in the list variable `effects`.
The effects are packed into a multi-bank cartridge in two outputs: `megademo2_8.bin` and `megademo2.rpk`
The cartridge ROM will be padded to the next power of 2 bytes.

Each effect should live in the `src` directory under a directory of its own name.
The build script looks for `src/<effectname>/<effectname>.bin` for the binary code that will be loaded at address >A000.
If the file `src/<effectname>/<effectname>.asm` or `.a99` exists, this will be assembled using `xas99`.
If the source code is C, you may opt to produce only the `.bin` file.
A set of common routines is callable in the >2000 low-memory area, and the equates can be imported using `COPY "../routines.inc"`

* `LDNEXT` load the next effect in the chain and runs it (does not return)
* `LDDATA` load the next effect/binary data to address R1
* `FCOUNT` word variable: frame counter
* `TRYSYNC` play music if the VDP interrupt is waiting, returning quickly if not. (Saves all registers)
* `VSYNC` wait until the VDP interrupt, then play music (Saves R10 only)
* `VSBR` VDP RAM Single Byte Read, R0=VDP source R1MSB=returned value
* `VSBW` VDP RAM Single Byte Write, R0=VDP dest R1MSB=value
* `VWTR` VDP RAM Write Register, R0MSB=register number R0LSB=value
* `VMBW` VDP RAM Multibyte Write, R0=VDP dest R1=source R2=count
* `VMBS` VDP RAM Multibyte Set, R0=VDP dest R1=address of byte R2=count
* `VMBR` VDP RAM Multibyte Read, R0=VDP source R1=dest R2=count

To load music, use the `loadsong` effect followed by another effect containing the binary song data.
The song will be stored at the unused space in >2000 memory.
The music must be compressed using https://github.com/tursilion/vgmcomp2

