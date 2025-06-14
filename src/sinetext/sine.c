#include <stdio.h>
#include <string.h>
#include <math.h>

#define ARRAY_SIZE(x) (sizeof(x)/sizeof(x[0]))


int main(int argc, char *argv[])
{
	const int width = 256+16;
	struct {
		int x, y;
	} spr[7*4] = { // 7 rows of 4 sprites
		// 5 row ys: 56, 72, 88, 104, 120, (136) 
		// 6 row ys: 48, 64, 80, 96, 112, 128, (144)
		// 7 row ys: 40, 56, 72, 88, 104, 120, 136, (152)  44.4*sin

		//{0,88},
		//{5,104},{5+16,104},
		//{21,120},{21+16,120},
		//{42,136},{42+16,136},{42+32,136}

		//{0,80},
		//{0,96},{16,96},
		//{13,112},{13+16,112},
		//{31,128},{31+16,128},{31+32,128},{31+48,128},

		// NOTE: all x must be even
					    {172,40},{188,40},{204,40},{220,40},
					  {154,56},{170,56},   {224,56},{240,56},
					{138,72},{154,72},	{240,72},{256,72},
		{0,88},                 {124,88},{140,88},		 {256,88},
		{0,104},{16,104},     {110,104},{126,104},
		 {18,120},{34,120},  {88,120},{104,120},
		   {36,136},{52,136},{68,136},{84,136},

	};

	int x, i;
	char tiles[24][width/8];
	int lo = 192, hi = 0;
	//int lasty = 192/2 - 3.5;
	int y[width];
	memset(tiles, 0, sizeof(tiles));

	for (x = 0; x < width; x++) {
		int y1 = 49.3*sin((x+1) * 2 * M_PI / width) - 3.5 + 192/2;
		int y2 = y1+7;
		//printf("%d,%d-%d\n", x, y, y2);
		y[x] = y1;
		tiles[y1/8][x/8] = 'O';
		tiles[y2/8][x/8] = 'O';
		//if (x > 0 && (y1 - lasty < -2 || y1 - lasty > 2)) return 1;
		//lasty = y1;
		if (y1 < lo) lo = y1;
		if (y2 > hi) hi = y2;

		int in1 = 0, in2 = 0;
		for (i = 0; i < ARRAY_SIZE(spr); i++) {
			if (x >= spr[i].x && x <= spr[i].x+15) {
				if (y1 >= spr[i].y && y1 <= spr[i].y+15)
					in1 = 1;
				if (y2 >= spr[i].y && y2 <= spr[i].y+15)
					in2 = 1;
			}
		}
		if (in1 == 0) {
			fprintf(stderr, "need sprite coverage for %d,%d\n", x, y1);
			//return 1;
		}
		if (in2 == 0) {
			fprintf(stderr, "need sprite coverage for %d,%d\n", x, y2);
			//return 1;
		}
	}
	fprintf(stderr, "lo=%d hi=%d\n", lo, hi);
	for (i = 0; i < 24; i++) {
		for (x = 0; x < width/8; x++) {
			fputc(tiles[i][x] ?: 
				((i&2) == 2) != ((x&2) == 2) ? '+' : '-',
				stderr);
		}
		fputc('\n', stderr);
	}

	// Character patterns are arranged in memory as follows:
	// For each character, 4 strips of 2x8 pixels:
	// For each strip, shifted and masked bytes:
	// BYTE >80,>80,>80,>80,>80,>80,>80,>80  ; strip left column shifted 0
	// BYTE >40,>40,>40,>40,>40,>40,>40,>40  ; strip right column shifted 0
	// BYTE >20,>20,>20,>20,>20,>20,>20,>20  ; shift 2
	// BYTE >10,>10,>10,>10,>10,>10,>10,>10  ; 
	// BYTE >08,>08,>08,>08,>08,>08,>08,>08  ; shift 4
	// BYTE >04,>04,>04,>04,>04,>04,>04,>04  ; 
	// BYTE >02,>02,>02,>02,>02,>02,>02,>02  ; shift 6
	// BYTE >01,>01,>01,>01,>01,>01,>01,>01  ; 
	// each strip consumes 64 bytes
	// each character pattern consumes 256 bytes
	// 40 character patterns would consume 10K

	int R9 = 0;

	// Generate code for filling sprites
	// 
	for (i = 0; i < ARRAY_SIZE(spr); i++) {
		int j;
		printf("       ; SPR %d @%d,%d\n", i, spr[i].x, spr[i].y);
		int lasty[8];

		// generate left or right half
		for (j = 0; j < 32; j++) {
			unsigned char mask = 0;
			unsigned char yj = spr[i].y+(j&15);
			unsigned int xj = spr[i].x+((j&16)/2);

			if (j == 0 || j == 16) {
				// get char pattern pointers in R1-R8

				// TODO
				// EMIT  LI R0,ADDRESS / MOVB R0,*R14 / SWPB R0 / MOVB R0,*R14
				// ONLY if it would replace more than 5 instruction words
				// or if it would consume fewer cycles


				// strip pointers head is in R9
				for (x = 0; x < 8; x+=2) {
					lasty[x] = y[xj+x] + 7;
					if (lasty[x] > yj+15) lasty[x] = yj+15;
					lasty[x+1] = y[xj+x+1] + 7;
					if (lasty[x+1] > yj+15) lasty[x+1] = yj+15;

					// check if the pointers for two columns are needed
					if ((yj+15 >= y[xj+x] && yj <= y[xj+x]+7)||
					    (yj+15 >= y[xj+x+1] && yj <= y[xj+x+1]+7))
					{
						int rel, rel2;

						if (xj+x == 0)
							printf("       MOV *R9,R%d   ; %d\n", x+1, y[xj+x]);
						else
							printf("       MOV @%d(R9),R%d   ; %d\n", xj+x, x+1, y[xj+x]);
						//if (xj+x != R9) {
						//	printf("       AI R9,%d\n", (xj+x)-R9);
						//	R9 = xj+x;
						//}
						//printf("       MOV *R9+,R%d   ; %d\n", x+1, y[xj+x]);
						//R9 += 2;
						printf("       MOV R%d,R%d       ; %d\n", x+1, x+2, y[xj+x+1]);
						
						// adjust the pattern offset if starting halfway thru
						rel = yj - y[xj+x];
						if (rel < 0) rel = 0;
						rel2 = rel + x*8; // adjust offset based on shift
						if (rel2 == 1) {
							printf("       INC R%d\n", x+1);
						} else if (rel2 == 2) {
							printf("       INCT R%d\n", x+1);
						} else if (rel2 > 0) {
							printf("       AI R%d,%d\n", x+1, rel2);
						}

						rel = yj - y[xj+x+1];
						if (rel < 0) rel = 0;
						rel2 = rel + x*8 + 8; // adjust offset based on shift
						if (rel2 == 1) {
							printf("       INC R%d\n", x+2);
						} else if (rel2 == 2) {
							printf("       INCT R%d\n", x+2);
						} else if (rel2 > 0) {
							printf("       AI R%d,%d\n", x+2, rel2);
						}
					}
				}
			}


			for (x = 0; x < 8; x++) {
				if (yj >= y[xj+x] && yj <= y[xj+x]+7) {
					mask |= 1 << x;
				}
			}
			
			if (mask == 0) {
				// TODO we can omit the CLR if the rest of the sprite pattern is blank
				// and the next sprite sets the VDP write address
				printf("       CLR *R15\n");
				//printf("       MOVB R10,*R15\n");
			} else {
				int first = 1;
				for (x = 0; x < 8; x++) {
					const char *inc = (yj == lasty[x]) ? "" : "+";
					if (mask == (1 << x)) {
						printf("       MOVB *R%d%s,*R15\n", x+1, inc);
						break;
					} else if (mask & (1 << x)) {
						if (first) {
							printf("       MOVB *R%d%s,R0\n", x+1, inc);
							first = 0;
						} else {
							printf("       SOCB *R%d%s,R0\n", x+1, inc);
						}
					}
				}
				if (first == 0) {
					printf("       MOVB R0,*R15\n");
				}
			}
		}
		if ((i&3)==3) printf("       BL @FSYNC\n");
	}

	if (R9) {
		printf("       AI R9,%d\n", -R9);
	}
	printf("       B @RUNSRT\n");

	printf("SPRDATA\n");
	for (i = 0; i < ARRAY_SIZE(spr); i++) {
		printf("       DATA >%02X%02X,>%02X%02X ; %d,%d  \n",
			spr[i].y, // Y
			(i << 2), // idx
			spr[i].x < 256 ? spr[i].x : spr[i].x - 256+32-16, // X
			(spr[i].x < 256 ? 0 : 0x80) | 5, // early clock, color
			spr[i].x, spr[i].y);
	}


	return 0;
}
