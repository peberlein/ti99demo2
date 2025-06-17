#!/usr/bin/env python
# Build the megademo

import os, sys, re, zipfile

# List of effects in the 'src' directory (loader is always first)
if len(sys.argv) > 1:
	effects = sys.argv[1:]
else:
	effects = [
		'loadsong', 'flying-shark-music',   # Placeholder music for testing
		'2-plane-scroll',   # by Asmusr
		'sinetext',         # by PeteE
	]
	# Add additional effects here! ^^^


# Set xas99 command
xas99 = 'python ' + os.path.join('tools','xas99.py')

# Build the loader first
src = os.path.join('src', 'loader', 'loader')
if os.system(f"{xas99} -b -R -o {src}.bin {src}.asm -S -L {src}.lst") != 0:
	exit(1)
# Get the symbols from the loader listing into ROUTINES.INC
with open(src+'.lst', 'r') as lst:
	with open(os.path.join('src','routines.inc'), 'w') as inc:
		for line in lst:
			match = re.search(r"^    (\w+)\.+ (\>[0-9A-Fa-f]+)", line)
			if match:
				inc.write(f"{match.group(1)} EQU {match.group(2)}\n")

# Build each effect if .asm or .a99 file exists, otherwise use .bin file as is.
for name in effects:
	src = os.path.join('src', name, name)
	lst = ""
	if os.path.exists(src+'.lst'):
		# Regenerate the listing if it's already there
		lst = '-L '+src+'.lst'
	if os.path.exists(src+'.asm'):
		# Build it
		if os.system(f"{xas99} -b -R -o {src}.bin {src}.asm {lst}") != 0:
			exit()
	elif os.path.exists(src+'.a99'):
		# Build it
		if os.system(f"{xas99} -b -R -o {src}.bin {src}.a99 {lst}") != 0:
			exit()
	elif not os.path.exists(src+'.bin'):
		print(f"Effect {src}.bin not found")
		exit()


# Build the cartridge
src = os.path.join('src', 'cart')
cart = 'megademo2_8.bin'
os.system(f"{xas99} -b -R -o {cart} {src}.asm -L {src}.lst")

# Get the header
with open(cart, 'rb') as file:
	header = file.read(30)

# Append the effects to the cartridge file
with open(cart, 'ab') as file:

	# Write the effect code, wrapping at bank boundaries
	for name in ['loader'] + effects:
		src = os.path.join('src', name, name+'.bin')
		size = os.path.getsize(src)
		odd = size % 2

		# Write the size (in words) before the data
		l = (size + odd) // 2
		file.write(bytes([l >> 8, l & 255]))

		print(f"Adding {src} size={size}")
		with open(src, 'rb') as bin:
			while size > 0:
				remain = 8192 - (file.tell() % 8192)
				#print(f"size={size} remain={remain}")
				if size >= remain:
					# Fills up end of bank, write header
					file.write(bin.read(remain))
					file.write(header)
					size -= remain
				else:
					# Copy file data
					file.write(bin.read(size))
					size = 0
		# Pad code to even number of bytes
		if odd:
			file.write(b'\0')

	# Terminate the effects list
	file.write(b'\0\0')

	# Pad the cart file to next power-of-2
	end = file.tell()
	power2 = max(8192, 2**(end-1).bit_length())
	print(f"Used {end}/{power2} bytes")

	# Pad zeros for the current bank
	file.write(b'\0' * (8192 - (end % 8192)))

	# Write header and zeros for remaining banks
	while file.tell() < power2:
		file.write(header)
		file.write(b'\0' * (8192-len(header)))


# Build the .rpk
with zipfile.ZipFile('megademo2.rpk', 'w', zipfile.ZIP_DEFLATED) as rpk:
	rpk.write(cart)
	rpk.writestr('layout.xml',
f"""<?xml version="1.0" encoding="utf-8"?>
<romset version="1.0">
   <resources>
      <rom id="romimage" file="{cart}"/>
   </resources>
   <configuration>
       <pcb type="paged378">
          <socket id="rom_socket" uses="romimage"/>
       </pcb>
   </configuration>
</romset>
""")
