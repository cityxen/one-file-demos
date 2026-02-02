
/*

<deadline_cxn> is that where I use stuff like nop to fix it
<@burg> yes and maybe do things like lda #$18 ldx #$1b sta $d018 stx $d011
<@groepaz> you need something called "stable raster" to remove the jitter
<@burg> so you use less cycles for the writes
<@groepaz> burg: hoogo always used decimals too... wtf, unreadable :)
<@burg> for this routine, u need 3 vic writes, d011,d016,d018

*/

#import "Constants.asm"


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

.const COLORS_BOTTOM_LEFT  = $dbc0

.var music = LoadSid("output.sid")
*=music.location "Music"
.fill music.size, music.getData(i)

*=charset_loc "Char Set Data"
// #import "chars-charset.asm"
charset:
.import binary "arcade-64chars.bin"

* = bitmap "Img Data"
imgdata:
.import binary "koala.kla",2

BasicUpstart2(start)

*=$0810 "Main Program"
start:

	lda 678 // $02a6 // 1 = pal 0 = ntsc
	beq !+
	// pal
	lda #120
	sta music_speed
	lda #1
	sta scroll_speed
	lda #240
	sta color_speed
	lda #$e8
	sta raster_wtf
	lda #$0e
	sta raster_divin
	jmp palcheck_out
!:
	// ntsc
	lda #120
	sta music_speed
	lda #1
	sta scroll_speed
	lda #240
	sta color_speed
	lda #$de
	sta raster_wtf
	lda #$52
	sta raster_divin

palcheck_out:

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

////////////////////////////////

mainloop:

	jsr KERNAL_GETIN

	beq next_main
	sta last_key_press

	cmp #KEY_F1
	bne !+
	inc raster_wtf
	jmp next_main
!:
	cmp #KEY_F3
	bne !+
	dec raster_wtf
	jmp next_main
!:

	cmp #KEY_F5
	bne !+
	inc raster_divin
	jmp next_main
!:

	cmp #KEY_F7
	bne !+
	dec raster_divin
	jmp next_main
!:


next_main:
	jsr irq_timers
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

irq_timers:
    inc irq_timer1
    inc irq_timer2
	inc irq_timer3

    lda irq_timer1
    cmp music_speed
    bne !it+
    inc irq_timer_trig1
    lda #$00
    sta irq_timer1
	jsr music.play
!it:

    lda irq_timer3
    cmp color_speed
    bne !it+
    inc irq_timer_trig3
    lda #$00
    sta irq_timer3
	jsr color_it
	
!it:

	rts

////////////////////////////////
// draw scroller irq

irq_chars:
	
	ldx #00
!:
	inx
	cpx raster_divin
	bne !-


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
	

	ldx #$1b
	stx $d011


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

	ldx scroll_speed
!:
	txa
	pha
	jsr scroll_it
	pla
	tax
	dex
	bne !-

	lda raster_wtf
	sta VIC_RASTER_COUNTER
	
	lda #<irq_chars
	sta $0314
	lda #>irq_chars
	sta $0315

    asl VIC_INTERRUPT_REG
	jmp $ea31

////////////////////////////////

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
	rts

////////////////////////////////

color_it:
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
    lda #$00
    sta vars+1
	ldx vars+1
	lda color_table,x
	sta COLORS_BOTTOM_LEFT
	rts

////////////////////////////////
// vars

vars:
.byte 0
.byte 0
music_speed:
.byte 0
scroll_speed:
.byte 0
color_speed:
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
.byte $f1
last_key_press:
.byte 0
// var space
irq_timer1:
.byte 0
irq_timer2:
.byte 0
irq_timer3:
.byte 0
irq_timer_trig1:
.byte 0
irq_timer_trig2:
.byte 0
irq_timer_trig3:
.byte 0
raster_divin:
.byte 12

* = color_cycle_loc "Color Cycle Data"
#import "color-cycle.asm"
* = scroll_loc "Scroll Text Data"
#import "scroller.asm"

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