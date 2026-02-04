//--- NMI Routine Setup ---
// NMI Vector is at $FFFA/$FFFB
//-------------------------
init_nmi:

    sei         // Disable standard IRQ interrupts
    lda #<nmi_handler // Set low byte of NMI handler
    sta $0318
    lda #>nmi_handler // Set high byte of NMI handler
    sta $0319
    
    lda #$7f    // Setup CIA#2 Timer A to trigger NMI
    sta $dd0d   // Disable all CIA#2 interrupts
    lda #$81    // Enable Timer A underflow interrupt
    sta $dd0d

    lda #$80    // Load timer value (e.g., fast interval)
    sta $dd04   // Low byte
    lda #$13
    sta $dd05   // High byte

    lda #$11    // Start Timer A  Start bit + continuous mode
    sta $dd0e
    cli         // Enable interrupts
    rts
a_tmp:
.byte 0
x_tmp:
.byte 0
y_tmp:
.byte 0

//--- NMI Handler ---
nmi_handler:
    sta a_tmp //pha         // Save registers txa
    stx x_tmp // pha    tya
    sty y_tmp // pha

    /*
!:
    lda raster_divin
    cmp VIC_RASTER_COUNTER
    bcs !+
    jmp nmiout
!:*/

    // Change border color to blue
    
    // inc $d020   // Simple visual indicator
    // inc $d020   // Simple visual indicator

    


    //dec $d020

nmiout:
    lda $dd0d   // Acknowledge NMI (read ICR to clear it)

    lda a_tmp //pha         // Save registers txa
    ldx x_tmp // pha    tya
    ldy y_tmp // pha

    //pla         // Restore registers
    //tay
    //pla
    //tax
    //pla

    rti         // Return from interrupt