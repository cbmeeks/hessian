        ; Loader part

                include memory.s
                include kernal.s
                include ldepacksym.s

RETRIES         = 5             ;Retries when reading a sector

MW_LENGTH       = 32            ;Bytes in one M-W command

LOAD_KERNAL     = $00           ;Load using Kernal and do not allow interrupts
LOAD_FAKEFAST   = $01           ;Load using Kernal, interrupts allowed
LOAD_FAST       = $80           ;(or any other negative value) Load using custom serial protocol, Kernal not used at all after startup

tablBi          = depackBuffer
tablLo          = depackBuffer + 52
tablHi          = depackBuffer + 104

drvFileTrk      = $0300
drvFileSct      = $0380
drvBuf          = $0400         ;Sector data buffer
drvStart        = $0500
InitializeDrive = $d005         ;1541 only

                org loaderCodeStart

        ; Loading initialization related subroutines, also used by mainpart

WaitBottom:     lda $d011                       ;Wait until bottom of screen
                bmi WaitBottom
WB_Loop2:       lda $d011
                bpl WB_Loop2
                rts

SilenceSID:     ldx #$00                        ;Mute SID by setting frequencies to zero
                txa
                jsr SS_Sub
                inx
SS_Sub:         sta $d400,x
                sta $d407,x
                sta $d40e,x
                rts

        ; IRQ redirector when Kernal is on

RedirectIrq:    ldx $01
                lda #$35                        ;Note: this will necessarily have overhead,
                sta $01                         ;which means that the sensitive IRQs like
                lda #>RI_Return                 ;the panel-split should take extra advance
                pha
                lda #<RI_Return
                pha
                php
                jmp ($fffe)
RI_Return:      stx $01
                jmp $ea81

        ; NMI routine

NMI:            rti

        ; Loader runtime data

fileNumber:     dc.b $01                        ;Initial filenumber for the concatenated intro + main part
fastLoadMode:   dc.b LOAD_KERNAL

                org loaderCodeEnd

        ; Loader initialization
        ; Assumption: $01 has value $35, interrupts are off

InitLoader:     inc $01                         ;Kernal back on (the initial GetByte routine switches it off)
                lda #$02
                jsr Close                       ;Close the file loaded from
                lda #$0b
                sta $d011                       ;Blank screen
                ldx #ilFastLoadEnd-ilFastLoadStart
IL_CopyFastLoad:lda ilFastLoadStart-1,x         ;Copy fastload file routines
                sta OpenFile-1,x
                dex
                bne IL_CopyFastLoad
                stx $d07f                       ;Disable SCPU hardware regs
                stx $d07a                       ;SCPU to slow mode
                stx $d030                       ;C128 back to 1MHz mode
                stx messages                    ;Disable KERNAL messages
                stx fileOpen                    ;Clear fileopen indicator
                stx palFlag
IL_DetectNtsc1: lda $d012                       ;Detect PAL/NTSC
IL_DetectNtsc2: cmp $d012
                beq IL_DetectNtsc2
                bmi IL_DetectNtsc1
                cmp #$20
                bcc IL_IsNtsc
                lda #$2c                        ;Adjust 2-bit fastload transfer
                sta FL_Delay                    ;delay for PAL
                inc palFlag
IL_IsNtsc:      lda #$7f                        ;Disable & acknowledge IRQ sources
                sta $dc0d
                lda $dc0d
                inc $d019
                lda #<NMI                       ;Set NMI vector
                sta $0318
                sta $fffa
                sta $fffe
                lda #>NMI
                sta $0319
                sta $fffb
                sta $ffff
                lda #<RedirectIrq               ;Setup the IRQ redirector for Kernal on mode
                sta $0314
                lda #>RedirectIrq
                sta $0315
                lda #$81                        ;Run Timer A once to disable NMI from Restore keypress
                sta $dd0d                       ;Timer A interrupt source
                lda #$01                        ;Timer A count ($0001)
                sta $dd04
                stx $dd05
                lda #%00011001                  ;Run Timer A in one-shot mode
                sta $dd0e
IL_CheckSafeMode:
                lda $dc00                       ;Check for safe mode loader
                and #$10
                beq IL_SafeMode
                lda $dc01
                and #$10
                bne IL_DetectDrive
IL_SafeMode:    lda #$06
                sta $d020
                jmp IL_NoFastLoad

IL_DetectDrive: lda #$aa
                sta $a5
                lda #(ilDriveCodeEnd-ilDriveCode+MW_LENGTH-1)/MW_LENGTH
                ldx #<ilDriveCode
                ldy #>ilDriveCode
                jsr UploadDriveCode             ;Upload test-drivecode
                lda status                      ;If error $c0, it's probably IDE64
                cmp #$c0                        ;and we must not persist with more
                beq IL_NoSerial                 ;serial IO or we'll lock up
                ldx #$00
                ldy #$00
IL_Delay:       inx                             ;Delay to make sure the test-
                bne IL_Delay                    ;drivecode executed to the end
                iny
                bpl IL_Delay
                lda fa                          ;Set drive to listen
                jsr Listen
                lda #$6f
                jsr Second
                ldx #$05
IL_DDSendMR:    lda ilMRString,x                ;Send M-R command (backwards)
                jsr CIOut
                dex
                bpl IL_DDSendMR
                jsr UnLsn
                lda fa
                jsr Talk
                lda #$6f
                jsr Tksa
                lda #$00
                jsr ACPtr                       ;First byte: test value
                pha
                jsr ACPtr                       ;Second byte: drive type
                tax
                jsr UnTlk
                pla
                cmp #$aa                        ;Drive can execute code, so can
                beq IL_FastLoadOK               ;use fastloader
                lda $a5                         ;If serial bus delay counter is
                cmp #$aa                        ;unchanged, it's probably VICE's
                bne IL_NoFastLoad               ;virtual device trap
IL_NoSerial:    inc fastLoadMode                ;Serial bus not used: switch to
                                                ;"fake" IRQ-loading mode
IL_NoFastLoad:  ldx #ilSlowLoadEnd-ilSlowLoadStart
IL_CopySlowLoad:lda ilSlowLoadStart-1,x         ;Copy slowload file routines
                sta OpenFile-1,x
                dex
                bne IL_CopySlowLoad
                jmp IL_Done

IL_FastLoadOK:  sta fastLoadMode                ;Use non-Kernal IRQ loading
                txa
                bne IL_Not1541                  ;On 1541, patch out the flush ($a2) job call
                lda #$ea
                sta DrvFlushJsr-drvStart+driveCode
                sta DrvFlushJsr-drvStart+driveCode+1
                sta DrvFlushJsr-drvStart+driveCode+2
IL_Not1541:     lda ilDirTrkLo,x                ;Patch directory
                sta DrvDirTrk+1-drvStart+driveCode
                lda ilDirTrkHi,x
                sta DrvDirTrk+2-drvStart+driveCode
                lda ilDirSctLo,x
                sta DrvDirSct+1-drvStart+driveCode
                lda ilDirSctHi,x
                sta DrvDirSct+2-drvStart+driveCode
                lda ilExecLo,x                  ;Patch job exec address
                sta DrvExecJsr+1-drvStart+driveCode
                lda ilExecHi,x
                sta DrvExecJsr+2-drvStart+driveCode
                lda ilJobTrkLo,x                ;Patch job track/sector
                sta DrvReadTrk+1-drvStart+driveCode
                adc #$00                        ;C=1 here, so adds 1
                sta DrvReadSct+1-drvStart+driveCode
                lda ilJobTrkHi,x
                sta DrvReadTrk+2-drvStart+driveCode
                adc #$00
                sta DrvReadSct+2-drvStart+driveCode
                lda ilExitJump,x                ;Patch exit jump
                sta DrvExitJump-drvStart+driveCode
                lda ilLedBit,x
                sta DrvLed+1-drvStart+driveCode
                lda ilLedAdrHi,x
                sta DrvLedAcc0+2-drvStart+driveCode
                sta DrvLedAcc1+2-drvStart+driveCode
                lda il1800Lo,x
                sta IL_Patch1800Lo+1
                lda il1800Hi,x
                sta IL_Patch1800Hi+1
                ldy #10
IL_PatchLoop:   ldx il1800Ofs,y
IL_Patch1800Lo: lda #$00                        ;Patch all $1800 accesses
                sta DrvMain+1-drvStart+driveCode,x
IL_Patch1800Hi: lda #$00
                sta DrvMain+2-drvStart+driveCode,x
                dey
                bpl IL_PatchLoop
                cmp #$18
                bne IL_StartFastLoad            ;Copy the 1 Mhz routine for 1541
                ldy #il1MHzEnd-il1MHzStart-1
IL_1MHzCopy:    lda il1MHzStart,y
                sta Drv1MHzSend-drvStart+driveCode,y
                dey
                bpl IL_1MHzCopy
IL_StartFastLoad:
                lda #(drvEnd-drvStart+MW_LENGTH-1)/MW_LENGTH
                ldx #<driveCode
                ldy #>driveCode
                jsr UploadDriveCode             ;Then start fastloader
IL_Done:        lda #$35                        ;Loader needs Kernal off to use the buffers
                sta $01                         ;under ROM
                lda #<introStart                ;Load the intro
                ldx #>introStart
                jsr LoadFile
                jmp introCodeStart

UploadDriveCode:sta loadTempReg                 ;Number of "packets" to send
                stx zpSrcLo
                sty zpSrcHi
                ldy #$00                        ;Init selfmodifying addresses
                sty iflMWString+2
                lda #>drvStart
                sta iflMWString+1
                bne UDC_NextPacket
UDC_SendMW:     lda iflMWString,x               ;Send M-W command (backwards)
                jsr CIOut
                dex
                bpl UDC_SendMW
                ldx #MW_LENGTH
UDC_SendData:   lda (zpSrcLo),y                 ;Send one byte of drive code
                jsr CIOut
                iny
                bne UDC_NotOver
                inc zpSrcHi
UDC_NotOver:    inc iflMWString+2               ;Also, move the M-W pointer forward
                bne UDC_NotOver2
                inc iflMWString+1
UDC_NotOver2:   dex
                bne UDC_SendData
                jsr UnLsn                       ;Unlisten to perform the command
UDC_NextPacket: lda fa                          ;Set drive to listen
                jsr Listen
                lda status                      ;Quit if error (IDE64)
                cmp #$c0
                beq UDC_Quit
                lda #$6f
                jsr Second
                ldx #$05
                dec loadTempReg                 ;All "packets" sent?
                bpl UDC_SendMW
UDC_SendME:     lda iflMEString-1,x             ;Send M-E command (backwards)
                jsr CIOut
                dex
                bne UDC_SendME
                jsr UnLsn
UDC_Quit:       rts

        ; Fast fileopen / getbyte / save routines

ilFastLoadStart:

                rorg OpenFile

        ; Open file
        ;
        ; Parameters: fileNumber
        ; Returns: -
        ; Modifies: A,X,Y

                jmp FastOpen

        ; Save file
        ;
        ; Parameters: A,X startaddress, zpBitsLo amount of bytes, fileNumber
        ; Returns: -
        ; Modifies: A,X,Y

                jmp FastSave

        ; Read a byte from an opened file
        ;
        ; Parameters: -
        ; Returns: if C=0, byte in A. If C=1, EOF/errorcode in A:
        ; $00 - EOF (no error)
        ; $01 - Read error
        ; $02 - File not found
        ; $80 - Device not present
        ; Modifies: A,X

GetByte:        ldx fileOpen
                beq GB_Closed
                lda loadBuffer,x
GB_FastCmp:     cpx #$00
                bcs GB_FastRefill
                inc fileOpen
FO_Done:        rts
GB_FastRefill:  pha
                jsr FL_FillBuffer
                pla
                clc
                rts
GB_Closed:      lda loadBuffer+2
                sec
                rts

FastOpen:       ldx fileOpen                    ;A file already open? If so, do nothing
                bne FO_Done                     ;(allows chaining of files)
                inc fileOpen                    ;Set initial fileopen value to make sure IRQs don't enable turbo after this point
                stx $d07a                       ;SCPU to slow mode
                stx $d030                       ;C128 to 1Mhz mode
                txa                             ;Command 0 = load
                jsr FL_SendCommand
FL_FillBuffer:  ldx #$00
FL_FillBufferWait:
                bit $dd00                       ;Wait for 1541 to signal data ready by
                bmi FL_FillBufferWait           ;setting DATA low
FL_FillBufferLoop:
FL_SpriteWait:  lda $d012                       ;Check for sprite Y-coordinate range
FL_MaxSprY:     cmp #$00                        ;(max & min values are filled in the
                bcs FL_NoSprites                ;raster interrupt)
FL_MinSprY:     cmp #$00
                bcs FL_SpriteWait
FL_NoSprites:   sei
FL_WaitBadLine: lda $d011
                clc
                sbc $d012
                and #$07
                beq FL_WaitBadLine
                lda $dd00
                ora #$10
                sta $dd00                       ;Set CLK low
FL_Delay:       bit $00                         ;Delay for synchronized transfer
                nop
                and #$03
                sta FL_Eor+1
                sta $dd00                       ;Set CLK high
                lda $dd00
                lsr
                lsr
                eor $dd00
                lsr
                lsr
                eor $dd00
                lsr
                lsr
FL_Eor:         eor #$00
                eor $dd00
                cli
                sta loadBuffer,x
                inx
                bne FL_FillBufferLoop
FL_Common:      dex                             ;X=$ff (end cmp for full buffer)
                lda loadBuffer
                bne FL_FullBuffer
                ldx loadBuffer+1                ;File ended if T&S both zeroes
                beq FL_LoadEnd
FL_FullBuffer:  stx GB_FastCmp+1
                ldx #$02
FL_LoadEnd:     stx fileOpen                    ;Set buffer read position / fileopen indicator
                rts

FL_SendCommand: jsr FL_SendByte
FL_FileNumber:  lda fileNumber
FL_SendByte:    sta loadTempReg
                ldx #$08                        ;Bit counter
FL_SendLoop:    lsr loadTempReg                 ;Send one bit
                lda #$10
                ora $dd00
                bcc FL_ZeroBit
                eor #$30
FL_ZeroBit:     sta $dd00
                lda #$c0                        ;Wait for CLK & DATA low (diskdrive answers)
FL_SendAck:     bit $dd00
                bne FL_SendAck
                lda #$ff-$30                    ;Set DATA and CLK high
                and $dd00
                sta $dd00
FL_SendWait:    bit $dd00                       ;Wait for both DATA & CLK to go high
                bpl FL_SendWait
                bvc FL_SendWait
                dex
                bne FL_SendLoop
                rts

FastSave:       sta zpSrcLo
                stx zpSrcHi
                lda #$01                        ;Command 1 = save
                jsr FL_SendCommand
                lda zpBitsLo
                jsr FL_SendByte
                lda zpBitsHi
                jsr FL_SendByte
                ldy #$00
                lda zpBitsLo
                beq FS_PreDecrement
FS_Loop:        lda (zpSrcLo),y
                jsr FL_SendByte
                iny
                bne FS_NotOver
                inc zpSrcHi
FS_NotOver:     dec zpBitsLo
                bne FS_Loop
FS_PreDecrement:dec zpBitsHi
                bpl FS_Loop
                rts

FastLoadEnd:

                rend

ilFastLoadEnd:

        ; Slow fileopen / getbyte / save routines

ilSlowLoadStart:

                rorg OpenFile

                jmp SlowOpen
                jmp SlowSave

SlowGetByte:    lda fileOpen
                beq SGB_Closed
                lda #$36
                sta $01
                jsr ChrIn
                pha
                lda status
                bne SGB_EOF
                dec $01
SGB_LastByte:   pla
                clc
SO_Done:        rts
SGB_EOF:        pha
                tya
                pha
                jsr CloseKernalFile
                pla
                tay
                pla
                and #$83
                sta SGB_Closed+1
                beq SGB_LastByte
                pla
SGB_Closed:     lda #$00
                sec
                rts

SlowOpen:       lda fileOpen
                bne SO_Done
                jsr PrepareKernalIO
                jsr SetFileName
                ldy #$00                        ;A is $02 here
                jsr SetLFSOpen
                jsr ChkIn
                jmp KernalOff                   ;Kernal off after opening

SlowSave:       sta zpSrcLo
                stx zpSrcHi
                jsr PrepareKernalIO
                lda #$05
                ldx #<scratch
                ldy #>scratch
                jsr SetNam
                lda #$0f
                tay
                jsr SetLFSOpen
                lda #$0f
                jsr Close
                jsr SetFileName
                ldy #$01                        ;Open for write
                jsr SetLFSOpen
                jsr ChkOut
                ldy #$00
                lda zpBitsLo
                beq SS_PreDecrement
SS_Loop:        lda (zpSrcLo),y
                jsr ChrOut
                iny
                bne SS_NotOver
                inc zpSrcHi
SS_NotOver:     dec zpBitsLo
                bne SS_Loop
SS_PreDecrement:dec zpBitsHi
                bpl SS_Loop

CloseKernalFile:lda #$02
                jsr Close
                dec fileOpen
KernalOff:      dec $01
                rts

PrepareKernalIO:inc fileOpen                    ;Set fileopen indicator, raster delays are to be expected
                lda fileNumber                  ;Convert filename
                pha
                and #$0f
                ldx #$01
                jsr CFN_Sub
                pla
                lsr
                lsr
                lsr
                lsr
                dex
                jsr CFN_Sub
                stx $d07a                       ;SCPU to slow mode
                stx $d030                       ;C128 back to 1MHz mode
                lda fastLoadMode                ;In fake-IRQload mode IRQs continue,
                bne KernalOnFast                ;so no setup necessary
                lda $d01a                       ;If raster IRQs not yet active, no
                lsr                             ;setup necessary (loading picture)
                bcc KernalOnFast
                jsr WaitBottom
                jsr SilenceSID
                sta $d01a                       ;Raster IRQs off
                sta $d015                       ;Sprites off
                sta $d011                       ;Blank screen
KernalOnFast:   lda #$36
                sta $01
                rts

SetFileName:    lda #$02
                ldx #<fileName
                ldy #>fileName
                jmp SetNam

SetLFSOpen:     ldx fa
                jsr SetLFS
                jsr Open
                ldx #$02
                rts

CFN_Sub:        ora #$30
                cmp #$3a
                bcc CFN_Number
                adc #$06
CFN_Number:     sta fileName,x
                rts

scratch:        dc.b "S0:"
fileName:       dc.b "  "

SlowLoadEnd:

                rend

ilSlowLoadEnd:

                if ilFastLoadEnd - ilFastLoadStart > $ff
                err
                endif

                if ilSlowLoadEnd - ilSlowLoadStart > $ff
                err
                endif

                if SlowLoadEnd > FastLoadEnd
                err
                endif

        ; 1MHz transfer drivecode

il1MHzStart:
                rorg Drv2MHzSend

Drv1MHzSend:    asl
                and #$0f
                sta $1800
                pla
                sta $1800
                asl
                and #$0f
                sta $1800
                ldx #$00
                iny
                bne DrvSendLoop
                nop
                stx $1800                       ;Finish send: DATA & CLK both high
                beq DrvSendDone

                rend
il1MHzEnd:

        ; Diskdrive code

driveCode:
                rorg drvStart

DrvMain:        ldx #$00
                txa
DrvResetCache:  sta drvFileTrk,x                ;Clear dir cache
                inx
                bpl DrvResetCache
DrvLoop:        cli
                jsr DrvGetByte                  ;Get command (load/save)
                beq DrvLoad
                jmp DrvSave
DrvLoad:        sei
                jsr DrvGetByte                  ;Get filenumber
                jsr DrvFindFile
                bcc DrvFound
DrvFileNotFound:ldx #$02                        ;Return code $02 = File not found
DrvEndMark:     stx drvBuf+2                    ;Send endmark, return code in X
                lda #$00
                sta drvBuf
                sta drvBuf+1
                beq DrvSendBlk

DrvFound:
DrvSectorLoop:  jsr DrvReadSector               ;Read the data sector
                bcs DrvEndMark                  ;Quit if cannot read
DrvSendBlk:     ldy #$00
                ldx #$02
DrvSendLoop:    lda drvBuf,y
                lsr
                lsr
                lsr
                lsr
DrvSerialAcc1:  stx $1800                       ;Set DATA=low for first byte, high for
                tax                             ;subsequent bytes
                lda drvSendTbl,x
                pha
                lda drvBuf,y
                and #$0f
                tax
                lda #$04
DrvSerialAcc2:  bit $1800                       ;Wait for CLK=low
                beq DrvSerialAcc2
                lda drvSendTbl,x
DrvSerialAcc3:  sta $1800

        ; 2MHz send timing code from ULoad3 by MagerValp

Drv2MHzSend:    jsr DrvDelay18
                nop
                asl
                and #$0f
Drv2MHzSerialAcc4:
                sta $1800
                cmp ($00,x)
                nop
                pla
Drv2MHzSerialAcc5:
                sta $1800
                cmp ($00,x)
                nop
                asl
                and #$0f
Drv2MHzSerialAcc6:
                sta $1800
                ldx #$00
                iny
                bne DrvSendLoop
                jsr DrvDelay12
Drv2MHzSerialAcc7:
                stx $1800                       ;Finish send: DATA & CLK both high

DrvSendDone:    lda drvBuf+1                    ;Follow the T/S chain
                ldx drvBuf
                bne DrvSectorLoop
                tay                             ;If 2 first bytes are both 0,
                bne DrvEndMark                  ;endmark has been sent and can
                jmp DrvLoop                     ;return to main loop

DrvGetSaveByte:
DrvSaveCountLo: lda #$00
                tay
DrvSaveCountHi: ora #$00
                beq DrvNoMoreBytes
                dec DrvSaveCountLo+1
                tya
                bne DrvGetByte
                dec DrvSaveCountHi+1
DrvGetByte:     ldy #$08                        ;Filenumber bit counter
DrvGetBitLoop:
DrvSerialAcc8:  lda $1800
                bpl DrvNoQuit                   ;Quit if ATN is low
                pla
                pla
DrvExitJump:    jmp InitializeDrive             ;1541 = exit through Initialize
                                                ;Others = exit through RTS
DrvNoQuit:      and #$05                        ;Wait for CLK or DATA going low
                beq DrvGetBitLoop
                lsr                             ;Read the data bit
                lda #$02                        ;Pull the other line low to acknowledge
                bcc DrvGetZero
                lda #$08
DrvGetZero:     ror drvReceiveBuf               ;Store the data bit
DrvSerialAcc9:  sta $1800
DrvGetWait:
DrvSerialAcc10: lda $1800                       ;Wait for either line going high
                and #$05
                cmp #$05
                beq DrvGetWait
                lda #$00
DrvSerialAcc11: sta $1800                       ;Set CLK & DATA high
                dey
                bne DrvGetBitLoop               ;Loop until all bits have been received
                lda drvReceiveBuf
DrvFindFileOK:  clc
                rts
DrvFindFileError:
DrvNoMoreBytes: sec
                rts

                if DrvSerialAcc11 - DrvMain > $ff
                    err
                endif

DrvFindFile:    sta DrvCheckForFile+1
                jsr DrvCheckForFile             ;Already cached?
                bne DrvFindFileOK
DrvDirTrk:      ldx $1000
DrvDirSct:      lda $1000                       ;Read disk directory
DrvDirLoop:     jsr DrvReadSector               ;Read sector
                bcs DrvFindFileError            ;If failed, abort caching
                ldy #$02
DrvNextFile:    lda drvBuf,y                    ;File type must be PRG
                and #$83
                cmp #$82
                bne DrvSkipFile
                lda drvBuf+5,y                  ;Must be two-letter filename
                cmp #$a0
                bne DrvSkipFile
                lda drvBuf+3,y                  ;Convert filename (assumed to be hexadecimal)
                jsr DrvDecodeLetter             ;into an index number for the cache
                asl
                asl
                asl
                asl
                sta DrvIndexOr+1
                lda drvBuf+4,y
                jsr DrvDecodeLetter
DrvIndexOr:     ora #$00
                tax
                lda drvBuf+1,y
                sta drvFileTrk,x
                lda drvBuf+2,y
                sta drvFileSct,x
DrvSkipFile:    tya
                clc
                adc #$20
                tay
                bcc DrvNextFile
                jsr DrvCheckForFile             ;Found on this directory track?
                bne DrvFindFileOK
                lda drvBuf+1                    ;Go to next directory block, until no
                ldx drvBuf                      ;more directory blocks
                beq DrvFindFileError
                bne DrvDirLoop

DrvDecodeLetter:sec
                sbc #$30
                cmp #$10
                bcc DrvDecodeLetterDone
                sbc #$07
DrvDecodeLetterDone:
                rts

DrvCheckForFile:ldy #$00
                lda drvFileSct,y
                ldx drvFileTrk,y
                rts

DrvSave:        jsr DrvGetByte                  ;Get filenumber
                pha
                jsr DrvGetByte                  ;Get amount of bytes to expect
                sta DrvSaveCountLo+1
                jsr DrvGetByte
                sta DrvSaveCountHi+1
                pla
                tay
                ldx drvFileTrk,y
                bne DrvSaveFound                ;If file not found, just receive the bytes
                beq DrvSaveFinish
DrvSaveFound:   lda drvFileSct,y
DrvSaveSectorLoop:
                jsr DrvReadSector               ;First read the sector for T/S chain
                bcs DrvSaveFinish               ;If reading fails, abort
                ldx #$02
DrvSaveByteLoop:jsr DrvGetSaveByte              ;Then get bytes from C64 and write
                bcs DrvSaveSector               ;If last byte, save the last sector
                sta drvBuf,x
                inx
                bne DrvSaveByteLoop
DrvSaveSector:  ldy #$90
                jsr DrvDoJob
                lda drvBuf+1                    ;Follow the T/S chain
                ldx drvBuf
                bne DrvSaveSectorLoop
DrvSaveFinish:  jsr DrvGetSaveByte              ;Make sure all bytes are received
                bcc DrvSaveFinish
DrvFlush:       ldy #$a2                        ;Flush buffers (1581 and CMD drives)
DrvFlushJsr:    jsr DrvDoJob
                jmp DrvLoop

DrvReadSector:
DrvReadTrk:     stx $1000
DrvReadSct:     sta $1000
                ldy #$80
DrvDoJob:       sty DrvRetry+1
                jsr DrvLed
                ldy #RETRIES                    ;Retry counter
DrvRetry:       lda #$80
                ldx #$01
DrvExecJsr:     jsr Drv1541Exec                 ;Exec buffer 1 job
                cmp #$02                        ;Error?
                bcc DrvSuccess
DrvSkipId:      dey                             ;Decrease retry counter
                bne DrvRetry
DrvFailure:     ldx #$01                        ;Return code $01 - Read error
DrvSuccess:     sei                             ;Make sure interrupts now disabled
DrvLed:         lda #$08
DrvLedAcc0:     eor $1c00
DrvLedAcc1:     sta $1c00
                rts

Drv1541Exec:    sta $01                         ;Set command for execution
                cli                             ;Allow interrupts to execute command
Drv1541ExecWait:
                lda $01                         ;Wait until command finishes
                bmi Drv1541ExecWait
                rts

DrvFdExec:      jsr $ff54                       ;FD2000 fix By Ninja
                lda $03
                rts

DrvDelay18:     cmp ($00,x)
DrvDelay12:     rts

drvSendTbl:     dc.b $0f,$07,$0d,$05
                dc.b $0b,$03,$09,$01
                dc.b $0e,$06,$0c,$04
                dc.b $0a,$02,$08,$00

drv1541DirSct  = drvSendTbl+7                   ;Byte $01
drv1581DirSct  = drvSendTbl+5                   ;Byte $03

drv1541DirTrk:  dc.b 18

drvCommand:     dc.b 0
drvReceiveBuf:  dc.b 0

drvEnd:
                if drvEnd > $0700
                    err
                endif

                rend

        ;Drive detection drivecode

ilDriveCode:
                rorg drvStart

                asl drvReturn                   ;Modify first returnvalue to prove
                                                ;we've executed something :)
                lda $fea0                       ;Recognize drive family
                ldx #3                          ;(from Dreamload)
DrvFLoop:       cmp drvFamily-1,x
                beq DrvFFound
                dex                             ;If unrecognized, assume 1541
                bne DrvFLoop
                beq DrvIdFound
DrvFFound:      lda drvIdLoclo-1,x
                sta DrvIdLda+1
                lda drvIdLochi-1,x
                sta DrvIdLda+2
DrvIdLda:       lda $fea4                       ;Recognize drive type
                ldx #3                          ;3 = CMD HD
DrvIdLoop:      cmp drvIdbyte-1,x               ;2 = CMD FD
                beq DrvIdFound                  ;1 = 1581
                dex                             ;0 = 1541
                bne DrvIdLoop
DrvIdFound:     stx drvReturn2
                rts

drvFamily:      dc.b $43,$0d,$ff
drvIdLoclo:     dc.b $a4,$c6,$e9
drvIdLochi:     dc.b $fe,$e5,$a6
drvIdbyte:      dc.b "8","F","H"

drvReturn:      dc.b $55
drvReturn2:     dc.b $00

                rend

ilDriveCodeEnd:

ilMRString:     dc.b 2,>drvReturn,<drvReturn,"R-M"

il1800Ofs:      dc.b DrvSerialAcc1-DrvMain
                dc.b DrvSerialAcc2-DrvMain
                dc.b DrvSerialAcc3-DrvMain
                dc.b Drv2MHzSerialAcc4-DrvMain
                dc.b Drv2MHzSerialAcc5-DrvMain
                dc.b Drv2MHzSerialAcc6-DrvMain
                dc.b Drv2MHzSerialAcc7-DrvMain
                dc.b DrvSerialAcc8-DrvMain
                dc.b DrvSerialAcc9-DrvMain
                dc.b DrvSerialAcc10-DrvMain
                dc.b DrvSerialAcc11-DrvMain

il1800Lo:       dc.b <$1800,<$4001,<$4001,<$8000
il1800Hi:       dc.b >$1800,>$4001,>$4001,>$8000

ilDirTrkLo:     dc.b <drv1541DirTrk,<$022b,<$54,<$2ba7
ilDirTrkHi:     dc.b >drv1541DirTrk,>$022b,>$54,>$2ba7
ilDirSctLo:     dc.b <drv1541DirSct,<drv1581DirSct,<$56,<$2ba9
ilDirSctHi:     dc.b >drv1541DirSct,>drv1581DirSct,>$56,>$2ba9

ilExecLo:       dc.b <Drv1541Exec,<$ff54,<DrvFdExec,<$ff4e
ilExecHi:       dc.b >Drv1541Exec,>$ff54,>DrvFdExec,>$ff4e

ilJobTrkLo:     dc.b <$0008,<$000d,<$000d,<$2802
ilJobTrkHi:     dc.b >$0008,>$000d,>$000d,>$2802

ilExitJump:     dc.b $4c,$60,$60,$60

ilLedBit:       dc.b $08,$40,$40,$00
ilLedAdrHi:     dc.b $1c,$40,$40,$05

iflMWString:    dc.b MW_LENGTH,>drvStart, <drvStart,"W-M"
iflMEString:    dc.b >DrvMain,<DrvMain, "E-M"

loaderInitEnd:
