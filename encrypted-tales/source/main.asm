
/*

<deadline_cxn> is that where I use stuff like nop to fix it
<@burg> yes and maybe do things like lda #$18 ldx #$1b sta $d018 stx $d011
<@groepaz> you need something called "stable raster" to remove the jitter
<@burg> so you use less cycles for the writes
<@groepaz> burg: hoogo always used decimals too... wtf, unreadable :)
<@burg> for this routine, u need 3 vic writes, d011,d016,d018

*/


.const scroll_loc          = $6000
.const color_cycle_loc     = $0b00
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

.const SCREEN_MEM_POINTER  = $288 // 648
.const VIC_CONTROL_REG_1   = $d011 // 53265 RST8 ECM- BMM- DEN- RSEL [   YSCROLL   ]
.const VIC_RASTER_COUNTER  = $d012 // 53266
.const VIC_CONTROL_REG_2   = $d016 // 53270 ---- ---- RES- MCM- CSEL [   XSCROLL   ]
.const VIC_MEM_POINTERS    = $d018 // 53272
.const VIC_INTERRUPT_REG   = $d019 // 53273 IRQ- ---- ---- ---- ILP- IMMC IMBC IRST
.const CIA_2               = $dd00 // 56576 0-1 vic bank (00: bank3, 01: bank2, 10: bank1, 11: bank 0)

.var music = LoadSid("Glitch4K-5000.sid")
*=music.location "Music"
.fill music.size, music.getData(i)

*=charset_loc "Char Set Data"
#import "chars-charset.asm"

* = bitmap "Img Data"
imgdata:
.import binary "encrypted tales.kla",2

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
	sta $c000,x
	sta $c100,x
	sta $c200,x
	sta $c300,x
	sta $c000+(1000-40),x
	inx
	bne !-

	jsr copychars // copy charset data

	ldx #0
	ldy #0
	lda #music.startSong-1 //<- Here we get the startsong and init address from the sid file
	jsr music.init



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


	lda #BLACK
	sta scroll_background_color

mainloop:

	jsr $ffe4 // getkey

	cmp #$0d
	bne !+
	inc raster_wtf
	jmp mainloop
!:
	cmp #$11
	bne !+
	dec raster_wtf
!:
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
	lda #$00 // zero out these chars (not used)
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

	//inc $d020
/*
    pha
	txa
	pha
	ldx raster_wtf
!:	
	nop
//	nop
	dex
	bne !-
	pla
	tax
	pla
	*/
	
	lda scroll_background_color
	sta $d021
	
	lda CIA_2 // change vic bank
	and #$fc
	sta CIA_2
	lda #$02
	sta VIC_MEM_POINTERS
	lda #$c0 // point screen memory to $c000
	sta SCREEN_MEM_POINTER
	lda scroll_count
	and #$07
    sta VIC_CONTROL_REG_2
	lda #$1b
	sta VIC_CONTROL_REG_1



	// lda #$18
	ldx #$1b
	// sta $d018
	stx $d011
	

	jsr scroll_it
	jsr music.play


	lda #$02
	sta VIC_RASTER_COUNTER

	lda #<irq_bitmap
	sta $0314
	lda #>irq_bitmap
	sta $0315

	asl VIC_INTERRUPT_REG
	jmp $ea31

////////////////////////////////
// draw bitmap irq

irq_bitmap:

	lda #$97
	sta $dd00
	lda #$15
	sta VIC_MEM_POINTERS
	lda #$04
	sta $288

	lda #$18
    sta $d018
    lda #$d8
    sta VIC_CONTROL_REG_2
    lda #$3b
    sta VIC_CONTROL_REG_1
	
	lda #$18        // Standard Bitmap + Multicolor
	sta VIC_CONTROL_REG_2
	lda #$3b        // Screen ON + Extended Color + Bitmap Mode
	sta VIC_CONTROL_REG_1

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

	lda #$f1
	sta VIC_RASTER_COUNTER

	lda #<irq_chars
	sta $0314
	lda #>irq_chars
	sta $0315

    asl VIC_INTERRUPT_REG
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
	ldx vars+1
	sta COLORS_BOTTOM_LEFT
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
.byte 0
.byte 0
.byte 0
.byte 0
.byte 0
scroll_background_color:
.byte 0
.byte 0
raster_wtf:
.byte $08

* = color_cycle_loc "Color Cycle Data"
color_table:
.byte YELLOW, YELLOW, YELLOW,YELLOW, YELLOW 
.byte YELLOW, YELLOW, YELLOW,YELLOW, YELLOW 
.byte YELLOW, YELLOW, YELLOW, YELLOW, ORANGE, ORANGE
.byte RED, RED, RED, RED
.byte ORANGE, ORANGE, YELLOW, YELLOW, YELLOW
.byte YELLOW, YELLOW, YELLOW,YELLOW, YELLOW
.byte YELLOW, YELLOW, YELLOW,YELLOW, YELLOW
.byte $ff

* = scroll_loc "Scroll Text Data"

hello_message:
.encoding "screencode_upper"
.text "                 "
.text " GREETINGS SCROLLTRAVELERS!"
.text "                 "
.text " IN BETWEEN REALITY, AND THE CYBER WORLD..."
.text " EXISTS A PLACE WHERE AI ENTITIES WAGE WAR..."
.text " MANIFESTING THEIR IMAGINATIONS INTO OUR REALITY..."
.text " A PLACE WHERE ANYTHING COULD HAPPEN..."
.text "                 "
.text " -=*( ENCRYPTED TALES )*=- "
.text "                 "
.text " A VIDEO SERIES BORN FROM THE ERA WHEN COMPUTERS WERE NOT APPS,"
.text " BUT PLACES YOU VISITED!"
.text "          "
.text " BACK WHEN LOADING SCREENS TOOK PATIENCE ->"
.text " WHEN CASSETTE MOTORS WHINED LIKE SMALL JET ENGINES ->"
.text " AND A SINGLE SYNTAX ERROR COULD END YOUR NIGHT! "
.text "                 "
.text " YOU LEARNED BY DOING... BY BREAKING THINGS..."
.text " BY TYPING IN PROGRAMS FROM MAGAZINES LINE BY LINE... "
.text " HOPING YOU DID NOT MISS A SINGLE CHARACTER."
.text "                 "
.text " THE KEYBOARD WAS LOUD, THE MONITOR WAS DEEP, "
.text " AND EVERY BOOT FELT LIKE OPENING A PORTAL..."
.text "                 "
.text " -=*( ENCRYPTED TALES )*=- "
.text "                 "
.text " STORIES HIDDEN IN THE NOISE -> "
.text " MYSTERIES WRAPPED IN STATIC -> "
.text " TRUTHS ENCODED BETWEEN BYTES !!!"
.text "                 "
.text " THIS IS A JOURNEY THROUGH FORGOTTEN DISKS,"
.text " CRACKED GAMES, HAND-LABELED FLOPPIES"
.text " AND FILES WITH NAMES THAT MEANT EVERYTHING"
.text " TO SOMEONE ONCE"
.text "                 "
.text " HERE THE LEAGUE OF 8-BIT COMPUTERS STIR..."
.text "                 "
.text " CLICKY, POKEY, VICTORIA, AMY, TEX AND THE REST..."
.text " OLD MACHINES WITH NEW INTENTIONS!"
.text "                 "
.text " THEY REMEMBER WHAT IT FELT LIKE..."
.text " TO WAIT FOR A PROGRAM TO LOAD ->"
.text " TO WATCH BARS CRAWL ACROSS THE SCREEN ->"
.text " TO WONDER IF THIS TIME IT WOULD WORK!"
.text "                 "
.text " THEY REMEMBER THE FEAR OF SAVING OVER THE WRONG DISK ->"
.text " THE TRIUMPH OF SEEING YOUR OWN CODE RUN ->"
.text " THE MAGIC OF MAKING A MACHINE DO SOMETHING NEW!"
.text "                 "
.text " >>> ENCRYPTED TALES IS NOT ABOUT SPEED <<<"
.text "                 "
.text " IT IS ABOUT PRESENCE..."
.text "                 "
.text " ABOUT SITTING IN A DARK ROOM LIT ONLY BY A CRT"
.text " WITH TIME TO THINK AND SPACE TO IMAGINE..."
.text "                 "
.text " ### EACH EPISODE - A CODED CHALLENGE ###"
.text "         "
.text " ### EACH CLUE - A FRAGMENT OF DIGITAL MYTH ###"
.text "         "
.text " ### EACH REVEAL - A SECRET UNLOCKED! ###"
.text "                 "
.text " FROM A TIME WHEN COMPUTERS TAUGHT US HOW TO THINK NOT JUST WHAT TO CLICK..."
.text "                 "
.text " THIS IS FOR THE KIDS WHO BECAME ENGINEERS ->"
.text " THE HOBBYISTS WHO BECAME CREATORS ->"
.text " AND THE ONES WHO NEVER STOPPED WONDERING WHAT ELSE WAS HIDING ON THAT DISK..."
.text "         "
.text " SO ADJUST THE VERTICAL HOLD, TURN UP THE VOLUME, AND LET THE SCROLL CONTINUE..."
.text "                 "
.text " -=*( ENCRYPTED TALES )*=- "
.text "                 "
.text " WHERE THE PAST BOOTS CLEAN AND THE MACHINE STILL HAS SECRETS!"
.text "                             "
.text "  CODE: DEADLINE/CXN         "
.text "                             "
.text "  SID: GLITCH4K BY SPIDER J."
.text "                             "
.text "  SEE ALL THE ENCRYPTED TALES VIDEOS AND PLEASE SUBSCRIBE: YOUTUBE/@CITYXEN"
.text "                             "
.text "  THX FOR WATCHING... L8R!"
.text "                             "
.text " -=*[ END TRANSMISSION ]*=- +++"
.text "                             "
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