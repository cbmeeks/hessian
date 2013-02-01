                include macros.s

        ; Constants that affect the memory map

MAX_SPR         = 24
MAX_ACT         = 26
MAX_COMPLEXACT  = 8
MAX_CACHESPRITES = 64
MAX_MAPROWS     = 128
MAX_BLK         = 192
MAX_LVLACT      = 128
MAX_LVLOBJ      = 96

        ; Zeropage variables

                VarBase $02

                Var loadTempReg                 ;Loader variables
                Var bufferStatus
                Var fileOpen

                Var zpLenLo                     ;Exomizer 2 depackroutine variables
                Var zpSrcLo
                Var zpSrcHi
                Var zpBitsLo
                Var zpBitsHi
                Var zpBitBuf
                Var zpDestLo
                Var zpDestHi

                Var temp1                       ;Temp variables
                Var temp2
                Var temp3
                Var temp4
                Var temp5
                Var temp6
                Var temp7
                Var temp8

                Var freeMemLo                   ;Memory allocator variables
                Var freeMemHi

                Var joystick                    ;Joystick/keyboard variables
                Var prevJoy
                Var keyPress
                Var keyType

                Var screen                      ;Scrolling/map/zone variables
                Var scrollX
                Var scrollY
                Var scrollSX
                Var scrollSY
                Var scrollCSX
                Var scrollCSY
                Var scrCounter
                Var scrAdd
                Var blockX
                Var blockY
                Var mapX
                Var mapY
                Var zoneNum
                Var zoneLo
                Var zoneHi
                Var limitL
                Var limitR
                Var limitU
                Var limitD
                Var mapSizeX

                Var firstSortSpr                ;Sprite multiplexing variables

                Var sprIndex                    ;Spritefile access variables
                Var sprFileNum
                Var sprFileLo
                Var sprFileHi
                Var frameLo
                Var frameHi

                Var textLo                      ;Panel text printing variables
                Var textHi
                Var textTime
                Var textDelay
                Var textLeftMargin
                Var textRightMargin
                Var panelUpdateFlags

                Var menuMode                    ;Menu system variables
                Var menuCounter
                Var menuMoveDelay

                Var actIndex                    ;Actor variables
                Var actLo
                Var actHi
                Var tgtActIndex
                Var addActorIndex
                Var lvlObjNum
                Var autoDeactObjNum
                Var autoDeactObjCounter

                Var wpnLo                       ;Weapon variables
                Var wpnHi
                Var magazineSize

                Var displayedItemName           ;Misc. game variables
                Var displayedHealth
                Var healthRecharge
                Var lastReceivedXP
                Var musicMode
                Var soundMode

                Var levelNum                    ;Player state
                Var itemIndex
                Var levelUp
                Var xpLo
                Var xpHi
                Var xpLevel
                Var xpLimitLo
                Var xpLimitHi

playerStateZPStart = levelNum
playerStateZPEnd = xpLimitHi+1

                VarRange sprOrder,MAX_SPR+1
                VarRange sprY,MAX_SPR+1

                CheckVarBase $90

                VarBase $c0
                VarRange sprXL,MAX_SPR
                VarRange sprXH,MAX_SPR

                Var ntscDelay                   ;Frame update/raster IRQ variables
                Var targetFrames
                Var newFrame
                Var irqSaveA
                Var irqSaveX
                Var irqSaveY
                Var irqSave01

                Var ntInitSong                  ;Playroutine
                Var ntTemp1
                Var ntTemp2
                Var ntTrackLo
                Var ntTrackHi
                Var ntFiltPos
                Var ntFiltTime
                Var ntFiltCutoff

                CheckVarBase $100

        ; Memory areas and non-zeropage variables

depackCodeStart = $0100

sprF            = $0100
sprC            = $0100+MAX_SPR
sprAct          = $0100+MAX_SPR*2
cacheSprAge     = $0100+MAX_SPR*3
cacheSprFile    = $0200
cacheSprFrame   = $02a7

mainCodeStart   = $0334

musicData       = $c000
fileAreaEnd     = musicData
screen1         = $c800
screen2         = $cc00
improveList     = screen1+1002
heroList        = screen2+1016-MAX_SPR*4-(MAX_COMPLEXACT+1)*2
villainList     = screen2+1016-MAX_SPR*4-(MAX_COMPLEXACT+1)
sprOrTbl        = screen2+1016-MAX_SPR*4
sprAndTbl       = screen2+1016-MAX_SPR*2
spriteCache     = $d000
colors          = $d800
textChars       = $e000
lvlActX         = $e300
lvlActY         = $e380
lvlActF         = $e400
lvlActT         = $e480
lvlActWpn       = $e500
lvlObjX         = $e580
lvlObjY         = $e5e0
lvlObjB         = $e640
lvlObjDL        = $e6a0
lvlObjDH        = $e700
lvlSpawnT       = $e760
lvlSpawnWpn     = $e770
lvlCodeStart    = $e780
lvlName         = $e7f0
chars           = $e800
charInfo        = $f000
charColors      = $f100
mapTblLo        = $f200
mapTblHi        = $f280
loadBuffer      = mapTblLo
blkTblLo        = $f300
blkTblHi        = $f3c0
depackBuffer    = blkTblLo + 1
scriptCodeStart = $f480
