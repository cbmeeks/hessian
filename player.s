FR_STAND        = 0
FR_WALK         = 1
FR_JUMP         = 9
FR_DUCK         = 12
FR_ENTER        = 14
FR_CLIMB        = 15
FR_DIE          = 19
FR_ROLL         = 22
FR_SWIM         = 28
FR_PREPARE      = 32
FR_ATTACK       = 34

DEATH_DISAPPEAR_DELAY = 50
DEATH_FLICKER_DELAY = 20

WATER_XBRAKING = 3
WATER_YBRAKING = 3

DEATH_YSPEED    = -6*8
DEATH_MAX_XSPEED = 6*8
HUMAN_MAX_YSPEED = 6*8

DAMAGING_FALL_DISTANCE = 4

INITIAL_GROUNDACC = 5
INITIAL_INAIRACC = 1
INITIAL_GROUNDBRAKE = 6
INITIAL_JUMPSPEED = 40
INITIAL_CLIMBSPEED = 84
INITIAL_HEALTIMER = 4

UPGRADE_DAMAGE_MODIFY = 6
UPGRADE_FIREARM_MODIFY = 10
UPGRADE_MELEE_MODIFY = 12
UPGRADE_RELOADTIME_MODIFY = 6

HEALTIMER_RESET = $c0

MAX_OXYGEN      = 200
MAX_BATTERY     = 56
MAX_DIFFICULTY  = 3
LOW_BATTERY     = MAX_BATTERY*2/7
LOW_HEALTH      = HP_PLAYER*2/7
LOW_OXYGEN      = MAX_OXYGEN/4

DRAIN_WALK      = 3                             ;At footstep sound, 6 per anim. cycle
DRAIN_SHOOT     = 6
DRAIN_CLIMB     = 6                             ;At footstep sound, 12 per anim. cycle
DRAIN_JUMP      = 16
DRAIN_SWIM      = 16                            ;When animation wraps
DRAIN_ROLL      = 20
DRAIN_MELEE     = 20
DRAIN_HEAL      = 96
DRAIN_EMP       = 128

UPG_MOVEMENT    = 1
UPG_STRENGTH    = 2
UPG_FIREARMS    = 4
UPG_ARMOR       = 8
UPG_HEALING     = 16
UPG_DRAIN       = 32
UPG_RECHARGE    = 64
UPG_TOXINFILTER = 128

        ; Player control and movement routine
        ;
        ; Parameters: X actor index
        ; Returns: -
        ; Modifies: A,Y,temp1-temp8,loader temp vars

MovePlayer:     ldy #ZONEH_BG3
                lda (zoneLo),y
                bmi MP_NoPlayerScroll           ;Scroll-disabled zone?
MP_ScrollHorizontal:
                ldy #$00
                lda actXL+ACTI_PLAYER
                rol
                rol
                rol
                and #$03
                sec
                sbc SL_CSSBlockX+1
                and #$03
                sta zpSrcLo
                lda actXH+ACTI_PLAYER
                sbc SL_CSSMapX+1
                asl
                asl
                ora zpSrcLo
                cmp #SCRCENTER_X-1
                bcs MP_NotLeft1
                dey
MP_NotLeft1:    cmp #SCRCENTER_X
                bcs MP_NotLeft2
                dey
MP_NotLeft2:    cmp #SCRCENTER_X+1
                bcc MP_NotRight1
                iny
MP_NotRight1:   cmp #SCRCENTER_X+2
                bcc MP_NotRight2
                iny
MP_NotRight2:   sty scrollSX
MP_ScrollVertical:
                ldy #$00
                lda actYL+ACTI_PLAYER
                rol
                rol
                rol
                and #$03
                sec
                sbc SL_CSSBlockY+1
                and #$03
                sta zpSrcLo
                lda actYH+ACTI_PLAYER
                sbc SL_CSSMapY+1
                asl
                asl
                ora zpSrcLo
                cmp #SCRCENTER_Y-2
                bcs MP_NotUp1
                dey
MP_NotUp1:      cmp #SCRCENTER_Y
                bcs MP_NotUp2
                dey
MP_NotUp2:      cmp #SCRCENTER_Y+1
                bcc MP_NotDown1
                iny
MP_NotDown1:    cmp #SCRCENTER_Y+3
                bcc MP_NotDown2
                iny
MP_NotDown2:    sty scrollSY
MP_NoPlayerScroll:
                lda menuMode                    ;No new controls in inventory / interaction / dialogue
                bne MP_SetWeapon
                ldy actF1+ACTI_PLAYER
                cpy #FR_DUCK+1
                bne MP_NoDuckFirePrevent
                lda actCtrl,x
                cmp #JOY_DOWN                   ;Prevent fire+down immediately after ducking
                bne MP_NoDuckFirePrevent        ;(need to release down direction first)
                lda joystick
                cmp #JOY_DOWN+JOY_FIRE
                bne MP_NoDuckFirePrevent
                ldy #$ff-JOY_FIRE
                bne MP_StoreControlMask
MP_NoDuckFirePrevent:
                lda joystick
                cmp #JOY_DOWN+JOY_FIRE
                beq MP_ControlMask
                ldy #$ff
MP_StoreControlMask:
                sty MP_ControlMask+1
MP_ControlMask: and #$ff
                sta actCtrl+ACTI_PLAYER
                cmp #JOY_FIRE
                bcc MP_NewMoveCtrl
                and #$0f                        ;When fire held down, eliminate the opposite
                tay                             ;directions from the previous move control
                lda moveCtrlAndTbl,y
                ldy actF1+ACTI_PLAYER
                cpy #FR_DUCK+1                  ;When already ducked, keep the down control
                bne MP_NotDucked
                ora #JOY_DOWN
MP_NotDucked:   and actMoveCtrl+ACTI_PLAYER
MP_NewMoveCtrl: sta actMoveCtrl+ACTI_PLAYER
MP_SetWeapon:   ldy itemIndex
                cpy #ITEM_FIRST_NONWEAPON
                bcc MP_WeaponOK
                ldy #ITEM_NONE
MP_WeaponOK:    sty actWpn+ACTI_PLAYER
                jmp MoveAndAttackHuman

        ; Humanoid character move routine
        ;
        ; Parameters: X actor index
        ; Returns: -
        ; Modifies: A,Y,temp1-temp8,loader temp vars

MH_IsClimbing:  jmp MH_Climbing
MH_IsSwimming:  jmp MH_Swimming
MoveHuman:      ldy #AL_SIZEUP                  ;Set size up based on currently displayed
                lda (actLo),y                   ;frame
                ldy actF1,x
                sec
                sbc humanSizeReduceTbl,y
                sta actSizeU,x
                lda actD,x                      ;Current dir for roll control check
                sta MH_OldDir+1
MoveGeneric:    lda actMoveCtrl,x               ;Current joystick controls
                sta temp2
                ldy #AL_MOVEFLAGS
                lda (actLo),y
                sta temp3                       ;Movement capability flags
                iny
                lda (actLo),y
                sta temp4                       ;Movement speed
                lda actMB,x                     ;Previous frame's movement bits
                sta temp1
                bpl MH_NotInWater
                lsr temp4                       ;Halve max. speed
                lda #WATER_XBRAKING             ;Global water braking, both for alive & dead characters
                jsr BrakeActorX
                lda actF1,x                     ;Allow jump in water to begin without braking
                cmp #FR_JUMP                    ;(so that can get out of water)
                beq MH_NotInWater
                lda #WATER_YBRAKING
                jsr BrakeActorY
MH_NotInWater:  ldy actF1,x
                cpy #FR_CLIMB
                bcc MH_NoClimb
                cpy #FR_CLIMB+4
                bcc MH_IsClimbing
                cpy #FR_SWIM
                bcs MH_IsSwimming
                cpy #FR_ROLL
                bcs MH_RollAnim
MH_DyingAnim:   lda #$00                        ;Make sure no movement when dead
                sta temp2
                lda temp1                       ;Extra braking for corpse in water
                bpl MH_NoExtraBraking
                pha
                lda #WATER_YBRAKING*2
                jsr BrakeActorY
                pla
MH_NoExtraBraking:
                lsr
                lda #$06
                ldy #FR_DIE+1
                bcc MH_DeathAnimDelay
MH_DeathGrounded:
                jsr MH_StopXSpeed               ;Immediate full stop so that the horizontal corpse
                lda #$02                        ;doesn't slide
                ldy #FR_DIE+2
MH_DeathAnimDelay:
                jsr OneShotAnimation
MH_DeathAnimDone:
                lda actHp,x                     ;For story purposes
                bne MH_NotActuallyDead
                jsr DeathFlickerAndRemove
MH_NotActuallyDead:
                jmp MH_Brake
MH_RollAnim:    lda #$01
                jsr AnimationDelay
                bcc MH_RollAcc
                tya
                adc #$00
                cmp #FR_ROLL+6                  ;Transition from roll to low duck once the roll is complete
                bcc MH_RollAnimDone
                lda #FR_DUCK+1
MH_RollAnimDone:sta actF1,x
                bne MH_RollAcc                  ;Forced acceleration (regardless of controls) when rolling
MH_NoClimb:     lda temp2                       ;Check turning / X-acceleration / braking
                and #JOY_LEFT|JOY_RIGHT
                beq MH_Brake
                and #JOY_RIGHT
                bne MH_TurnRight
                lda #$80
MH_TurnRight:   cpy #FR_DUCK                    ;Only turn & brake if ducked
                beq MH_Brake2
MH_DuckBrake:   sta actD,x
                bcs MH_Brake2                   ;If ducking, only turn, then brake
MH_RollAcc:     lda temp1
                lsr                             ;Faster acceleration when on ground
                ldy #AL_GROUNDACCEL
                bcs MH_UseGroundAccel
                iny
MH_UseGroundAccel:
                lda actD,x
                asl                             ;Direction to carry
                lda (actLo),y
                ldy temp4
                jsr AccActorXNegOrPos
                jmp MH_HorizMoveDone
MH_Brake:       lda temp1                       ;Only brake when grounded
                lsr
                bcc MH_HorizMoveDone
MH_Brake2:      ldy #AL_BRAKING
                lda (actLo),y
                jsr BrakeActorX
MH_HorizMoveDone:
                ldy #AL_HEIGHT                  ;Actor height for ceiling check
                lda (actLo),y
                sta temp4
                ldy #AL_FALLACCEL               ;Make jump longer by holding joystick up
                lda actSY,x                     ;as long as still has upward velocity
                bpl MH_NoLongJump
                lda temp2
                and #JOY_UP
                beq MH_NoLongJump
                ldy #AL_LONGJUMPACCEL
MH_NoLongJump:  lda (actLo),y
                ldy #HUMAN_MAX_YSPEED
                jsr MoveWithGravity             ;Actually move & check collisions
                sta temp1                       ;Update saved movement flags
                bpl MH_NoStartSwim
                lda #-3                         ;In water: check for starting to swim
                jsr GetCharInfoOffset           ;(deep water)
                and #CI_WATER
                beq MH_NoStartSwim2
                txa                             ;If not player, kill instantly
                beq MH_CanSwim
DestroyActorNoSource:
                ldy #NODAMAGESRC
                jmp DestroyActor
MH_CanSwim:     lda actHp,x                     ;If already dead, do not start to swim
                beq MH_NoStartSwim2
                lda #-8*8                       ;Swimming frames have vertical hotspot at center,
                jsr MoveActorYNoInterpolation   ;so move up now to compensate
                lda #FR_SWIM
                jmp MH_AnimDone
MH_NoStartSwim2:lda temp1
MH_NoStartSwim: and #MB_HITWALL+MB_LANDED       ;Hit wall (and didn't land at the same time)?
                cmp #MB_HITWALL
                bne MH_NoHitWall
                lda actSY,x                     ;If hit wall while ascending, check wallflip
                bpl MH_NoWallFlip
                lda temp3
                and #AMF_WALLFLIP
                beq MH_NoWallFlip
                lda #JOY_UP|JOY_RIGHT
                ldy actSX,x
                beq MH_NoWallFlip
                bmi MH_WallFlipRight
                lda #JOY_UP|JOY_LEFT
MH_WallFlipRight:
                cmp temp2
                bne MH_NoWallFlip
                cmp #JOY_UP|JOY_RIGHT
                jsr MH_SetSignedHalfSpeed
                jmp MH_StartJump
MH_NoWallFlip:  jsr MH_StopXSpeed
MH_NoHitWall:   lda actF1,x                     ;If roll or death animation, continue it and don't animate
                cmp #FR_DIE                     ;jump/walk/run
                bcs MH_AnimDone2
                lda temp1
                lsr
                bcc MH_InAir
MH_PlayerStartFall:
                jmp MH_OnGround

MH_InAir:       and #MB_STARTFALLING/2
                beq MH_OkToFall
                txa                             ;One frame of ground controls for player to allow late jumps
                beq MH_PlayerStartFall
                jsr MH_ResetFall                ;Make sure unapplied fall distance isn't carried over
                lda actAIHelp,x                 ;Check AI reactions to falling off a ledge
                bpl MH_NoDropDown
                lda #3                          ;Allow drop down if ground reasonably close
                jsr GetCharInfoOffset
                and #CI_GROUND|CI_OBSTACLE
                bne MH_OkToFall
MH_NoDropDown:  lda actAIHelp,x                 ;Check autoturn or stop
                and #AIH_AUTOSTOPLEDGE|AIH_AUTOTURNLEDGE
                beq MH_OkToFall                 ;If none, just fall
                pha
                lda actSX,x
                jsr MoveActorXNeg
                jsr MH_SetGrounded
                pla
                lsr
                bcs MH_DoAutoStop
                jmp MH_DoAutoTurn
MH_DoAutoStop:  jmp MH_ResetMoveCtrl
MH_OkToFall:    lda temp3                       ;AI's will never grab ladders, so if enemy has no falldamage
                and #AMF_FALLDAMAGE             ;can also skip the grabbing code
                bne MH_UpdateFallCounter
MH_JumpAnim:    ldy #FR_JUMP+1
                lda actSY,x
                bpl MH_JumpAnimDown
MH_JumpAnimUp:  cmp #-1*8
                bcs MH_JumpAnimDone
                dey
                skip2
MH_JumpAnimDown:cmp #3*8
                bcc MH_JumpAnimDone
                iny
MH_JumpAnimDone:tya
MH_AnimDone2:   jmp MH_AnimDone

MH_UpdateFallCounter:
                lda actSY,x
                bmi MH_CheckGrab
MH_IncFall:     asl
                adc actFallL,x
                sta actFallL,x
                bcc MH_CheckGrab2
                inc actFall,x
                bcs MH_CheckGrab2
MH_CheckGrab:   cmp #-2*8                       ;Do not grab when moving up fast
                bcc MH_JumpAnim
MH_CheckGrab2:  txa                             ;Only player will grab ladders
                bne MH_JumpAnim
                lda actCtrl,x                   ;Do not grab if fire held
                and #JOY_UP|JOY_FIRE
                cmp #JOY_UP
                bne MH_JumpAnim
                jsr GetCharInfo4Above
                and #CI_CLIMB
                beq MH_JumpAnim
                jmp MH_InitClimb

MH_ForcedDuck:  lda temp1
                and #MB_LANDED                  ;Falling damage applied right after landing
                beq MH_NoFallDamage
                lda temp3                       ;Possibility to reduce damage by rolling
                and #AMF_ROLL
                beq MH_NoRollSave
                lda actSX,x                     ;Must be facing move direction and have some X-speed
                beq MH_NoRollSave
                eor actD,x
                bmi MH_NoRollSave
                lda temp2
                cmp #JOY_LEFT
                and #JOY_DOWN
                beq MH_NoRollSave
                bcc MH_NoRollSave
                lda #$00
                sta actFall,x                   ;Reset remaining forced ducking
                dey
                jsr ApplyFallDamage
                jmp MH_StartRoll
MH_NoRollSave:  jsr ApplyFallDamage
                txa
                bne MH_NoFallDamage
                jsr PlayFootstep
MH_NoFallDamage:dec actFall,x
                jmp MH_NoInitClimbDown

MH_OnGround:    ldy actFall,x                   ;Forced duck after falling?
                bne MH_ForcedDuck
                and #MB_HITWALL/2               ;Check AI reactions to hitting wall when on ground
                beq MH_NoAutoTurn
                lda actAIHelp,x
                bpl MH_NoAutoScale
                ldy #1
                lda actD,x
                bpl MH_CheckWallRight
                ldy #-1
MH_CheckWallRight:
                lda #-3
                jsr GetCharInfoXYOffset         ;Check that the wall is possible to scale
                and #CI_OBSTACLE|CI_NOPATH      ;Do not jump to nonnavigable ledge, which could
                bne MH_NoAutoScale              ;lead to a drop
                jmp MH_StartJump
MH_NoAutoScale: lda actAIHelp,x
                and #AIH_AUTOTURNWALL
                beq MH_NoAutoTurn
MH_DoAutoTurn:  lda actD,x
                eor #$80
                sta actD,x
MH_ResetMoveCtrl:
                jsr MH_StopXSpeed
                sta temp2
                sta actMoveCtrl,x
MH_NoAutoTurn:  lda actCtrl,x                   ;When holding fire can not initiate jump
                and #JOY_FIRE                   ;or operate
                bne MH_NoNewJump
                lda temp2
                cmp #JOY_UP+1
                and #JOY_UP
                beq MH_NoNewJump
                bcs MH_NoOperate
                txa                             ;If player, check for operating levelobjects
                bne MH_NoOperate
                ldy lvlObjNum
                bmi MH_NoOperate
                jsr OperateObject
                bcc MH_NoNewJump
                rts                             ;If operated successfully, do nothing else
MH_NoOperate:   lda temp3
                and #AMF_CLIMB
                beq MH_NoInitClimbUp
                jsr GetCharInfo4Above           ;Jump or climb?
                and #CI_CLIMB
                beq MH_NoInitClimbUp
                jmp MH_InitClimb
MH_NoInitClimbUp:
                lda temp2                      ;Jump requires left/right input (as in MW4)
                and #JOY_LEFT|JOY_RIGHT
                beq MH_NoNewJump
                lda temp3
                and #AMF_JUMP
                beq MH_NoNewJump
                lda actPrevCtrl,x
                and #JOY_UP
                bne MH_NoNewJump
MH_StartJump:   ldy #AL_JUMPSPEED
                lda (actLo),y
                sta actSY,x
                txa
                bne MH_JumpNoPlayer
                lda #DRAIN_JUMP
                jsr DrainBatteryMultiplier
                lda #SFX_JUMP
                jsr PlayMovementSound
MH_JumpNoPlayer:jsr MH_ResetGrounded
                lda #FR_JUMP
                jmp MH_AnimDone
MH_NoNewJump:   ldy actF1,x                     ;If in enter stance,
                cpy #FR_ENTER                   ;hold it as long as joy up/down held
                bne MH_NoEnterFrame             ;but not firebutton
                lda actCtrl,x
                cmp #JOY_FIRE
                bcs MH_StopEnter
                and #JOY_DOWN|JOY_UP
                bne MH_KeepEnterFrame
MH_StopEnter:   jmp MH_StandAnim
MH_KeepEnterFrame:
                tya
                jmp MH_AnimDone
MH_NoEnterFrame:lda temp2
                and #JOY_DOWN
                beq MH_NoDuck
MH_NewDuckOrRoll:
                lda temp3
                and #AMF_ROLL
                beq MH_NoNewRoll
                lda temp1                       ;Can't roll in water
                bmi MH_NoNewRoll
                lda temp2                       ;To initiate a roll, must push the
                cmp actPrevCtrl,x               ;joystick diagonally down
                beq MH_NoNewRoll
                and #JOY_LEFT|JOY_RIGHT
                beq MH_NoNewRoll
                lda actD,x                      ;If changed direction while ducking, no roll
MH_OldDir:      eor #$00
                bmi MH_NoNewRoll
MH_StartRoll:   lda #$00
                sta actFd,x
                txa
                bne MH_RollNoPlayer
                lda #DRAIN_ROLL
                jsr DrainBatteryMultiplier
                lda #SFX_ROLL
                jsr PlayMovementSound
MH_RollNoPlayer:lda #FR_ROLL
                jmp MH_AnimDone
MH_NoNewRoll:   lda temp3
                and #AMF_CLIMB
                beq MH_NoInitClimbDown
                lda actCtrl,x                   ;When holding fire can not initiate climbing
                and #JOY_FIRE
                bne MH_NoInitClimbDown
                lda actGroundCharInfo,x         ;Duck or climb?
                and #CI_CLIMB
                beq MH_NoInitClimbDown
                jmp MH_InitClimb
MH_NoInitClimbDown:
                lda temp3
                and #AMF_DUCK
                beq MH_NoDuck
                lda actF1,x
                cmp #FR_DUCK
                bcs MH_DuckAnim
MH_StartDuck:   lda #$00
                sta actFd,x
                lda #FR_DUCK
                bne MH_AnimDone
MH_DuckAnim:    lda #$01
                ldy #FR_DUCK+1
                jsr OneShotAnimation
                lda actF1,x
                bpl MH_AnimDone
MH_NoDuck:      lda actF1,x
                cmp #FR_DUCK
                bcc MH_StandOrWalk
MH_DuckStandUpAnim:
                lda #$01
                jsr AnimationDelay
                bcc MH_AnimDone3
                lda actF1,x
                sbc #$01
                cmp #FR_DUCK
                bcc MH_StandAnim
                bcs MH_AnimDone
MH_StandOrWalk: lda temp3                       ;Custom stand/walk animation?
                bmi MH_AnimDone3
                lda temp2
                and #JOY_LEFT|JOY_RIGHT
                beq MH_AnimDone                 ;0 = walk frame
                lda actSX,x
                beq MH_AnimDone
                asl
                bcc MH_WalkAnimSpeedPos
                eor #$ff
                adc #$00
MH_WalkAnimSpeedPos:
                adc #$40
                adc actFd,x
                sta actFd,x
                bcc MH_AnimDone3
                lda actF1,x
                adc #$00
                cmp #FR_WALK+8
                bcc MH_NoWalkAnimWrap
                lda #FR_WALK
MH_NoWalkAnimWrap:
                cpx #ACTI_PLAYER
                bne MH_AnimDone
                pha
                and #$03
                cmp #$02
                bne MH_NoWalkFootstep
                jsr PlayFootstep
                lda #DRAIN_WALK
                jsr DrainBatteryMultiplier ;Drain battery at each footstep
MH_NoWalkFootstep:
                pla
MH_AnimDone:    sta actF1,x
                sta actF2,x
MH_AnimDone3:   rts
MH_StandAnim:   lda #FR_STAND
                beq MH_AnimDone

MH_InitClimb:   lda #$80
                sta actXL,x
                sta actFd,x
                lda actYL,x
                and #$c0
                sta actYL,x
                jsr MH_StopXSpeed
                sta actSY,x
                jsr NoInterpolation
                lda #FR_CLIMB
                bne MH_AnimDone

MH_Climbing:    jsr GetCharInfo
                sta temp1
                sta actGroundCharInfo,x         ;Store char info for AI, like walking physics does
                and #CI_WATER                   ;Store updated state of water bit
                beq MH_ClimbNotInWater          ;for climbing out of water
                lda #MB_INWATER
MH_ClimbNotInWater:
                sta actMB,x
                ldy #AL_CLIMBSPEED
                lda (actLo),y
                sta temp7
                lda actF1,x                     ;Reset frame in case attack ended
                sta actF2,x
                lda temp2
                lsr
                bcc MH_NoClimbUp
                jmp MH_ClimbUp
MH_NoClimbUp:   lsr
                bcs MH_ClimbDown
                lda temp2                       ;Exit ladder?
                and #JOY_LEFT|JOY_RIGHT
                beq MH_ClimbDone
                lsr                             ;Left bit to direction
                lsr
                lsr
                ror
                sta actD,x
                lda temp1                       ;Check ground bit
                lsr
                bcs MH_ClimbExit
                lda actYL,x                     ;If half way a char, check also 1 char
                and #$20                        ;below
                beq MH_ClimbDone
                jsr GetCharInfo1Below
                lsr
                bcc MH_ClimbDone
MH_ClimbExitBelow:
                lda #8*8
                jsr MoveActorY
MH_ClimbExit:   lda actYL,x
                and #$c0
                sta actYL,x
                jsr MH_SetGrounded
                jsr NoInterpolation
                jmp MH_StandAnim

MH_ClimbDown:   lda temp1
                and #CI_CLIMB
                beq MH_ClimbDone
                ldy #4*8
                bne MH_ClimbCommon
MH_ClimbDone:   rts

MH_ClimbUp:     jsr GetCharInfo4Above
                sta temp8
                and #CI_OBSTACLE
                bne MH_ClimbUpNoJump
                lda temp2                       ;Check for exiting the ladder
                cmp actPrevCtrl,x               ;by jumping
                beq MH_ClimbUpNoJump
                and #JOY_LEFT|JOY_RIGHT
                beq MH_ClimbUpNoJump
                lda temp1                       ;If in the middle of an obstacle
                and #CI_OBSTACLE                ;block, can not exit by jump
                bne MH_ClimbUpNoJump
                lda #-2
                jsr GetCharInfoOffset
                and #CI_OBSTACLE
                bne MH_ClimbUpNoJump
                lda temp2
                cmp #JOY_RIGHT
                jsr MH_SetSignedHalfSpeed
                sta actD,x
                jmp MH_StartJump
MH_ClimbUpNoJump:
                lda actYL,x
                and #$20
                bne MH_ClimbUpOk
                lda temp8
                and #CI_CLIMB
                beq MH_ClimbDone
MH_ClimbUpOk:   ldy #-4*8
MH_ClimbCommon: lda temp7                       ;Climbing speed
                clc
                adc actFd,x
                sta actFd,x
                bcc MH_ClimbDone
                lda #$01                        ;Add 1 or 3 depending on climbing dir
                cpy #$80
                bcc MH_ClimbAnimDown
                lda #$02                        ;C=1, add one less
MH_ClimbAnimDown:
                adc actF1,x
                sbc #FR_CLIMB-1                 ;Keep within climb frame range
                and #$03
                adc #FR_CLIMB-1
                sta actF1,x
                sta actF2,x
                lsr
                php
                tya
                jsr MoveActorY
                plp
                txa
                bne MH_ClimbNotPlayer
                bcc MH_ClimbNoSound
                jsr PlayFootstep
                lda #DRAIN_CLIMB
                jsr DrainBatteryMultiplier
MH_ClimbNoSound:
MH_ClimbNotPlayer:
                jmp NoInterpolation

MH_Swimming:    ldy #AL_MOVESPEED
                lda (actLo),y
                lsr                             ;Swimming max speed = half of ground speed
                sta temp4
                iny
                lda (actLo),y
                sta temp5
                ldy temp2
                cpy #JOY_LEFT
                bcc MH_SwimHorizDone
MH_SwimHorizLeftOrRight:
                lda #$00
                cpy #JOY_RIGHT
                bcs MH_SwimRight
                lda #$80
MH_SwimRight:   sta actD,x
                asl                             ;Direction to carry
                ldy temp4
                lda temp5
                jsr AccActorXNegOrPos
MH_SwimHorizDone:
                lda temp2
                and #JOY_UP|JOY_DOWN
                beq MH_SwimVertDone
                lsr
                lda temp5
                ldy temp4
                jsr AccActorYNegOrPos
MH_SwimVertDone:lda actSY,x
                bne MH_NotStationary
                lda #-1                         ;If Y-speed stationary, rise up slowly
                sta actSY,x
MH_NotStationary:
                bpl MH_NotSwimmingUp            ;When going up, make sure there's water above
                lda #-1
                jsr GetCharInfoOffset
                tay
                and #CI_WATER
                bne MH_HasWaterAbove
                lda #$00
                sta actSY,x
                lda temp2                       ;If joystick held up, exit if ground above
                lsr
                bcc MH_NotExitingWater
                cmp #JOY_LEFT/2                 ;Check for exiting to left/right
                bcc MH_ExitWaterCheckAbove
                cmp #JOY_RIGHT/2
                lda #8*8
                ldy #3
                bcs MH_ExitWaterCheckRight
                lda #-8*8
                ldy #-3
MH_ExitWaterCheckRight:
                sta temp1
                lda #-1
                jsr GetCharInfoXYOffset
                lsr
                bcc MH_NotExitingWater
MH_GetOutOfWaterLoop:
                lda #-1                         ;Move actor until standing on ground
                jsr GetCharInfoOffset
                lsr
                bcs MH_ExitWaterCommon
                lda temp1
                jsr MoveActorX
                jmp MH_GetOutOfWaterLoop
MH_ExitWaterCheckAbove:
                tya
                lsr
                bcc MH_NotExitingWater
MH_ExitWaterCommon:
                lda #-8*8
                jsr MoveActorY
                lda actYL,x
                and #$c0
                sta actYL,x
                lda #SFX_JUMP
                jsr PlayMovementSound           ;Note: assumes that only the player will swim
                lda #MB_GROUNDED
                jsr MH_SetMoveBits              ;A=0 when returning, resets falling
                sta actSY,x
                jsr NoInterpolation
                lda #FR_DUCK+1
                jmp MH_AnimDone
MH_NotExitingWater:
MH_HasWaterAbove:
MH_NotSwimmingUp:
                lda #2
                sta temp4
                lda #0
                ldy #CI_WATER
                jsr MoveFlyer
                lda #$03
                jsr AnimationDelay
                lda actF1,x
                adc #$00
                cmp #FR_SWIM+4
                bcc MH_SwimAnimDone
                lda #DRAIN_SWIM
                jsr DrainBatteryMultiplier      ;Drain battery when the animation wraps
                lda #FR_SWIM                    ;Assumes only the player will swim
MH_SwimAnimDone:jmp MH_AnimDone

MH_SetGrounded: lda actMB,x
                ora #MB_GROUNDED
                bne MH_SetMoveBits
MH_ResetGrounded:
                lda #$00                        ;Reset anything left to groundcharinfo
                sta actGroundCharInfo,x         ;when jumping
                lda actMB,x
                and #$ff-MB_GROUNDED
MH_SetMoveBits: sta actMB,x
                sta temp1
MH_ResetFall:   lda #$00
                sta actFall,x
                sta actFallL,x
                rts

MH_StopXSpeed:  lda #$00
                sta actSX,x
                rts

MH_SetSignedHalfSpeed:
                ldy #AL_MOVESPEED
                lda (actLo),y
                php
                lsr
                plp
                bcs MH_SSHSDone
                eor #$ff
                adc #$01
MH_SSHSDone:    sta actSX,x
                rts

        ; Play footstep sound during player movement. No-op if music is on
        ;
        ; Parameters: -
        ; Returns: -
        ; Modifies: A,Y

PlayFootstep:   lda #SFX_FOOTSTEP
PlayMovementSound:
                ldy PS_CurrentSong+1
                beq PMS_DoPlay
CS_NoFreeActor:
PMS_NoSound:    rts

        ; Create a water splash
        ;
        ; Parameters: X source actor
        ; Returns: -
        ; Modifies: A,Y

CreateSplash:   lda #ACTI_FIRSTEFFECT
                bmi CS_NoFreeActor
                ldy #ACTI_LASTEFFECT
                jsr GetFreeActor
                bcc CS_NoFreeActor
                lda #ACT_WATERSPLASH
                jsr SpawnActor
                tya
                tax
                jsr FixSplashPosition
                ldx actIndex
                lda #SFX_SPLASH
PMS_DoPlay:     jmp PlaySfx

        ; Drain battery charge
        ;
        ; Parameters: A amount of drain
        ; Returns: -
        ; Modifies: A,Y (DrainBatteryMultiplier)

DrainBatteryMultiplier:
                ldy #$08
                jsr ModifyDamage
DrainBattery:   lsr                             ;Replaced by CLC if no battery upgrade
DrainBatteryRound:
                if GODMODE_CHEAT = 0
                adc #$00                        ;Round upward if reduced
                else
                lda #$00
                endif
                sta DB_Amount+1
                lda battery
                sec
DB_Amount:      sbc #$00
                bcs DB_Done
                dec battery+1
                bpl DB_Done
                lda #$00
                sta battery+1
DB_Done:        sta battery
DB_Skip:        rts

        ; Add (sub)quest completion score (5000 points)
        ;
        ; Parameters: -
        ; Returns: -
        ; Modifies: A,Y

AddQuestScore:  lda #<500
                ldy #>500

        ; Add score
        ;
        ; Parameters: A score lowbyte, Y score highbyte
        ; Returns: -
        ; Modifies: A

AddScore:       clc
                adc score
                sta score
                tya
                adc score+1
                sta score+1
                bcc AS_Done
                inc score+2
SetPanelRedrawScore:
AS_Done:        lda #REDRAW_SCORE
                jmp SetPanelRedraw

        ; Create player actor and (re)load level
        ;
        ; Parameters: -
        ; Returns: -
        ; Modifies: A,X,Y,temp vars

CreatePlayerActor:
                ldx #MAX_ACT-1                  ;Clear all actors when starting game
RCP_ClearActorLoop:
                jsr RemoveActor
                dex
                bpl RCP_ClearActorLoop
                jsr LoadLevel
                ldy #ACTI_PLAYER
                sty scriptVariable              ;Reset per-zone script variable
                sty UA_SpawnDelay+1             ;Reset enemy spawning delay counter
                jsr GFA_Found                   ;Reset player's actor variables
                ldx #6
                ldy #6*MAX_ACT
LoadPlayerActorVars:
                lda saveXL,x
                sta actXL+ACTI_PLAYER,y
                tya
                sbc #MAX_ACT                    ;C=1 here
                tay
                dex
                bpl LoadPlayerActorVars
                inx                             ;X=0
                stx actAIMode+ACTI_PLAYER       ;Make sure player doesn't attempt to run an AI routine
                jsr InitActor
                jsr SetNotPersistent
                lda #REDRAW_ITEM+REDRAW_AMMO+REDRAW_SCORE
                sta panelUpdateFlags

        ; Apply upgrade effects
        ;
        ; Parameters: -
        ; Returns: X=0
        ; Modifies: A,X,Y,temp6-temp8

ApplyUpgrades:  lda upgrade
                sta temp6
                ldx #2                          ;Base consumption 2*4 = 8
                and #$ff-UPG_RECHARGE
AU_CountMultiplier:                             ;Count upgrades (except recharge) for battery drain multiplier
                lsr
                bcc AU_NoMultiplier
                inx
AU_NoMultiplier:bne AU_CountMultiplier
                txa
                asl
                asl
                sta DrainBatteryMultiplier+1
                ldx #C_PLAYER_BOTTOM
                ldy #C_PLAYER_TOP
                lda temp6
                lsr                             ;Movement upgrade turns lower part armored
                bcc AU_NoBottomArmor
                inx
AU_NoBottomArmor:
                lsr                             ;Strength upgrade turns upper part armored
                bcc AU_NoTopArmor
                iny
AU_NoTopArmor:  stx adPlayerBottomSprFile
                sty adPlayerTopSprFile
                lda #INITIAL_MAX_WEAPONS
                sta AI_MaxWeaponsCount+1
                lsr temp6                       ;Check movement
                ldx #0
                ldy #INITIAL_CLIMBSPEED
                bcc AU_NoMovement
                inc AI_MaxWeaponsCount+1        ;Add one weapon slot
                ldx #2
                ldy #INITIAL_CLIMBSPEED+12
AU_NoMovement:  txa
                clc
                adc #INITIAL_GROUNDACC
                sta plrGroundAcc
                txa
                adc #INITIAL_INAIRACC
                sta plrInAirAcc
                txa
                asl
                eor #$ff
                adc #1-INITIAL_JUMPSPEED
                sta plrJumpSpeed
                sty plrClimbSpeed
                lsr temp6                       ;Check strength
                ldy #NO_MODIFY
                bcc AU_NoStrength
                inc AI_MaxWeaponsCount+1        ;Add one weapon slot
                ldy #UPGRADE_MELEE_MODIFY
AU_NoStrength:  sty AH_PlayerMeleeBonus+1
                ldx #itemDefaultPickup-itemDefaultMaxCount
AU_AmmoLoop:    lda itemDefaultMaxCount-1,x     ;Set carrying capacity for weapons/consumables
                cpy #NO_MODIFY
                beq AU_NoAmmoIncrease
                lsr
                clc
                adc itemDefaultMaxCount-1,x
AU_NoAmmoIncrease:
                sta itemMaxCount-1,x
                dex
                bne AU_AmmoLoop
                lsr temp6                       ;Check firearms
                ldx #NO_MODIFY
                ldy #NO_MODIFY
                bcc AU_NoFirearms
                ldx #UPGRADE_FIREARM_MODIFY
                ldy #UPGRADE_RELOADTIME_MODIFY
AU_NoFirearms:  stx AH_PlayerFirearmBonus+1
                sty AH_PlayerReloadTimeMod+1
                lsr temp6                       ;Check subdermal armor for player damage
                lda #NO_MODIFY                  ;modifier
                bcc AU_NoArmor
                lda #UPGRADE_DAMAGE_MODIFY
AU_NoArmor:     sta plrDmgModify
                lsr temp6                       ;Check healing speed
                lda #INITIAL_HEALTIMER-1        ;Healing code has C=1 while adding, so subtract 1 here
                bcc AU_NoHealing
                lda #INITIAL_HEALTIMER+2-1
AU_NoHealing:   sta ULO_HealingRate+1
                lsr temp6                       ;Check battery drain reduce
                lda #$18                        ;CLC
                bcc AU_NoDrainReduce
                lda #$4a                        ;LSR
AU_NoDrainReduce:
                sta DrainBattery
                rts
