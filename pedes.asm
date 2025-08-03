; -----------------------------------------------------------------------------
;
; Constants
;
; -----------------------------------------------------------------------------
VERA_CTRL           := $9f25
VERA_ADDR           := $9f20
VERA_ADDR_M         := $9f21
VERA_ADDR_H         := $9f22
DATA0               := $9f23
SCRN_VRAM           := $b000
SCRN_WIDTH          := 32
SCRN_VWIDTH         := 128
SCRN_HEIGHT         := 25
PEDE_START_LEN      := 6
PEDE_LEN_MAX        := 16
PEDE_HEAD_LEFT      := 83
PEDE_HEAD_RIGHT     := 84
PEDE_BODY_1         := 81
PEDE_BODY_2         := 82
DIR_LEFT            := 1
DIR_RIGHT           := 2
DIR_UP              := 4
DIR_DOWN            := 8
LEFT_EDGE           := 1
RIGHT_EDGE          := 30
TOP_EDGE            := 2
BOTTOM_EDGE         := 23
MUSHROOM_CHAR       := 88
TOXIC_COLOR         := $f1
PLAYER_CHAR         := 90
PLAYER_COLOR        := $50
MISSILE_CHAR        := 93
SPIDER_CHAR         := 85
FLEA_CHAR           := 94
SPIDER_CEILING_Y    := 17
MISSILE_COLOR       := $3b
JOY_RIGHT           := 1
JOY_LEFT            := 2
JOY_DOWN            := 4
JOY_UP              := 8
JOY_START           := 16
JOY_FIRE            := 128
GAMESTATE_ACTIVE    := $01
GAMESTATE_LEVELWON  := $10
GAMESTATE_LEVELLOST := $11
GAMESTATE_GAMEOVER  := $ff

; Petsciipede info lives in hi ram (bank 1)
pede_x              := $a000
pede_y              := pede_x+PEDE_LEN_MAX
pede_body           := pede_y+PEDE_LEN_MAX
pede_dir            := pede_body+PEDE_LEN_MAX
pede_vdir           := pede_dir+PEDE_LEN_MAX




; -----------------------------------------------------------------------------
;
; ZP locations shared with BASIC 
;
; -----------------------------------------------------------------------------
MISSILE_ACTIVE      := $23
SPIDER_ACTIVE       := $24
FLEA_ACTIVE         := $25
PLAYER_X            := $26
PLAYER_Y            := $27
MISSILE_X           := $28
MISSILE_Y           := $29
SPIDER_X            := $2a
SPIDER_Y            := $2b
SPIDER_DIR          := $2c
FLEA_X              := $2d
FLEA_Y              := $2e
UNDER_MISSILE_CHAR  := $2f
UNDER_MISSILE_COLOR := $30
UNDER_SPIDER_CHAR   := $31
UNDER_SPIDER_COLOR  := $32
UNDER_FLEA_CHAR     := $33
UNDER_FLEA_COLOR    := $34
SPIDER_COLOR        := $35
FLEA_COLOR          := $36
SPECIALS_DELAY      := $37
SPECIALS_DELAY_CNT  := $38
TOXIC_FLAG          := $39
PEDE_PATROL_LINE    := $40
PEDE_LEN            := $3c
PEDE_COLOR          := $3e
MUSHROOM_COLOR      := $3f
GAME_STATE          := $40



; -----------------------------------------------------------------------------
;
; ZP Variables
;
; -----------------------------------------------------------------------------
ZP_COL              := $70
ZP_ROW              := $71
ZP_CHAR             := $72
ZP_COLOR            := $73
ZP_ADDR             := $74
ZP_ROWCOUNT         := $76
ZP_TMP1             := $77



; -----------------------------------------------------------------------------
;
; Kernal
;
; -----------------------------------------------------------------------------
K_ENTROPY           := $fecf



; -----------------------------------------------------------------------------
;
;
; Code
;
; 
; -----------------------------------------------------------------------------
.org $0400

; $0400
jmp init_pedes
; $0403
jmp move_pedes
; $0406
jmp show_pedes
; $0409
jmp show_player
; $040c
jmp hide_player
; $040f
jmp update_scene



; -----------------------------------------------------------------------------
;
; update_scene
;
; -----------------------------------------------------------------------------
.proc update_scene
            lda MISSILE_ACTIVE          ; if missile is active, update it
            beq :+
            jsr hide_missile            ; hide from current position
            jsr move_missile            ; move it one step further
            lda MISSILE_ACTIVE          ; if still active (didn't go off screen)
            beq :+
            jsr show_missile            ; redisplay it

:           inc SPECIALS_DELAY_CNT      ; slow down spider and flea using delay
            lda SPECIALS_DELAY
            cmp SPECIALS_DELAY_CNT
            bne end

            stz SPECIALS_DELAY_CNT

            lda #1
            cmp SPIDER_ACTIVE           ; is spider active?
            bne :+
            jsr hide_spider             ; hide from current position
            jsr move_spider             ; move it
            jsr show_spider             ; display it
            bra end

:           lda #1
            cmp FLEA_ACTIVE             ; is flea active?
            bne end
            jsr hide_flea               ; hide from current position
            jsr move_flea               ; move it
            jsr show_flea               ; display it

end:        rts

.endproc



; -----------------------------------------------------------------------------
;
; move_missile 
;
; -----------------------------------------------------------------------------
.proc move_missile
            lda MISSILE_Y               ; get missile y position
            cmp #TOP_EDGE               ; if at the top of screen, deactivate
            beq deactivate 
            dec                         ; otherwise, move it up
            sta MISSILE_Y 
            jmp end 

deactivate: stz MISSILE_ACTIVE
            jsr hide_missile

end:        rts 
.endproc



; -----------------------------------------------------------------------------
;
; show_missile 
;
; -----------------------------------------------------------------------------
.proc show_missile
            lda MISSILE_X 
            sta ZP_COL 
            lda MISSILE_Y 
            sta ZP_ROW

            jsr vpeek
            sta UNDER_MISSILE_CHAR 
            stx UNDER_MISSILE_COLOR

            lda #MISSILE_CHAR
            ldx #MISSILE_COLOR 
            jsr vpoke 
            rts             
.endproc



; -----------------------------------------------------------------------------
;
; hide_missile 
;
;  Restores previous char and color that the missile covered up.
; -----------------------------------------------------------------------------
.proc hide_missile
            lda MISSILE_X               ; get missile coords
            sta ZP_COL 
            lda MISSILE_Y 
            sta ZP_ROW
            
            lda UNDER_MISSILE_CHAR      ; prep vpoke
            ldx UNDER_MISSILE_COLOR

            jsr vpoke                   ; draw previous char under missile

            rts             
.endproc



; -----------------------------------------------------------------------------
;
; move_spider 
;
; Moves downward, if at the bottom, deactivates. Random side movement.
; -----------------------------------------------------------------------------
.proc move_spider
            lda SPIDER_DIR              ; what dir is the spider moving?
            and #DIR_LEFT
            bne move_left
            lda SPIDER_DIR 
            and #DIR_RIGHT
            bne move_right 
            
            jmp end                     ; not moving left nor right

move_left:  lda SPIDER_X                ; dec x pos
            cmp #LEFT_EDGE
            beq deactivate              ; if at left edge, deactivate
            dec 
            sta SPIDER_X 
            jmp move_vert 

move_right: lda SPIDER_X 
            cmp #RIGHT_EDGE
            beq deactivate              ; if at right edge, deactivate
            inc 
            sta SPIDER_X 
            
move_vert:  lda SPIDER_DIR 
            and #DIR_DOWN
            bne move_down 
            lda SPIDER_DIR 
            and #DIR_UP 
            bne move_up 

            jmp end 

move_up:    lda SPIDER_Y 
            cmp #SPIDER_CEILING_Y
            beq turn_down
            dec 
            sta SPIDER_Y 
            jmp end

turn_down:  lda SPIDER_DIR
            eor #DIR_UP
            ora #DIR_DOWN
            sta SPIDER_DIR
            jmp end 

move_down:  lda SPIDER_Y 
            cmp #BOTTOM_EDGE
            beq turn_up
            inc 
            sta SPIDER_Y 
            jmp end

turn_up:    lda SPIDER_DIR
            eor #DIR_DOWN
            ora #DIR_UP
            sta SPIDER_DIR 
            jmp end

deactivate: stz SPIDER_ACTIVE
            jsr hide_spider

end:        rts 
.endproc



; -----------------------------------------------------------------------------
;
; show_spider 
;
; -----------------------------------------------------------------------------
.proc show_spider
            lda SPIDER_ACTIVE
            beq end

            lda SPIDER_X 
            sta ZP_COL 
            lda SPIDER_Y 
            sta ZP_ROW
            
            jsr vpeek

            cmp #PLAYER_CHAR
            bne :+
            ldx #$11
            stx GAME_STATE

:           cmp #MUSHROOM_CHAR
            beq :+
            cmp #MUSHROOM_CHAR+1
            beq :+
            lda #$20            
:           sta UNDER_SPIDER_CHAR
            stx UNDER_SPIDER_COLOR

            inc SPIDER_COLOR

            lda #SPIDER_CHAR            
            ldx SPIDER_COLOR 
            jsr vpoke 

end:        rts             
.endproc



; -----------------------------------------------------------------------------
;
; hide_spider 
;
; -----------------------------------------------------------------------------
.proc hide_spider
            lda SPIDER_X 
            sta ZP_COL 
            lda SPIDER_Y 
            sta ZP_ROW
            
            lda UNDER_SPIDER_CHAR 
            ldx UNDER_SPIDER_COLOR

            jsr vpoke 

            rts             
.endproc



; -----------------------------------------------------------------------------
;
; move_flea 
;
; Moves downward, if at the bottom, deactivates. Random side movement.
; -----------------------------------------------------------------------------
.proc move_flea
            lda FLEA_Y                  ; get current y
            cmp #BOTTOM_EDGE
            beq deactivate              ; if at edge, deactivate flea

            inc                         ; move a line down
            sta FLEA_Y 

            bra end

deactivate: stz FLEA_ACTIVE
            jsr hide_flea

end:        rts
.endproc 



; -----------------------------------------------------------------------------
;
; show_flea 
;
; -----------------------------------------------------------------------------
.proc show_flea
            lda FLEA_ACTIVE
            beq end 

            lda FLEA_X 
            sta ZP_COL 
            lda FLEA_Y 
            sta ZP_ROW
            
            jsr vpeek

            cmp #PLAYER_CHAR
            bne :+
            lda #$11
            sta GAME_STATE
            jmp end

:           cmp #MUSHROOM_CHAR
            beq toxic
            cmp #MUSHROOM_CHAR+1
            beq :+
            lda #$20
            bra :+

toxic:      lda #MUSHROOM_CHAR
            ldx #TOXIC_COLOR
            jsr vpoke

:           sta UNDER_FLEA_CHAR
            stx UNDER_FLEA_COLOR


            inc FLEA_COLOR

            lda #FLEA_CHAR
            ldx FLEA_COLOR 
            jsr vpoke 
            
end:        rts             
.endproc



; -----------------------------------------------------------------------------
;
; hide_flea 
;
; -----------------------------------------------------------------------------
.proc hide_flea
            lda FLEA_X 
            sta ZP_COL 
            lda FLEA_Y 
            sta ZP_ROW
            
            lda UNDER_FLEA_CHAR 
            ldx UNDER_FLEA_COLOR

            jsr vpoke

            rts             
.endproc


; -----------------------------------------------------------------------------
;
; init_pedes
;
; -----------------------------------------------------------------------------
.proc init_pedes
            jsr K_ENTROPY               ; get a psuedo-random number
            and #31                     ; want a number 6-19
:           cmp #19
            bcc :+
            dec
            bra :- 
:           cmp #6
            bcs :+
            inc
            jmp :- 

:           tax 

            ldy #0                      ; position each segment
            lda #PEDE_HEAD_LEFT         ; first segment is the head
            sta pede_body,y             ; assign head as first body part

            txa         
            sta pede_x,y                ; assign head's position
            lda #TOP_EDGE
            sta pede_y,y

            lda #DIR_LEFT
            sta pede_dir,y              ; initial direction is left

            lda #DIR_DOWN
            sta pede_vdir,y             ; initial vertical dir is down
            
            iny                         ; position to segment after head
            inx 

loop:       txa 
            sta pede_x,y 
            lda #TOP_EDGE
            sta pede_y,y

            tya                         ; assign alternating body chars
            and #1
            beq :+
            lda #PEDE_BODY_1
            bra :++
:           lda #PEDE_BODY_2            
:           sta pede_body,y

            iny 
            inx                         ; pede will start left to right
            cpy PEDE_LEN
            bcc loop

            rts
.endproc



; -----------------------------------------------------------------------------
;
; move_pedes
;
; -----------------------------------------------------------------------------
.proc move_pedes
            ldy PEDE_LEN                ; start at end of pede table
            dey

loop:       lda pede_body,y             ; get next pede segment

            bne :+ 
            jmp next_seg                ; if not active, move to next  

:           jsr erasesegment

chkhead:    lda pede_body,y
            cmp #PEDE_HEAD_LEFT         ; if this is a head,
            beq move_head               ; move the head logic is different
            cmp #PEDE_HEAD_RIGHT
            beq move_head

moveseg:    dey                         ; this is a body segment
            lda pede_x,y                ; get x pos from segment in front
            pha 
            lda pede_y,y                ; get y pos from segment in front
            iny 

            sta pede_y,y                ; update segment with those coords
            pla 
            sta pede_x,y 

            jmp next_seg

move_head:  lda pede_dir,y              ; get dir pede is moving in
            tax                         ; keep a copy for next compare
            and #DIR_LEFT
            bne look_left               ; moving to the left
            txa 
            and #DIR_RIGHT
            bne look_right              ; moving to the right

            jsr move_pede_vertical      ; move vertically
            jmp next_seg                ; not moving left or right (i.e toxic is true)

look_left:  lda pede_x,y                ; look for obstacle to the left
            cmp #LEFT_EDGE
            beq turn_right              ; at the left edge, so turn around

            dec                         ; what's to the left?
            sta ZP_COL
            lda pede_y,y
            sta ZP_ROW 
            jsr vpeek 

            cmp #$20                    ; if open, continue moving left
            beq move_left
            jsr detect_toxic_mushroom
            cmp #PLAYER_CHAR            ; if player is there, continue moving left
            bne :+
            lda #$11
            sta GAME_STATE              ; player lost this wave
            jmp move_left 

:           jmp turn_right              ; something else is there, turn right

move_left:  lda pede_x,y 
            dec 
            sta pede_x,y
            jmp next_seg

move_right: lda pede_x,y 
            inc 
            sta pede_x,y 
            jmp next_seg

look_right: lda pede_x,y                ; check for right edge of screen
            cmp #RIGHT_EDGE
            beq turn_left               ; at right edge, turn left

            inc                         ; what's to the right?
            sta ZP_COL 
            lda pede_y,y 
            sta ZP_ROW 
            jsr vpeek 

            cmp #$20                    ; if open, move right
            beq move_right 
            jsr detect_toxic_mushroom
            cmp #PLAYER_CHAR            ; if it's the player, move right
            bne turn_left
            lda #$11
            sta GAME_STATE
            bra move_right 

turn_left:  lda #DIR_LEFT
            sta pede_dir,y              ; set direction to left
            lda #PEDE_HEAD_LEFT
            sta pede_body,y
            jsr move_pede_vertical      ; move to next line
            jmp next_seg

turn_right: lda #DIR_RIGHT 
            sta pede_dir,y              ; set direction to right
            lda #PEDE_HEAD_RIGHT 
            sta pede_body,y
            jsr move_pede_vertical      ; move to next line
            jmp next_seg

next_seg:   cpy #0                      ; if out of segments, exit
            beq end 

            dey                         ; dec segment offset, go to top 
            jmp loop

end:        rts
.endproc

; -----------------------------------------------------------------------------
;
; detect_toxic_mushroom
;
;  Checks the petsciipede's obstacle to see if it's a toxic mushroom, 
;  setting flag if so.
;
; Assumptions:
;  a = obstacle
;  x = color
; -----------------------------------------------------------------------------
.proc detect_toxic_mushroom
            cmp #MUSHROOM_CHAR
            bne end
            cpx #TOXIC_COLOR
            bne end
            inc TOXIC_FLAG              ; 0 = toxic enabled
            ldx #2
            stx PEDE_PATROL_LINE
            pha
            lda #DIR_DOWN
            sta pede_dir,y              ; only move down
            pla
end:        rts
.endproc


; -----------------------------------------------------------------------------
;
; erasesegment
;
;  Erase a petsciipede segment from screen
;
; Setup:
;  y = offset into pede
;
; -----------------------------------------------------------------------------
.proc erasesegment   
            lda pede_x,y                ; remove segment from screen 
            sta ZP_COL 
            lda pede_y,y 
            sta ZP_ROW 
            lda #$20                    ; space char
            ldx #0                      ; all black
            jsr vpoke 
            rts
.endproc



; -----------------------------------------------------------------------------
;
; move_pede_vertical
;
; Setup:
;  y = offset into pede
;
; -----------------------------------------------------------------------------
.proc move_pede_vertical
            lda pede_vdir,y             ; get the direction to move
            tax

            lda pede_y,y                ; current y
            cpx #DIR_UP
            bne :+

            cmp PEDE_PATROL_LINE        ; has pede return too far up
            beq turn_down               ; if so, turn back down
            
            dec 
            jmp savey

:           cpx #DIR_DOWN               ; if moving down
            bcs :+
            bra end

:           cmp #BOTTOM_EDGE            ; if at the bottom, start moving up
            bcs turn_up
            inc 
            bra savey

turn_down:  lda #DIR_DOWN
            sta pede_vdir,y
            bra end

turn_up:    lda #DIR_UP
            sta pede_vdir,y
            lda pede_y,y
            dec 
            sta pede_y,y
            bra end

savey:      sta pede_y,y
end:        rts
.endproc



; -----------------------------------------------------------------------------
;
; show_pedes
;
; -----------------------------------------------------------------------------
.proc show_pedes
            lda PEDE_LEN
            sta ZP_ROWCOUNT
            ldy #0
            lda PEDE_COLOR
            sta ZP_COLOR            

loop:       lda pede_x,y                ; get x,y,char,color info for segment
            sta ZP_COL
            lda pede_y,y
            sta ZP_ROW
            lda pede_body,y
            sta ZP_CHAR
            ldx ZP_COLOR

            cmp #0                      ; if body part not active, skip rendering
            beq next

            jsr vpoke                   ; render

next:       dec ZP_ROWCOUNT
            lda ZP_ROWCOUNT
            beq end

            iny
            bra loop

end:        rts

.endproc



; -----------------------------------------------------------------------------
;
; show_player 
;
; -----------------------------------------------------------------------------
.proc show_player
            lda PLAYER_X 
            sta ZP_COL 
            lda PLAYER_Y 
            sta ZP_ROW 
            lda #PLAYER_CHAR
            ldx #PLAYER_COLOR
            jsr vpoke 

            rts
.endproc




; -----------------------------------------------------------------------------
;
; hide_player 
;
; -----------------------------------------------------------------------------
.proc hide_player
            lda PLAYER_X 
            sta ZP_COL 
            lda PLAYER_Y 
            sta ZP_ROW 
            lda #$20
            ldx #0
            jsr vpoke 

            rts
.endproc


; -------------------------------------------------------------------
; 
; calc_vram
; 
; Calculate the VRAM address of position x,y
;
; Setup:
;   Expects ZP_COL and ZP_ROW to already hold the col, row coords
; -------------------------------------------------------------------
.proc calc_vram
    ; start with the beginnnig of mapbase layer 1
    lda #<SCRN_VRAM
    sta ZP_ADDR
    lda #>SCRN_VRAM
    sta ZP_ADDR+1
    
    lda ZP_ROW              ; x will hold how many rows to add to addr
    asl 
    tax

    beq addcol              ; if rows=0 skip to add columns

:   clc
    lda ZP_ADDR
    adc #SCRN_VWIDTH        ; add screen width to lo byte
    sta ZP_ADDR 
    lda ZP_ADDR+1 
    adc #0                  ; add 0 to high byte in case there 
    sta ZP_ADDR+1           ; was a carry

    dex                     ; decrement row count
    bne :-                  ; if not 0, there are more rows to add
    
addcol:                     ; add the col to the total
    lda ZP_COL
    asl 
    sta ZP_TMP1
    clc 
    lda ZP_ADDR
    adc ZP_TMP1
    sta ZP_ADDR
    lda ZP_ADDR+1
    adc #0
    sta ZP_ADDR+1

    rts
.endproc



; -------------------------------------------------------------------
; 
; vpoke
; 
; Place a char at the specified screen coordinates
;
; Parameters
; a = screen code of the char to render
; x = color attrib to assign
; Assumed ZP_COL and ZP_ROW hold the col,row coords
; -------------------------------------------------------------------
.proc vpoke
    pha                     ; save screen code in a safe place
    phx                     ; save color in a safe place

    jsr calc_vram           ; translate col,row to VRAM address

    stz VERA_CTRL           ; setup data port 0
    lda ZP_ADDR            ; assign VRAM address to data port 0
    sta VERA_ADDR
    lda ZP_ADDR+1
    sta VERA_ADDR_M
    lda #%00010001          ; increment of 1, layer 1
    sta VERA_ADDR_H

    plx                     ; get the color attrib back
    pla                     ; get the screen code back

    sta DATA0               ; write the screen code    
    stx DATA0               ; write the color attrib

    rts
.endproc



; -------------------------------------------------------------------
; 
; vpeek
; 
; Get the char and color at the specified screen coordinates
;
; Parameters
;   Assumed ZP_COL and ZP_ROW hold the col,row coords
;
; Return:
;   a = screen code at the col, row address
;   x = the color
; -------------------------------------------------------------------
.proc vpeek
    jsr calc_vram           ; translate col,row to VRAM address
    stz VERA_CTRL           ; setup data port 0
    lda ZP_ADDR             ; assign VRAM address to data port 0
    sta VERA_ADDR
    lda ZP_ADDR+1
    sta VERA_ADDR_M
    lda #%00010001          ; no increment, layer 1
    sta VERA_ADDR_H

    lda DATA0               ; write the screen code to a
    ldx DATA0               ; write color to x
    rts
.endproc



; -----------------------------------------------------------------------------
;
; Data
;
; -----------------------------------------------------------------------------
; .org $a000

; pede_x:         .res PEDE_LEN_MAX, $00
; pede_y:         .res PEDE_LEN_MAX, $00
; pede_body:      .res PEDE_LEN_MAX, $00
; pede_dir:       .res PEDE_LEN_MAX, $00
; pede_vdir:      .res PEDE_LEN_MAX, $08

