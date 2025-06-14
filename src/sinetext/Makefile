AS:=../../xdt99/xas99.py


#sinetxt8.bin: sinetext.asm sinetext.inc textpat.bin
#	$(AS) -b -R $< -o $@ -S -L sinetxt8.lst

sinetext.inc: sine
	./sine > $@

sine: LDLIBS=-lm

textpat.bin: sine.mag Makefile
	../../tools/mag.py -c 44 47 $^ > $@
