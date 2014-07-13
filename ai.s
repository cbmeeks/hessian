MAX_LINE_STEPS      = 10

MAX_NAVIGATION_STEPS = 8

AIH_AUTOTURNWALL    = $20
AIH_AUTOTURNLEDGE   = $40
AIH_AUTOSTOPLEDGE   = $80

JOY_CLIMBSTAIRS     = $40
JOY_FREEMOVE        = $80

AIMODE_IDLE         = 0
AIMODE_TURNTO       = 1
AIMODE_FOLLOW       = 2
AIMODE_SNIPER       = 3

NOTARGET            = $ff

BI_GROUND           = 1
BI_OBSTACLE         = 2
BI_CLIMB            = 4
BI_STAIRSLEFT       = 8
BI_STAIRSRIGHT      = 9

LINE_NOTCHECKED     = $00
LINE_NO             = $40
LINE_YES            = $80

DIR_UP              = $00
DIR_DOWN            = $01
DIR_LEFT            = $02
DIR_RIGHT           = $03
DIR_NONE            = $ff

        ; AI character update routine
        ;
        ; Parameters: X actor index
        ; Returns: -
        ; Modifies: A,Y,temp1-temp8,loader temp vars

MoveAIHuman:    lda actCtrl,x
                sta actPrevCtrl,x
                ldy actAIMode,x
                lda aiJumpTblLo,y
                sta MA_AIJump+1
                lda aiJumpTblHi,y
                sta MA_AIJump+2
MA_AIJump:      jsr $0000
MA_SkipAI:      jsr MoveHuman
                jmp AttackHuman

        ; Follow (pathfinding) AI

AI_Follow:      lda #ACTI_PLAYER                ;Todo: do not hardcode player as target
                sta actAITarget,x
                lda #AIH_AUTOSTOPLEDGE
                sta actAIHelp,x
                ldy actAITarget,x               ;Check distance to target: if less than one block,
                jsr GetActorDistance            ;reset navigation
                lda temp6
                ora temp8
                bne AI_FollowNotClose
AI_FollowClose: sta actNavNewYH,x               ;When close to target, perform an idle reset
                lda #$ff                        ;for the navigation system to not consume CPU
                bne AI_FollowReset2
AI_FollowNotClose:
                lda actNavYH,x                  ;Has a current waypoint?
                bpl AI_FollowGotoWaypoint
                if SHOW_NAVIGATION > 0
                lda #$00
                sta actT+20
                endif
AI_FollowCopyNew:
                lda actNavNewYH,x               ;Copy new waypoint if exists, or retry if failed
                bmi AI_FollowIdle
                bne AI_FollowHasNext
AI_FollowReset: lda #$ff
                sta actNavNewYH,x
AI_FollowReset2:sta actNavYH,x
AI_FollowIdle:  jmp AI_Idle
AI_FollowHasNext:
                sta actNavYH,x
                lda actNavNewXH,x
                sta actNavXH,x
                lda actNavNewExclude,x
                sta actNavExclude,x
                lda #$ff
                sta actNavNewYH,x               ;Then make already the next request
AI_FollowGotoWaypoint:
                if SHOW_NAVIGATION > 0
                lda actNavXH,x
                sta actXH+20
                sta actPrevXH+20
                lda actNavYH,x
                sta actYH+20
                sta actPrevYH+20
                lda #$80
                sta actXL+20
                sta actPrevXL+20
                lda #ACT_OBJECTMARKER
                sta actT+20
                endif
                lda actF1,x
                cmp #FR_CLIMB
                bcs AI_FollowClimbing
                lda actMB,x
                lsr
                bcc AI_FollowJumping
                lda actYH,x                     ;Check for stair junction climbing
                cmp actNavYH,x
                beq AI_FollowNoStairs
                tay
                rol temp8                       ;Up/down bit (C) to temp8
                getmaprow                       ;Get blockinfo at feet
                ldy actXH,x
                getblockinfo
                cmp #BI_STAIRSLEFT
                bcs AI_FollowOnStairs
                lsr
                bcc AI_FollowNoStairs
                ldy actYH,x                     ;Get blockinfo above
                dey
                getmaprow
                ldy actXH,x
                getblockinfo
                cmp #BI_STAIRSLEFT
                bcc AI_FollowNoStairs
                beq AI_FollowStairsLeft
AI_FollowStairsRight:
                lda actXL,x                     ;Move to right edge of block
                cmp #$c0
                bcc AI_FollowRight
AI_FollowClimbToStairs:
                lda #-8*8
                jmp MoveActorY
AI_FollowStairsLeft:
                lda actXL,x                     ;Move to left edge of block
                cmp #$40
                bcs AI_FollowLeft
                bcc AI_FollowClimbToStairs
AI_FollowOnStairs:
                eor temp8
                eor #$01
                lsr
                bpl AI_FollowRight

AI_FollowJumping:
                jmp AI_FreeMove
AI_FollowClimbing:
                lda actYH,x                     ;First climb to the correct block
                cmp actNavYH,x
                bne AI_FollowVertical3
                lda actYL,x
                cmp #$40
                bcs AI_FollowVerticalUp         ;Then to the bottom of the block
                                                ;Finally exit the ladder to left or right
AI_FollowNoStairs:
                lda actXH,x
                cmp actNavXH,x
                beq AI_FollowVertical
AI_FollowHorizontal:
AI_FollowRight: lda #JOY_RIGHT
                bcc AI_FollowStoreCtrl
AI_FollowLeft:  lda #JOY_LEFT
AI_FollowStoreCtrl:
                jmp AI_StoreMoveCtrl
AI_FollowVertical:
                lda actYH,x
                cmp actNavYH,x
                bne AI_FollowVertical2
                jmp AI_FollowCopyNew            ;Reached waypoint (X & Y distance both zero?)
AI_FollowVertical2:
                rol temp8                       ;Store C to low bit of temp8
                lda actXL,x                     ;Center on the ladder before climbing
                cmp #$40
                bcc AI_FollowRight
                cmp #$c0
                bcs AI_FollowLeft
                lsr temp8                       ;Restore C
AI_FollowVertical3:
                lda #JOY_DOWN
                bcc AI_FollowStoreCtrl
AI_FollowVerticalUp:
                lda #JOY_UP
                bcs AI_FollowStoreCtrl

        ; Turn to AI

AI_TurnTo:      ldy actAITarget,x
                bmi AI_Idle
                jsr GetActorDistance
AI_TurnToTarget:lda temp5
                sta actD,x                      ;Fall through

        ; Idle AI

AI_Idle:        lda #$00
                jmp AI_StoreMoveCtrl

        ; Sniper AI

AI_Sniper:      jsr FindTarget                  ;Todo: add proper aggression/defense code. Now is just a test
                ldy actAITarget,x               ;for attack direction finding
                bmi AI_Idle
                lda actLine,x                   ;If line-of-sight blocked, try to get new target
                bmi AI_HasLineOfSight
                beq AI_Idle
                jsr FT_PickNew
                jmp AI_Idle
AI_HasLineOfSight:
                jsr GetAttackDir
                bmi AI_FreeMoveWithTurn
                sta actCtrl,x
                cmp #JOY_FIRE
                bcc AI_NoFire
                lda #$00
AI_NoFire:      sta actMoveCtrl,x
                lda #AIH_AUTOSTOPLEDGE
AI_StoreMovementHelp:
                sta actAIHelp,x
                rts

AI_FreeMoveWithTurn:
                lda #AIH_AUTOTURNLEDGE|AIH_AUTOTURNWALL
                sta actAIHelp,x
AI_FreeMove:    lda #JOY_RIGHT                  ;Move forward into facing direction, turn at walls / ledges
                ldy actD,x
                bpl AI_FreeMoveRight
                lda #JOY_LEFT
AI_FreeMoveRight:
AI_StoreMoveCtrl:
                sta actMoveCtrl,x
                lda #$00
                sta actCtrl,x
                rts

        ; Validate existing AI target / find new target
        ;
        ; Parameters: X actor index
        ; Returns: actAITarget set to new value if necessary
        ; Modifies: A,Y,temp regs

FindTarget:     ldy actAITarget,x
                bmi FT_PickNew
                lda actHp,y                     ;When actor is removed (actT = 0) also health is zeroed
                beq FT_Invalidate               ;so only checking for health is enough
FT_TargetOK:    rts
FT_Invalidate:  lda #NOTARGET
FT_StoreTarget: sta actAITarget,x
FT_NoTarget:    rts
FT_PickNew:     ldy numTargets
                beq FT_NoTarget
                jsr Random
                and targetListAndTbl-1,y
                cmp numTargets
                bcc FT_PickTargetOK
                sbc numTargets
FT_PickTargetOK:tay
                lda targetList,y
                tay
                lda actFlags,x                  ;Must not be in same group
                eor actFlags,y
                and #AF_GROUPBITS
                beq FT_NoTarget
FT_CheckLine:   cpx #ACTI_LASTNPC+1             ;If this is a homing bullet, there will be no line-of-sight
                bcs FT_CheckLine2               ;check later, so check now
                lda #LINE_NOTCHECKED            ;For NPCs, reset line-of-sight information now until checked
                sta actLine,x
                tya
                bcc FT_StoreTarget
FT_CheckLine2:  tya
                pha
                jsr LineCheck
                pla
                bcs FT_StoreTarget
                rts

        ; Check if there is obstacles between actors (coarse line-of-sight)
        ;
        ; Parameters: X actor index, Y target actor index
        ; Returns: C=1 route OK, C=0 route fail
        ; Modifies: A,Y,temp1-temp3, loader temp variables

LineCheck:      lda actXH,x
                sta temp1
                lda actYL,x                     ;Check 1 block higher if low Y-pos < $80
                asl
                lda actYH,x
                sbc #$00
                sta temp2
                lda actXH,y
                sta LC_CmpX+1
                lda actYL,y                     ;Check 1 block higher if low Y-pos < $80
                asl
                lda actYH,y
                sbc #$00
                sta LC_CmpY+1
                sta LC_CmpY2+1
                lda #MAX_LINE_STEPS
                sta temp3
                ldy temp2                       ;Take initial maprow
                getmaprow
LC_Loop:        ldy temp1
LC_CmpX:        cpy #$00
                bcc LC_MoveRight
                bne LC_MoveLeft
                ldy temp2
LC_CmpY:        cpy #$00
                bcc LC_MoveDown
                bne LC_MoveUp
                rts                             ;C=1, line-of-sight found
LC_MoveRight:   iny
                bcc LC_MoveXDone
LC_MoveLeft:    dey
LC_MoveXDone:   sty temp1
                ldy temp2
LC_CmpY2:       cpy #$00
                bcc LC_MoveDown
                beq LC_MoveYDone2
LC_MoveUp:      dey
                bcs LC_MoveYDone
LC_MoveDown:    iny
LC_MoveYDone:   sty temp2
                getmaprow
LC_MoveYDone2:  dec temp3
                beq LC_NoLine
                ldy temp1
                getblockinfo                   ;Read blockinfo from map
                and #BI_OBSTACLE
                beq LC_Loop
LC_NoLine:      clc                             ;Route not found
                rts

        ; Get attack controls for an AI actor that has a valid target, including "move away" controls
        ; if target is too close
        ;
        ; Parameters: X actor index
        ; Returns: A:controls, flags also reflect its value
        ; Modifies: A,Y,temp regs

GetAttackDir:   ldy actAITarget,x               ;Check whether attack can be horizontal, vertical or diagonal
                jsr GetActorDistance
                jsr GetActorCharCoords          ;If is on the screen edge, do not fire, but come closer
                dey
                cpy #SCROLLROWS+4               ;(game can be too difficult otherwise)
                bcs GAD_NeedLessDistance
                cmp #39
                bcs GAD_NeedLessDistance
                ldy actWpn,x
                lda temp8
                beq GAD_Horizontal
                lda temp6
                beq GAD_Vertical
                cmp temp8
                beq GAD_Diagonal
GAD_NoAttackDir:bcc GAD_GoVertical              ;Diagonal, but not completely: need to move either closer or away
GAD_NeedLessDistance:
                lda temp5
                bmi GAD_NLDLeft
GAD_NLDRight:   lda #JOY_RIGHT
                rts
GAD_NLDLeft:    lda #JOY_LEFT
                rts
GAD_GoVertical: asl                             ;If is closer to a fully vertical angle, reduce distance instead
                cmp temp8
                bcc GAD_NeedLessDistance
GAD_NoAttackHint:
                lda #$00                        ;Otherwise, it is not wise to go away from target, as target may
                rts                             ;be moving under a platform, where the routecheck is broken
GAD_NeedMoreDistance:
                lda temp6                       ;If target is at same block (possibly using a melee weapon)
                ora temp8                       ;break away into whatever direction available
                bne GAD_NotAtSameBlock
                lda #JOY_FREEMOVE
                rts
GAD_NotAtSameBlock:
                lda temp5
                bmi GAD_NLDRight
                bpl GAD_NLDLeft
GAD_Diagonal:
GAD_Horizontal: lda temp6                       ;Verify horizontal distance too close / too far
                cmp itemNPCMinDist-1,y
                bcc GAD_NeedMoreDistance
                cmp itemNPCMaxDist-1,y
                bcs GAD_NeedLessDistance
                lda #JOY_RIGHT|JOY_FIRE
                ldy temp5
                bpl GAD_AttackRight
                lda #JOY_LEFT|JOY_FIRE
GAD_AttackRight:ldy temp8                       ;If block-distance is zero, do not fire diagonally
                beq GAD_Done
GAD_AttackAboveOrBelow:
                ldy temp7
                beq GAD_Done
                bpl GAD_AttackBelow
GAD_AttackAbove:ora #JOY_UP|JOY_FIRE
                rts
GAD_AttackBelow:ora #JOY_DOWN|JOY_FIRE
                rts
GAD_Vertical:   lda temp8                       ;For vertical distance, only check if too far
                cmp itemNPCMaxDist-1,y
                lda #$00                        ;If so, currently there is no navigation hint
                bcc GAD_AttackAboveOrBelow
GAD_Done:       tay                             ;Get flags of A
                rts

        ; Check for navigation routes to target
        ;
        ; Parameters: X actor index
        ; Returns: -
        ; Modifies: A,Y,temp variables

NavigationCheck:
                lda actNavExclude,x
                sta zpBitBuf
                lda actNavXH,x                  ;Is the actor currently following the path?
                ldy actNavYH,x                  ;If yes, use the last waypoint, else current
                bpl NC_StoreStartPos            ;actor position
NC_NotOnRoute:  lda #DIR_NONE
                sta zpBitBuf
                lda actXH,x
                ldy actYH,x
NC_StoreStartPos:
                sta temp1
                sta temp6
                sty temp2
                sty temp7
                ldy actAITarget,x
                lda actXH,y                     ;Get target's position (todo: could support also
                sta temp3                       ;fixed waypoints)
                lda actYH,y
                sta temp4
                lda actMB,y
                lsr
                bcs NC_TargetOnGround           ;If target is jumping, aim intentionally 1 block below
                inc temp4
NC_TargetOnGround:
                lda temp1                       ;First check if already at target
                cmp temp3
                bne NC_NotAtTarget
                lda temp2
                cmp temp4
                bne NC_NotAtTarget
                jmp NC_NoRoute
NC_NotAtTarget: lda #$ff
                ldy #$03
NC_ClearLoop:   sta routeYH,y                   ;Assume all subroutes (up, down, left, right) fail
                dey
                bpl NC_ClearLoop

        ; Up subroute

NC_Up:          lda zpBitBuf                    ;Check if up route should be excluded
                bne NC_UpOK
                jmp NC_Down
NC_UpOK:        lda #MAX_NAVIGATION_STEPS       ;Step counter
                sta temp5
                jsr NC_GetBlockInfo
                cmp #BI_STAIRSLEFT              ;Currently on stairs up?
                bcs NC_UpStairs
                ldy temp2
                dey
                jsr NC_GetBlockInfoDirect
                cmp #BI_CLIMB                   ;Stairs or ladder above?
                bcc NC_UpFail
                cmp #BI_STAIRSLEFT
                bcs NC_UpStairs2
NC_UpLadder:    lda #DIR_DOWN
                sta routeExclude                ;Store exclude dir for this subroute
NC_UpLadderLoop:dec temp2                       ;Move up
                jsr NC_GetBlockInfo
                lsr                             ;Ground bit to C
                and #BI_CLIMB/2                 ;Ladder ends -> fail
                beq NC_UpFail
                bcs NC_UpDone                   ;Found junction (ground)
                lda temp1
                cmp temp3
                bne NC_UpNotAtTarget
                lda temp2
                cmp temp4
                beq NC_UpDone                   ;Found target
NC_UpNotAtTarget:
                dec temp5                       ;Steps left?
                bne NC_UpLadderLoop
                beq NC_UpFail
NC_UpDone:      lda temp1                       ;Store the subroute endpoint
                sta routeXH
                lda temp2
                sta routeYH
NC_UpFail:      jmp NC_Down
NC_UpStairs2:   dec temp2                       ;Begin from the stairs above
NC_UpStairs:
NC_UpStairsLoop:lda temp1
                cmp temp3
                bne NC_UpStairsNotAtTarget
                lda temp2
                cmp temp4
                beq NC_UpDone                   ;Found target
NC_UpStairsNotAtTarget:
                jsr NC_GetBlockInfo
                cmp #BI_STAIRSLEFT
                bcc NC_UpFail                   ;Move horizontally first to determine whether
                beq NC_UpStairsMoveRight        ;the stairs continue up, or land at a junction
NC_UpStairsMoveLeft:
                lda #DIR_RIGHT
                sta routeExclude
                dec temp1
                jmp NC_UpStairsMoveCommon
NC_UpStairsMoveRight:
                lda #DIR_LEFT
                sta routeExclude
                inc temp1
NC_UpStairsMoveCommon:
                getblockinfo
                lsr                             ;Ground bit to C
                bcs NC_UpDone                   ;Found junction?
                dec temp2                       ;Otherwise move also up
                dec temp5                       ;Steps left?
                bne NC_UpStairsLoop
                beq NC_UpFail

        ; Down subroute

NC_Down:        lda zpBitBuf                    ;Check if down route should be excluded
                cmp #DIR_DOWN
                beq NC_DownFail
                lda temp6                       ;Reload position
                sta temp1
                lda temp7
                sta temp2
                jsr NC_GetBlockInfo
                and #BI_CLIMB
                beq NC_DownFail                 ;If not, subroute not possible
                lda #MAX_NAVIGATION_STEPS       ;Step counter
                sta temp5
NC_DownLoop:    inc temp2                       ;Move down
                jsr NC_GetBlockInfo
                lsr                             ;Ground bit to C
                bcs NC_DownDone                 ;Found junction
                and #BI_CLIMB/2                 ;Ladder ends -> fail
                beq NC_DownFail
                lda temp1
                cmp temp3
                bne NC_DownNotAtTarget
                lda temp2
                cmp temp4
                beq NC_DownDone                 ;Found target
NC_DownNotAtTarget:
                dec temp5                       ;Steps left?
                bne NC_DownLoop
                beq NC_DownFail
NC_DownDone:    lda temp1                       ;Store the subroute endpoint
                sta routeXH+1
                lda temp2
                sta routeYH+1
NC_DownFail:    lda zpBitBuf
                cmp #DIR_LEFT
                beq NC_ExcludeLeft
                lda #$02
                sta NC_HorzDone+1
                lda #$c6                        ;DEC zeropage
                ldy #BI_STAIRSLEFT
                jsr NC_Horz
NC_ExcludeLeft: lda zpBitBuf
                cmp #DIR_RIGHT
                beq NC_ExcludeRight
                lda #$03
                sta NC_HorzDone+1
                lda #$e6                        ;INC zeropage
                ldy #BI_STAIRSRIGHT
                jsr NC_Horz
NC_ExcludeRight:

        ; Subroutes done, determine best of them

NC_SubroutesDone:
                lda #$ff                        ;Best found subroute & distance
                sta temp1
                sta temp2
                stx temp8
                ldx #$03
NC_CheckBestLoop:
                lda routeYH,x                   ;Negative Y = failed
                bmi NC_CheckBestNext
                sec
                sbc temp4
                sta temp6                       ;Temp6 = signed Y-distance
                bpl NC_CheckBestYOK
                clc
                eor #$ff
                adc #$01
NC_CheckBestYOK:sta temp5
                lda routeXH,x
                sec
                sbc temp3
                clc
                bpl NC_CheckBestXOK
                eor #$ff
                adc #$01
NC_CheckBestXOK:adc temp5                       ;A = current abs. distance to target
                ldy temp6
                beq NC_CheckBestNoPenalty
                cpy #$80
                ldy routeYH,x
                bcs NC_CheckBestTargetBelow
                dey
NC_CheckBestTargetBelow:
                pha                             ;If target is below but route endpoint
                getmaprow                       ;doesn't give a possibility to go further
                ldy routeXH,x                   ;below, add a "penalty". Likewise if target
                getblockinfo                    ;is above
                cmp #BI_CLIMB
                pla
                bcs NC_CheckBestNoPenalty
                asl
NC_CheckBestNoPenalty:
                cmp temp2                       ;Better than last?
                bcs NC_CheckBestNext
                sta temp2
                stx temp1
NC_CheckBestNext:
                dex
                bpl NC_CheckBestLoop
                ldx temp8
                ldy temp1
                bmi NC_NoRoute
                lda routeExclude,y
                sta actNavNewExclude,x
                lda routeXH,y                    ;Store new waypoint for AI
                sta actNavNewXH,x
                lda routeYH,y
NC_StoreNewYH:  sta actNavNewYH,x
                rts
NC_NoRoute:     lda #$00
                beq NC_StoreNewYH

        ; Horizontal subroute

NC_Horz:        sta NC_HorzLoop
                sta NC_HorzJunctionMove
                sty NC_HorzStairsDown+1
                lda NC_HorzDone+1               ;By default the opposite horizontal direction is excluded
                eor #$01
                sta NC_HorzExclude+1
                lda #MAX_NAVIGATION_STEPS       ;Step counter
                sta temp5
                lda temp6                       ;Reload position
                sta temp1
                lda temp7
                sta temp2
                jsr NC_GetBlockInfo             ;Check if currently on stairs down
                cmp NC_HorzStairsDown+1
                beq NC_HorzMoveDown
NC_HorzLoop:    dec temp1                       ;Move left/right
                lda temp1                       ;Check for going outside the map horizontally
                cmp limitL
                bcc NC_HorzFail
                cmp limitR
                bcs NC_HorzFail
                cmp temp3
                bne NC_HorzNotAtTarget
                lda temp2
                cmp temp4
                bne NC_HorzNotAtTarget
NC_HorzDone:    ldy #$02
                lda temp1                       ;Store the subroute endpoint
                sta routeXH,y
                lda temp2
                sta routeYH,y
NC_HorzExclude: lda #$00
                sta routeExclude,y
NC_HorzFail:    rts
NC_HorzNotAtTarget:
                jsr NC_GetBlockInfo
                sta zpDestLo                    ;Store blockinfo at feet
NC_HorzStairsDown:
                cmp #BI_STAIRSLEFT              ;Check for moving down
                beq NC_HorzMoveDown
                and #BI_CLIMB                   ;If ladder down, found junction
                bne NC_HorzDone
                ldy temp2
                dey
                jsr NC_GetBlockInfoDirect
                ;sta zpDestHi                   ;Store blockinfo above
                cmp #BI_CLIMB                   ;Stairs or ladder above?
                bcs NC_HorzMoveUp
                lda zpDestLo
                lsr                             ;Ground bit to C
                bcc NC_HorzFail                 ;Fail if ground ended
NC_HorzDecrement:
                dec temp5                       ;Steps left?
                beq NC_HorzFail
                jmp NC_HorzLoop
NC_HorzMoveDown:inc temp2                       ;Move down stairs
                jsr NC_GetBlockInfo
                lsr                             ;If hit level ground after moving down, found a stairs junction
                bcc NC_HorzDecrement
NC_HorzJunctionMove:
                dec temp1
                lda #DIR_UP                     ;In that case exclude the "up" direction next
                sta NC_HorzExclude+1
                beq NC_HorzDone
NC_HorzMoveUp:  cmp #BI_STAIRSLEFT              ;If found a ladder above, it's a junction
                bcc NC_HorzDone
                lda zpDestLo
                lsr
                bcs NC_HorzDone                 ;If ground at feet and stairs leading up above, found a junction
                dec temp2                       ;Else move up along the stairs, then check for reaching target
                lda temp1
                cmp temp3
                bne NC_HorzDecrement
                lda temp2
                cmp temp4
                beq NC_HorzDone

NC_GetBlockInfo:ldy temp2
NC_GetBlockInfoDirect:
                getmaprow
                ldy temp1
                getblockinfo
                rts