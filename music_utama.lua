-- Music Player (gaya Spotify) | 300x404
-- Lagu diambil dari GitHub (file .lua / .txt berisi mp3 base64), otomatis disalin ke folder
-- workspace executor, lalu diputar lewat getcustomasset. Bisa juga dari link mp3 langsung.
-- Hanya kamu yang mendengar (suara diputar di sisi client).
--
-- Fitur: urutan lagu otomatis, ulang (mati / semua / satu), acak, antrian "putar berikutnya",
-- timer tidur, kecepatan putar, info "Berikutnya", simpan pengaturan, gelembung mini (tombol X).
-- Pintasan keyboard: ]  lagu berikutnya | [  lagu sebelumnya | \  putar/jeda
--
-- Ganti nama file lagu di GitHub untuk mengubah judul di UI:
--   "Judul Lagu.lua"          -> judul: Judul Lagu
--   "Judul Lagu - Artis.lua"  -> judul + artis   (garis bawah _ jadi spasi)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
if not player then
	player = Players.PlayerAdded:Wait()
end
local playerGui = player:WaitForChild("PlayerGui", 8)

-- ─── CONFIG ───────────────────────────────────────────────────────────────
local GUI_NAME = "SpotifyStylePlayer"
local SOUND_NAME = "SpotifyStyleSound"
local W, H = 320, 350
local DEFAULT_SONG = "lagu1.mp3"   -- lagu bawaan (hanya muncul kalau filenya ada di workspace)
local START_VOLUME = 0.6           -- posisi awal slider volume (0 - 1)
local VOLUME_MAX = 5               -- slider 100% = Volume 5 di Roblox (20% = Volume 1 = normal). Maks Roblox: 10
local LOAD_TIMEOUT = 8             -- detik menunggu file dimuat

-- Opsional: unduh lagu otomatis ke workspace dari link LANGSUNG ke file mp3.
-- Contoh: { name = "lagu1.mp3", url = "https://contoh.com/lagu1.mp3" }
local AUTO_DOWNLOAD = {
}

-- Lagu dari GitHub: tiap lagu = 1 file .lua (music1.lua, music2.lua, ...)
local REPOS = {
	{ owner = "n01771542-cmd", repo = "music_penyimpanan", branch = "main", folder = "" },
	-- tambah repository lain di sini kalau perlu
}
local SLOTS = 15                       -- cadangan: coba music1.lua ... music15.lua
local SONG_DIR = "MusicPlayerSongs"    -- folder di workspace executor tempat lagu disalin
local EXCLUDE = { ["music.lua"] = true, ["music_player.lua"] = true, ["index.txt"] = true, ["readme.txt"] = true }

-- ► UBAH NAMA LAGU DI SINI. Kiri = nama file di GitHub (tanpa .lua/.txt), kanan = tampilan di UI.
--   Format "Judul" atau "Judul - Artis". Lagu yang tidak ditulis di sini memakai nama filenya.
local NAMES = {
	["Music1"]  = "505",
	["Music2"]  = "Music 2",
	["Music3"]  = "Music 3",
	["Music4"]  = "Music 4",
	["Music5"]  = "Music 5",
	["Music6"]  = "Music 6",
	["Music7"]  = "Music 7",
	["Music8"]  = "Music 8",
	["Music9"]  = "Music 9",
	["Music10"] = "Music 10",
	["Music11"] = "Music 11",
	["Music12"] = "Music 12",
	["Music13"] = "Music 13",
	["Music14"] = "Music 14",
	["Music15"] = "Music 15",
}

-- Opsional: lagu dari link LANGSUNG ke file mp3 (mis. catbox.moe / raw GitHub)
local EXTRA_SONGS = {
	-- { title = "Judul", artist = "Artis", url = "https://files.catbox.moe/xxxxxx.mp3" },
}

local SETTINGS_FILE = "MusicPlayerSettings.json" -- menyimpan volume, acak, ulang, kecepatan, lagu terakhir
local saved = {}
pcall(function()
	if type(isfile) == "function" and type(readfile) == "function" and isfile(SETTINGS_FILE) then
		local d = HttpService:JSONDecode(readfile(SETTINGS_FILE))
		if type(d) == "table" then saved = d end
	end
end)

-- ─── WARNA (palet Spotify) ────────────────────────────────────────────────
local BG     = Color3.fromRGB(18, 18, 18)
local PANEL  = Color3.fromRGB(24, 24, 24)
local BTN    = Color3.fromRGB(40, 40, 40)
local GREEN  = Color3.fromRGB(29, 185, 84)
local WHITE  = Color3.fromRGB(255, 255, 255)
local BLACK  = Color3.fromRGB(0, 0, 0)
local GRAY   = Color3.fromRGB(179, 179, 179)
local DIM    = Color3.fromRGB(83, 83, 83)
local ERR    = Color3.fromRGB(255, 120, 120)
-- warna sampul bergantian per lagu (atas gelembung/latar ikut berubah)
local COVERS = {
	{ Color3.fromRGB(29, 185, 84),  Color3.fromRGB(10, 60, 36) },
	{ Color3.fromRGB(80, 120, 255), Color3.fromRGB(20, 30, 90) },
	{ Color3.fromRGB(255, 110, 150), Color3.fromRGB(90, 20, 50) },
	{ Color3.fromRGB(255, 170, 60), Color3.fromRGB(100, 50, 10) },
	{ Color3.fromRGB(170, 100, 255), Color3.fromRGB(50, 20, 100) },
	{ Color3.fromRGB(60, 200, 210), Color3.fromRGB(10, 60, 70) },
}

local FONT_BOLD = Enum.Font.GothamBold
local FONT_MED  = Enum.Font.GothamMedium

-- ─── HELPERS UI ───────────────────────────────────────────────────────────
local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props) do
		inst[k] = v
	end
	if parent then inst.Parent = parent end
	return inst
end

local function corner(parent, radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function stroke(parent, color, thickness, transparency)
	return new("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

local function gradient(parent, c0, c1, rotation)
	return new("UIGradient", {
		Color = ColorSequence.new(c0, c1),
		Rotation = rotation or 0,
	}, parent)
end

local function label(parent, text, size, font, color, pos, sz, alignX)
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		Font = font,
		TextColor3 = color,
		Position = pos,
		Size = sz,
		TextXAlignment = alignX or Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, parent)
end

-- tombol teks polos (tanpa latar)
local function textButton(parent, text, size, color, anchor, pos, sz)
	return new("TextButton", {
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		Font = FONT_BOLD,
		TextColor3 = color,
		AnchorPoint = anchor or Vector2.new(0, 0),
		Position = pos,
		Size = sz,
		BorderSizePixel = 0,
	}, parent)
end

-- tombol berlatar abu gelap berbentuk kapsul/lingkaran
local function pillButton(parent, text, size, pos, sz, radius)
	local bg = new("Frame", {
		Position = pos,
		Size = sz,
		BackgroundColor3 = BTN,
		BorderSizePixel = 0,
	}, parent)
	corner(bg, radius)
	local btn = textButton(bg, text, size, WHITE, nil, UDim2.new(), UDim2.fromScale(1, 1))
	return btn, bg
end

-- ─── GUI ──────────────────────────────────────────────────────────────────
-- hapus UI dan suara lama kalau script dijalankan ulang
for _, root in ipairs({ CoreGui, playerGui, SoundService }) do
	pcall(function()
		if not root then return end
		local oldGui = root:FindFirstChild(GUI_NAME)
		if oldGui then oldGui:Destroy() end
		local oldSnd = root:FindFirstChild(SOUND_NAME)
		if oldSnd then
			oldSnd:Stop()
			oldSnd:Destroy()
		end
	end)
end

local gui = new("ScreenGui", {
	Name = GUI_NAME,
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	IgnoreGuiInset = true,
	DisplayOrder = 50,
})
local parented = pcall(function() gui.Parent = CoreGui end)
if not parented or not gui.Parent then
	gui.Parent = playerGui
end

local main = new("Frame", {
	Name = "Main",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(W, H),
	BackgroundColor3 = BG,
	BorderSizePixel = 0,
	ClipsDescendants = true,
}, gui)
corner(main, 14)
stroke(main, Color3.fromRGB(55, 55, 55), 1.5, 0.2)

-- skala otomatis: UI mengecil sendiri kalau layar pendek (HP)
local uiScale = new("UIScale", { Scale = 1 }, main)
local function fitScale()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local vs = cam.ViewportSize
	uiScale.Scale = math.clamp(math.min((vs.Y - 24) / H, (vs.X - 16) / W), 0.5, 1)
end
fitScale()
pcall(function()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitScale)
	end
end)

-- latar atas bergradasi (warnanya ikut sampul lagu, seperti Spotify)
local tint = new("Frame", {
	Size = UDim2.new(1, 0, 0, 190),
	BackgroundColor3 = Color3.fromRGB(14, 90, 50),
	BorderSizePixel = 0,
}, main)
new("UIGradient", {
	Rotation = 90,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	}),
}, tint)

-- header: [Daftar]      nama daftar      [X]
local listBtn = pillButton(main, "Daftar", 13, UDim2.fromOffset(12, 8), UDim2.fromOffset(76, 32), 16)
label(main, "Daftar putar GitHub", 13, FONT_BOLD, WHITE,
	UDim2.fromOffset(96, 8), UDim2.new(1, -96 - 56, 0, 32), Enum.TextXAlignment.Center)
local closeBtn, closeBg = pillButton(main, "", 17, UDim2.new(1, -54, 0, 2), UDim2.fromOffset(46, 46), 23)
closeBg.BackgroundTransparency = 1
for _, rot in ipairs({ 45, -45 }) do
	local bar = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(24, 3),
		Rotation = rot,
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
	}, closeBg)
	corner(bar, 2)
end

-- sampul (kiri) + judul / artis / berikutnya (kanan)
local art = new("Frame", {
	Position = UDim2.fromOffset(16, 52),
	Size = UDim2.fromOffset(96, 96),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
}, main)
corner(art, 8)
local artGrad = gradient(art, GREEN, Color3.fromRGB(10, 60, 36), 45)
local artLetter = label(art, "M", 46, FONT_BOLD, WHITE, UDim2.new(), UDim2.fromScale(1, 1), Enum.TextXAlignment.Center)

local titleLabel = label(main, "Tidak ada lagu", 19, FONT_BOLD, WHITE,
	UDim2.fromOffset(124, 54), UDim2.new(1, -140, 0, 26))
titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
local subLabel = label(main, "Lagu lokal", 13, FONT_MED, GRAY,
	UDim2.fromOffset(124, 82), UDim2.new(1, -140, 0, 18))
subLabel.TextTruncate = Enum.TextTruncate.AtEnd
local nextLabel = label(main, "", 12, FONT_MED, Color3.fromRGB(150, 150, 150),
	UDim2.fromOffset(124, 104), UDim2.new(1, -140, 0, 44))
nextLabel.TextWrapped = true
nextLabel.TextYAlignment = Enum.TextYAlignment.Top

-- fungsi isi bar (progres / volume)
local function setFill(fill, knob, ratio)
	ratio = math.clamp(ratio, 0, 1)
	fill.Size = UDim2.new(ratio, 0, 1, 0)
	knob.Position = UDim2.new(ratio, 0, 0.5, 0)
end

-- bar geser (dipakai progres dan volume): tap atau seret
local function makeBar(parent, y, x0, x1Offset)
	local hit = new("TextButton", {
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Text = "",
		Position = UDim2.fromOffset(x0 - 8, y - 14),
		Size = UDim2.new(1, -(x0 - 8) - (x1Offset - 8), 0, 28),
		BorderSizePixel = 0,
	}, parent)
	local track = new("Frame", {
		Position = UDim2.fromOffset(x0, y),
		Size = UDim2.new(1, -x0 - x1Offset, 0, 4),
		BackgroundColor3 = DIM,
		BorderSizePixel = 0,
	}, parent)
	corner(track, 2)
	local fill = new("Frame", {
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
	}, track)
	corner(fill, 2)
	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, track)
	corner(knob, 6)
	return hit, track, fill, knob
end

local function makeSlider(hit, track, onMove, onRelease)
	local dragging = false
	local function update(x)
		local w = math.max(track.AbsoluteSize.X, 1)
		onMove(math.clamp((x - track.AbsolutePosition.X) / w, 0, 1))
	end
	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			update(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			update(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			if onRelease then onRelease() end
		end
	end)
end

-- progres lagu
local progHit, progTrack, progFill, progKnob = makeBar(main, 168, 20, 20)
progFill.BackgroundColor3 = WHITE
local curLabel = label(main, "0:00", 12, FONT_MED, GRAY,
	UDim2.fromOffset(20, 177), UDim2.new(0.5, -20, 0, 16))
local totLabel = label(main, "0:00", 12, FONT_MED, GRAY,
	UDim2.new(0.5, 0, 0, 177), UDim2.new(0.5, -20, 0, 16), Enum.TextXAlignment.Right)

-- kontrol: [Acak]  |<  (PLAY)  >|  [Ulang]
local CY = 222

-- segitiga bersudut MEMBULAT (jarak ke segitiga <= r), digambar dari irisan vertikal 1px
local function makeTri(parent, Wt, Ht, r, color, flip)
	local A, B, C = { r, r }, { r, Ht - r }, { Wt - r, Ht / 2 }
	local function segDist(px, py, a, b)
		local dx, dy = b[1] - a[1], b[2] - a[2]
		local t = math.clamp(((px - a[1]) * dx + (py - a[2]) * dy) / (dx * dx + dy * dy), 0, 1)
		local cx, cy = a[1] + t * dx, a[2] + t * dy
		return math.sqrt((px - cx) ^ 2 + (py - cy) ^ 2)
	end
	local function side(px, py, a, b)
		return (px - b[1]) * (a[2] - b[2]) - (a[1] - b[1]) * (py - b[2])
	end
	local function dist(px, py)
		local d1, d2, d3 = side(px, py, A, B), side(px, py, B, C), side(px, py, C, A)
		local hasNeg = d1 < 0 or d2 < 0 or d3 < 0
		local hasPos = d1 > 0 or d2 > 0 or d3 > 0
		if not (hasNeg and hasPos) then return 0 end
		return math.min(segDist(px, py, A, B), segDist(px, py, B, C), segDist(px, py, C, A))
	end
	local box = new("Frame", {
		Size = UDim2.fromOffset(Wt, Ht),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, parent)
	for i = 0, Wt - 1 do
		local x = i + 0.5
		local top, bottom
		for k = 0, Ht * 4 do
			local y = k / 4
			if dist(x, y) <= r then
				top = top or y
				bottom = y
			end
		end
		if top then
			new("Frame", {
				Position = UDim2.fromOffset(flip and (Wt - i - 1.6) or i, top),
				Size = UDim2.fromOffset(1.6, math.max(bottom - top, 1)),
				BackgroundColor3 = color,
				BorderSizePixel = 0,
			}, box)
		end
	end
	return box
end

-- ikon lewati: batang + segitiga membulat
local function skipIcon(btn, forward)
	local h = 20
	local box = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(24, h),
		BackgroundTransparency = 1,
	}, btn)
	local tri = makeTri(box, 17, h, 3, WHITE, not forward)
	tri.Position = forward and UDim2.fromOffset(0, 0) or UDim2.fromOffset(7, 0)
	local bar = new("Frame", {
		Position = forward and UDim2.fromOffset(20, 0) or UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(4, h),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
	}, box)
	corner(bar, 2)
end
local shuffleBtn, shuffleBg = pillButton(main, "Acak", 12, UDim2.new(0, 14, 0, CY - 16), UDim2.fromOffset(62, 32), 16)
shuffleBtn.TextColor3 = GRAY
local repeatBtn, repeatBg = pillButton(main, "Ulang", 12, UDim2.new(1, -76, 0, CY - 16), UDim2.fromOffset(62, 32), 16)
repeatBtn.TextColor3 = GRAY
local prevBtn = textButton(main, "", 26, WHITE, Vector2.new(0.5, 0.5),
	UDim2.new(0, 108, 0, CY), UDim2.fromOffset(48, 48))
local nextBtn = textButton(main, "", 26, WHITE, Vector2.new(0.5, 0.5),
	UDim2.new(1, -108, 0, CY), UDim2.fromOffset(48, 48))
skipIcon(prevBtn, false)
skipIcon(nextBtn, true)

local playBg = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0, CY),
	Size = UDim2.fromOffset(58, 58),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
}, main)
corner(playBg, 29)
-- ikon play: segitiga bersudut membulat ala Spotify (digeser ke kanan agar terlihat di tengah)
local playGlyph = makeTri(playBg, 24, 26, 4, BLACK, false)
playGlyph.AnchorPoint = Vector2.new(0.5, 0.5)
playGlyph.Position = UDim2.new(0.5, 3, 0.5, 0)
-- ikon jeda: dua batang hitam
local pauseIcon = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(20, 24),
	BackgroundTransparency = 1,
	Visible = false,
}, playBg)
for _, x in ipairs({ 0, 13 }) do
	local bar = new("Frame", {
		Position = UDim2.fromOffset(x, 0),
		Size = UDim2.fromOffset(7, 24),
		BackgroundColor3 = BLACK,
		BorderSizePixel = 0,
	}, pauseIcon)
	corner(bar, 2)
end
local playBtn = textButton(playBg, "", 14, BLACK, nil, UDim2.new(), UDim2.fromScale(1, 1))

-- volume
label(main, "Vol", 12, FONT_BOLD, GRAY, UDim2.fromOffset(20, 268), UDim2.fromOffset(30, 22))
local volHit, volTrack, volFill, volKnob = makeBar(main, 279, 54, 62)
local volLabel = label(main, "50%", 12, FONT_BOLD, GRAY,
	UDim2.new(1, -56, 0, 268), UDim2.fromOffset(40, 22), Enum.TextXAlignment.Right)

-- baris fitur: timer tidur | kecepatan | antrian
local timerBtn, timerBg = pillButton(main, "Timer: Mati", 12, UDim2.fromOffset(12, 304), UDim2.fromOffset(96, 32), 16)
local speedBtn, speedBg = pillButton(main, "Kecepatan 1x", 12, UDim2.fromOffset(112, 304), UDim2.fromOffset(96, 32), 16)
local queueBtn, queueBg = pillButton(main, "Antrian: 0", 12, UDim2.fromOffset(212, 304), UDim2.fromOffset(96, 32), 16)

-- panel daftar lagu (menutupi sampul sampai info lagu)
local popup = new("Frame", {
	Position = UDim2.fromOffset(12, 48),
	Size = UDim2.new(1, -24, 0, 290),
	BackgroundColor3 = PANEL,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 20,
}, main)
corner(popup, 12)
stroke(popup, Color3.fromRGB(55, 55, 55), 1.2, 0.2)

local listTitle = label(popup, "Daftar lagu", 13, FONT_BOLD, WHITE,
	UDim2.fromOffset(12, 8), UDim2.new(0.4, 0, 0, 24))
listTitle.ZIndex = 21
local listInfo = label(popup, "", 10, FONT_MED, GRAY,
	UDim2.new(0.4, 0, 0, 8), UDim2.new(0.6, -80, 0, 24), Enum.TextXAlignment.Right)
listInfo.TextTruncate = Enum.TextTruncate.AtEnd
listInfo.ZIndex = 21
local exitBtn, exitBg = pillButton(popup, "Keluar", 11, UDim2.new(1, -68, 0, 8), UDim2.fromOffset(58, 24), 12)
exitBg.ZIndex = 21
exitBtn.ZIndex = 22

local listScroll = new("ScrollingFrame", {
	Position = UDim2.fromOffset(6, 40),
	Size = UDim2.new(1, -12, 1, -46),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 3,
	ScrollBarImageColor3 = GREEN,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	ZIndex = 21,
}, popup)
local emptyHint = label(popup, "", 12, FONT_MED, GRAY,
	UDim2.fromOffset(12, 60), UDim2.new(1, -24, 0, 100), Enum.TextXAlignment.Center)
emptyHint.TextWrapped = true
emptyHint.ZIndex = 21
emptyHint.Visible = false

-- drag jendela dari area header
do
	local dragging, dragStart, startPos
	main.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			local rel = Vector2.new(input.Position.X, input.Position.Y) - main.AbsolutePosition
			if rel.Y < 46 * uiScale.Scale then
				dragging = true
				dragStart = input.Position
				startPos = main.Position
			end
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - dragStart
			main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
				startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

-- ─── LOGIKA PEMUTAR ───────────────────────────────────────────────────────
local sound = new("Sound", {
	Name = SOUND_NAME,
	Volume = (tonumber(saved.volume) or START_VOLUME) * VOLUME_MAX,
	Looped = false,
}, SoundService)

local function setStatus(text, color)
	subLabel.Text = text
	subLabel.TextColor3 = color or GRAY
end

local function fmt(t)
	t = math.max(0, t or 0)
	return ("%d:%02d"):format(math.floor(t / 60), math.floor(t) % 60)
end

local function displayName(song)
	local n = song.name:gsub("%.[%w]+$", "")
	n = n:gsub("%s~%w+$", "") -- buang penanda id lagu online
	return n
end

-- "Judul - Artis" (lagu online) -> judul, artis
local function splitName(song)
	local base = displayName(song)
	local title, artist = base:match("^(.-) %- (.+)$")
	if title and artist then return title, artist end
	return base, nil
end

local function subFor(song)
	local _, artist = splitName(song)
	if artist then return artist .. " · " .. (song.source or "Lokal") end
	return song.source and ("Dari " .. song.source) or "Lagu lokal"
end

local function firstLetter(song)
	local ch = displayName(song):match("%w")
	return ch and ch:upper() or "M"
end

-- opsional: unduh lagu dari link langsung ke workspace
local function downloadConfigured()
	if type(writefile) ~= "function" then return end
	for _, item in ipairs(AUTO_DOWNLOAD) do
		local exists = false
		if type(isfile) == "function" then
			local ok, res = pcall(isfile, item.name)
			exists = ok and res
		end
		if not exists then
			setStatus("Mengunduh " .. item.name .. "...", GREEN)
			local ok, data = pcall(function() return game:HttpGet(item.url) end)
			if ok and type(data) == "string" and #data > 0 then
				pcall(writefile, item.name, data)
			else
				setStatus("Gagal mengunduh " .. item.name, ERR)
			end
		end
	end
end

-- ─── LAGU DARI GITHUB (music1.lua ... music15.lua) ────────────────────────
local repoSongs = {}

local function httpGet(url)
	local ok, res = pcall(function() return game:HttpGet(url) end)
	if ok and type(res) == "string" and res ~= "" then return res end
	local req = (syn and syn.request) or http_request or request
		or (http and http.request) or (fluxus and fluxus.request)
	if type(req) == "function" then
		local ok2, r = pcall(req, { Url = url, Method = "GET" })
		if ok2 and type(r) == "table" and (r.StatusCode == nil or r.StatusCode == 200)
			and type(r.Body) == "string" and r.Body ~= "" then
			return r.Body
		end
	end
	return nil
end

local B64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_LOOKUP = {}
for i = 1, 64 do
	B64_LOOKUP[B64_CHARS:byte(i)] = i - 1
end

local nativeB64 = (crypt and (crypt.base64decode or (crypt.base64 and crypt.base64.decode)))
	or base64_decode or (base64 and (base64.decode or base64.decode_str))
	or (syn and syn.crypt and syn.crypt.base64 and syn.crypt.base64.decode)

local function decodeBase64(data)
	if nativeB64 then
		local okN, res = pcall(nativeB64, data)
		if okN and type(res) == "string" and #res > 0 then return res end
	end
	data = (data:gsub("[^%w%+/]", ""))
	local out, n, len, i = {}, 0, #data, 1
	while i <= len - 3 do
		local a, b, c, d = data:byte(i, i + 3)
		local v = B64_LOOKUP[a] * 262144 + B64_LOOKUP[b] * 4096 + B64_LOOKUP[c] * 64 + B64_LOOKUP[d]
		n += 1
		out[n] = string.char(math.floor(v / 65536), math.floor(v / 256) % 256, v % 256)
		i += 4
		if n % 40000 == 0 then task.wait() end
	end
	local rem = len - i + 1
	if rem == 3 then
		local a, b, c = data:byte(i, i + 2)
		local v = B64_LOOKUP[a] * 262144 + B64_LOOKUP[b] * 4096 + B64_LOOKUP[c] * 64
		n += 1
		out[n] = string.char(math.floor(v / 65536), math.floor(v / 256) % 256)
	elseif rem == 2 then
		local a, b = data:byte(i, i + 1)
		local v = B64_LOOKUP[a] * 262144 + B64_LOOKUP[b] * 4096
		n += 1
		out[n] = string.char(math.floor(v / 65536))
	end
	return table.concat(out)
end

local function rawUrl(r, file)
	local folder = (r.folder and r.folder ~= "") and (r.folder .. "/") or ""
	local enc = file:gsub("[^%w%-_%.~]", function(c)
		return ("%%%02X"):format(c:byte())
	end)
	return ("https://raw.githubusercontent.com/%s/%s/%s/%s%s"):format(
		r.owner, r.repo, r.branch or "main", folder, enc)
end

-- nama file di GitHub -> nama lagu di UI ("Judul - Artis")
local NAMES_L = {}
for k, v in pairs(NAMES) do
	NAMES_L[(tostring(k):lower():gsub("%.%a+$", ""))] = v
end

local function repoDisplayName(file)
	local base = (file:gsub("%.%a+$", ""))
	local override = NAMES_L[base:lower()]
	if override and override ~= "" then return override end
	local num = base:lower():match("^music%s*(%d+)$")
	if num then return "Music " .. num end
	return (base:gsub("_", " "))
end

local function fetchRepoList()
	local items, seen, seenName = {}, {}, {}
	local function add(r, file, sha, optional)
		local lower = file:lower()
		if not (lower:match("%.lua$") or lower:match("%.txt$")) or EXCLUDE[lower] then return end
		local key = r.owner .. "/" .. r.repo .. "/" .. file
		if seen[key] then return end
		seen[key] = true
		local name = repoDisplayName(file)
		if seenName[name] then return end -- Music1.lua dan Music1.txt = lagu yang sama
		seenName[name] = true
		local safe = (file:gsub("%.%a+$", ""):gsub("[^%w%-_ ]", "_"))
		if sha and sha ~= "" then safe = safe .. "_" .. sha:sub(1, 7) end -- isi lagu diganti -> unduh ulang
		local alt = (file == lower) and rawUrl(r, (file:gsub("^%l", string.upper))) or rawUrl(r, lower)
		items[#items + 1] = {
			file = file,
			name = name .. ".mp3",
			path = SONG_DIR .. "/" .. safe .. ".mp3",
			url = rawUrl(r, file),
			altUrl = alt,
			optional = optional,
			source = "GitHub",
		}
	end

	for _, r in ipairs(REPOS) do
		local got = false
		-- 1) daftar file lewat GitHub API
		local apiUrl = ("https://api.github.com/repos/%s/%s/contents/%s?ref=%s"):format(
			r.owner, r.repo, r.folder or "", r.branch or "main")
		local body = httpGet(apiUrl)
		if body then
			local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
			if ok and type(data) == "table" then
				for _, item in ipairs(data) do
					if type(item) == "table" and item.type == "file" and item.name then
						add(r, item.name, item.sha)
						got = true
					end
				end
			end
		end
		-- 2) cadangan: index.txt (satu nama file per baris)
		if not got then
			local idx = httpGet(rawUrl(r, "index.txt"))
			if idx then
				for line in idx:gmatch("[^\r\n]+") do
					add(r, (line:gsub("^%s+", ""):gsub("%s+$", "")))
					got = true
				end
			end
		end
		-- 3) cadangan terakhir: music1.lua ... musicN.lua
		if not got then
			for i = 1, SLOTS do
				add(r, "music" .. i .. ".lua", nil, true)
			end
		end
	end

	table.sort(items, function(a, b)
		local na = tonumber(a.file:lower():match("^music(%d+)%.%a+$"))
		local nb = tonumber(b.file:lower():match("^music(%d+)%.%a+$"))
		if na and nb then return na < nb end
		if na then return true end
		if nb then return false end
		return a.file:lower() < b.file:lower()
	end)

	-- lagu dari link mp3 langsung
	for _, c in ipairs(EXTRA_SONGS) do
		local ext = c.url:lower():match("%.(%w+)$") or "mp3"
		local id = (c.url:match("([^/]+)%.%w+$") or tostring(#items + 1)):gsub("[^%w%-_]", "_")
		local base = c.title
		if c.artist and c.artist ~= "" then base = c.title .. " - " .. c.artist end
		items[#items + 1] = {
			file = c.title,
			name = base .. "." .. ext,
			path = SONG_DIR .. "/" .. id .. "_x." .. ext,
			url = c.url,
			altUrl = c.url,
			isAudio = true,
			source = "Link",
		}
	end
	return items
end

-- unduh file audio (biner): pakai request() dulu, cek ukuran vs Content-Length
local function binaryGet(url)
	local fn = (syn and syn.request) or http_request or request
		or (http and http.request) or (fluxus and fluxus.request)
	if type(fn) == "function" then
		local ok, r = pcall(fn, { Url = url, Method = "GET" })
		if ok and type(r) == "table" and type(r.Body) == "string"
			and (tonumber(r.StatusCode) or 200) >= 200 and (tonumber(r.StatusCode) or 200) < 300 then
			local want
			if type(r.Headers) == "table" then
				for k, v in pairs(r.Headers) do
					if tostring(k):lower() == "content-length" then want = tonumber(v) end
				end
			end
			return r.Body, want
		end
	end
	local ok, body = pcall(function() return game:HttpGet(url) end)
	if ok and type(body) == "string" and body ~= "" then return body, nil end
	return nil
end

-- unduh 1 file lagu (.lua), decode base64, simpan ke workspace. return true / nil, error
local function installRepoSong(song)
	if type(writefile) ~= "function" then
		return nil, "Executor tidak mendukung writefile"
	end
	if type(isfolder) == "function" and type(makefolder) == "function" then
		pcall(function()
			if not isfolder(SONG_DIR) then makefolder(SONG_DIR) end
		end)
	end
	if type(isfile) == "function" then
		local ok, exists = pcall(isfile, song.path)
		if ok and exists then return true end -- sudah ada di workspace
	end

	local src, wantLen
	if song.isAudio then
		src, wantLen = binaryGet(song.url)
	else
		src = httpGet(song.url)
		if not src and song.altUrl ~= song.url then src = httpGet(song.altUrl) end
	end
	if not src then return nil, "tidak ada di repo / link mati" end

	local bytes = src
	if song.isAudio then
		local head = bytes:sub(1, 4)
		local okHead = head:sub(1, 3) == "ID3" or head == "OggS" or head:byte(1) == 255
		if #bytes < 2000 or not okHead then return nil, "bukan file audio yang valid" end
		if wantLen and wantLen ~= #bytes then return nil, "unduhan terpotong" end
	else
		local chunk = loadstring(src)
		if not chunk then return nil, "file lagu rusak" end
		local okRun, data = pcall(chunk)
		if not okRun or type(data) ~= "table" or type(data.data) ~= "string" then
			return nil, "format file lagu salah"
		end
		bytes = decodeBase64(data.data)
		if data.size and #bytes ~= data.size then
			return nil, "ukuran file tidak cocok"
		end
	end
	if not pcall(writefile, song.path, bytes) then
		return nil, "gagal menyimpan ke workspace"
	end
	return true
end

-- siapkan 1 lagu (unduh kalau belum): dipakai pengunduh latar DAN tombol putar
local onSongState = function() end
local function ensureSong(song)
	if not song.source or song.state == "ready" then return true end
	if song.state == "loading" then
		while song.state == "loading" do task.wait(0.15) end
		return song.state == "ready", song.err
	end
	song.state = "loading"
	onSongState()
	local ok, err = installRepoSong(song)
	if ok then
		song.state, song.err = "ready", nil
	elseif song.optional then
		song.state = "gone"      -- slot cadangan yang filenya memang tidak ada
	else
		song.state, song.err = "error", err
	end
	onSongState()
	return ok, err
end

-- cari semua file mp3/ogg di folder workspace executor
local function getSongs()
	local list, seen = {}, {}
	local function add(name, path)
		local lower = name:lower()
		if (lower:match("%.mp3$") or lower:match("%.ogg$")) and not seen[name] then
			seen[name] = true
			list[#list + 1] = { name = name, path = path }
		end
	end

	for _, rs in ipairs(repoSongs) do
		if rs.state ~= "gone" and not seen[rs.name] then
			seen[rs.name] = true
			list[#list + 1] = rs
		end
	end

	if type(listfiles) == "function" then
		for _, folder in ipairs({ "", "workspace" }) do
			local ok, files = pcall(listfiles, folder)
			if ok and type(files) == "table" then
				for _, f in ipairs(files) do
					local path = tostring(f)
					add(path:match("([^/\\]+)$") or path, path)
				end
			end
		end
	end

	-- lagu bawaan: hanya kalau filenya ada (atau executor tidak bisa mengecek)
	if type(isfile) == "function" then
		local ok, exists = pcall(isfile, DEFAULT_SONG)
		if ok and exists then add(DEFAULT_SONG, DEFAULT_SONG) end
	elseif #list == 0 then
		add(DEFAULT_SONG, DEFAULT_SONG)
	end
	return list
end

-- ubah file menjadi aset yang bisa dimainkan Sound
local function resolveAsset(song)
	if type(getcustomasset) ~= "function" then
		return nil, "Executor tidak mendukung getcustomasset"
	end
	for _, path in ipairs({ song.path, song.name }) do
		local ok, asset = pcall(getcustomasset, path)
		if ok and type(asset) == "string" and asset ~= "" then
			return asset
		end
	end
	return nil, "File tidak ditemukan di workspace"
end

local songs = {}
local index = 1
local current = nil
local playToken = 0
local shuffleOn = saved.shuffle == true
local repeatMode = tonumber(saved.repeatMode) or 0   -- 0 mati | 1 semua | 2 satu lagu
local SPEEDS = { 1, 1.25, 1.5, 0.75 }
local speedIdx = math.clamp(tonumber(saved.speedIdx) or 1, 1, #SPEEDS)
local SLEEP_OPTS = { 0, 15, 30, 60 }                 -- menit
local sleepIdx, sleepAt = 1, nil
local queue = {}
local volumePct = math.clamp(tonumber(saved.volume) or START_VOLUME, 0, 1)
local userPicked = false
local updateNext, saveSettings
local seeking, seekRatio = false, 0

local function showNowPlaying()
	if current then
		titleLabel.Text = (splitName(current))
		artLetter.Text = firstLetter(current)
		local c = COVERS[((index - 1) % #COVERS) + 1]
		artGrad.Color = ColorSequence.new(c[1], c[2])
		tint.BackgroundColor3 = c[1]:Lerp(BG, 0.45)
	else
		titleLabel.Text = "Pilih lagu"
		artLetter.Text = "M"
		setStatus("Belum ada lagu diputar", GRAY)
	end
end

local function playSong(i)
	local song = songs[i]
	if not song then
		setStatus("Pilih lagu dulu", ERR)
		return
	end
	index, current, userPicked = i, song, true
	showNowPlaying()
	updateNext()

	playToken += 1
	local myToken = playToken

	sound:Stop()
	if song.source then
		if song.state ~= "ready" then setStatus("Menyiapkan lagu...", GREEN) end
		local okEnsure, errEnsure = ensureSong(song)
		if playToken ~= myToken then return end
		if not okEnsure then
			setStatus(errEnsure or "Gagal menyiapkan lagu", ERR)
			return
		end
	end

	local asset, err = resolveAsset(song)
	if not asset then
		sound:Stop()
		setStatus(err, ERR)
		return
	end

	sound:Stop()
	sound.SoundId = asset
	sound.Looped = (repeatMode == 2)
	sound.TimePosition = 0
	setStatus("Memuat...", GREEN)

	local t0 = os.clock()
	while not sound.IsLoaded and os.clock() - t0 < LOAD_TIMEOUT and playToken == myToken do
		task.wait(0.1)
	end
	if playToken ~= myToken then return end -- diganti lagu lain
	if not sound.IsLoaded then
		setStatus("Gagal memuat file", ERR)
		return
	end

	sound:Play()
	setStatus(subFor(current), GRAY)
	saveSettings()
end

local function toast(text)
	setStatus(text, GREEN)
	task.delay(1.6, function()
		if gui.Parent and current then setStatus(subFor(current), GRAY) end
	end)
end

function saveSettings()
	if type(writefile) ~= "function" then return end
	pcall(function()
		writefile(SETTINGS_FILE, HttpService:JSONEncode({
			volume = volumePct,
			shuffle = shuffleOn,
			repeatMode = repeatMode,
			speedIdx = speedIdx,
			last = current and current.name or nil,
		}))
	end)
end

local function findIndex(song)
	for i, sg in ipairs(songs) do
		if sg.name == song.name then return i end
	end
end

-- teks "Berikutnya" + penghitung antrian
function updateNext()
	local txt = ""
	if not current then
		txt = "Pilih lagu yang ingin di dengarkan di daftar"
	elseif repeatMode == 2 then
		txt = "Diulang: lagu ini terus"
	elseif #queue > 0 then
		txt = "Berikutnya (antrian): " .. (splitName(queue[1]))
	elseif shuffleOn and #songs > 1 then
		txt = "Berikutnya: acak"
	elseif #songs > 0 then
		if index >= #songs and repeatMode == 0 then
			txt = "Berikutnya: selesai (urutan habis)"
		else
			txt = "Berikutnya: " .. (splitName(songs[index % #songs + 1]))
		end
	end
	nextLabel.Text = txt
	queueBtn.Text = "Antrian: " .. #queue
	queueBtn.TextColor3 = #queue > 0 and GREEN or WHITE
end

-- auto = true -> lagu selesai sendiri (hormati mode ulang); false -> tombol next
local function pickNext(auto)
	if #songs == 0 then return nil end
	while #queue > 0 do
		local i = findIndex(table.remove(queue, 1))
		if i then return i end
	end
	if shuffleOn and #songs > 1 then
		local n = index
		while n == index do
			n = math.random(1, #songs)
		end
		return n
	end
	if auto and repeatMode == 0 and index >= #songs then return nil end
	return index % #songs + 1
end

local function nextSong(auto)
	if not current then toast("Pilih lagu dulu di daftar") return end
	local n = pickNext(auto)
	if n then
		playSong(n)
	else
		sound:Stop()
		setStatus("Selesai · semua lagu sudah diputar", GRAY)
		updateNext()
	end
end

local function prevSong()
	if not current then toast("Pilih lagu dulu di daftar") return end
	if #songs == 0 then return end
	if sound.TimePosition > 3 then
		sound.TimePosition = 0 -- seperti Spotify: lagu yang sudah jalan diulang dulu
		return
	end
	local p = index - 1
	if p < 1 then p = #songs end
	playSong(p)
end

-- lagu selesai -> antrian, lalu urutan / acak (kecuali mode ulang satu lagu)
sound.Ended:Connect(function()
	if gui.Parent and not sound.Looped then
		task.spawn(nextSong, true)
	end
end)

local showList
local function togglePlay()
	if not current then -- belum ada lagu dipilih: buka daftar
		showList()
		popup.Visible = true
		return
	end
	popup.Visible = false
	if sound.IsPlaying then
		sound:Pause()
	elseif sound.IsPaused then
		sound:Resume()
	else
		task.spawn(playSong, index)
	end
end
playBtn.MouseButton1Click:Connect(togglePlay)
nextBtn.MouseButton1Click:Connect(function()
	popup.Visible = false
	task.spawn(nextSong, false)
end)
prevBtn.MouseButton1Click:Connect(function()
	popup.Visible = false
	task.spawn(prevSong)
end)

shuffleBtn.MouseButton1Click:Connect(function()
	shuffleOn = not shuffleOn
	shuffleBtn.TextColor3 = shuffleOn and GREEN or GRAY
	updateNext()
	saveSettings()
	toast(shuffleOn and "Acak: nyala" or "Acak: mati")
end)

local function applyRepeatUI()
	repeatBtn.Text = repeatMode == 2 and "Ulang 1" or "Ulang"
	repeatBtn.TextColor3 = repeatMode > 0 and GREEN or GRAY
	sound.Looped = (repeatMode == 2)
	updateNext()
end
repeatBtn.MouseButton1Click:Connect(function()
	repeatMode = (repeatMode + 1) % 3
	applyRepeatUI()
	saveSettings()
	toast(({ [0] = "Ulang: mati (berhenti di lagu terakhir)", [1] = "Ulang: semua lagu", [2] = "Ulang: satu lagu" })[repeatMode])
end)

local function applySpeedUI()
	sound.PlaybackSpeed = SPEEDS[speedIdx]
	speedBtn.Text = ("Kecepatan %gx"):format(SPEEDS[speedIdx])
	speedBtn.TextColor3 = SPEEDS[speedIdx] ~= 1 and GREEN or WHITE
end
speedBtn.MouseButton1Click:Connect(function()
	speedIdx = speedIdx % #SPEEDS + 1
	applySpeedUI()
	saveSettings()
end)

timerBtn.MouseButton1Click:Connect(function()
	sleepIdx = sleepIdx % #SLEEP_OPTS + 1
	local mins = SLEEP_OPTS[sleepIdx]
	if mins > 0 then
		sleepAt = os.clock() + mins * 60
		timerBtn.Text = ("Timer: %dm"):format(mins)
		timerBtn.TextColor3 = GREEN
		toast(("Musik berhenti otomatis dalam %d menit"):format(mins))
	else
		sleepAt = nil
		timerBtn.Text = "Timer: Mati"
		timerBtn.TextColor3 = WHITE
	end
end)

queueBtn.MouseButton1Click:Connect(function()
	if #queue > 0 then
		queue = {}
		updateNext()
		toast("Antrian dikosongkan")
	else
		toast("Antrian kosong · tekan + di daftar")
	end
end)

-- ─── DAFTAR LAGU ──────────────────────────────────────────────────────────
local function renderRows(items, emptyText)
	for _, c in ipairs(listScroll:GetChildren()) do
		if c:IsA("TextButton") then c:Destroy() end
	end
	emptyHint.Text = emptyText
	emptyHint.Visible = #items == 0
	listScroll.CanvasSize = UDim2.new(0, 0, 0, #items * 58)

	for i, item in ipairs(items) do
		local row = new("TextButton", {
			AutoButtonColor = false,
			Position = UDim2.fromOffset(0, (i - 1) * 58),
			Size = UDim2.new(1, -6, 0, 54),
			BackgroundColor3 = BTN,
			BackgroundTransparency = item.current and 0.4 or 1,
			Text = "",
			BorderSizePixel = 0,
			ZIndex = 22,
		}, listScroll)
		corner(row, 8)

		local thumb = new("Frame", {
			Position = UDim2.fromOffset(7, 7),
			Size = UDim2.fromOffset(40, 40),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			ZIndex = 23,
		}, row)
		corner(thumb, 6)
		gradient(thumb, GREEN, Color3.fromRGB(14, 60, 36), 45)
		label(thumb, (item.title:match("%w") or "M"):upper(), 18, FONT_BOLD, WHITE,
			UDim2.new(), UDim2.fromScale(1, 1), Enum.TextXAlignment.Center).ZIndex = 24

		local t = label(row, item.title, 14, FONT_BOLD, item.current and GREEN or WHITE,
			UDim2.fromOffset(56, 7), UDim2.new(1, -102, 0, 20))
		t.TextTruncate = Enum.TextTruncate.AtEnd
		t.ZIndex = 23
		local sb = label(row, item.sub, 11, FONT_MED, GRAY,
			UDim2.fromOffset(56, 29), UDim2.new(1, -102, 0, 16))
		sb.TextTruncate = Enum.TextTruncate.AtEnd
		sb.ZIndex = 23

		-- tombol + : masukkan ke antrian (diputar setelah lagu ini selesai)
		local qBg = new("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -6, 0.5, 0),
			Size = UDim2.fromOffset(34, 34),
			BackgroundColor3 = BTN,
			BorderSizePixel = 0,
			ZIndex = 23,
		}, row)
		corner(qBg, 17)
		local qBtn = textButton(qBg, "+", 24, GREEN, nil, UDim2.new(), UDim2.fromScale(1, 1))
		qBtn.ZIndex = 24
		qBtn.MouseButton1Click:Connect(item.onQueue)

		row.MouseButton1Click:Connect(item.onClick)
	end
end

function showList()
	songs = getSongs()
	if current then
		local i = findIndex(current)
		if i then index = i end
	end
	local items = {}
	for i, sg in ipairs(songs) do
		local title = splitName(sg)
		local sub = subFor(sg)
		if sg.state == "pending" then sub = "Menunggu unduhan..."
		elseif sg.state == "loading" then sub = "Mengunduh..."
		elseif sg.state == "error" then sub = "Gagal · ketuk untuk coba lagi" end
		items[#items + 1] = {
			title = title,
			sub = sub,
			current = current and current.name == sg.name,
			onClick = function()
				popup.Visible = false
				task.spawn(playSong, i)
			end,
			onQueue = function()
				queue[#queue + 1] = sg
				updateNext()
				listInfo.Text = "+ antrian: " .. title
			end,
		}
	end
	renderRows(items, "Belum ada lagu.\nTunggu lagu disalin dari GitHub,\natau taruh mp3 di folder workspace.")
	listInfo.Text = #songs .. " lagu"
end

listBtn.MouseButton1Click:Connect(function()
	if popup.Visible then
		popup.Visible = false
	else
		showList()
		popup.Visible = true
	end
end)

-- pintasan keyboard
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not gui.Parent then return end
	if input.KeyCode == Enum.KeyCode.RightBracket then
		task.spawn(nextSong, false)
	elseif input.KeyCode == Enum.KeyCode.LeftBracket then
		task.spawn(prevSong)
	elseif input.KeyCode == Enum.KeyCode.BackSlash then
		togglePlay()
	end
end)

-- terapkan pengaturan tersimpan
shuffleBtn.TextColor3 = shuffleOn and GREEN or GRAY
applyRepeatUI()
applySpeedUI()

-- ─── SLIDER: VOLUME (langsung mengubah sound.Volume) & PROGRES (seek) ─────
local function applyVolume(p)
	volumePct = math.clamp(p, 0, 1)
	sound.Volume = volumePct * VOLUME_MAX
	setFill(volFill, volKnob, volumePct)
	volLabel.Text = math.floor(volumePct * 100 + 0.5) .. "%"
end
makeSlider(volHit, volTrack, applyVolume, saveSettings)
applyVolume(volumePct)

makeSlider(progHit, progTrack, function(r)
	seeking = true
	seekRatio = r
	setFill(progFill, progKnob, r)
	curLabel.Text = fmt(r * sound.TimeLength)
end, function()
	seeking = false
	if sound.TimeLength > 0 then
		sound.TimePosition = seekRatio * sound.TimeLength
	end
end)

-- ─── GELEMBUNG MINI (muncul saat tombol X ditekan) ───────────────────────
local bubbleMoved = false
local bubble = new("Frame", {
	Name = "Bubble",
	Size = UDim2.fromOffset(52, 52),
	Position = UDim2.new(0, 8, 0.5, -26),
	BackgroundColor3 = Color3.fromRGB(8, 8, 8),
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 60,
}, gui)
corner(bubble, 26)
local bubbleStroke = stroke(bubble, GREEN, 1.2, 0.4)
local eqBars = {}
for i = 1, 3 do
	local bar = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromOffset(16 + (i - 1) * 10, 37),
		Size = UDim2.fromOffset(5, 8),
		BackgroundColor3 = GREEN,
		BorderSizePixel = 0,
		ZIndex = 61,
	}, bubble)
	corner(bar, 2)
	eqBars[i] = bar
end
local bubbleHit = new("TextButton", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "",
	ZIndex = 62,
}, bubble)

local savedMainPos
local function minimize()
	popup.Visible = false
	savedMainPos = main.Position
	if not bubbleMoved then
		bubble.Position = UDim2.new(0, 8, 0.5, -26) -- sisi kiri layar
	end
	main.Visible = false
	bubble.Visible = true
end

local function restore()
	if savedMainPos then main.Position = savedMainPos end
	bubble.Visible = false
	main.Visible = true
end

-- gelembung: tap = buka lagi, seret = pindahkan
do
	local down, moved, dragStart, startPos = false, false, nil, nil
	bubbleHit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			down, moved = true, false
			dragStart, startPos = input.Position, bubble.Position
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if down and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - dragStart
			if d.Magnitude > 6 then moved, bubbleMoved = true, true end
			if moved then
				bubble.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
					startPos.Y.Scale, startPos.Y.Offset + d.Y)
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if down and (input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch) then
			down = false
			if not moved then restore() end
		end
	end)
end

-- tombol X = kecilkan jadi gelembung (musik tetap jalan)
closeBtn.MouseButton1Click:Connect(minimize)

-- tombol Keluar (di panel daftar) = hentikan dan hapus semuanya
exitBtn.MouseButton1Click:Connect(function()
	playToken += 1
	saveSettings()
	pcall(function()
		sound:Stop()
		sound:Destroy()
	end)
	gui:Destroy()
end)

-- pembaruan tampilan: progres, waktu, ikon play/jeda, gelembung, timer tidur
task.spawn(function()
	while gui.Parent do
		local playing = sound.IsPlaying
		if main.Visible and not seeking then
			local len, pos = sound.TimeLength, sound.TimePosition
			setFill(progFill, progKnob, len > 0 and pos / len or 0)
			curLabel.Text = fmt(pos)
			totLabel.Text = fmt(len)
		end
		pauseIcon.Visible = playing
		playGlyph.Visible = not playing

		if bubble.Visible then
			local t = os.clock()
			for i, bar in ipairs(eqBars) do
				local h = playing and (6 + 16 * math.abs(math.sin(t * (2.5 + i) + i))) or 6
				bar.Size = UDim2.fromOffset(5, h)
			end
			bubbleStroke.Transparency = playing and 0.1 or 0.5
		end

		if sleepAt then
			local left = sleepAt - os.clock()
			if left <= 0 then
				sleepAt, sleepIdx = nil, 1
				timerBtn.Text = "Timer: Mati"
				timerBtn.TextColor3 = WHITE
				if sound.IsPlaying then sound:Pause() end
				toast("Timer tidur selesai · musik dijeda")
			else
				timerBtn.Text = ("Timer: %dm"):format(math.ceil(left / 60))
			end
		end
		task.wait(0.1)
	end
end)

-- mulai: salin semua lagu GitHub ke workspace, lalu siap diputar
local function refreshSongs()
	songs = getSongs()
	if current then
		local i = findIndex(current)
		if i then index = i end
	end
	updateNext()
end

task.spawn(function()
	downloadConfigured()
	refreshSongs()
	showNowPlaying()

	if type(getcustomasset) ~= "function" then
		setStatus("Executor tidak mendukung getcustomasset", ERR)
		return
	end
	if type(writefile) ~= "function" then
		setStatus("Executor tidak mendukung writefile", ERR)
		return
	end

	-- pesan proses hanya tampil kalau tidak sedang memutar lagu
	local function info(text, color)
		if gui.Parent and not sound.IsPlaying then setStatus(text, color) end
	end

	info("Memuat daftar lagu...", GREEN)
	local items = fetchRepoList()

	-- 1) semua lagu langsung masuk daftar (yang sudah ada di workspace langsung "siap")
	for _, song in ipairs(items) do
		song.state = "pending"
		if type(isfile) == "function" then
			local okf, exists = pcall(isfile, song.path)
			if okf and exists then song.state = "ready" end
		end
		repoSongs[#repoSongs + 1] = song
	end
	onSongState = function()
		if gui.Parent and popup.Visible then showList() end
	end
	refreshSongs()
	if popup.Visible then showList() end

	-- 2) unduh di latar: 3 lagu sekaligus. Lagu yang ditekan play diunduh duluan.
	local total, cursor, finished, workers = #items, 1, 0, 3
	local function worker()
		while gui.Parent and cursor <= total do
			local song = items[cursor]
			cursor += 1
			if song.state == "pending" then
				local okE, errE = ensureSong(song)
				if not okE and not song.optional then
					warn("[Music] " .. song.file .. ": " .. tostring(errE))
				end
				refreshSongs()
			end
			finished += 1
			info(("Menyalin lagu %d/%d..."):format(finished, total), GREEN)
		end
	end
	for _ = 1, workers do
		task.spawn(function()
			worker()
			workers -= 1
		end)
	end
	while workers > 0 and gui.Parent do
		task.wait(0.2)
	end
	if not gui.Parent then return end

	refreshSongs()
	if popup.Visible then showList() end
	local ready, failed = 0, 0
	for _, song in ipairs(items) do
		if song.state == "ready" then ready += 1
		elseif song.state == "error" then failed += 1 end
	end
	if #songs == 0 then
		info("Tidak ada lagu (cek repo / workspace)", ERR)
	elseif failed > 0 then
		info(("%d lagu siap, %d gagal"):format(ready, failed), ERR)
	else
		info(current and subFor(current) or (("%d lagu siap · pilih di daftar"):format(ready)), GRAY)
	end
end)
