# Mahoraga: Adapt to Anything (Noita mod)

A Mahoraga-inspired boss waits in a temple arena at the far east edge of every Noita world. He adapts to every kind of harm (even drowning). Each adaptation heals him to full and makes him tougher and stronger, and some of them teach him new techniques: Giant Slash, Giant Napalm, Giant Nuke, Electrocute Giant Punch and Holy Shower. Beat him for the exclusive perk **Adapt to Anything**.

- Steam Workshop: https://steamcommunity.com/sharedfiles/filedetails/?id=3820434703
- Current version: 1.1.0

## Layout
| Folder | What it is |
|---|---|
| `mod/mahoraga/` | The mod itself. Copy it to `Noita/mods/mahoraga` and enable it in the Mods menu. |
| `sheets/` | Data for the boss, attacks, projectiles, adaptations, perk and world. |
| `tools/gen.ps1` | Generates `mod/mahoraga/files/generated/*`, the projectile/boss XMLs, perk list and translations from `sheets/`. |
| `tools/*.cs` | Small helpers: `luacheck` (Lua syntax check with the game's lua51.dll), `wakunpack` (unpack `data/data.wak`), `makeart` (sprites), `wincap` (window capture). |
| `workshop/` | Steam Workshop metadata (`workshop.xml`, item id, preview image). |

## Building
```powershell
powershell -ExecutionPolicy Bypass -File tools\gen.ps1
```
Build a helper (32-bit, needed for lua51.dll):
```powershell
C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe /platform:x86 /out:tools\luacheck.exe tools\luacheck.cs
tools\luacheck.exe "<Noita folder>" mod\mahoraga
```
Unpack the game's data for reference (not part of this repository):
```powershell
tools\wakunpack.exe "<Noita folder>\data\data.wak" vanilla
```

## Credits
Fan-made boss inspired by Mahoraga from *Jujutsu Kaisen* by Gege Akutami; not affiliated with the series or with Nolla Games. All sprites were drawn for this mod. Sounds and effects come from the player's own copy of Noita. Code under the MIT license (`mod/mahoraga/LICENSE.txt`).
