# Weapon Kill Limit — CS:S (SourceMod)

Limits weapon usage by kill count. Tracks rounds in which a player got a kill with a restricted weapon — not total kills.

**Version:** 1.0  
**Author:** RitzAtemo  

---

## Requirements

- **SourceMod 1.10+**
- **Metamod:Source**
- **Extensions** (included with SourceMod):
  - `sdktools.ext`
  - `cstrike.ext`

---

## Installation

Copy the contents of this folder to the root of your CS:S server.

### 1. Plugin

Files are already in the correct locations:
```
addons/sourcemod/scripting/weapon_limit.sp
addons/sourcemod/plugins/weapon_limit.smx
addons/sourcemod/configs/weapon_limit.cfg
```
SourceMod loads all `.smx` files from the `plugins/` folder automatically.

### 2. Weapon config

Edit `addons/sourcemod/configs/weapon_limit.cfg` to set limits per weapon.

Restart the server or change map after copying.

---

## How it works

1. Each round: if a player gets a kill with a limited weapon — their round counter for that weapon increments by 1 (rounds with kills, not kill count)
2. When the limit is reached:
   - The weapon is **removed** from inventory via `RemovePlayerItem` + `AcceptEntityInput("Kill")`
   - Buying that weapon and its ammo is **blocked** via `AddCommandListener`
3. Counters reset on player disconnect

---

## Configuration

`addons/sourcemod/configs/weapon_limit.cfg`

```
"WeaponLimits"
{
    "awp"     { "limit" "1" }
    "deagle"  { "limit" "5" }
    "scout"   { "limit" "3" }
}
```

---

## Supported weapon names

| Category | Weapons |
|----------|---------|
| Rifles | awp, scout, g3sg1, sg550, ak47, m4a1, aug, sg552, famas, galil |
| SMG | mp5navy, p90, tmp, mac10, ump45 |
| Shotguns | m3, xm1014 |
| Pistols | deagle, usp, glock, p228, elite, fiveseven |
| Heavy | m249 |
