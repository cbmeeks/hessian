        ; AI jumptable

aiJumpTblLo:    dc.b <AI_Player
                dc.b <AI_Idle
                dc.b <AI_TurnTo
                dc.b <AI_Follow
                dc.b <AI_Sniper
                dc.b <AI_Mover
                dc.b <AI_Guard
                dc.b <AI_Berzerk
                dc.b <AI_Flyer

aiJumpTblHi:    dc.b >AI_Player
                dc.b >AI_Idle
                dc.b >AI_TurnTo
                dc.b >AI_Follow
                dc.b >AI_Sniper
                dc.b >AI_Mover
                dc.b >AI_Guard
                dc.b >AI_Berzerk
                dc.b >AI_Flyer

flyerDirTbl:    dc.b JOY_LEFT|JOY_UP
                dc.b JOY_LEFT|JOY_DOWN
                dc.b JOY_RIGHT|JOY_UP
                dc.b JOY_RIGHT|JOY_DOWN

        ; Spawn list entry selection tables

spawnListAndTbl:dc.b $00                        ;0: entry 0

spawnListAddTbl:dc.b $00                        ;0: entry 0

        ; Spawn list entries

spawnTypeTbl:   dc.b ACT_FLYINGCRAFT            ;0

spawnPlotTbl:   dc.b NOPLOTBIT                  ;0

spawnWpnTbl:    dc.b ITEM_AUTORIFLE|SPAWN_AIR             ;0
