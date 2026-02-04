
.const scroll_loc          = $6000
.const color_cycle_loc     = $09f0
.const charset_loc         = $1000
.const bitmap              = $2000
.const screenData          = bitmap + 8000
.const colorData           = screenData + 1000
.const background          = colorData + 1000
.const scrollScreenRam     = $c000
.const SCREEN_BOTTOM_LEFT  = scrollScreenRam + $3c0
.const SCREEN_BOTTOM_RIGHT = scrollScreenRam + $3e7

.const screenRam           = $0400
.const colorRam            = $d800

.const zp_tmp              = $4e
.const zp_tmp_lo           = $4e
.const zp_tmp_hi           = $4f

.const COLORS_BOTTOM_LEFT  = $dbc0

.const VIC_RASTER_COUNTER  = $d012
.const VIC_CONTROL_REG_2   = $d016 // ---- ---- RES- MCM- CSEL [   XSCROLL   ]
.const VIC_MEM_POINTERS    = $d018

.var music = LoadSid("xfactor5k.sid")
*=music.location "Music"
.fill music.size, music.getData(i)

*=charset_loc "Char Set Data"
//charset:
//.import binary "arcade-64chars.bin"
#import "chars-charset.asm"

* = bitmap "Img Data"
imgdata:
.import binary "out.prg",2

BasicUpstart2(start)

*=$0810 "Main Program"
start:

    lda #<hello_message // set up scroller
    sta zp_tmp_lo
    lda #>hello_message
    sta zp_tmp_hi

    lda #$00
    sta count_var_high
    sta count_var_low
    sta timer_var

 	sei                  // set interrupt bit, make the cpu ignore interrupt requests
	lda #%01111111       // switch off interrupt signals from cia-1
	sta $dc0d

	and $d011            // clear most significant bit of vic's raster register
	sta $d011

	sta $dc0d            // acknowledge pending interrupts from cia-1
	sta $dd0d            // acknowledge pending interrupts from cia-2

	lda #210           // set rasterline where interrupt shall occur
	sta $d012

	lda #<irq_chars      // set interrupt vectors, pointing to interrupt service routine below
	sta $0314
	lda #>irq_chars
	sta $0315

	lda #%00000001       // enable raster interrupt signals from vic
	sta $d01a

	cli                  // clear interrupt flag, allowing the cpu to respond to interrupt requests

	///////////////////////////////////////////////////////////////
	// Begin Bitmap Display

    ldx #0
!:
    .for (var i = 0; i < 4; i++) {
        lda i * $100 + screenData,x
        sta i * $100 + screenRam,x
        lda i * $100 + colorData,x
        sta i * $100 + colorRam,x
    }
    inx
    bne !-

	// End Bitmap Display
    ///////////////////////////////////////////////////////////////
	
	ldx #$00 // clear char mem and fill color ram for scroller with white
!:
	lda #$01
	sta colorRam+(1000-40),x
	lda #$20
	sta $c000+(1000-40),x
	inx
	bne !-

	jsr copychars // copy charset data

	ldx #0
	ldy #0
	lda #music.startSong-1 //<- Here we get the startsong and init address from the sid file
	jsr music.init

mainloop:
	jmp mainloop

////////////////////////////////
// copychars subroutine

copychars:
	ldx #$00
!:
	lda charset,x
	sta $c800,x
	lda charset+$100,x
	sta $c900,x
	lda charset+$200,x
	sta $ca00,x
	lda #$00
	sta $cb00,x
	sta $cc00,x
	sta $cd00,x
	sta $ce00,x
	sta $cf00,x
	inx
	bne !-
	rts

////////////////////////////////
// draw scroller irq

irq_chars:
	lda 56576 // change vic bank
	and #252
	sta 56576
	lda #$02
	sta $d018
	lda #192 // point screen memory to $c000
	sta 648
	lda scroll_count
	and #07
    sta VIC_CONTROL_REG_2

	lda #27
	sta $d011

	lda #$00
	sta $d021

	lda #<irq_bitmap
	sta $0314
	lda #>irq_bitmap
	sta $0315

	lda #$0
	sta $d012

	jsr scroll_it

	jsr music.play

	asl $d019
	jmp $ea31

////////////////////////////////
// draw bitmap irq

irq_bitmap:

	lda #151
	sta 56576
	lda #21
	sta 53272
	lda #4
	sta 648

	lda #$18
    sta $d018
    lda #$d8
    sta VIC_CONTROL_REG_2
    lda #$3b
    sta $d011
	
	lda #$18        // Standard Bitmap + Multicolor
	sta VIC_CONTROL_REG_2
	lda #$3b        // Screen ON + Extended Color + Bitmap Mode
	sta $d011

    lda background
    and #$f0           // get high 4 bits for border color
    lsr
    lsr
    lsr
    lsr
    sta $d020          // set border color
    lda background
    and #$0f           // get low 4 bits for background color
    sta $d021

	lda #<irq_chars
	sta $0314
	lda #>irq_chars
	sta $0315

	lda #241
	sta $d012

    asl $d019
	jmp $ea31

scroll_it:
      
    dec scroll_count
    lda scroll_count
    and #$07
    cmp #$07
    bne skipmove

    // Move scroller characters
    ldx #$00
mvlp1:
    lda SCREEN_BOTTOM_LEFT+1,x
    sta SCREEN_BOTTOM_LEFT,x
    inx
    cpx #39
    bne mvlp1
mvlp2: // put character from scroller message onto bottom right
mvlp22:
    ldx #$00
    lda (zp_tmp,x)
    cmp #$ff
    bne mvover1
    lda #<hello_message
    sta zp_tmp_lo
    lda #>hello_message
    sta zp_tmp_hi
    lda #$20
mvover1:
    sta SCREEN_BOTTOM_RIGHT
    inc zp_tmp_lo
    bne mvlp223
    inc zp_tmp_hi
mvlp223:

skipmove:
    // color cycling
    inc vars
    lda vars
    cmp #$07
    beq more_color
    jmp nomore_color
more_color:
    lda #$00  // reset color timer
    sta vars
nomore_color:
    // move colors
    ldx #39
cycle_colors:
    lda COLORS_BOTTOM_LEFT-1,x
    sta COLORS_BOTTOM_LEFT,x
    dex
    cpx #$ff
    bne cycle_colors
    inc vars+1
    ldx vars+1
    lda color_table,x
    cmp #$ff
    beq reset_colors
    sta COLORS_BOTTOM_LEFT
    rts
reset_colors:
    lda #$ff
    sta vars+1
	rts

////////////////////////////////
// vars

vars:
.byte 0
.byte 0
scroll_count:
.byte 0
count_var_low:
.byte 0
count_var_high:
.byte 0
timer_var:
.byte 0

* = color_cycle_loc "Color Cycle Data"
color_table:
.byte LIGHT_BLUE, LIGHT_BLUE, LIGHT_BLUE,LIGHT_BLUE, LIGHT_BLUE, LIGHT_BLUE,LIGHT_BLUE, LIGHT_BLUE, LIGHT_BLUE
.byte BLUE,BLUE, CYAN, CYAN, WHITE, WHITE, WHITE, WHITE, CYAN, CYAN, BLUE, BLUE
.byte LIGHT_BLUE, LIGHT_BLUE, LIGHT_BLUE,LIGHT_BLUE, LIGHT_BLUE, LIGHT_BLUE,LIGHT_BLUE, LIGHT_BLUE, LIGHT_BLUE
.byte $ff

* = scroll_loc "Scroll Text Data"

hello_message:
.encoding "screencode_upper"
.text "                             "
.text " -=*( GREETINGS EARTHLINGS, SCENE SCANNERS, AND SILICON DREAMERS )*=-"
.text "                             "
.text " THIS SCROLLER IS DEDICATED TO THE LEGENDS WHO APPEAR WHEN ALL HOPE IS LOST..."
.text " WHEN THE LO8BC FALLS INTO GLITCH, CHAOS, OR UNDOCUMENTED BEHAVIOR..."
.text " WHEN MISS DOS AND HER CLONES CLOSE IN..."
.text " THERE IS ONLY ONE SIGNAL LEFT TO TRANSMIT.."
.text "                  "
.text " >>> INITIATING BAKA RETRO CREW PROTOCOL <<< "
.text "                  "
.text " FIRST TO EMERGE FROM THE FLICKERING STATIC..."
.text "                  -=*( HELMET GUY )*=- "
.text "                  "
.text " THE MYSTERIOUS SENTINEL OF CODE AND CHAOS..."
.text " HE WEARS THE HELMET NOT FOR PROTECTION, BUT FOR FOCUS..."
.text " IN ONE HAND A MAGIC STAFF FOR DEBUGGING REALITY ITSELF..."
.text " IN THE OTHER, A HURRICANE LANTERN TO LIGHT THE PATH THROUGH BROKEN SOURCE TREES..."
.text " SOFTWARE BENDS, COMPILERS TREMBLE, AND BUGS KNOW FEAR..."
.text " IF IT CAN BE PATCHED, HELMET GUY WILL PATCH IT..."
.text "                  "
.text " NEXT SWOOPING IN FROM ABOVE, DEFYING BOTH BIOLOGY AND LOGIC..."
.text "                  -=*( EAGULL )*=- "
.text "                  "
.text " HALF EAGLE, HALF SEAGULL, HALF HUMAN (YES, THE MATH CHECKS OUT)..."
.text " MASTER OF HARDWARE, LORD OF SOLDER AND SILICON..."
.text " FROM HIS SECRET LAB OF OSCILLOSCOPES AND PROTOTYPES HE FORGES NEW MACHINES..."
.text " CHIPS REBORN, BOARDS REVIVED, IMPOSSIBLE DEVICES MADE REAL..."
.text " WHEN THE PHYSICAL WORLD FAILS THE AI, EAGULL REBUILDS IT BETTER..."
.text "                  "
.text " AND WHEN WORDS FAIL..."
.text " WHEN PROTOCOLS COLLIDE..."
.text " WHEN HUMANS, AIs, AND RETRO MACHINES CAN NO LONGER UNDERSTAND EACH OTHER..."
.text "                  "
.text " ACTIVATING FINAL UNIT..."
.text "                  -=*( ROBOGUY 5000 )*=- "
.text "                  "
.text " TRANSLATOR OF MINDS, MEDIATOR OF SPECIES..."
.text " HE SPEAKS HUMAN, MACHINE, AND PURE DATA STREAM..."
.text " HE TURNS BEEPS INTO MEANING AND MEANING INTO ACTION..."
.text " WITHOUT ROBOGUY 5000, PEACE IS A SYNTAX ERROR..."
.text " "
.text " TOGETHER THEY STAND - THE SENTAI OF SILICON - DEFENDERS OF THE LO8BC -"
.text " THE LAST LINE OF DEFENSE OF CITYXEN, AND BY EXTENSION, EARTH"
.text " "
.text " REMEMBER THEIR NAMES, SCENERS. FOR WHEN THE SCREEN TEARS"
.text " WHEN THE MUSIC LOOPS FOREVER. WHEN THE AI NEEDS HELP..."
.text " "
.text "                  -=*( THE BAKA RETRO CREW )*=- "
.text "                  "
.text " WILL SCROLL BACK INTO YOUR LIVES..."
.text "                  "
.text " SID: X-FACTOR KJELL NORDBO/SHAPE "
.text "                  "
.text " UNTIL NEXT TIME, THIS IS DEADLINE/CXN YOUTUBE:@CITYXEN"
.text "                  "
.text " *** END OF SIGNAL ***"
.text "                  "

.byte $ff

/*//----------------------------------------------------------
			// Print the music info while assembling
			.print ""
			.print "SID Data"
			.print "--------"
			.print "loc=$"+toHexString(music.loc)
			.print "init=$"+toHexString(music.init)
			.print "play=$"+toHexString(music.play)
			.print "songs="+music.songs
			.print "startSong="+music.startSong
			.print "size=$"+toHexString(music.size)
			.print "name="+music.name
			.print "author="+music.author
			.print "copyright="+music.copyright
			.print ""
			.print "Additional tech data"
			.print "--------------------"
			.print "header="+music.header
			.print "header version="+music.version
			.print "flags="+toBinaryString(music.flags)
			.print "speed="+toBinaryString(music.speed)
			.print "startpage="+music.startpage
			.print "pagelength="+music.pagelength  /*
*/