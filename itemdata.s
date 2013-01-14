ITEM_NONE       = 0
ITEM_FISTS      = 1
ITEM_KNIFE      = 2
ITEM_BAT        = 3
ITEM_PISTOL     = 4
ITEM_SHOTGUN    = 5
ITEM_AUTORIFLE  = 6
ITEM_SNIPERRIFLE = 7
ITEM_MINIGUN    = 8
ITEM_FLAMETHROWER = 9
ITEM_GRENADELAUNCHER = 10
ITEM_GRENADE    = 11
ITEM_MEDKIT     = 12

ITEM_FIRST_CONSUMABLE = ITEM_GRENADE
ITEM_FIRST_NONWEAPON = ITEM_MEDKIT

MAG_INFINITE = $ff

itemMaxCount:   dc.b 0                          ;Fists
                dc.b 0                          ;Knife
                dc.b 0                          ;Bat
                dc.b 0                          ;Pistol
                dc.b 0                          ;Shotgun
                dc.b 0                          ;Auto rifle
                dc.b 0                          ;Sniper rifle
                dc.b 0                          ;Minigun
                dc.b 0                          ;Flamethrower
                dc.b 0                          ;Grenade launcher
                dc.b 0                          ;Grenade
                dc.b 0                          ;Medikit

itemDefaultMaxCount:
                dc.b 1                          ;Fists
                dc.b 1                          ;Knife
                dc.b 1                          ;Bat
                dc.b 50                         ;Pistol
                dc.b 24                         ;Shotgun
                dc.b 90                         ;Auto rifle
                dc.b 15                         ;Sniper rifle
                dc.b 100                        ;Minigun
                dc.b 120                        ;Flamethrower
                dc.b 6                          ;Grenade launcher
                dc.b 5                          ;Grenade
                dc.b 2                          ;Medikit

itemMaxCountAdd:dc.b 0                          ;Fists
                dc.b 0                          ;Knife
                dc.b 0                          ;Bat
                dc.b 10                         ;Pistol
                dc.b 6                          ;Shotgun
                dc.b 30                         ;Auto rifle
                dc.b 5                          ;Sniper rifle
                dc.b 50                         ;Minigun
                dc.b 30                         ;Flamethrower
                dc.b 3                          ;Grenade launcher
                dc.b 2                          ;Grenade
                dc.b 1                          ;Medikit

itemDefaultPickup:
                dc.b 1                          ;Fists
                dc.b 1                          ;Knife
                dc.b 1                          ;Bat
                dc.b 6                          ;Pistol
                dc.b 4                          ;Shotgun
                dc.b 15                         ;Auto rifle
                dc.b 3                          ;Sniper rifle
                dc.b 50                         ;Minigun
                dc.b 30                         ;Flamethrower
                dc.b 2                          ;Grenade launcher
                dc.b 2                          ;Grenade
                dc.b 1                          ;Medikit

itemMagazineSize:
                dc.b MAG_INFINITE               ;Fists
                dc.b MAG_INFINITE               ;Knife
                dc.b MAG_INFINITE               ;Bat
                dc.b 10                         ;Pistol
                dc.b 6                          ;Shotgun
                dc.b 30                         ;Auto rifle
                dc.b 5                          ;Sniper rifle
                dc.b 0                          ;Minigun
                dc.b 60                         ;Flamethrower
                dc.b 3                          ;Grenade launcher
                dc.b 0                          ;Grenade
                dc.b 0                          ;Medikit

itemNPCMinDist: dc.b 0                          ;Fists
                dc.b 0                          ;Knife
                dc.b 0                          ;Bat
                dc.b 1                          ;Pistol
                dc.b 1                          ;Shotgun
                dc.b 1                          ;Auto rifle
                dc.b 1                          ;Sniper rifle
                dc.b 1                          ;Minigun
                dc.b 1                          ;Flamethrower
                dc.b 2                          ;Grenade launcher
                dc.b 2                          ;Grenade

itemNPCMaxDist: dc.b 1                          ;Fists
                dc.b 1                          ;Knife
                dc.b 1                          ;Bat
                dc.b 6                          ;Pistol
                dc.b 5                          ;Shotgun
                dc.b 6                          ;Auto rifle
                dc.b 7                          ;Sniper rifle
                dc.b 6                          ;Minigun
                dc.b 5                          ;Flamethrower
                dc.b 5                          ;Grenade launcher
                dc.b 6                          ;Grenade


itemNPCAttackLength:                            ;Note: stored as negative
                dc.b -6/2                       ;Fists
                dc.b -6/2                       ;Knife
                dc.b -6/2                       ;Bat
                dc.b -6/2                       ;Pistol
                dc.b -6/2                       ;Shotgun
                dc.b -10/2                      ;Auto rifle
                dc.b -6/2                       ;Sniper rifle
                dc.b -10/2                      ;Minigun
                dc.b -10/2                      ;Flamethrower
                dc.b -6/2                       ;Grenade launcher
                dc.b -6/2                       ;Grenade

itemNPCAttackThreshold:
                dc.b $08                        ;Fists
                dc.b $0c                        ;Knife
                dc.b $0e                        ;Bat
                dc.b $20                        ;Pistol
                dc.b $30                        ;Shotgun
                dc.b $20                        ;Auto rifle
                dc.b $38                        ;Sniper rifle
                dc.b $30                        ;Minigun
                dc.b $30                        ;Flamethrower
                dc.b $40                        ;Grenade launcher
                dc.b $40                        ;Grenade

