using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;

// Draws every sprite the mod ships: Mahoraga's sheet, the wheel, projectiles, perk icons and the arena.
class MakeArt {
    static readonly Color T = Color.FromArgb(0, 0, 0, 0);
    static readonly Color Outline = Color.FromArgb(255, 34, 30, 40);
    static readonly Color Skin = Color.FromArgb(255, 236, 232, 222);
    static readonly Color SkinShade = Color.FromArgb(255, 184, 176, 166);
    static readonly Color SkinDark = Color.FromArgb(255, 140, 132, 128);
    static readonly Color Cloth = Color.FromArgb(255, 58, 50, 66);
    static readonly Color ClothLight = Color.FromArgb(255, 92, 82, 104);
    static readonly Color Mark = Color.FromArgb(255, 70, 40, 60);
    static readonly Color Blade = Color.FromArgb(255, 214, 222, 232);
    static readonly Color BladeEdge = Color.FromArgb(255, 255, 255, 255);
    static readonly Color BladeShade = Color.FromArgb(255, 150, 160, 176);
    static readonly Color Gold = Color.FromArgb(255, 232, 186, 64);
    static readonly Color GoldLight = Color.FromArgb(255, 255, 230, 140);
    static readonly Color GoldDark = Color.FromArgb(255, 150, 104, 30);
    static readonly Color Feather = Color.FromArgb(255, 246, 244, 240);
    static readonly Color FeatherShade = Color.FromArgb(255, 196, 192, 200);

    const int FW = 40, FH = 44;

    static void Px(Bitmap b, int x, int y, Color c) {
        if (x >= 0 && y >= 0 && x < b.Width && y < b.Height) b.SetPixel(x, y, c);
    }
    static void Rect(Bitmap b, int x0, int y0, int w, int h, Color c) {
        for (int y = y0; y < y0 + h; y++) for (int x = x0; x < x0 + w; x++) Px(b, x, y, c);
    }
    static void Line(Bitmap b, double x0, double y0, double x1, double y1, double thick, Color c) {
        int steps = (int)Math.Ceiling(Math.Max(Math.Abs(x1 - x0), Math.Abs(y1 - y0)) * 2) + 1;
        for (int i = 0; i <= steps; i++) {
            double t = (double)i / steps;
            double x = x0 + (x1 - x0) * t, y = y0 + (y1 - y0) * t;
            int r = (int)Math.Floor(thick / 2);
            for (int dy = -r; dy <= r; dy++) for (int dx = -r; dx <= r; dx++)
                if (dx * dx + dy * dy <= r * r + r) Px(b, (int)Math.Round(x) + dx, (int)Math.Round(y) + dy, c);
        }
    }
    // Draws a 1px dark outline around every opaque pixel inside the frame at (fx, fy).
    static void OutlineFrame(Bitmap b, int fx, int fy, int w, int h) {
        var mask = new bool[w, h];
        for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) mask[x, y] = b.GetPixel(fx + x, fy + y).A > 0;
        for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
            if (mask[x, y]) continue;
            bool near = false;
            for (int d = 0; d < 4 && !near; d++) {
                int nx = x + (d == 0 ? 1 : d == 1 ? -1 : 0), ny = y + (d == 2 ? 1 : d == 3 ? -1 : 0);
                if (nx >= 0 && ny >= 0 && nx < w && ny < h && mask[nx, ny]) near = true;
            }
            if (near) b.SetPixel(fx + x, fy + y, Outline);
        }
    }

    // One pose of Mahoraga, facing right. legA/legB: foot x offsets; bob: body y shift;
    // swordAngle: degrees, 0 = pointing forward, -90 = up.
    static void DrawBody(Bitmap b, int fx, int fy, int legA, int legB, int bob, double swordAngle, int liftA, int liftB) {
        int cx = fx + 16;
        int hip = fy + 28 + bob;
        // back leg (darker)
        Line(b, cx - 2, hip, cx - 3 + legB, fy + 41 - liftB, 4, SkinShade);
        Rect(b, cx - 5 + legB, fy + 41 - liftB, 5, 2, SkinDark);
        // back arm hanging behind torso
        Line(b, cx - 6, fy + 16 + bob, cx - 8, fy + 27 + bob, 3, SkinShade);
        // torso
        for (int y = 0; y < 14; y++) {
            int half = y < 4 ? 7 : (y < 8 ? 6 : (y < 11 ? 5 : 4));
            for (int x = -half; x <= half; x++) {
                Color c = x <= -half + 1 ? SkinShade : Skin;
                if (y >= 5 && y <= 6 && (x == -2 || x == 2)) c = SkinShade; // chest line
                if (y >= 8 && y <= 12 && x == 0) c = SkinShade;            // abs
                if (y == 10 && Math.Abs(x) <= 3) c = SkinShade;
                Px(b, cx + x, fy + 14 + bob + y, c);
            }
        }
        // loincloth and belt
        Rect(b, cx - 6, fy + 27 + bob, 13, 2, Cloth);
        Rect(b, cx - 3, fy + 29 + bob, 7, 6, Cloth);
        Rect(b, cx - 1, fy + 29 + bob, 2, 6, ClothLight);
        // front leg
        Line(b, cx + 2, hip, cx + 2 + legA, fy + 41 - liftA, 4, Skin);
        Rect(b, cx + legA, fy + 41 - liftA, 5, 2, SkinShade);
        // neck and head
        Rect(b, cx - 1, fy + 12 + bob, 3, 2, SkinShade);
        Rect(b, cx - 3, fy + 6 + bob, 7, 7, Skin);
        Rect(b, cx - 3, fy + 6 + bob, 1, 7, SkinShade);
        // face markings: dark streaks over the eyes
        Rect(b, cx - 1, fy + 8 + bob, 5, 1, Mark); Px(b, cx + 1, fy + 9 + bob, Mark);
        Px(b, cx + 3, fy + 10 + bob, Mark);
        Px(b, cx + 3, fy + 10 + bob, Mark);
        Rect(b, cx + 1, fy + 11 + bob, 2, 1, SkinDark);
        // head wings: two pairs of feathered wings sweeping up and out from the head
        int hy = fy + 5 + bob;
        Line(b, cx - 4, hy, cx - 9, hy - 5, 2, Feather);
        Line(b, cx - 4, hy + 1, cx - 12, hy - 1, 2, FeatherShade);
        Line(b, cx + 4, hy, cx + 9, hy - 5, 2, Feather);
        Line(b, cx + 4, hy + 1, cx + 12, hy - 1, 2, FeatherShade);
        Px(b, cx - 9, hy - 6, Feather); Px(b, cx + 9, hy - 6, Feather);
        // front arm and the Sword of Extermination
        double sx = cx + 5, sy = fy + 16 + bob;
        double rad = swordAngle * Math.PI / 180.0;
        double ex = sx + Math.Cos(rad + 0.9) * 6, ey = sy + Math.Sin(rad + 0.9) * 6;
        Line(b, sx, sy, ex, ey, 3, Skin);
        double tx = ex + Math.Cos(rad) * 17, ty = ey + Math.Sin(rad) * 17;
        Line(b, ex, ey, tx, ty, 3, Blade);
        Line(b, ex + Math.Cos(rad - 1.57), ey + Math.Sin(rad - 1.57), tx, ty, 1, BladeEdge);
        Line(b, ex + Math.Cos(rad + 1.57), ey + Math.Sin(rad + 1.57), tx, ty, 1, BladeShade);
        Rect(b, (int)ex - 1, (int)ey - 1, 3, 3, GoldDark); // bracer
    }

    static Bitmap Sheet() {
        // rows: 0 stand(2) 1 walk(4) 2 attack(4) 3 jump(2)
        var b = new Bitmap(FW * 4, FH * 4, PixelFormat.Format32bppArgb);
        DrawBody(b, 0 * FW, 0, 1, -2, 0, 40, 0, 0);
        DrawBody(b, 1 * FW, 0, 1, -2, 1, 44, 0, 0);
        int[] la = { 3, 1, -2, 1 }, lb = { -3, -1, 2, -1 }, bob = { 0, 1, 0, 1 }, ua = { 0, 2, 0, 0 }, ub = { 0, 0, 0, 2 };
        for (int i = 0; i < 4; i++) DrawBody(b, i * FW, FH, la[i], lb[i], bob[i], 36, ua[i], ub[i]);
        double[] sw = { -60, -100, 10, 40 };
        for (int i = 0; i < 4; i++) DrawBody(b, i * FW, FH * 2, 2, -2, i == 2 ? 1 : 0, sw[i], 0, 0);
        DrawBody(b, 0, FH * 3, 2, -3, -1, -30, 3, 3);
        DrawBody(b, FW, FH * 3, 3, -2, 0, 20, 1, 1);
        for (int r = 0; r < 4; r++) for (int c = 0; c < 4; c++) OutlineFrame(b, c * FW, r * FH, FW, FH);
        return b;
    }

    static Bitmap Wheel(int size, double spin) {
        var b = new Bitmap(size, size, PixelFormat.Format32bppArgb);
        double c = (size - 1) / 2.0, ro = size / 2.0 - 1.5, ri = ro - 2.2;
        for (int y = 0; y < size; y++) for (int x = 0; x < size; x++) {
            double d = Math.Sqrt((x - c) * (x - c) + (y - c) * (y - c));
            if (d <= ro && d >= ri) b.SetPixel(x, y, d > ro - 1 ? GoldDark : Gold);
            if (d < 2.2) b.SetPixel(x, y, GoldLight);
        }
        for (int k = 0; k < 8; k++) {
            double a = spin + k * Math.PI / 4;
            Line(b, c, c, c + Math.Cos(a) * (ri), c + Math.Sin(a) * (ri), 1, Gold);
            double hx = c + Math.Cos(a) * (ro + 1.5), hy = c + Math.Sin(a) * (ro + 1.5);
            Px(b, (int)Math.Round(hx), (int)Math.Round(hy), GoldLight); // handles
        }
        OutlineFrame(b, 0, 0, size, size);
        return b;
    }

    static Bitmap Slash() {
        var b = new Bitmap(24, 24, PixelFormat.Format32bppArgb);
        for (int y = 0; y < 24; y++) for (int x = 0; x < 24; x++) {
            double d1 = Math.Sqrt((x - 4) * (x - 4) + (y - 11.5) * (y - 11.5));
            double d2 = Math.Sqrt((x - 0) * (x - 0) + (y - 11.5) * (y - 11.5));
            if (d1 <= 11.5 && d2 > 11.5 && x > 4) {
                double edge = d1 / 11.5;
                int a = (int)(120 + 135 * edge);
                b.SetPixel(x, y, Color.FromArgb(Math.Min(a, 255), 255, (int)(230 + 25 * edge), (int)(170 + 85 * edge)));
            }
        }
        return b;
    }

    static Bitmap Orb() {
        var b = new Bitmap(8, 8, PixelFormat.Format32bppArgb);
        for (int y = 0; y < 8; y++) for (int x = 0; x < 8; x++) {
            double d = Math.Sqrt((x - 3.5) * (x - 3.5) + (y - 3.5) * (y - 3.5));
            if (d < 3.8) b.SetPixel(x, y, d < 1.8 ? Color.FromArgb(255, 255, 250, 210) : Color.FromArgb(220, 255, 200, 70));
        }
        return b;
    }

    static Bitmap Shard() {
        var b = new Bitmap(8, 8, PixelFormat.Format32bppArgb);
        Rect(b, 2, 2, 4, 4, Color.FromArgb(255, 140, 128, 110));
        Rect(b, 3, 1, 2, 1, Color.FromArgb(255, 180, 168, 150));
        Rect(b, 1, 3, 1, 2, Color.FromArgb(255, 110, 100, 90));
        OutlineFrame(b, 0, 0, 8, 8);
        return b;
    }

    static Bitmap PerkIcon(bool item) {
        var b = new Bitmap(16, 16, PixelFormat.Format32bppArgb);
        if (item) {
            for (int y = 0; y < 16; y++) for (int x = 0; x < 16; x++) {
                double d = Math.Sqrt((x - 7.5) * (x - 7.5) + (y - 7.5) * (y - 7.5));
                if (d < 7.6) b.SetPixel(x, y, Color.FromArgb(255, 44, 36, 60));
            }
        }
        var w = Wheel(item ? 14 : 16, 0.39);
        int o = item ? 1 : 0;
        for (int y = 0; y < w.Height; y++) for (int x = 0; x < w.Width; x++) {
            var c = w.GetPixel(x, y);
            if (c.A > 0) b.SetPixel(x + o, y + o, c);
        }
        return b;
    }

    // Arena: material map (Noita reads colours as materials), background picture.
    static void Arena(string dir, int W, int H) {
        var brick = Color.FromArgb(255, 0x64, 0x6c, 0x58);      // templebrick_thick_static (explosions cannot break it)
        var gold = Color.FromArgb(255, 0xb0, 0x7e, 0x13);       // templebrick_golden_static
        var dark = Color.FromArgb(255, 0x5b, 0x50, 0x47);       // templebrickdark_static
        var air = Color.FromArgb(255, 0, 0, 0x42);              // air (pure black means "leave as is")
        var glow = Color.FromArgb(255, 0xff, 0xc9, 0x31);       // glowstone_altar
        var m = new Bitmap(W, H, PixelFormat.Format32bppArgb);
        int wall = 12;
        Rect(m, 0, 0, W, H, brick);
        Rect(m, wall, wall, W - wall * 2, H - wall * 2, air);
        // west doorway reaching the floor
        Rect(m, 0, H - wall - 48, wall, 48, air);
        // golden trim on the floor and ceiling, dark brick pillars
        Rect(m, wall, H - wall, W - wall * 2, 2, gold);
        Rect(m, wall, wall - 2, W - wall * 2, 2, gold);
        for (int px = 70; px < W - 40; px += 70) {
            Rect(m, px, wall, 6, 10, dark);
            Rect(m, px + 1, wall + 10, 4, 2, glow);
        }
        // two low ledges to dodge onto
        Rect(m, 60, H - wall - 60, 40, 6, brick);
        Rect(m, W - 100, H - wall - 60, 40, 6, brick);
        m.Save(Path.Combine(dir, "arena.png"), ImageFormat.Png);

        var bg = new Bitmap(W, H, PixelFormat.Format32bppArgb);
        for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) {
            bool mortar = (y % 8 == 0) || ((x + ((y / 8) % 2) * 8) % 16 == 0);
            int v = mortar ? 22 : 34 + ((x * 7 + y * 13) % 5);
            bg.SetPixel(x, y, Color.FromArgb(255, v, v - 4, v + 4));
        }
        var big = Wheel(120, 0.0);
        int ox = W / 2 - 60, oy = H / 2 - 66;
        for (int y = 0; y < 120; y++) for (int x = 0; x < 120; x++) {
            var c = big.GetPixel(x, y);
            if (c.A > 0) bg.SetPixel(ox + x, oy + y, Color.FromArgb(255, c.R / 3, c.G / 3, c.B / 4));
        }
        bg.Save(Path.Combine(dir, "arena_bg.png"), ImageFormat.Png);
    }

    static void Main(string[] args) {
        string gfx = args[0], arena = args[1];
        Directory.CreateDirectory(gfx);
        Directory.CreateDirectory(arena);
        Sheet().Save(Path.Combine(gfx, "mahoraga.png"), ImageFormat.Png);
        Wheel(24, 0.0).Save(Path.Combine(gfx, "wheel.png"), ImageFormat.Png);
        for (int i = 0; i < 6; i++) Wheel(24, i * Math.PI / 4 / 6).Save(Path.Combine(gfx, "wheel_" + i + ".png"), ImageFormat.Png);
        Slash().Save(Path.Combine(gfx, "slash.png"), ImageFormat.Png);
        Orb().Save(Path.Combine(gfx, "orb.png"), ImageFormat.Png);
        Shard().Save(Path.Combine(gfx, "shard.png"), ImageFormat.Png);
        PerkIcon(false).Save(Path.Combine(gfx, "perk_ui.png"), ImageFormat.Png);
        PerkIcon(true).Save(Path.Combine(gfx, "perk_item.png"), ImageFormat.Png);
        Arena(arena, 352, 208);
        // a big preview of the sheet for checking by eye
        var s = Sheet();
        var big = new Bitmap(s.Width * 4, s.Height * 4);
        using (var g = Graphics.FromImage(big)) {
            g.Clear(Color.FromArgb(255, 70, 90, 110));
            g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.NearestNeighbor;
            g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.Half;
            g.DrawImage(s, 0, 0, s.Width * 4, s.Height * 4);
        }
        big.Save(Path.Combine(args[2], "sheet_preview.png"), ImageFormat.Png);
        Console.WriteLine("art done");
    }
}



