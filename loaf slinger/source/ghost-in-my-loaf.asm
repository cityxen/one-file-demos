.const scroll_location     = $0a20
.const color_cycle_location = $09f0
.const charset_location    = $1000
.const zp_tmp              = $4e
.const zp_tmp_lo           = $4e
.const zp_tmp_hi           = $4f
.const scrollScreenRam     = $c000
.const SCREEN_BOTTOM_LEFT  = scrollScreenRam + $3c0
.const SCREEN_BOTTOM_RIGHT = scrollScreenRam + $3e7
.const COLORS_BOTTOM_LEFT  = $DBC0
.const VIC_MEM_POINTERS    = $d018
.const screenRam           = $0400
.const colorRam            = $d800
.const bitmap              = $2000
.const screenData          = bitmap + 8000
.const colorData           = screenData + 1000
.const background          = colorData + 1000
.const VIC_RASTER_COUNTER  = $d012 // 53266
.const VIC_CONTROL_REG_2   = $d016 // 53270 ---- ---- RES- MCM- CSEL [   XSCROLL   ]

.var music = LoadSid("ghost-in-my-loaf-5000.sid")
*=music.location "Music"
.fill music.size, music.getData(i) // <- Here we put the music in memory

*=charset_location "char set"
charset:
.import binary "arcade-64chars.bin"

* = $2000 "Img Data" // Set destination address
imgdata:
.import binary "realdata-6000.prg",2

BasicUpstart2(start)

*=$0810 "Main Program"
start:

// set up scroller

    lda #<hello_message
    sta zp_tmp_lo
    lda #>hello_message
    sta zp_tmp_hi

    lda #$00
    sta count_var_high
    sta count_var_low
    sta timer_var

// set up interrupts

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

	// clear char mem and fill color ram for scroller with white
	
	ldx #$00
!:
	lda #$01
	sta colorRam+(1000-40),x
	lda #$20
	sta $c000+(1000-40),x
	inx
	bne !-

	jsr copychars

	ldx #0
	ldy #0
	lda #music.startSong-1 //<- Here we get the startsong and init address from the sid file
	jsr music.init


!:
jmp !-

vars:
.byte 0

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

scroll_count:
.byte 0
count_var_low:
.byte 0
count_var_high:
.byte 0
timer_var:
.byte 0

* = color_cycle_location "Color Cycle Data"
color_table:
.byte LIGHT_RED, LIGHT_RED, LIGHT_RED,LIGHT_RED, LIGHT_RED, LIGHT_RED,LIGHT_RED, LIGHT_RED, LIGHT_RED
.byte RED,RED, ORANGE,ORANGE, YELLOW,YELLOW, WHITE,WHITE,WHITE,WHITE, YELLOW,YELLOW, ORANGE,ORANGE, RED, RED
.byte LIGHT_RED, LIGHT_RED, LIGHT_RED,LIGHT_RED, LIGHT_RED, LIGHT_RED,LIGHT_RED, LIGHT_RED, LIGHT_RED
.byte $ff

* = scroll_location "Scroll Text"


hello_message:
.encoding "screencode_upper"
.text "                    . . . "
.text " LISTEN CLOSELY, SCENERS! THE YEAR WAS DARK, AND THE SERIAL BUS WAS SILENT."
.text " OUR 64S WERE CRYING OUT FOR DATA, STRANDED ON AN ISLAND OF OBSOLETE CONNECTIVITY..."
.text " UNTIL A SHADOW APPEARED ON THE HORIZON."
.text "          -=*( ENTER: LOAF SLINGER )*=-             "
.text " WHILE OTHERS COMPLAINED ABOUT SLOW LOAD TIMES AND BRICKED DRIVES,"
.text " LOAF SLINGER DIDN'T JUST SIT BY. HE STEPPED INTO THE ARENA, ARMED"
.text " WITH NOTHING BUT A SOLDERING IRON AND A VISION. HE SAW THE FRUSTRATION"
.text " OF A THOUSAND COMMODORE FANS AND SAID, 'NOT ON MY WATCH!'     "
.text " ### THE MAN WHO BROKE THE CHAINS ###       "
.text " HE TOOK THE CHAOTIC MESS OF MODERN TECH AND TAMED IT, FORCING THE"
.text " INTERNET ITSELF TO BOW BEFORE THE POWER OF THE COMMODORE. "
.text "        LOAF SLINGER - HE'S THE PROTECTOR OF OUR 8-BIT DREAMS!           "
.text " HE GAVE US THE KEY TO THE KINGDOM, ENSURING THAT NO COMMODORE WOULD EVER"
.text " BE LEFT BEHIND IN THE ANALOG DUST. "
.text " WHEN THE IEC BUS WAS AT ITS WEAKEST, LOAF SLINGER WAS AT HIS STRONGEST."
.text "    --- A TRUE SCENE LEGEND ---    "
.text " THE VISIONARY: HE SAW THE POTENTIAL WHERE OTHERS SAW LIMITATIONS."
.text " THE CRAFTSMAN: HE REFINES, HE IMPROVES, HE DELIVERS."
.text " THE HERO: HE RESTORED THE FLOW OF DATA TO THE MASSES!"
.text "        HTTPS://MEATLOAF.CC         "
.text "        SID: GHOST IN MY LOAF BY CHRIS WEMYSS"
.text "        UNTIL NEXT WE MEET AGAIN... THIS IS DEADLINE/CXN "
.text " SUBSCRIBE TO OUR YOUTUBE CHANNEL: @CITYXEN "
.text "                         END "
.text "                             "
.byte $ff

//----------------------------------------------------------
			// Print the music info while assembling
			//.print ""
			//.print "SID Data"
			//.print "--------"
			.print "location=$"+toHexString(music.location)
			.print "init=$"+toHexString(music.init)
			.print "play=$"+toHexString(music.play)
			//.print "songs="+music.songs
			//.print "startSong="+music.startSong
			.print "size=$"+toHexString(music.size)
			.print "name="+music.name
			.print "author="+music.author
			//.print "copyright="+music.copyright

/*
			.print ""
			.print "Additional tech data"
			.print "--------------------"
			.print "header="+music.header
			.print "header version="+music.version
			.print "flags="+toBinaryString(music.flags)
			.print "speed="+toBinaryString(music.speed)
			.print "startpage="+music.startpage
			.print "pagelength="+music.pagelength


*/