-- Mahoraga spritesheet generator (procedural rig). Facing right; Noita mirrors it.
local W, H, OX, GY = 64, 56, 24, 54   -- frame size, feet center x, ground row (outline below at 55)
local COLS = 8
local pc = app.pixelColor
local function C(h) return pc.rgba(tonumber(h:sub(2,3),16), tonumber(h:sub(4,5),16), tonumber(h:sub(6,7),16), 255) end
local K  = C"#1c1820"
local WB, S, D = C"#ece8df", C"#bab3aa", C"#8a837c"
local F, FS = C"#dcd8d2", C"#a29c98"
local HK, HS = C"#3a4744", C"#27302e"
local L, LS = C"#a9a9a3", C"#7c7d78"
local B = C"#2e2a30"
local BL, BS, BH = C"#d3dfe9", C"#869cb3", C"#ffffff"
local E1, E2, E3 = C"#bfe9ff", C"#5fb8ff", C"#ffffff"

local buf
local function idx(x, y) return y * W + x end
local function inb(x, y) return x >= 0 and y >= 0 and x < W and y < H end
local function put(x, y, c) if inb(x, y) then buf[idx(x, y)] = c end end
local function get(x, y) if inb(x, y) then return buf[idx(x, y)] end end

-- deterministic random
local seed = 1
local function rnd() seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648 end

-- masks (relative coords: x from feet center, y up negative from ground)
local function segdist(px, py, ax, ay, bx, by)
  local dx, dy = bx - ax, by - ay
  local l2 = dx * dx + dy * dy
  local t = 0
  if l2 > 0 then t = math.max(0, math.min(1, ((px - ax) * dx + (py - ay) * dy) / l2)) end
  local qx, qy = ax + t * dx - px, ay + t * dy - py
  return math.sqrt(qx * qx + qy * qy)
end
local function capsule(m, ax, ay, bx, by, r)
  ax, ay, bx, by = ax + OX, ay + GY, bx + OX, by + GY
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
    q[i] = { p[1] + OX, p[2] + GY }
    x0, y0 = math.min(x0, q[i][1]), math.min(y0, q[i][2])
    x1, y1 = math.max(x1, q[i][1]), math.max(y1, q[i][2])
  end
  for y = math.floor(y0) - 1, math.ceil(y1) + 1 do
    for x = math.floor(x0) - 1, math.ceil(x1) + 1 do
      if inb(x, y) then
        local inside, near = false, false
        local j = #q
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
local function has(m, x, y) return inb(x, y) and m[idx(x, y)] end

-- paint a part: outline (4-neighbours outside the mask) then fill; shade(x,y,m) may return a colour
local function paint(m, fill, shade, noOutline)
  if not noOutline then
    for i in pairs(m) do
      local x, y = i % W, i // W
      for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
        local nx, ny = x + d[1], y + d[2]
        if inb(nx, ny) and not m[idx(nx, ny)] then buf[idx(nx, ny)] = K end
      end
    end
  end
  for i in pairs(m) do
    local x, y = i % W, i // W
    buf[i] = (shade and shade(x, y, m)) or fill
  end
end
local function shadeBottom(c) return function(x, y, m) if not has(m, x, y + 1) then return c end end end
local function shadeBack(c, n) return function(x, y, m) if not has(m, x - n, y) then return c end end end

local function rad(a) return a * math.pi / 180 end
local function knee(h, ft)
  local dx, dy = ft[1] - h[1], ft[2] - h[2]
  local d = math.max(0.01, math.sqrt(dx * dx + dy * dy))
  local o = math.sqrt(math.max(0, 10.3 * 10.3 - (d / 2) ^ 2))
  return { h[1] + dx / 2 + dy / d * o, h[2] + dy / 2 - dx / d * o }
end
local function armPts(s, a)
  local e = { s[1] + 7 * math.cos(rad(a[1])), s[2] + 7 * math.sin(rad(a[1])) }
  local h = { e[1] + 6 * math.cos(rad(a[2])), e[2] + 6 * math.sin(rad(a[2])) }
  return e, h
end

local function drawArm(s, a, front)
  local e, h = armPts(s, a)
  local m = {}
  capsule(m, s[1], s[2], e[1], e[2], front and 2.7 or 2.4)
  capsule(m, e[1], e[2], h[1], h[2], 2.1)
  capsule(m, h[1], h[2], h[1], h[2], 2.3)
  paint(m, front and WB or S, shadeBottom(front and S or D))
  -- wrist band
  local w0 = { e[1] + (h[1] - e[1]) * 0.6, e[2] + (h[2] - e[2]) * 0.6 }
  local w1 = { e[1] + (h[1] - e[1]) * 0.75, e[2] + (h[2] - e[2]) * 0.75 }
  local band = capsule({}, w0[1], w0[2], w1[1], w1[2], 2.5)
  for i in pairs(band) do if m[i] then buf[i] = B end end
  return h
end

local function drawLeg(hip, k, ft, front)
  local m = {}
  capsule(m, k[1], k[2], ft[1], ft[2] - 1.5, 1.6)
  capsule(m, hip[1], hip[2], k[1], k[2], 2.2)
  poly(m, { { ft[1] - 2, ft[2] - 1 }, { ft[1] + 3, ft[2] - 1 }, { ft[1] + 3, ft[2] }, { ft[1] - 2, ft[2] } })
  paint(m, front and WB or S, shadeBack(front and S or D, 1))
  local ab = capsule({}, ft[1] - 3, ft[2] - 3, ft[1] + 3, ft[2] - 3, 0.5)
  for i in pairs(ab) do if m[i] then buf[i] = B end end
end

local function drawSword(h, ang, len)
  local dx, dy = math.cos(rad(ang)), math.sin(rad(ang))
  local px, py = -dy, dx
  local b = { h[1] - dx, h[2] - dy }
  local tip = { h[1] + dx * len, h[2] + dy * len }
  local en = { tip[1] - dx * 3, tip[2] - dy * 3 }
  local w = 1.2
  local m = poly({}, { { b[1] + px * w, b[2] + py * w }, { en[1] + px * w, en[2] + py * w }, tip,
                       { en[1] - px * w, en[2] - py * w }, { b[1] - px * w, b[2] - py * w } })
  paint(m, BL, function(x, y)
    local side = (x - OX - h[1]) * px + (y - GY - h[2]) * py
    if side > 0.5 then return BS elseif side < -0.5 then return BH end
  end)
  return tip
end

-- effects (no outline)
local function ring(cx, cy, r0, r1, a0, a1, dither, cols)
  for y = 0, H - 1 do for x = 0, W - 1 do
    local dx, dy = x - (cx + OX), y - (cy + GY)
    local d = math.sqrt(dx * dx + dy * dy)
    local a = math.deg(math.atan(dy, dx))
    if d >= r0 and d <= r1 and a >= a0 and a <= a1 and (not dither or (x + y) % 2 == 0) then
      local t = (d - r0) / math.max(0.01, r1 - r0)
      put(x, y, t > 0.66 and cols[3] or (t > 0.33 and cols[2] or cols[1]))
    end
  end end
end
local function bolt(x, y, ang, len, col)
  for i = 1, len do
    ang = ang + (rnd() - 0.5) * 80
    x, y = x + math.cos(rad(ang)), y + math.sin(rad(ang))
    put(math.floor(x + OX + 0.5), math.floor(y + GY + 0.5), col)
  end
end

local function effects(p, ctx)
  for _, fx in ipairs(p.fx or {}) do
    local name, a = fx[1], fx
    if name == "arc" then
      ring(ctx.sF[1], ctx.sF[2], 16, 20, a[2], a[3], a[4], { E2, E1, E3 })
    elseif name == "wave" then
      ring(a[2], -22, 11, 14, -55, 55, a[3], { E2, E1, E3 })
    elseif name == "shock" then
      local cx, r = ctx.tip and ctx.tip[1] or 8, a[2]
      for x = -r, r do
        if not a[3] or x % 2 == 0 then
          put(cx + x + OX, GY, math.abs(x) > r - 3 and E1 or E3)
          if math.abs(x) % 3 == 1 then put(cx + x + OX, GY - 1 - (r - math.abs(x)) // 4, E1) end
        end
      end
      for i = 1, a[4] or 0 do put(cx + OX + math.floor((rnd() - 0.5) * r * 2), GY - 2 - math.floor(rnd() * r / 2), D) end
    elseif name == "spark" then
      seed = a[2]
      for i = 1, a[3] do
        bolt(ctx.hB[1], ctx.hB[2], rnd() * 360, a[4], i % 2 == 0 and E1 or E3)
      end
      put(math.floor(ctx.hB[1] + OX + 0.5), math.floor(ctx.hB[2] + GY + 0.5), E3)
    elseif name == "speed" then
      for _, l in ipairs({ { -24, 4 }, { -18, 6 }, { -30, 5 }, { -12, 3 }, { -26, 7 } }) do
        local y = l[1] + (a[2] or 0) % 3
        for x = 0, l[2] do put(ctx.bx - 12 - x - (a[2] or 0) + OX, y + GY, x < 2 and E3 or E1) end
      end
    end
  end
end

local function glow(level)
  local add = {}
  for y = 0, H - 1 do for x = 0, W - 1 do
    if not get(x, y) then
      for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
        if get(x + d[1], y + d[2]) == K then add[#add + 1] = { x, y }; break end
      end
    end
  end end
  for _, q in ipairs(add) do if level > 1 or (q[1] + q[2]) % 2 == 0 then put(q[1], q[2], level > 1 and E2 or E1) end end
end

local function dissolve(ratio, s)
  seed = s
  local parts = {}
  for y = 0, H - 1 do for x = 0, W - 1 do
    if get(x, y) and rnd() < ratio then
      buf[idx(x, y)] = nil
      if rnd() < 0.06 then parts[#parts + 1] = { x, y - math.floor(ratio * 14) } end
    end
  end end
  for _, q in ipairs(parts) do put(q[1], q[2], E1) end
end

local function drawPose(p)
  buf = {}
  local by, bx, lean = p.by or 0, p.bx or 0, p.lean or 0
  local tx = bx + lean
  local hx, hy = tx + (p.hx or 0), by + (p.hy or 0)
  local f, f2 = p.fin or 0, math.floor((p.fin or 0) / 2)
  local hipF, hipB = { bx + 3, -20 + by }, { bx - 3, -20 + by }
  local ff, bf = p.ff or { 3, 0 }, p.bf or { -3, 0 }
  local kF, kB = p.kf or knee(hipF, ff), p.kb or knee(hipB, bf)
  local sF, sB = { tx + 7, -29 + by }, { tx - 6 + (p.sbx or 0), -29 + by }
  local fa, ba = p.fa or { 80, 60 }, p.ba or { 100, 95 }
  local ctx = { sF = sF, bx = bx }

  -- back fins (up wing + trailing hair fin)
  paint(poly({}, { { hx - 1, -42 + hy }, { hx - 6, -47 + hy }, { hx - 11, -48 + hy + f }, { hx - 15, -46 + hy + f }, { hx - 10, -44 + hy + f }, { hx - 4, -40 + hy } }), FS, shadeBottom(D))
  paint(poly({}, { { hx - 2, -38 + hy }, { hx - 12, -39 + hy + f2 }, { hx - 12, -37 + hy + f2 }, { hx - 3, -35 + hy } }), FS, shadeBottom(D))
  if not p.baFront then ctx.hB = drawArm(sB, ba, false) end
  -- legs and hakama
  drawLeg(hipB, kB, bf, false)
  drawLeg(hipF, kF, ff, true)
  local hemY = math.max(kF[2], kB[2]) + 1
  local hl, hr = math.min(kF[1], kB[1]) - 3, math.max(kF[1], kB[1]) + 3
  local hk = poly({}, { { bx - 6, -21 + by }, { bx + 6, -21 + by }, { hr, hemY }, { hl, hemY } })
  paint(hk, HK, shadeBack(HS, 2))
  local fold = capsule({}, bx + 1, -15 + by, (kF[1] + kB[1]) / 2, hemY, 0.4)
  for i in pairs(fold) do if hk[i] then buf[i] = HS end end
  -- torso with deltoids
  local torso = poly({}, { { tx - 2, -34 + hy }, { tx + 3, -34 + hy }, { tx + 3, -31 + by }, { tx - 2, -31 + by } })
  poly(torso, { { tx - 7, -31 + by }, { tx + 8, -31 + by }, { tx + 8, -27 + by }, { bx + 5, -21 + by }, { bx - 5, -21 + by }, { tx - 7, -27 + by } })
  capsule(torso, tx + 8, -29 + by, tx + 8, -29 + by, 2.6)
  capsule(torso, tx - 7, -29 + by, tx - 7, -29 + by, 2.4)
  paint(torso, WB, shadeBack(S, 2))
  local function det(x, y, c) local X, Y = math.floor(x + OX + 0.5), math.floor(y + GY + 0.5); if torso[idx(X, Y)] then put(X, Y, c) end end
  for x = -3, 5 do if x ~= 1 then det(tx + x, -26 + by, S) end end
  det(tx + 1, -25 + by, S); det(tx + 1, -23 + by, S)
  -- U-shaped bead necklace with tags
  det(tx - 4, -31 + by, K); det(tx + 6, -31 + by, K)
  for x = -3, 5 do det(tx + x, -30 + by, K) end
  det(tx - 1, -29 + by, B); det(tx + 1, -29 + by, B); det(tx + 3, -29 + by, B)
  -- sash + knot
  paint(poly({}, { { bx - 6, -22 + by }, { bx + 6, -22 + by }, { bx + 6, -20 + by }, { bx - 6, -20 + by } }), L, shadeBack(LS, 2))
  paint(poly({}, { { bx + 1, -20 + by }, { bx + 4, -20 + by }, { bx + 4 + (p.knot or 0), -13 + by }, { bx + 2 + (p.knot or 0), -12 + by } }), L, shadeBack(LS, 1))
  -- head (face to the right, grin)
  paint(poly({}, { { hx - 3, -42 + hy }, { hx + 3, -42 + hy }, { hx + 5, -40 + hy }, { hx + 5, -35 + hy }, { hx, -34 + hy }, { hx - 3, -36 + hy } }), WB, shadeBack(S, 1))
  for x = 0, 4 do put(math.floor(hx + x + OX), -40 + hy + GY, S) end
  put(hx + 1 + OX, -37 + hy + GY, K); for x = 2, 4 do put(hx + x + OX, -36 + hy + GY, K) end; put(hx + 5 + OX, -37 + hy + GY, K)
  put(hx + 3 + OX, -37 + hy + GY, WB)
  -- front wing fin from the top of the head
  paint(poly({}, { { hx, -42 + hy }, { hx + 5, -47 + hy }, { hx + 10, -48 + hy + f }, { hx + 14, -46 + hy + f }, { hx + 9, -44 + hy + f }, { hx + 1, -41 + hy } }), F, shadeBottom(FS))
  if p.baFront then ctx.hB = drawArm(sB, ba, false) end
  -- sword arm
  local e, h = armPts(sF, fa)
  ctx.tip = drawSword(h, p.sa or fa[2], p.sl or 13)
  drawArm(sF, fa, true)
  effects(p, ctx)
  if p.glow then glow(p.glow) end
  if p.dissolve then dissolve(p.dissolve, 77) end
  return buf
end

-- poses ---------------------------------------------------------------
local function cyc(n, fn) local t = {} for i = 0, n - 1 do t[#t + 1] = fn(i / n * 2 * math.pi, i) end return t end
local function rd(v) return math.floor(v + 0.5) end

local anims = {
  { "stand", 0.3, 1, {
    { fin = 0 }, { fin = -1 }, { by = 1, fin = 0, fa = { 82, 62 }, ba = { 102, 97 } }, { by = 1, fin = 1, fa = { 82, 62 }, ba = { 102, 97 } } } },
  { "walk", 0.12, 1, cyc(6, function(t)
    local c, s = math.cos(t), math.sin(t)
    return { lean = 1, by = rd(math.abs(c)), fin = rd(math.sin(2 * t)),
      ff = { rd(4 * c), s < 0 and -rd(2 * -s) or 0 }, bf = { rd(-4 * c), s > 0 and -rd(2 * s) or 0 },
      fa = { 80 + 12 * c, 60 + 12 * c }, ba = { 95 - 20 * c, 75 - 20 * c }, knot = rd(-c) }
  end) },
  { "run", 0.08, 1, cyc(6, function(t)
    local c, s = math.cos(t), math.sin(t)
    return { lean = 3, bx = 1, by = rd(math.abs(c)), fin = 1 + rd(math.sin(2 * t)), knot = -1,
      ff = { 1 + rd(6 * c), s < 0 and -rd(3 * -s) or 0 }, bf = { 1 + rd(-6 * c), s > 0 and -rd(3 * s) or 0 },
      fa = { 115 + 15 * c, 135 + 15 * c }, sa = 165, ba = { 90 - 35 * c, 40 - 35 * c } }
  end) },
  { "attack", 0.07, 0, {
    { lean = -2, by = 1, ff = { 4, 0 }, bf = { -4, 0 }, fa = { -160, -140 }, sa = -150, ba = { 70, 30 }, fin = -1 },
    { lean = 0, by = 1, ff = { 5, 0 }, bf = { -4, 0 }, fa = { -100, -60 }, sa = -50, ba = { 80, 40 }, fin = -2, fx = { { "arc", -110, -60, true } } },
    { lean = 3, by = 1, ff = { 7, 0 }, bf = { -4, 0 }, fa = { 0, 15 }, sa = 10, ba = { 130, 150 }, fin = 1, fx = { { "arc", -60, 25 } } },
    { lean = 3, by = 2, ff = { 7, 0 }, bf = { -4, 0 }, fa = { 60, 90 }, sa = 105, ba = { 130, 150 }, fin = 2, fx = { { "arc", -10, 80, true } } },
    { lean = 2, by = 2, ff = { 7, 0 }, bf = { -4, 0 }, fa = { 70, 95 }, sa = 112, ba = { 120, 140 }, fin = 1 },
    { lean = 1, by = 1, ff = { 5, 0 }, bf = { -3, 0 }, fa = { 80, 70 }, sa = 70, ba = { 105, 100 } } } },
  { "attack_ranged", 0.07, 0, {
    { lean = -1, by = 1, ff = { 4, 0 }, bf = { -4, 0 }, fa = { -170, -150 }, sa = -160, ba = { 60, 20 }, fin = -1 },
    { lean = 3, by = 1, ff = { 6, 0 }, bf = { -4, 0 }, fa = { -20, 0 }, sa = -10, ba = { 130, 150 }, fin = 1, fx = { { "wave", 18 } } },
    { lean = 3, by = 1, ff = { 6, 0 }, bf = { -4, 0 }, fa = { 10, 20 }, sa = 20, ba = { 130, 150 }, fin = 1, fx = { { "wave", 26 } } },
    { lean = 2, by = 1, ff = { 6, 0 }, bf = { -4, 0 }, fa = { 40, 50 }, sa = 50, ba = { 115, 130 }, fx = { { "wave", 33, true } } },
    { lean = 1, ff = { 4, 0 }, bf = { -3, 0 }, fa = { 75, 62 }, sa = 62 } } },
  { "slam", 0.09, 0, {
    { by = 4, lean = 1, ff = { 5, 0 }, bf = { -5, 0 }, fa = { -120, -100 }, sa = -95, ba = { -115, -90 }, fin = -1 },
    { by = -4, lean = 1, ff = { 4, -6 }, bf = { -4, -5 }, fa = { -50, -30 }, sa = -35, ba = { -100, -70 }, fin = 2 },
    { by = 5, lean = 3, ff = { 7, 0 }, bf = { -6, 0 }, fa = { 40, 80 }, sa = 90, ba = { 60, 90 }, fin = -2, fx = { { "shock", 9, false, 4 } } },
    { by = 5, lean = 3, ff = { 7, 0 }, bf = { -6, 0 }, fa = { 40, 80 }, sa = 90, ba = { 60, 90 }, fin = -1, fx = { { "shock", 16, true, 6 } } },
    { by = 2, lean = 1, ff = { 5, 0 }, bf = { -4, 0 }, fa = { 70, 80 }, sa = 85, ba = { 95, 95 } } } },
  { "charge", 0.07, 1, cyc(4, function(t, i)
    local c, s = math.cos(t), math.sin(t)
    return { lean = 5, bx = 2, by = 2 + rd(math.abs(s)), fin = 2, knot = -2,
      ff = { 3 + rd(5 * c), s < 0 and -2 or 0 }, bf = { 1 + rd(-5 * c), s > 0 and -2 or 0 },
      fa = { 10, 0 }, sa = 0, ba = { 140, 165 }, fx = { { "speed", i } } }
  end) },
  { "punch", 0.07, 0, {
    { lean = -2, by = 1, ff = { 4, 0 }, bf = { -4, 0 }, ba = { 135, -70 }, fa = { 95, 80 }, fin = -1 },
    { lean = 4, bx = 1, by = 1, ff = { 7, 0 }, bf = { -4, 0 }, sbx = 6, baFront = true, ba = { 0, 0 }, fa = { 110, 120 }, sa = 130, fin = 1, fx = { { "spark", 3, 4, 5 } } },
    { lean = 4, bx = 1, by = 1, ff = { 7, 0 }, bf = { -4, 0 }, sbx = 6, baFront = true, ba = { 0, 0 }, fa = { 110, 120 }, sa = 130, fin = 2, fx = { { "spark", 9, 8, 9 } } },
    { lean = 4, bx = 1, by = 1, ff = { 7, 0 }, bf = { -4, 0 }, sbx = 6, baFront = true, ba = { 0, 0 }, fa = { 110, 120 }, sa = 130, fin = 1, fx = { { "spark", 21, 6, 12 } } },
    { lean = 1, ff = { 5, 0 }, bf = { -3, 0 }, ba = { 100, 90 }, fa = { 85, 65 } } } },
  { "jump_up", 0.15, 1, {
    { by = -2, ff = { 4, -4 }, bf = { -4, -1 }, fa = { -30, -60 }, sa = -60, ba = { -120, -100 }, fin = 2 },
    { by = -2, ff = { 4, -4 }, bf = { -4, -1 }, fa = { -30, -60 }, sa = -60, ba = { -120, -100 }, fin = 3, knot = -1 } } },
  { "jump_fall", 0.15, 1, {
    { ff = { 4, 0 }, bf = { -3, -1 }, fa = { 30, 10 }, sa = 10, ba = { 150, 170 }, fin = -2, knot = 1 },
    { ff = { 4, 0 }, bf = { -3, -1 }, fa = { 25, 5 }, sa = 5, ba = { 155, 175 }, fin = -3, knot = 2 } } },
  { "land", 0.08, 0, {
    { by = 4, lean = 1, ff = { 5, 0 }, bf = { -5, 0 }, fa = { 60, 40 }, sa = 40, ba = { 120, 130 }, fin = 2 },
    { by = 2, ff = { 4, 0 }, bf = { -4, 0 }, fa = { 70, 50 }, sa = 50, ba = { 110, 110 }, fin = 1 },
    { by = 0, fa = { 80, 60 }, fin = 0 } } },
  { "hurt", 0.1, 0, {
    { lean = -3, bx = -1, by = 1, fa = { 110, 120 }, sa = 120, ba = { 120, 140 }, fin = 2, hy = 1 },
    { lean = -2, by = 1, fa = { 100, 100 }, sa = 100, ba = { 115, 125 }, fin = 1 } } },
  { "death", 0.12, 0, {
    { lean = -3, bx = -1, by = 1, fa = { 110, 120 }, sa = 120, ba = { 120, 140 }, fin = 2, hy = 1 },
    { by = 6, lean = 1, ff = { 6, 0 }, bf = { -8, 0 }, kb = { -2, -1 }, fa = { 95, 100 }, sa = 100, ba = { 100, 100 }, fin = 2 },
    { by = 8, lean = 3, ff = { 6, 0 }, bf = { -8, 0 }, kb = { -2, -1 }, fa = { 95, 95 }, sa = 95, ba = { 95, 95 }, fin = 3, hy = 2 },
    { by = 8, lean = 3, ff = { 6, 0 }, bf = { -8, 0 }, kb = { -2, -1 }, fa = { 95, 95 }, sa = 95, ba = { 95, 95 }, fin = 3, hy = 2, dissolve = 0.15 },
    { by = 8, lean = 3, ff = { 6, 0 }, bf = { -8, 0 }, kb = { -2, -1 }, fa = { 95, 95 }, sa = 95, ba = { 95, 95 }, fin = 3, hy = 2, dissolve = 0.35 },
    { by = 8, lean = 3, ff = { 6, 0 }, bf = { -8, 0 }, kb = { -2, -1 }, fa = { 95, 95 }, sa = 95, ba = { 95, 95 }, fin = 3, hy = 2, dissolve = 0.6 },
    { by = 8, lean = 3, ff = { 6, 0 }, bf = { -8, 0 }, kb = { -2, -1 }, fa = { 95, 95 }, sa = 95, ba = { 95, 95 }, fin = 3, hy = 2, dissolve = 0.85 },
    { by = 8, lean = 3, ff = { 6, 0 }, bf = { -8, 0 }, kb = { -2, -1 }, fa = { 95, 95 }, sa = 95, ba = { 95, 95 }, fin = 3, hy = 2, dissolve = 1.0 } } },
  { "adapt", 0.15, 1, {
    { fin = -2, fa = { 70, 50 }, sa = 50, ba = { 110, 120 } },
    { fin = -3, fa = { 65, 45 }, sa = 45, ba = { 115, 125 }, glow = 1 },
    { fin = -3, fa = { 65, 45 }, sa = 45, ba = { 115, 125 }, glow = 2 },
    { fin = -2, fa = { 70, 50 }, sa = 50, ba = { 110, 120 }, glow = 1 } } },
}

-- build sprite with one frame per pose + tags
local total = 0
for _, a in ipairs(anims) do total = total + #a[4] end
local spr = Sprite(W, H, ColorMode.RGB)
spr.layers[1].name = "mahoraga"
for i = 2, total do spr:newEmptyFrame() end
local sheet = Image(W * COLS, H * #anims, ColorMode.RGB)
local fi = 1
local xml = { '<Sprite filename="mods/mahoraga/files/gfx/mahoraga.png" offset_x="' .. OX .. '" offset_y="' .. (GY + 1) .. '" default_animation="stand">' }
local rowOf = {}
for row, a in ipairs(anims) do
  local name, wait, loop, poses = a[1], a[2], a[3], a[4]
  local first = fi
  for col, p in ipairs(poses) do
    local b = drawPose(p)
    local img = Image(W, H, ColorMode.RGB)
    for i, c in pairs(b) do img:drawPixel(i % W, i // W, c) end
    spr:newCel(spr.layers[1], fi, img, Point(0, 0))
    spr.frames[fi].duration = wait
    sheet:drawImage(img, Point((col - 1) * W, (row - 1) * H))
    fi = fi + 1
  end
  local tag = spr:newTag(first, fi - 1)
  tag.name = name
  rowOf[name] = { row - 1, #poses, wait, loop }
  xml[#xml + 1] = string.format('\t<RectAnimation name="%s" pos_x="0" pos_y="%d" frame_count="%d" frame_width="%d" frame_height="%d" frame_wait="%s" frames_per_row="%d" loop="%d" />',
    name, (row - 1) * H, #poses, W, H, tostring(wait), COLS, loop)
end
-- aliases Noita's animal AI may ask for
for _, al in ipairs({ { "burn", "run" }, { "fly_idle", "jump_fall" }, { "fly_move", "jump_fall" } }) do
  local r = rowOf[al[2]]
  xml[#xml + 1] = string.format('\t<RectAnimation name="%s" pos_x="0" pos_y="%d" frame_count="%d" frame_width="%d" frame_height="%d" frame_wait="%s" frames_per_row="%d" loop="1" />',
    al[1], r[1] * H, r[2], W, H, tostring(r[3]), COLS)
end
xml[#xml + 1] = "</Sprite>"

local out = args.out
spr:saveAs(out .. "\\mahoraga_anim.aseprite")
local ss = Sprite(sheet.width, sheet.height, ColorMode.RGB)
ss.cels[1].image = sheet
ss:saveAs(out .. "\\mahoraga_spritesheet.png")
ss:close()
local f = io.open(out .. "\\mahoraga.xml", "w"); f:write(table.concat(xml, "\n") .. "\n"); f:close()
if app.isUIAvailable then app.sprite = spr; app.command.FitScreen() end
return { frames = total, sheet = { sheet.width, sheet.height } }
