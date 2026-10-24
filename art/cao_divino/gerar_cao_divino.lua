-- Divine Dogs spritesheets (procedural rig, same approach as gerar_mahoraga.lua). Facing right; Noita mirrors it.
-- Run: aseprite -b --script-param out=<folder> --script gerar_cao_divino.lua
-- Makes: cao_branco.png, cao_preto.png (40x32 frames), cao_totalidade.png (64x50 frames), one .aseprite each,
-- their Noita sprite XMLs, plus the perk icons (16x16) and two effects: crack.png and electric_burst.png.
local pc = app.pixelColor
local function C(h) return pc.rgba(tonumber(h:sub(2,3),16), tonumber(h:sub(4,5),16), tonumber(h:sub(6,7),16), 255) end
local CA = function(h, a) return pc.rgba(tonumber(h:sub(2,3),16), tonumber(h:sub(4,5),16), tonumber(h:sub(6,7),16), a) end
local COLS = 8

local W, H, OX, GY, SC   -- current frame size, feet centre x, ground row, scale
local buf
local function idx(x, y) return y * W + x end
local function inb(x, y) return x >= 0 and y >= 0 and x < W and y < H end
local function has(m, x, y) return inb(x, y) and m[idx(x, y)] end

local function segdist(px, py, ax, ay, bx, by)
  local dx, dy = bx - ax, by - ay
  local l2 = dx * dx + dy * dy
  local t = 0
  if l2 > 0 then t = math.max(0, math.min(1, ((px - ax) * dx + (py - ay) * dy) / l2)) end
  local qx, qy = ax + t * dx - px, ay + t * dy - py
  return math.sqrt(qx * qx + qy * qy)
end
-- rig coordinates are in "dog units" (x from feet centre, y up negative), scaled by SC
local function capsule(m, ax, ay, bx, by, r)
  ax, ay, bx, by, r = ax * SC + OX, ay * SC + GY, bx * SC + OX, by * SC + GY, r * SC
  for y = math.floor(math.min(ay, by) - r) - 1, math.ceil(math.max(ay, by) + r) + 1 do
    for x = math.floor(math.min(ax, bx) - r) - 1, math.ceil(math.max(ax, bx) + r) + 1 do
      if inb(x, y) and segdist(x, y, ax, ay, bx, by) <= r then m[idx(x, y)] = true end
    end
  end
  return m
end
local function poly(m, pts)
  local q, x0, y0, x1, y1 = {}, 1e9, 1e9, -1e9, -1e9
  for i, p in ipairs(pts) do
    q[i] = { p[1] * SC + OX, p[2] * SC + GY }
    x0, y0 = math.min(x0, q[i][1]), math.min(y0, q[i][2])
    x1, y1 = math.max(x1, q[i][1]), math.max(y1, q[i][2])
  end
  for y = math.floor(y0) - 1, math.ceil(y1) + 1 do
    for x = math.floor(x0) - 1, math.ceil(x1) + 1 do
      if inb(x, y) then
        local inside, near, j = false, false, #q
        for i = 1, #q do
          local a, b = q[i], q[j]
          if ((a[2] > y) ~= (b[2] > y)) and (x < (b[1] - a[1]) * (y - a[2]) / (b[2] - a[2]) + a[1]) then inside = not inside end
          if segdist(x, y, a[1], a[2], b[1], b[2]) <= 0.5 then near = true end
          j = i
        end
        if inside or near then m[idx(x, y)] = true end
      end
    end
  end
  return m
end
local function paint(m, fill, shade, outline)
  for i in pairs(m) do
    local x, y = i % W, i // W
    for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
      local nx, ny = x + d[1], y + d[2]
      if inb(nx, ny) and not m[idx(nx, ny)] then buf[idx(nx, ny)] = outline end
    end
  end
  for i in pairs(m) do
    local x, y = i % W, i // W
    buf[i] = (shade and shade(x, y, m)) or fill
  end
end
local function shadeBottom(c) return function(x, y, m) if not has(m, x, y + 1) then return c end end end
local function dot(ux, uy, c) local x, y = math.floor(ux * SC + OX + 0.5), math.floor(uy * SC + GY + 0.5); if inb(x, y) then buf[idx(x, y)] = c end end
local function rad(a) return a * math.pi / 180 end

-- palettes
local PAL = {
  white = { O = C"#1c1820", F = C"#ece8df", S = C"#bab3aa", D = C"#8a837c", M = C"#2e2a30", E = C"#1c1820", N = C"#2e2a30", T = C"#d9675f" },
  black = { O = C"#0b0a0d", F = C"#36313b", S = C"#242128", D = C"#18161b", M = C"#ece8df", E = C"#f2efe6", N = C"#0b0a0d", T = C"#d9675f" },
  total = { O = C"#0b0a0d", F = C"#2f2b33", S = C"#1f1c22", D = C"#141216", M = C"#ece8df", E = C"#9fe6ff", N = C"#0b0a0d", T = C"#d9675f", mane = C"#ece8df", maneS = C"#bab3aa" },
}

-- one pose: by (body bob), lean (body tilt), legs {fl, bl} as {foot x, foot y} offsets, head {dx, dy}, jaw (open px), tail angle, eye shut
local function drawPose(p, pal, mane)
  buf = {}
  local by, lean = p.by or 0, p.lean or 0
  local hip, sh = { -6, -10 + by + lean }, { 6, -11 + by - lean }
  local head = { 11 + (p.hx or 0), -16 + by - lean + (p.hy or 0) }
  -- far legs first (shaded), then tail, body, near legs, head
  local function leg(top, foot, near)
    local m = {}
    local back = top[1] < 0
    local knee = { (top[1] + foot[1]) / 2 + (back and -1.6 or 0.8), (top[2] + foot[2]) / 2 + 0.5 }
    capsule(m, top[1], top[2], knee[1], knee[2], back and 1.9 or 1.4)
    capsule(m, knee[1], knee[2], foot[1], foot[2] - 0.6, 0.95)
    capsule(m, foot[1] - 0.3, foot[2] - 0.5, foot[1] + 1.3, foot[2] - 0.5, 0.8)
    paint(m, near and pal.F or pal.S, shadeBottom(near and pal.S or pal.D), pal.O)
  end
  local L = p.legs or { { 6, 0 }, { -6, 0 }, { 4, 0 }, { -8, 0 } }  -- front-near, back-near, front-far, back-far
  leg({ sh[1] - 1, sh[2] + 2 }, L[3], false)
  leg({ hip[1] - 1, hip[2] + 2 }, L[4], false)
  -- tail (curled up like a husky)
  local ta = rad(p.tail or -120)
  local tm = {}
  local t0 = { hip[1] - 3, hip[2] - 1 }
  local t1 = { t0[1] + 4 * math.cos(ta), t0[2] + 4 * math.sin(ta) }
  local t2 = { t1[1] + 3 * math.cos(ta + 0.9), t1[2] + 3 * math.sin(ta + 0.9) }
  capsule(tm, t0[1], t0[2], t1[1], t1[2], 1.4)
  capsule(tm, t1[1], t1[2], t2[1], t2[2], 1.9)
  paint(tm, pal.F, shadeBottom(pal.S), pal.O)
  -- body + neck
  local bm = {}
  capsule(bm, hip[1], hip[2] - 0.5, sh[1], sh[2] - 0.5, 3.3)
  capsule(bm, sh[1] - 1, sh[2] + 0.5, sh[1] + 1, sh[2] + 0.5, 4.0)
  capsule(bm, sh[1], sh[2] - 1, head[1] - 2, head[2] + 1, 2.6)
  paint(bm, pal.F, shadeBottom(pal.S), pal.O)
  if mane then  -- Totality: white mane over neck and shoulders
    local mm = {}
    capsule(mm, sh[1] - 2, sh[2] - 1, head[1] - 2, head[2] + 1, 3.6)
    poly(mm, { { sh[1] - 6, sh[2] - 3 }, { sh[1] - 3, sh[2] - 7 }, { sh[1], sh[2] - 4 }, { sh[1] + 2, sh[2] - 8 }, { head[1] - 2, head[2] - 2 }, { sh[1] + 2, sh[2] + 3 } })
    paint(mm, pal.mane, shadeBottom(pal.maneS), pal.O)
  end
  leg({ sh[1], sh[2] + 2 }, L[1], true)
  leg({ hip[1], hip[2] + 2 }, L[2], true)
  -- head: skull, snout, jaw, ears
  local hm = {}
  capsule(hm, head[1] - 1, head[2], head[1] + 1, head[2] - 0.5, 2.8)
  poly(hm, { { head[1] + 1, head[2] - 2 }, { head[1] + 7.5, head[2] - 0.3 }, { head[1] + 7.5, head[2] + 1 }, { head[1] + 1, head[2] + 1.5 } })
  local jaw = p.jaw or 0
  poly(hm, { { head[1], head[2] + 1 }, { head[1] + 5, head[2] + 1.5 + jaw }, { head[1] + 4, head[2] + 2.5 + jaw }, { head[1], head[2] + 2.5 } })
  local em = {}
  poly(em, { { head[1] - 3.5, head[2] - 1.5 }, { head[1] - 3, head[2] - 8.5 }, { head[1] - 0.8, head[2] - 2.5 } })
  paint(em, pal.S, nil, pal.O)
  local em2 = {}
  poly(em2, { { head[1] - 1.5, head[2] - 2 }, { head[1] - 0.5, head[2] - 9 }, { head[1] + 1.8, head[2] - 2.5 } })
  paint(em2, pal.F, nil, pal.O)
  paint(hm, pal.F, shadeBottom(pal.S), pal.O)
  -- markings: the shikigami stripe over the eye and the nose
  for k = -1, 3 do dot(head[1] + k, head[2] - 2.2 + k * 0.15, pal.M) end
  dot(head[1] - 1, head[2] + 0.5, pal.M); dot(head[1] - 2, head[2] + 1.5, pal.M)
  if p.shut then dot(head[1] + 1.5, head[2] - 0.8, pal.O) else dot(head[1] + 1.5, head[2] - 0.8, pal.E) end
  dot(head[1] + 7.5, head[2] - 0.2, pal.N); dot(head[1] + 7, head[2] - 0.2, pal.N)
  if jaw > 1 then dot(head[1] + 3, head[2] + 1.5 + jaw * 0.5, pal.T); dot(head[1] + 4.5, head[2] + 1 + jaw * 0.6, C"#ffffff") end
  return buf
end

local run = {
  { by = 0, legs = { { 9, 0 }, { -3, 0 }, { 2, -1 }, { -10, -1 } }, tail = -140 },
  { by = -1, legs = { { 6, -2 }, { -6, 0 }, { 5, 0 }, { -8, -2 } }, tail = -130 },
  { by = -2, legs = { { 2, -2 }, { -9, -2 }, { 8, 0 }, { -4, 0 } }, tail = -120 },
  { by = 0, legs = { { 3, 0 }, { -10, -1 }, { 9, 0 }, { -3, 0 } }, tail = -140 },
  { by = -1, legs = { { 5, 0 }, { -8, -2 }, { 6, -2 }, { -6, 0 } }, tail = -130 },
  { by = -2, legs = { { 8, 0 }, { -4, 0 }, { 2, -2 }, { -9, -2 } }, tail = -120 },
}
local anims = {
  { "stand", 0.25, 1, { { tail = -120 }, { tail = -110 }, { by = -0.5, tail = -100 }, { by = -0.5, tail = -110 } } },
  { "walk", 0.1, 1, run },
  { "run", 0.07, 1, run },
  { "attack", 0.06, 0, {
    { hx = -1, hy = 1, lean = 1, tail = -150 },
    { hx = 2, hy = 0, jaw = 2, legs = { { 9, 0 }, { -6, 0 }, { 7, 0 }, { -8, 0 } }, tail = -120 },
    { hx = 4, hy = 1, jaw = 3, lean = -1, legs = { { 11, 0 }, { -5, 0 }, { 9, 0 }, { -7, 0 } }, tail = -110 },
    { hx = 3, hy = 1, jaw = 0, legs = { { 9, 0 }, { -6, 0 }, { 7, 0 }, { -8, 0 } }, tail = -120 } } },
  { "jump_up", 0.12, 1, { { by = -2, lean = 2, legs = { { 10, -4 }, { -9, -1 }, { 8, -5 }, { -11, -1 } }, tail = -160 }, { by = -2, lean = 2, legs = { { 11, -5 }, { -10, -2 }, { 9, -5 }, { -12, -1 } }, tail = -165 } } },
  { "jump_fall", 0.12, 1, { { by = -1, lean = -1, legs = { { 9, 0 }, { -7, -3 }, { 7, -1 }, { -9, -3 } }, tail = -100 }, { by = -1, lean = -1, legs = { { 9, 1 }, { -7, -2 }, { 7, 0 }, { -9, -2 } }, tail = -95 } } },
  { "hurt", 0.1, 0, { { hx = -2, hy = 1, by = 1, shut = true, tail = -200 }, { hx = -1, hy = 0, shut = true, tail = -190 } } },
}

local function build(name, pal, fw, fh, ox, gy, sc, mane, out)
  W, H, OX, GY, SC = fw, fh, ox, gy, sc
  local total = 0
  for _, a in ipairs(anims) do total = total + #a[4] end
  local spr = Sprite(W, H, ColorMode.RGB)
  spr.layers[1].name = name
  for i = 2, total do spr:newEmptyFrame() end
  local sheet = Image(W * COLS, H * #anims, ColorMode.RGB)
  local xml = { string.format('<Sprite filename="mods/mahoraga/files/gfx/%s.png" offset_x="%d" offset_y="%d" default_animation="stand">', name, OX, GY + 1) }
  local fi, rowOf = 1, {}
  for row, a in ipairs(anims) do
    local first = fi
    for col, p in ipairs(a[4]) do
      local b = drawPose(p, pal, mane)
      local img = Image(W, H, ColorMode.RGB)
      for i, c in pairs(b) do img:drawPixel(i % W, i // W, c) end
      spr:newCel(spr.layers[1], fi, img, Point(0, 0))
      spr.frames[fi].duration = a[2]
      sheet:drawImage(img, Point((col - 1) * W, (row - 1) * H))
      fi = fi + 1
    end
    local tag = spr:newTag(first, fi - 1); tag.name = a[1]
    rowOf[a[1]] = { row - 1, #a[4], a[2] }
    xml[#xml + 1] = string.format('\t<RectAnimation name="%s" pos_x="0" pos_y="%d" frame_count="%d" frame_width="%d" frame_height="%d" frame_wait="%s" frames_per_row="%d" loop="%d" />',
      a[1], (row - 1) * H, #a[4], W, H, tostring(a[2]), COLS, a[3])
  end
  for _, al in ipairs({ { "burn", "run" }, { "attack_ranged", "attack" }, { "land", "stand" }, { "fly_idle", "jump_fall" }, { "fly_move", "jump_fall" } }) do
    local r = rowOf[al[2]]
    xml[#xml + 1] = string.format('\t<RectAnimation name="%s" pos_x="0" pos_y="%d" frame_count="%d" frame_width="%d" frame_height="%d" frame_wait="%s" frames_per_row="%d" loop="1" />',
      al[1], r[1] * H, r[2], W, H, tostring(r[3]), COLS)
  end
  xml[#xml + 1] = "</Sprite>"
  spr:saveAs(out .. "\\" .. name .. ".aseprite")
  local ss = Sprite(sheet.width, sheet.height, ColorMode.RGB)
  ss.cels[1].image = sheet
  ss:saveAs(out .. "\\" .. name .. ".png")
  ss:close(); spr:close()
  local f = io.open(out .. "\\" .. name .. ".xml", "w"); f:write(table.concat(xml, "\n") .. "\n"); f:close()
end

local out = app.params.out
build("cao_branco", PAL.white, 40, 32, 18, 30, 1.0, false, out)
build("cao_preto", PAL.black, 40, 32, 18, 30, 1.0, false, out)
build("cao_totalidade", PAL.total, 64, 50, 28, 48, 1.6, true, out)

-- perk icons: the white dog's head on a dark disc (16x16 ui, 16x16 item)
-- hand-placed 16x16 head (K outline, W white, S shade, M marking, E eye, N nose)
local HEAD = {
  "................",
  "..K....K........",
  ".KWK..KWK.......",
  ".KSWK.KWWK......",
  ".KSWWKWWWWK.....",
  "..KWWWWWWWWK....",
  "..KWMMMMWWWWK...",
  "..KWWWEMWWWWWK..",
  ".KWWWWWWWWWWWWKK",
  ".KWWWWWWWWWWWWNK",
  ".KSWWWWWWWKKKKK.",
  ".KSSWWWWWWK.....",
  "..KSSWWWWK......",
  "...KSSSSK.......",
  "....KKKK........",
  "................",
}
local function icon(file, bg)
  local P = PAL.white
  local map = { K = P.O, W = P.F, S = P.S, M = P.M, E = C"#1c1820", N = P.N }
  local img = Image(16, 16, ColorMode.RGB)
  if bg then for y = 0, 15 do for x = 0, 15 do local d = (x - 7.5) ^ 2 + (y - 7.5) ^ 2; if d < 56 then img:drawPixel(x, y, C"#26232b") elseif d < 64 then img:drawPixel(x, y, C"#bab3aa") end end end end
  for y, row in ipairs(HEAD) do
    for x = 1, 16 do local ch = row:sub(x, x); if map[ch] then img:drawPixel(x - 1, y - 1, map[ch]) end end
  end
  local s = Sprite(16, 16, ColorMode.RGB); s.cels[1].image = img; s:saveAs(out .. "\\" .. file); s:close()
end
icon("cao_perk_ui.png", true)
icon("cao_perk_item.png", false)

-- effects: ground crack (96x16) and electric burst (96x96)
local function save(img, file) local s = Sprite(img.width, img.height, ColorMode.RGB); s.cels[1].image = img; s:saveAs(out .. "\\" .. file); s:close() end
do
  local img = Image(96, 16, ColorMode.RGB)
  local seed = 7
  local function rnd() seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648 end
  local function crackLine(x, y, dir, len, w)
    for i = 1, len do
      x = x + dir; y = math.max(1, math.min(14, y + math.floor(rnd() * 3) - 1))
      for k = 0, w - 1 do img:drawPixel(x, y + k, C"#120f10"); img:drawPixel(x, y + k - 1, CA("#4a3a2a", 255)) end
      if rnd() < 0.12 and w > 1 then crackLine(x, y, dir, math.floor(len * 0.4), w - 1) end
    end
  end
  crackLine(48, 8, 1, 46, 2); crackLine(48, 8, -1, 46, 2)
  for y = 6, 10 do for x = 44, 52 do img:drawPixel(x, y, C"#120f10") end end
  save(img, "crack.png")
end
do
  local img = Image(96, 96, ColorMode.RGB)
  local seed = 3
  local function rnd() seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648 end
  for r = 0, 47 do for a = 0, 359, 3 do
    local d = r / 47
    if rnd() < 0.08 * (1 - d) then img:drawPixel(48 + math.floor(r * math.cos(rad(a))), 48 + math.floor(r * math.sin(rad(a))), CA("#5fb8ff", 200)) end
  end end
  for b = 1, 9 do  -- jagged lightning arms
    local ang, x, y = rad(b * 40 + rnd() * 20), 48, 48
    for s = 1, 15 do
      ang = ang + (rnd() - 0.5) * 0.9
      local nx, ny = x + 3 * math.cos(ang), y + 3 * math.sin(ang)
      for t = 0, 1, 0.25 do
        local px, py = math.floor(x + (nx - x) * t), math.floor(y + (ny - y) * t)
        if px > 0 and py > 0 and px < 95 and py < 95 then
          img:drawPixel(px, py, C"#ffffff"); img:drawPixel(px + 1, py, C"#bfe9ff"); img:drawPixel(px, py + 1, C"#5fb8ff")
        end
      end
      x, y = nx, ny
    end
  end
  for y = 40, 56 do for x = 40, 56 do if (x - 48) ^ 2 + (y - 48) ^ 2 < 50 then img:drawPixel(x, y, C"#ffffff") elseif (x - 48) ^ 2 + (y - 48) ^ 2 < 64 then img:drawPixel(x, y, C"#bfe9ff") end end end
  save(img, "electric_burst.png")
end
return "ok"
