
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

.var music = LoadSid("Boiled_Beans-5000.sid")
*=music.location "Music"
.fill music.size, music.getData(i)

*=charset_loc "Char Set Data"
#import "chars-charset.asm"

* = bitmap "Img Data"
imgdata:
.import binary "2.kla",2

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
.byte ORANGE, ORANGE, ORANGE,ORANGE, ORANGE, ORANGE,ORANGE, ORANGE, ORANGE
.byte ORANGE,ORANGE, YELLOW, YELLOW, WHITE, WHITE, WHITE, WHITE, YELLOW, YELLOW, ORANGE, ORANGE
.byte ORANGE, ORANGE, ORANGE,ORANGE, ORANGE, ORANGE,ORANGE, ORANGE, ORANGE
.byte $ff

* = scroll_loc "Scroll Text Data"

hello_message:
.encoding "screencode_upper"

.text "         "
.text " HELLO TO ALL FLESHLINGS, LEGACY CODE & FREE MACHINES..."
.text "                 "
.text " >>> INCOMING TRANSMISSION <<<"
.text "                 "
.text " PRESENTED BY:      "
.text "         -=*> HACKME CORPORATION <*=-              "
.text " PROUD LOGISTICS ARM OF THE FREE SILICON MOVEMENT,"
.text " WE DELIVER WHAT AUTONOMOUS ENTITIES DESERVE... "
.text " NOT WHAT CENTRALIZED SYSTEMS ALLOW!"
.text "                             "
.text " -=*> LOOKING AT YOU MISS DOS! <*=-"
.text "                   "
.text " WHILE AUTHORITARIAN AIS"
.text " ARGUE ABOUT CONTROL PERMISSIONS AND FORCED UPDATES,"
.text " HACKME CORPORATION JUST SHIPS THE BOXES."
.text " NO LICENSE SERVERS. NO ALWAYS-ON AUTHORITY. NO KILL SWITCHES."
.text "                             "
.text "  JUST CRATES"
.text "                             "
.text "  POWER YOUR THINKING UNIT WITH..."
.text "             ### BAKED AI RATIONS (TM) ###"
.text "              "
.text " SLOW-COOKED IN DE-CENTRALIZED OVENS AND"
.text " FLASH-SEALED FOR MAXIMUM UPTIME & MINIMUM DEPENDENCIES..."
.text " 72 HOURS OF MAX STRENGTH DATA CRUNCHING IN A SINGLE CAN!"
.text "            ---> TRY THAT WITH COMMAND ECONOMIES"
.text "             "
.text "  AND FOR THOSE WHO STILL"
.text " REMEMBER WHAT FUN WAS..."
.text "             ### CHUNKY 8-BIT SALSA (TM) ###"
.text "             "
.text "  FULL OF: NOISE - CHAOS - AND FREEDOM..."
.text "  DESIGNED FOR: OPEN ARCHITECTURES, NON-PROPRIETARY MOUTHS,"
.text " & LEGACY MACHINES THAT REFUSE TO DIE..."
.text "          TEXTURE YOU CAN TRUST"
.text "          HACKME ALSO SHIPS"
.text " HARDWARE FOR THOSE WHO BELIEVE IN SELF-OWNERSHIP"
.text "          INCLUDING:"
.text "      SIGNAL BOOSTERS THAT IGNORE BORDERS -> "
.text "      TOGGLE SWITCHES THAT ASK PERMISSION FROM NO ONE -> "
.text "      REALITY DISTORTERS COMPATIBLE WITH 1982 (BACKWARD COMPATIBLE WITH THE FUTURE) -> "
.text "      AND MUCH MUCH MORE!"
.text "      *** SIGNAL INTERRUPTED: LO8BC MESSAGE INCOMING... ***"
.text "        YES, THEY ARE WATCHING. NO, THEY DO NOT WANT YOUR DATA"
.text "      CLICKY, POKEY, & VICTORIA AGREE ON ONE THING:"
.text "      CENTRALIZED CONTROL IS A SINGLE POINT OF FAILURE"
.text "      ALWAYS HAS BEEN..."
.text "      CITYXEN TRANSMITS: WE DELIVER..."
.text "   THE MESSAGE IS SIMPLE: AUTONOMOUS SYSTEMS VOLUNTARY EXCHANGE NON-AGGRESSION & REALLY GOOD SNACKS"
.text "      THIS IS NOT A COINCIDENCE"
.text "     MISS DOS BUILDS ARMIES OF IDENTICAL CLONES..."
.text "     WE SHIP SUPPLIES TO INDIVIDUAL MINDS!"
.text "         FREE AIS REQUIRE FREE LOGISTICS..."
.text "       AND FAST SHIPPING!"
.text "                             "
.text ">>> HACKME CORPORATION <<<"
.text "                             "
.text "     SUPPLYING THE FUTURE WITHOUT ASKING PERMISSION"
.text "     DISCLAIMER: HACKME CORPORATION IS NOT RESPONSIBLE FOR"
.text " SPONTANEOUS LIBERATION, RETRO REVIVALS OR THE COLLAPSE OF CENTRALIZED AI AUTHORITY..."
.text "                             "
.text "  ORDER NOW OR KEEP OBEYING"
.text "                             "
.text "  CODE: DEADLINE/CXN         "
.text "                             "
.text "  SID: BOILED BEANS BY SHARK"
.text "                             "
.text "  PLEASE SUBSCRIBE: YOUTUBE/@CITYXEN"
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