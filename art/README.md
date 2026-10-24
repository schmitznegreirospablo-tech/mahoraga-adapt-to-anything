# Art sources (Aseprite)

The sprites are drawn by Lua scripts run in Aseprite's batch mode, which also save the `.aseprite` files:

```powershell
& "C:\Program Files (x86)\Steam\steamapps\common\Aseprite\aseprite.exe" -b --script-param out=<folder> --script art\cao_divino\gerar_cao_divino.lua
```

- `mahoraga/`: Mahoraga (64x56 frames; layout in `tools/gen.ps1` `$bossAnims`). Export goes to `mod/mahoraga/files/gfx/mahoraga.png`.
- `cao_divino/`: the Divine Dogs (white and black 40x32, Totality 64x50, with their sprite XMLs), the perk icons,
  the earthquake crack and the electric punch burst. Copy the outputs to `mod/mahoraga/files/gfx/`.
