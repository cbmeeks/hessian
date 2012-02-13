SCROLLROWS      = 22
SCROLLSPLIT     = 11

CI_GROUND       = 1                             ;Char info bits
CI_OBSTACLE     = 2
CI_CLIMB        = 4
CI_DOOR         = 8
CI_STAIRS       = 16
CI_SHELF        = 16
CI_SLOPE1       = 32
CI_SLOPE2       = 64
CI_SLOPE3       = 128

OPTIMIZE_SPRITEIRQS = 0

        ; Set map position and reset scrolling
        ;
        ; Parameters: X,Y new position
        ; Returns: -
        ; Modifies: A

SetMapPos:      stx mapX
                sty mapY
                lda #$00
                sta blockX
                sta blockY

        ; Reset & center scrolling
        ;
        ; Parameters: -
        ; Returns: -
        ; Modifies: A

InitScroll:     lda #$00
                sta scrollSX
                sta scrollSY
                sta scrCounter
                sta scrAdd
                lda #$04
                sta scrollX
                sta scrollY
                jmp SL_NewMapPos

        ; Blank the gamescreen and turn off sprites
        ; (return to normal display by calling UpdateFrame)
        ;
        ; Parameters: -
        ; Returns: -
        ; Modifies: A,X
        
BlankScreen:    jsr WaitBottom
                lda #$57
                sta Irq1_ScrollY+1
BS_Common:      ldx #$00
                stx Irq1_D015+1
                stx Irq1_MaxSprY+1
                inx                             ;Re-enable raster interrupts, if were disabled by the loader
                stx $d01a
                rts

        ; Show text at the game screen and turn off sprites
        ; (return to normal display by calling UpdateFrame)
        ;
        ; Parameters: -
        ; Returns: -
        ; Modifies: A,X

ShowTextScreen: jsr WaitBottom
                lda #$18
                sta Irq1_ScrollX+1
                lda #$17
                sta Irq1_ScrollY+1
                lda #PANEL_D018
                sta Irq1_Screen+1
                lda #TEXT_BG1
                sta Irq1_Bg1+1
                lda #TEXT_BG2
                sta Irq1_Bg2+1
                lda #TEXT_BG3
                sta Irq1_Bg3+1
                bpl BS_Common

        ; Perform scrolling logic
        ;
        ; Parameters: -
        ; Returns: -
        ; Modifies: A,X,Y

ScrollLogic:
                if SHOW_SCROLL_RASTERTIME > 0
                lda #$0e
                sta $d020
                endif

                lda scrAdd                      ;If speed is zero, look out
                beq SL_GetNewSpeed              ;for a new speed-setting
                clc
                adc scrCounter                  ;Update workcounter
                sta scrCounter
                tax
                lda scrollX                     ;Update finescroll-counters
                adc scrollCSX                   ;(let them wrap)
                and #$07
                sta scrollX
                lda scrollY
                clc
                adc scrollCSY
                and #$07
                sta scrollY                     ;Then check workcounter
                cpx #$08                        ;If it's >7 then this scrolling
                bcs SL_GetNewSpeed              ;is ready
                cpx #$04
                bne SL_CalcSprSub2
SL_SwapScreen:  lda screen
                eor #$01
                sta screen
SL_NewMapPos:   lda blockX
                sta SL_CSSBlockX+1
                lda blockY
                sta SL_CSSBlockY+1
                lda mapX
                sta SL_CSSMapX+1
                lda mapY
                sta SL_CSSMapY+1
SL_CalcSprSub2: jmp SL_CalcSprSub

SL_GetNewSpeed: lda #$00                        ;Reset the workcounter
                sta scrCounter
                ldx #$04                        ;Reset shift direction (center)
                lda scrollSX                    ;Get the requested speed
                sta scrollCSX
                beq SL_XDone
                bmi SL_XNeg
SL_XPos:        lda mapX                        ;Are we on the edge of map?
                clc                             ;(right)
                adc #$0a
                cmp limitR
                bcc SL_XPosOk
                lda blockX
                cmp #$01
                bcs SL_XZero
SL_XPosOk:      lda blockX                      ;Update block & map-coords
                adc #$01
                cmp #$04
                and #$03
                sta blockX
                bcc SL_XPosOk2
                inc mapX
SL_XPosOk2:     lda #$04
                sta scrollX
                inx
                bpl SL_XDone
SL_XNeg:        lda blockX                      ;Are we on the edge of map?
                bne SL_XNegOk                   ;(left)
                lda mapX
                cmp limitL
                beq SL_XZero
SL_XNegOk:      lda #$03
                dec blockX                      ;Update block & map-coords
                bpl SL_XNegOk2
                sta blockX
                dec mapX
SL_XNegOk2:     sta scrollX
                dex
                bpl SL_XDone
SL_XZero:       lda #$00
                sta scrollCSX
SL_XDone:       stx SW_ColorShiftDir+1
                lda scrollSY
                sta scrollCSY
                beq SL_YDone
                bmi SL_YNeg
SL_YPos:        lda mapY                        ;Are we on the edge of map?
                clc                             ;(bottom)
                adc #$06
                cmp limitD
                bcc SL_YPosOk
                lda blockY
                cmp #$02
                bcs SL_YZero
SL_YPosOk:      lda blockY                      ;Update block & map-coords
                adc #$01
                cmp #$04
                and #$03
                sta blockY
                bcc SL_YPosOk2
                inc mapY
SL_YPosOk2:     lda #$04
                sta scrollY
                inx
                inx
                inx
                bpl SL_YDone
SL_YNeg:        lda blockY                      ;Are we on the edge of map?
                bne SL_YNegOk                   ;(top)
                lda mapY
                cmp limitU
                beq SL_YZero
SL_YNegOk:      lda #$03
                dec blockY                      ;Update block & map-coords
                bpl SL_YNegOk2
                sta blockY
                dec mapY
SL_YNegOk2:     sta scrollY
                dex
                dex
                dex
                bpl SL_YDone
SL_YZero:       lda #$00
                sta scrollCSY
SL_YDone:       stx SW_ShiftDir+1
                ldy screen                      ;Update scrollwork jumps now
                lda screenBaseTbl,y
                eor #$05
                sta SW_DrawColorsRLoop+2
                sta SW_DrawColorsRLdy2+2
                sta SW_DrawColorsRLdy3+2
                lda screenJumpTblLo,y
                sta SW_ScreenJump+1
                lda screenJumpTblHi,y
                sta SW_ScreenJump+2
                lda colorJumpTblLo,x
                sta SW_ColorJump+1
                lda colorJumpTblHi,x
                sta SW_ColorJump+2
                lda scrollCSX                   ;Get absolute X-speed
                bpl SL_XPos2
                eor #$ff
                clc
                adc #$01
SL_XPos2:       tax
                sta scrAdd
                lda scrollCSY                   ;Then absolute Y-speed
                bpl SL_YPos2
                eor #$ff
                clc
                adc #$01
SL_YPos2:       tay
                cmp scrAdd                      ;Use the higher speed
                bcc SL_ScrAddYNotHigher
                sta scrAdd
SL_ScrAddYNotHigher:
                lda scrAdd
                cmp #$02                        ;If speed 2, then must use that on both axes
                bcc SL_ScrAddOk
                cpx #$02
                bcs SL_XSpeedOk
                asl scrollCSX
SL_XSpeedOk:    cpy #$02
                bcs SL_ScrAddOk
                asl scrollCSY
SL_ScrAddOk:
SL_CalcSprSub:  lda scrollX
                and #$01
                eor #$01
                sta SSpr_FineScroll1+1           ;Sprite X coord least significant bit
                sta SSpr_FineScroll2+1
SL_CSSBlockX:   lda #$00
                asl
                asl
                asl
                ora scrollX
                and #$fe
                asl
                asl
                asl
                sec
                sbc #<(31*8)
                sta DA_SprSubXL+1
SL_CSSMapX:     lda #$00
                sbc #(>(31*8))+1
                sta DA_SprSubXH+1
SL_CSSBlockY:   lda #$00
                asl
                asl
                asl
                ora scrollY
                asl
                asl
                asl
                sec
                sbc #<(54*8)
                sta DA_SprSubYL+1
SL_CSSMapY:     lda #$00
                sbc #(>(54*8))
                sta DA_SprSubYH+1
                if SHOW_SCROLL_RASTERTIME > 0
                lda #$00
                sta $d020
                endif
                rts

        ; Sort sprites, set new frame to be displayed and perform scrollwork
        ;
        ; Parameters: -
        ; Returns: -
        ; Modifies: A,X,Y,temp1-temp6

                if sprOrder < MAX_SPR+1         ;Ensure that a zeropage addressing trick works
                    err
                endif

UpdateFrame:    lda #$01                        ;Re-enable raster IRQs if were disabled by the loader
                sta $d01a
SSpr_Wait:      lda newFrame                    ;Wait until sprite IRQ is done with the current sprites
                bmi SSpr_Wait
                if SHOW_SPRITE_RASTERTIME > 0
                lda #$05
                sta $d020
                endif
                lda firstSortSpr                ;Switch sprite doublebuffer side
                eor #MAX_SPR
                sta firstSortSpr
                ldx #$00
                stx temp3                       ;D010 bits for first IRQ
                txa
SSpr_Loop1:     ldy sprOrder,x                  ;Check for coordinates being in order
                cmp sprY,y
                beq SSpr_NoSwap2
                bcc SSpr_NoSwap1
                stx temp1                       ;If not in order, begin insertion loop
                sty temp2
                lda sprY,y
                ldy sprOrder-1,x
                sty sprOrder,x
                dex
                beq SSpr_Swapdone1
SSpr_Swap1:     ldy sprOrder-1,x
                sty sprOrder,x
                cmp sprY,y
                bcs SSpr_Swapdone1
                dex
                bne SSpr_Swap1
SSpr_Swapdone1: ldy temp2
                sty sprOrder,x
                ldx temp1
                ldy sprOrder,x
SSpr_NoSwap1:   lda sprY,y
SSpr_NoSwap2:   inx
                cpx #MAX_SPR
                bne SSpr_Loop1
                ldx #$00
SSpr_FindFirst: ldy sprOrder,x                  ;Find upmost visible sprite
                lda sprY,y
                cmp #MIN_SPRY
                bcs SSpr_FirstFound
                inx
                bne SSpr_FindFirst
SSpr_FirstFound:txa
                adc #<sprOrder                  ;Add one more, C=1 becomes 0
                sbc firstSortSpr                ;Subtract one more to cancel out
                sta SSpr_CopyLoop1+1
                ldy firstSortSpr
                tya
                adc #8-1                        ;C=1
                sta SSpr_CopyLoop1End+1         ;Set endpoint for first copyloop
                bpl SSpr_CopyLoop1

SSpr_CopyLoop1Skip:
                inc SSpr_CopyLoop1+1
SSpr_CopyLoop1: ldx sprOrder,y
                lda sprY,x                      ;If reach the maximum Y-coord, all done
                cmp #MAX_SPRY
                bcs SSpr_CopyLoop1Done
                sta sortSprY,y
                lda sprC,x                      ;Check flashing
                bmi SSpr_CopyLoop1Skip
                sta sortSprC,y
                lda sprF,x
                sta sortSprF,y
                lda sprX,x
                asl
SSpr_FineScroll1:
                ora #$00
                sta sortSprX,y
                bcc SSpr_CopyLoop1MsbLow
                lda temp3
                ora sprOrTbl,y
                sta temp3
SSpr_CopyLoop1MsbLow:
                iny
SSpr_CopyLoop1End:
                cpy #$00
                bcc SSpr_CopyLoop1
                lda temp3
                sta sortSprD010-1,y
                lda sortSprC-1,y                ;Make first IRQ endmark
                ora #$80
                sta sortSprC-1,y
                lda SSpr_CopyLoop1+1            ;Copy sortindex from first copyloop
                sta SSpr_CopyLoop2+1            ;to second
                bcs SSpr_CopyLoop2

SSpr_CopyLoop1Done:
                lda temp3
                sta sortSprD010-1,y
                sty temp1                       ;Store sorted sprite end index
                cpy firstSortSpr                ;Any sprites at all?
                beq SSpr_NoSprites
                lda sortSprC-1,y                ;Make first (and final) IRQ endmark
                ora #$80
                sta sortSprC-1,y
                jmp SSpr_FinalEndMark
SSpr_NoSprites: jmp SSpr_AllDone

SSpr_CopyLoop2Skip:
                inc SSpr_CopyLoop2+1
SSpr_CopyLoop2: ldx sprOrder,y
                lda sprY,x
                cmp #MAX_SPRY
                bcs SSpr_CopyLoop2Done
                sta sortSprY,y
                sbc #21-1
                cmp sortSprY-8,y                ;Check for physical sprite overlap
                bcc SSpr_CopyLoop2Skip
                lda sprC,x                      ;Check flashing
                bmi SSpr_CopyLoop2Skip
                sta sortSprC,y
                lda sprF,x
                sta sortSprF,y
                lda sprX,x
                asl
SSpr_FineScroll2:
                ora #$00
                sta sortSprX,y
                lda sortSprD010-1,y
                bcc SSpr_CopyLoop2MsbLow
                ora sprOrTbl,y
                bne SSpr_CopyLoop2MsbDone
SSpr_CopyLoop2MsbLow:
                and sprAndTbl,y
SSpr_CopyLoop2MsbDone:
                sta sortSprD010,y
                iny
                bne SSpr_CopyLoop2

SSpr_CopyLoop2Done:
                sty temp1                       ;Store sorted sprite end index
                ldy SSpr_CopyLoop1End+1         ;Go back to the second IRQ start
                cpy temp1
                beq SSpr_FinalEndMark
SSpr_IrqLoop:   sty temp2                       ;Store IRQ startindex
                lda sortSprY,y                  ;C=0 here
                if OPTIMIZE_SPRITEIRQS > 0
                sbc #21+12-1                    ;First sprite of IRQ: store the Y-coord
                sta SSpr_IrqYCmp1+1             ;compare values
                adc #21+12+6-1
                else
                adc #6
                endif
                sta SSpr_IrqYCmp2+1
SSpr_IrqSprLoop:iny
                cpy temp1
                bcs SSpr_IrqDone
                if OPTIMIZE_SPRITEIRQS > 0
                lda sortSprY-8,y                ;Add next sprite to this IRQ?
SSpr_IrqYCmp1:  cmp #$00                        ;(try to add as many as possible while
                bcc SSpr_IrqSprLoop             ;avoiding glitches)
                endif
                lda sortSprY,y
SSpr_IrqYCmp2:  cmp #$00
                bcc SSpr_IrqSprLoop
SSpr_IrqDone:   tya
                sbc temp2
                tax
                lda sprIrqAdvanceTbl-1,x
                ldx temp2
                adc sortSprY,x
                sta sprIrqLine-1,x              ;Store IRQ start line (with advance)
                lda sortSprC-1,y                ;Make endmark
                ora #$80
                sta sortSprC-1,y
                cpy temp1                       ;Sprites left?
                bcc SSpr_IrqLoop
SSpr_FinalEndMark:
                lda #$00                        ;Make final endmark
                sta sprIrqLine-1,y

SSpr_AllDone:
                if SHOW_SPRITE_RASTERTIME > 0
                lda #$00
                sta $d020
                endif
UF_WaitPrevFrame:
                lda newFrame                    ;Now wait until the previous new frame
                bne UF_WaitPrevFrame            ;has been processed
                lda scrCounter                  ;Is it the colorshift? (needs special timing)
                cmp #$04
                bne UF_WaitNormal
UF_WaitColorShift:
                lda $d012                       ;Wait until we are near the scorescreen split
                cmp #IRQ3_LINE-$40
                bcc UF_WaitColorShift
                cmp #IRQ3_LINE+$20
                bcs UF_WaitColorShift
                bcc UF_WaitDone
UF_WaitNormal:  lda $d011                       ;If no colorshift, just need to make sure we
                bmi UF_WaitDone                 ;are not late from the frameupdate
                lda $d012
                cmp #IRQ1_LINE+$02
                bcs UF_WaitDone
                cmp #IRQ1_LINE-$05
                bcs UF_WaitNormal
UF_WaitDone:    lda scrollX                     ;Copy scrolling and screen number
                eor #$07
                ora #$10
                sta Irq1_ScrollX+1
                lda scrollY
                eor #$07
                ora #$10
                sta Irq1_ScrollY+1
                ldx screen
                lda d018Tbl,x
                sta Irq1_Screen+1
                lda screenFrameTbl,x
                sta Irq1_ScreenFrame+1
                tya                             ;Check which sprites are on
                sec
                sbc firstSortSpr
                cmp #$09
                bcc UF_NotMoreThan8
                lda #$08
UF_NotMoreThan8:tax
                lda d015Tbl,x
                sta Irq1_D015+1
                beq UF_NoSprites
                ldx firstSortSpr                ;Find out sprite Y-range for the fastloader
                stx Irq1_FirstSortSpr+1
                lda sortSprY,x                  ;(where to avoid the timed data transfer)
                sec
                sbc #$04
                sta Irq1_MinSprY+1
                ldy temp1
                lda sortSprY-1,y
                adc #22
UF_NoSprites:   sta Irq1_MaxSprY+1
                lda #$80
                sta newFrame
                if SHOW_SCROLL_RASTERTIME > 0
                lda #$0f
                sta $d020
                jsr ScrollWork
                lda #$00
                sta $d020
                rts
                endif

ScrollWork:     lda scrCounter
                bne SW_NoScreenShift
                lda scrAdd
                beq SW_NoWork
SW_ShiftScreen:
SW_ShiftDir:    ldx #$04
                lda shiftEndTbl,x
                pha
                ldy shiftSrcTbl,x
                lda shiftDestTbl,x
                tax
                pla
SW_ScreenJump:  jmp SW_NoWork

SW_NoScreenShift:
                cmp #$04
                bne SW_NoShiftColors
SW_ShiftColors:
SW_ColorShiftDir:
                ldx #$00
                stx temp1
SW_ColorJump:   jmp SW_NoWork

SW_NoShiftColors:
                cmp #$02
                bne SW_NoWork
SW_DrawBlocks:  lda scrollCSX
                beq SW_DBXDone
                bmi SW_DBLeft
SW_DBRight:     jsr SW_DrawRight
                jmp SW_DBXDone
SW_DBLeft:      jsr SW_DrawLeft
SW_DBXDone:     lda scrollCSY
                beq SW_NoWork
                bmi SW_DBUp
SW_DBDown:      jmp SW_DrawDown
SW_DBUp:        jmp SW_DrawUp
SW_NoWork:      rts

        ; Screen shifting routines

SW_Shift1:      sta SW_Shift1End
SW_Shift1Loop:                                  ;Screen shift routine:
N               set 0                           ;From screen1 to screen2
                repeat SCROLLROWS
                lda screen1-40+N*40,y
                sta screen2+N*40,x
N               set N+1
                repend
                dey
                dex
SW_Shift1End:   beq SW_Shift1Done
                jmp SW_Shift1Loop
SW_Shift1Done:  rts

SW_Shift2:      sta SW_Shift2End
SW_Shift2Loop:                                  ;Screen shift routine:
N               set 0                           ;From screen2 to screen1
                repeat SCROLLROWS
                lda screen2-40+N*40,y
                sta screen1+N*40,x
N               set N+1
                repend
                dey
                dex
SW_Shift2End:   beq SW_Shift2Done
                jmp SW_Shift2Loop
SW_Shift2Done:  rts

        ; Color shifting routines

SW_ShiftColorsUp:
                lda colorYTbl-3,x
                sta SW_ShiftColorsUpTopIny
                sta SW_ShiftColorsUpBottomIny
                lda colorXTbl-3,x
                sta SW_ShiftColorsUpTopInx
                sta SW_ShiftColorsUpBottomInx
                lda colorEndTbl-3,x
                sta SW_ShiftColorsUpTopCpx+1
                sta SW_ShiftColorsUpBottomCpx+1
                ldy colorDestTbl-3,x
                lda colorSrcTbl-3,x
                tax
SW_ShiftColorsUpTopLoop:
N               set SCROLLSPLIT-1
                repeat SCROLLSPLIT
                lda colors+N*40,x
                sta colors+40+N*40,y
N               set N-1
                repend
                lda vColBuf,y
                sta colors,y
SW_ShiftColorsUpTopIny:
                iny
SW_ShiftColorsUpTopInx:
                inx
SW_ShiftColorsUpTopCpx:
                cpx #$00
                bne SW_ShiftColorsUpTopLoop
                ldx temp1
                ldy colorSideTbl-3,x
                jsr SW_DrawColorsHorizTop
                ldy colorDestTbl-3,x
                lda colorSrcTbl-3,x
                tax
SW_ShiftColorsUpBottomLoop:
N               set SCROLLROWS-2
                repeat SCROLLROWS-SCROLLSPLIT-2
                lda colors+N*40,x
                sta colors+40+N*40,y
N               set N-1
                repend
SW_ShiftColorsUpBottomIny:
                iny
SW_ShiftColorsUpBottomInx:
                inx
SW_ShiftColorsUpBottomCpx:
                cpx #$00
                bne SW_ShiftColorsUpBottomLoop
                jsr SW_DrawColorsReconstruct
                ldx temp1
                ldy colorSideTbl-3,x
SW_DrawColorsHorizBottom:
                bmi SW_DrawColorsHorizBottomSkip
N               set SCROLLSPLIT
                repeat SCROLLROWS-SCROLLSPLIT
                lda hColBuf+N*40
                sta colors+N*40,y
N               set N+1
                repend
SW_DrawColorsHorizBottomSkip:
                rts

SW_ShiftColorsHoriz:
                lda colorYTbl-3,x
                sta SW_ShiftColorsHorizTopIny
                sta SW_ShiftColorsHorizBottomIny
                lda colorXTbl-3,x
                sta SW_ShiftColorsHorizTopInx
                sta SW_ShiftColorsHorizBottomInx
                lda colorEndTbl-3,x
                sta SW_ShiftColorsHorizTopCpx+1
                sta SW_ShiftColorsHorizBottomCpx+1
                ldy colorDestTbl-3,x
                lda colorSrcTbl-3,x
                tax
SW_ShiftColorsHorizTopLoop:
N               set 0
                repeat SCROLLSPLIT
                lda colors+N*40,x
                sta colors+N*40,y
N               set N+1
                repend
SW_ShiftColorsHorizTopIny:
                iny
SW_ShiftColorsHorizTopInx:
                inx
SW_ShiftColorsHorizTopCpx:
                cpx #$00
                bne SW_ShiftColorsHorizTopLoop
                ldx temp1
                ldy colorSideTbl-3,x
                jsr SW_DrawColorsHorizTop
                ldy colorDestTbl-3,x
                lda colorSrcTbl-3,x
                tax
SW_ShiftColorsHorizBottomLoop:
N               set SCROLLSPLIT
                repeat SCROLLROWS-SCROLLSPLIT
                lda colors+N*40,x
                sta colors+N*40,y
N               set N+1
                repend
SW_ShiftColorsHorizBottomIny:
                iny
SW_ShiftColorsHorizBottomInx:
                inx
SW_ShiftColorsHorizBottomCpx:
                cpx #$00
                bne SW_ShiftColorsHorizBottomLoop
                ldx temp1
                ldy colorSideTbl-3,x
                jmp SW_DrawColorsHorizBottom

SW_ShiftColorsDown:
                lda colorYTbl-3,x
                sta SW_ShiftColorsDownTopIny
                sta SW_ShiftColorsDownBottomIny
                lda colorXTbl-3,x
                sta SW_ShiftColorsDownTopInx
                sta SW_ShiftColorsDownBottomInx
                lda colorEndTbl-3,x
                sta SW_ShiftColorsDownTopCpx+1
                sta SW_ShiftColorsDownBottomCpx+1
                ldy colorDestTbl-3,x
                lda colorSrcTbl-3,x
                tax
SW_ShiftColorsDownTopLoop:
N               set 0
                repeat SCROLLSPLIT
                lda colors+40+N*40,x
                sta colors+N*40,y
N               set N+1
                repend
SW_ShiftColorsDownTopIny:
                iny
SW_ShiftColorsDownTopInx:
                inx
SW_ShiftColorsDownTopCpx:
                cpx #$00
                bne SW_ShiftColorsDownTopLoop
                ldx temp1
                ldy colorSideTbl-3,x
                jsr SW_DrawColorsHorizTop
                ldy colorDestTbl-3,x
                lda colorSrcTbl-3,x
                tax
SW_ShiftColorsDownBottomLoop:
N               set SCROLLSPLIT
                repeat SCROLLROWS-SCROLLSPLIT-1
                lda colors+40+N*40,x
                sta colors+N*40,y
N               set N+1
                repend
                lda vColBuf,y
                sta colors+SCROLLROWS*40-40,y
SW_ShiftColorsDownBottomIny:
                iny
SW_ShiftColorsDownBottomInx:
                inx
SW_ShiftColorsDownBottomCpx:
                cpx #$00
                bne SW_ShiftColorsDownBottomLoop
                ldx temp1
                ldy colorSideTbl-3,x
                jmp SW_DrawColorsHorizBottom

SW_DrawColorsHorizTop:
                bmi SW_DrawColorsHorizTopSkip
N               set 0
                repeat SCROLLSPLIT
                lda hColBuf+N*40
                sta colors+N*40,y
N               set N+1
                repend
SW_DrawColorsHorizTopSkip:
                rts

SW_DrawColorsReconstruct:
                ldx #12                         ;Reconstruct the colors that are lost when
SW_DrawColorsRLoop:                             ;shifting colors up in two parts
                ldy screen1+SCROLLSPLIT*40+40,x
                lda charColors,y
                sta colors+SCROLLSPLIT*40+40,x
SW_DrawColorsRLdy2:
                ldy screen1+SCROLLSPLIT*40+40+13,x
                lda charColors,y
                sta colors+SCROLLSPLIT*40+40+13,x
SW_DrawColorsRLdy3:
                ldy screen1+SCROLLSPLIT*40+40+26,x
                lda charColors,y
                sta colors+SCROLLSPLIT*40+40+26,x
                dex
                bpl SW_DrawColorsRLoop
                rts

        ; New blocks drawing routines

SW_DrawLeft:    ldx mapY                     ;Draw new blocks to the left
                lda mapTblLo,x
                sta temp3
                lda mapTblHi,x
                sta temp4
                ldx #temp3
                lda mapX
                jsr Add8
                lda blockX
                sta temp1
                lda #$00
SWDL_Common:    sta SWDL_Sta+1
                lda screen
                eor #$01
                tax
                lda screenBaseTbl,x
                sta SWDL_Sta+2
                lda #<hColBuf
                sta SWDL_Sta2+1
                lda #>hColBuf
                sta SWDL_Sta2+2
                lda #SCROLLROWS-1
                sta temp5
                lda #<hColBuf
                sta SWDL_Sta2+1
                lda blockY
                asl
                asl
                ora temp1
                ldx #$00
SWDL_GetBlock:  sta temp2
                ldy #$00
                lda (temp3),y
                tay
                lda blkTblLo,y
                sta SWDL_Lda+1
                lda blkTblHi,y
                sta SWDL_Lda+2
                ldy temp2
SWDL_Lda:       lda $1000,y
SWDL_Sta:       sta $1000,x
                sta SWDL_Lda2+1
SWDL_Lda2:      lda charColors
SWDL_Sta2:      sta hColBuf,x
                dec temp5
                bmi SWDL_Ready
                txa
                clc
                adc #40
                tax
                bcc SWDL_Not2
                inc SWDL_Sta+2
                inc SWDL_Sta2+2
SWDL_Not2:      lda blockDownTbl,y
                tay
                bpl SWDL_Lda
SWDL_Block:     lda temp3
                clc
                adc mapSizeX
                sta temp3
                bcc SWDL_Not3
                inc temp4
SWDL_Not3:      lda temp1
                jmp SWDL_GetBlock
SWDL_Ready:     rts

SW_DrawRight:   ldx mapY                     ;Draw new blocks to the right
                lda mapTblLo,x
                sta temp3
                lda mapTblHi,x
                sta temp4
                lda mapX
                clc
                adc #$09
                ldx #temp3
                jsr Add8
                lda blockX
                clc
                adc #$02
                cmp #$04
                and #$03
                sta temp1
                bcc SWDR_NotOver
                lda #$01
                jsr Add8
SWDR_NotOver:   lda #38
                jmp SWDL_Common

SW_DrawUp:      ldx mapY                     ;Draw new blocks to top of
                lda mapTblLo,x                  ;screen
                sta temp3
                lda mapTblHi,x
                sta temp4
                lda blockY
                asl
                asl
                ora blockX
                sta temp2
                lda screen
                eor #$01
                tax
                lda #$00
                sta SWDU_Sta+1
                lda screenBaseTbl,x
                sta SWDU_Sta+2
SWDU_Common:    lda #<vColBuf
                sta SWDU_Sta2+1
                lda #>vColBuf
                sta SWDU_Sta2+2
SWDU_Common2:   ldx #$00
                ldy mapX
SWDU_GetBlock:  lda (temp3),y
                iny
                sty temp5
                tay
                lda blkTblLo,y
                sta SWDU_Lda+1
                lda blkTblHi,y
                sta SWDU_Lda+2
                ldy temp2
SWDU_Lda:       lda $1000,y
SWDU_Sta:       sta screen1,x
                sta SWDU_Lda2+1
SWDU_Lda2:      lda charColors
SWDU_Sta2:      sta vColBuf,x
                inx
                cpx #39
                bcs SWDU_Ready
                lda blockRightTbl,y
                tay
                bpl SWDU_Lda
                and #$0f
                sta temp2
                ldy temp5
                jmp SWDU_GetBlock
SWDU_Ready:     rts

SW_DrawDown:    lda mapY                     ;Draw new blocks to bottom of
                clc                             ;screen
                adc #$05
                tax
                lda blockY
                adc #$01
                cmp #$04
                bcc SW_DDCalcDone
                and #$03
                inx
SW_DDCalcDone:  asl
                asl
                ora blockX
                sta temp2
                lda mapTblLo,x
                sta temp3
                lda mapTblHi,x
                sta temp4
                lda screen
                eor #$01
                tax
                lda #<(screen1+SCROLLROWS*40-40)
                sta SWDU_Sta+1
                lda screenBaseTbl,x
                ora #>(SCROLLROWS*40-40)
                sta SWDU_Sta+2
                jmp SWDU_Common

        ; Redraw screen fully and center scrolling
        ;
        ; Parameters: -
        ; Returns: -
        ; Modifies: A,X,Y,temp1-temp6

RedrawScreen:   jsr BlankScreen
                jsr InitScroll
                ldx mapY
                lda mapTblLo,x
                sta temp3
                lda mapTblHi,x
                sta temp4
                lda blockY
                asl
                asl
                ora blockX
                sta temp1
                sta temp2
                ldx screen
                lda #$00
                sta SWDU_Sta+1
                lda screenBaseTbl,x
                sta SWDU_Sta+2
                lda #<colors
                sta SWDU_Sta2+1
                lda #>colors
                sta SWDU_Sta2+2
                lda #SCROLLROWS
                sta temp6
RS_Loop:        jsr SWDU_Common2
                lda SWDU_Sta+1
                clc
                adc #40
                sta SWDU_Sta+1
                sta SWDU_Sta2+1
                bcc RS_NotOver1
                inc SWDU_Sta+2
                inc SWDU_Sta2+2
RS_NotOver1:    ldy temp1
                lda blockDownTbl,y
                bpl RS_NotOver3
                pha
                lda temp3
                clc
                adc mapSizeX
                sta temp3
                pla
                bcc RS_NotOver2
                inc temp4
RS_NotOver2:    and #$0f
RS_NotOver3:    sta temp1
                sta temp2
                dec temp6
                bne RS_Loop
                rts
        
        ; Get char collision info from the actor's position.
        ; Reduces amount of JSR's needed, if only this info is necessary
        ;
        ; Parameters: X actor index
        ; Returns: A charinfo
        ; Modifies: A,Y,loader temp vars

GetCharInfoActor:
                lda actXL,x
                rol
                rol
                rol
                and #$03
                sta zpBitsLo
                lda actYL,x
                lsr
                lsr
                lsr
                lsr
                and #$0c
                sta zpBitsHi
                ldy actYH,x
                lda mapTblLo,y
                sta zpDestLo
                lda mapTblHi,y
                sta zpDestHi
                ldy actXH,x
                jmp GCI_Common
                
        ; Initialize charinfo check location with actor's position
        ;
        ; Parameters: X actor index
        ; Returns: -
        ; Modifies: A,Y,loader temp vars
        
SetCharInfoPosActor:
                lda actXH,x
                sta zpSrcLo
                lda actYH,x
                sta zpSrcHi
                lda actXL,x
                rol
                rol
                rol
                and #$03
                sta zpBitsLo
                lda actYL,x
                lsr
                lsr
                lsr
                lsr
                and #$0c
                sta zpBitsHi
                lda #$ff
                sta GCI_NewBlock+1
                rts

        ; Initialize charinfo check location with arbitrary location
        ;
        ; Parameters: temp1-temp2 X position, temp3-temp4 Y position
        ; Returns: -
        ; Modifies: A,loader temp vars

SetCharInfoPos: lda temp2
                sta zpSrcLo
                lda temp4
                sta zpSrcHi
                lda temp1
                rol
                rol
                rol
                and #$03
                sta zpBitsLo
                lda temp3
                lsr
                lsr
                lsr
                lsr
                and #$0c
                sta zpBitsHi
                lda #$ff
                sta GCI_NewBlock+1
                rts

        ; Move charinfo check location horizontally
        ;
        ; Parameters: A how many chars (signed)
        ; Returns: -
        ; Modifies: A,Y,loader temp vars

MoveCharInfoPosX:
                clc
                adc zpBitsLo
                bmi MCIPX_Neg
MCIPX_Pos:      cmp #$04
                bcc MCIPX_Done
                ldy #$ff
                sty GCI_NewBlock+1
MCIPX_PosLoop:  inc zpSrcLo
                sbc #$04
                cmp #$04
                bcs MCIPX_PosLoop
MCIPX_Done:     sta zpBitsLo
                rts
MCIPX_Neg:      ldy #$ff
                sty GCI_NewBlock+1
MCIPX_NegLoop:  dec zpSrcLo
                clc
                adc #$04
                bmi MCIPX_NegLoop
                sta zpBitsLo
                rts

        ; Move charinfo check location vertically
        ;
        ; Parameters: A how many chars (signed)
        ; Returns: -
        ; Modifies: A,Y,loader temp vars

MoveCharInfoPosY:
                asl
                asl
                clc
                adc zpBitsHi
                bmi MCIPY_Neg
MCIPY_Pos:      cmp #$10
                bcc MCIPY_Done
                ldy #$ff
                sty GCI_NewBlock+1
MCIPY_PosLoop:  inc zpSrcHi
                sbc #$10
                cmp #$10
                bcs MCIPY_PosLoop
MCIPY_Done:     sta zpBitsHi
                rts
MCIPY_Neg:      ldy #$ff
                sty GCI_NewBlock+1
MCIPY_NegLoop:  dec zpSrcHi
                clc
                adc #$10
                bmi MCIPY_NegLoop
                sta zpBitsHi
                rts

        ; Get charinfo bits from the check location
        ; Parameters: -
        ; Returns: A charinfo
        ; Modifies: A,Y,loader temp vars

GetCharInfo:
GCI_NewBlock:   lda #$00                        ;TODO: this check must be changed if more
                bpl GCI_BlockReady              ;than 128 blocks are used
GCI_GetNewBlock:ldy zpSrcHi
                lda mapTblLo,y
                sta zpDestLo
                lda mapTblHi,y
                sta zpDestHi
                ldy zpSrcLo
GCI_Common:     cpy limitL
                bcc GCI_Outside
                cpy limitR
                bcs GCI_Outside
                lda (zpDestLo),y                ;Get block from map
GCI_OutsideDone:sta GCI_NewBlock+1
                tay
                lda blkTblLo,y
                sta zpDestLo
                lda blkTblHi,y
                sta zpDestHi
GCI_BlockReady: lda zpBitsLo
                ora zpBitsHi
                tay
                lda (zpDestLo),y                ;Get char from block
                tay
                lda charInfo,y                  ;Get charinfo
                rts

GCI_Outside:    lda #$00                        ;Outside map block $00 is always returned
                beq GCI_OutsideDone
