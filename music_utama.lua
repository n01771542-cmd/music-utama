--[[
  Music Player (gaya Spotify) | 300x368
  - Lagu dari GitHub (music1.lua … music15.lua, base64) → workspace → getcustomasset
  - Nama lagu di-hardcode di SONG_META (ubah di situ saja)
  - X = minimize ke orb hitam + outline hijau, suara tetap jalan
  - Daftar hanya lokal (online dihapus)
  - Repeat: Off → One → All | Shuffle | Next/Prev | Volume
]]

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local HttpService       = game:GetService("HttpService")
local SoundService      = game:GetService("SoundService")
local CoreGui           = game:GetService("CoreGui")
local TweenService      = game:GetService("TweenService")

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = player:WaitForChild("PlayerGui", 8)

-- ═══════════════════════════════════════════════════════════════════════════
-- CONFIG  (ubah di sini)
-- ═══════════════════════════════════════════════════════════════════════════
local GUI_NAME      = "SpotifyStylePlayer"
local SOUND_NAME    = "SpotifyStyleSound"
local ORB_NAME      = "SpotifyStyleOrb"
local W, H          = 300, 350
local START_VOLUME  = 0.6
local VOLUME_MAX    = 5
local LOAD_TIMEOUT  = 8
local SONG_DIR      = "MusicPlayerSongs"
local SLOTS         = 15
local EXCLUDE       = { ["music.lua"] = true, ["music_player.lua"] = true }

local REPOS = {
	{ owner = "n01771542-cmd", repo = "music_penyimpanan", branch = "main", folder = "" },
}

--[[
  NAMA LAGU  — ubah di sini saja.
  Key = nama file di GitHub (music1.lua, music2.lua, …)
  title / artist = yang tampil di UI
]]
local SONG_META = {
	["music1.lua"]  = { title = "Lagu Satu",     artist = "Artis A" },
	["music2.lua"]  = { title = "Lagu Dua",      artist = "Artis B" },
	["music3.lua"]  = { title = "Lagu Tiga",     artist = "Artis C" },
	["music4.lua"]  = { title = "Lagu Empat",    artist = "Artis D" },
	["music5.lua"]  = { title = "Lagu Lima",     artist = "Artis E" },
	["music6.lua"]  = { title = "Lagu Enam",     artist = "Artis F" },
	["music7.lua"]  = { title = "Lagu Tujuh",    artist = "Artis G" },
	["music8.lua"]  = { title = "Lagu Delapan",  artist = "Artis H" },
	["music9.lua"]  = { title = "Lagu Sembilan", artist = "Artis I" },
	["music10.lua"] = { title = "Lagu Sepuluh",  artist = "Artis J" },
	["music11.lua"] = { title = "Lagu Sebelas",  artist = "Artis K" },
	["music12.lua"] = { title = "Lagu Dua Belas",artist = "Artis L" },
	["music13.lua"] = { title = "Lagu Tiga Belas",artist = "Artis M" },
	["music14.lua"] = { title = "Lagu Empat Belas",artist = "Artis N" },
	["music15.lua"] = { title = "Lagu Lima Belas", artist = "Artis O" },
}

-- ═══════════════════════════════════════════════════════════════════════════
-- PALETTE
-- ═══════════════════════════════════════════════════════════════════════════
local BG    = Color3.fromRGB(18, 18, 18)
local PANEL = Color3.fromRGB(24, 24, 24)
local BTN   = Color3.fromRGB(40, 40, 40)
local GREEN = Color3.fromRGB(29, 185, 84)
local WHITE = Color3.fromRGB(255, 255, 255)
local BLACK = Color3.fromRGB(0, 0, 0)
local GRAY  = Color3.fromRGB(179, 179, 179)
local DIM   = Color3.fromRGB(83, 83, 83)
local ERR   = Color3.fromRGB(255, 120, 120)

local FONT_BOLD = Enum.Font.GothamBold
local FONT_MED  = Enum.Font.GothamMedium

-- ═══════════════════════════════════════════════════════════════════════════
-- UI HELPERS
-- ═══════════════════════════════════════════════════════════════════════════
local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props) do inst[k] = v end
	if parent then inst.Parent = parent end
	return inst
end

local function corner(p, r)
	return new("UICorner", { CornerRadius = UDim.new(0, r) }, p)
end

local function stroke(p, color, thick, trans)
	return new("UIStroke", {
		Color = color,
		Thickness = thick or 1,
		Transparency = trans or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, p)
end

local function gradient(p, c0, c1, rot)
	return new("UIGradient", {
		Color = ColorSequence.new(c0, c1),
		Rotation = rot or 0,
	}, p)
end

local function label(p, text, size, font, color, pos, sz, alignX)
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
		BorderSizePixel = 0,
	}, p)
end

local function textBtn(p, text, size, color, anchor, pos, sz)
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
	}, p)
end

local function pillBtn(p, text, size, pos, sz, radius)
	local bg = new("Frame", {
		Position = pos,
		Size = sz,
		BackgroundColor3 = BTN,
		BorderSizePixel = 0,
	}, p)
	corner(bg, radius)
	local btn = textBtn(bg, text, size, WHITE, nil, UDim2.new(), UDim2.fromScale(1, 1))
	return btn, bg
end

-- ═══════════════════════════════════════════════════════════════════════════
-- CLEAN OLD
-- ═══════════════════════════════════════════════════════════════════════════
for _, root in ipairs({ CoreGui, playerGui, SoundService }) do
	pcall(function()
		if not root then return end
		local g = root:FindFirstChild(GUI_NAME)
		if g then g:Destroy() end
		local o = root:FindFirstChild(ORB_NAME)
		if o then o:Destroy() end
		local s = root:FindFirstChild(SOUND_NAME)
		if s then s:Stop() s:Destroy() end
	end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ROOT GUI
-- ═══════════════════════════════════════════════════════════════════════════
local gui = new("ScreenGui", {
	Name = GUI_NAME,
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	IgnoreGuiInset = true,
	DisplayOrder = 50,
})
if not pcall(function() gui.Parent = CoreGui end) or not gui.Parent then
	gui.Parent = playerGui
end

-- ─── MAIN WINDOW ───────────────────────────────────────────────────────────
local main = new("Frame", {
	Name = "Main",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -24, 0.5, 0), -- muncul di kanan layar
	Size = UDim2.fromOffset(W, H),
	BackgroundColor3 = BG,
	BorderSizePixel = 0,
	ClipsDescendants = true,
}, gui)
corner(main, 14)
stroke(main, Color3.fromRGB(55, 55, 55), 1.5, 0.2)

-- Header
local listBtn = pillBtn(main, "Daftar", 12, UDim2.fromOffset(12, 8), UDim2.fromOffset(66, 28), 14)
label(main, "SEDANG DIPUTAR", 10, FONT_BOLD, GRAY,
	UDim2.fromOffset(84, 8), UDim2.new(1, -84 - 52, 0, 28), Enum.TextXAlignment.Center)
local closeBtn = pillBtn(main, "X", 22, UDim2.new(1, -46, 0, 5), UDim2.fromOffset(34, 34), 17)

-- Album art
local art = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 46),
	Size = UDim2.fromOffset(128, 128),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
}, main)
corner(art, 10)
gradient(art, GREEN, Color3.fromRGB(14, 60, 36), 45)
local artLetter = label(art, "M", 54, FONT_BOLD, WHITE,
	UDim2.new(), UDim2.fromScale(1, 1), Enum.TextXAlignment.Center)

-- Title / sub
local titleLabel = label(main, "Tidak ada lagu", 17, FONT_BOLD, WHITE,
	UDim2.fromOffset(20, 182), UDim2.new(1, -40, 0, 22))
titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
local subLabel = label(main, "Lagu lokal", 12, FONT_MED, GRAY,
	UDim2.fromOffset(20, 204), UDim2.new(1, -40, 0, 16))
subLabel.TextTruncate = Enum.TextTruncate.AtEnd

-- Progress / volume bar factory
local function setFill(fill, knob, ratio)
	ratio = math.clamp(ratio, 0, 1)
	fill.Size = UDim2.new(ratio, 0, 1, 0)
	knob.Position = UDim2.new(ratio, 0, 0.5, 0)
end

local function makeBar(parent, y, x0, x1Off)
	local hit = new("TextButton", {
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Text = "",
		Position = UDim2.fromOffset(x0 - 8, y - 10),
		Size = UDim2.new(1, -(x0 - 8) - (x1Off - 8), 0, 24),
		BorderSizePixel = 0,
	}, parent)
	local track = new("Frame", {
		Position = UDim2.fromOffset(x0, y),
		Size = UDim2.new(1, -x0 - x1Off, 0, 4),
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
		Size = UDim2.fromOffset(12, 12),
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

-- Progress
local progHit, progTrack, progFill, progKnob = makeBar(main, 236, 20, 20)
progFill.BackgroundColor3 = GREEN
local curLabel = label(main, "0:00", 10, FONT_MED, GRAY,
	UDim2.fromOffset(20, 246), UDim2.new(0.5, -20, 0, 14))
local totLabel = label(main, "0:00", 10, FONT_MED, GRAY,
	UDim2.new(0.5, 0, 0, 246), UDim2.new(0.5, -20, 0, 14), Enum.TextXAlignment.Right)

-- Controls row (symmetric, play lebih besar & halus)
local CTRL_Y = 298
local shuffleBtn = textBtn(main, "Acak", 11, GRAY, Vector2.new(0.5, 0.5),
	UDim2.new(0, 36, 0, CTRL_Y), UDim2.fromOffset(48, 36))
local prevBtn = textBtn(main, "|<", 20, WHITE, Vector2.new(0.5, 0.5),
	UDim2.new(0, 90, 0, CTRL_Y), UDim2.fromOffset(44, 36))
local nextBtn = textBtn(main, ">|", 20, WHITE, Vector2.new(0.5, 0.5),
	UDim2.new(1, -90, 0, CTRL_Y), UDim2.fromOffset(44, 36))
local repeatBtn = textBtn(main, "Ulang", 11, GRAY, Vector2.new(0.5, 0.5),
	UDim2.new(1, -36, 0, CTRL_Y), UDim2.fromOffset(48, 36))

local playBg = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0, CTRL_Y),
	Size = UDim2.fromOffset(64, 64),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
}, main)
corner(playBg, 32)
-- soft green ring
stroke(playBg, GREEN, 1.5, 0.55)

local playGlyph = label(playBg, "▶", 28, FONT_BOLD, BLACK,
	UDim2.fromOffset(2, 0), UDim2.fromScale(1, 1), Enum.TextXAlignment.Center)
local pauseIcon = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(18, 20),
	BackgroundTransparency = 1,
	Visible = false,
}, playBg)
for _, x in ipairs({ 0, 12 }) do
	local bar = new("Frame", {
		Position = UDim2.fromOffset(x, 0),
		Size = UDim2.fromOffset(6, 20),
		BackgroundColor3 = BLACK,
		BorderSizePixel = 0,
	}, pauseIcon)
	corner(bar, 2)
end
local playBtn = textBtn(playBg, "", 14, BLACK, nil, UDim2.new(), UDim2.fromScale(1, 1))

-- Volume
local volTitle = label(main, "Vol", 10, FONT_BOLD, GRAY,
	UDim2.fromOffset(20, 338), UDim2.fromOffset(28, 20))
local volHit, volTrack, volFill, volKnob = makeBar(main, 348, 50, 56)
local volLabel = label(main, "60%", 10, FONT_BOLD, GRAY,
	UDim2.new(1, -48, 0, 338), UDim2.fromOffset(32, 20), Enum.TextXAlignment.Right)

-- ─── SONG LIST POPUP (lokal only) ──────────────────────────────────────────
local popup = new("Frame", {
	Position = UDim2.fromOffset(12, 44),
	Size = UDim2.new(1, -24, 0, 214),
	BackgroundColor3 = PANEL,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 20,
}, main)
corner(popup, 12)
stroke(popup, Color3.fromRGB(55, 55, 55), 1.2, 0.2)

local listHeader = label(popup, "DAFTAR LAGU", 12, FONT_BOLD, GRAY,
	UDim2.fromOffset(12, 10), UDim2.new(1, -24, 0, 20), Enum.TextXAlignment.Center)
listHeader.ZIndex = 21

local listScroll = new("ScrollingFrame", {
	Position = UDim2.fromOffset(6, 36),
	Size = UDim2.new(1, -12, 1, -44),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 3,
	ScrollBarImageColor3 = GREEN,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	ZIndex = 21,
}, popup)

local emptyHint = label(popup, "", 12, FONT_MED, GRAY,
	UDim2.fromOffset(12, 70), UDim2.new(1, -24, 0, 100), Enum.TextXAlignment.Center)
emptyHint.TextWrapped = true
emptyHint.ZIndex = 21
emptyHint.Visible = false

-- Drag main from header
do
	local dragging, dragStart, startPos
	main.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			local rel = Vector2.new(input.Position.X, input.Position.Y) - main.AbsolutePosition
			if rel.Y < 42 then
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
			main.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + d.X,
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

-- ─── FLOATING ORB / TOGGLE (kiri layar) ────────────────────────────────────
local orb = new("Frame", {
	Name = ORB_NAME,
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 16, 0.5, 0), -- kiri tengah
	Size = UDim2.fromOffset(56, 56),
	BackgroundColor3 = BLACK,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 100,
}, gui)
corner(orb, 28)
local orbStroke = stroke(orb, GREEN, 2.5, 0.25)
local orbLetter = label(orb, "♪", 24, FONT_BOLD, GREEN,
	UDim2.new(), UDim2.fromScale(1, 1), Enum.TextXAlignment.Center)
orbLetter.ZIndex = 101

-- soft pulse on orb stroke
task.spawn(function()
	local t = 0
	while gui.Parent do
		if orb.Visible then
			t += 0.04
			orbStroke.Transparency = 0.2 + 0.15 * math.sin(t)
		end
		task.wait(0.05)
	end
end)

-- drag orb
do
	local dragging, dragStart, startPos
	orb.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = orb.Position
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - dragStart
			orb.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + d.X,
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

-- ═══════════════════════════════════════════════════════════════════════════
-- PLAYER STATE
-- ═══════════════════════════════════════════════════════════════════════════
local sound = new("Sound", {
	Name = SOUND_NAME,
	Volume = START_VOLUME * VOLUME_MAX,
	Looped = false,
}, SoundService)

local songs      = {}
local repoSongs  = {}
local index      = 1
local current    = nil
local playToken  = 0
local shuffleOn  = false
local repeatMode = 0   -- 0 Off | 1 One | 2 All
local seeking    = false
local seekRatio  = 0
local muted      = false
local lastVol    = START_VOLUME

local function setStatus(text, color)
	subLabel.Text = text
	subLabel.TextColor3 = color or GRAY
end

local function fmt(t)
	t = math.max(0, t or 0)
	return ("%d:%02d"):format(math.floor(t / 60), math.floor(t) % 60)
end

local function metaFor(song)
	if song.meta then return song.meta end
	return { title = song.name:gsub("%.[%w]+$", ""), artist = nil }
end

local function showNowPlaying()
	if current then
		local m = metaFor(current)
		titleLabel.Text = m.title
		artLetter.Text = (m.title:match("%w") or "M"):upper()
		orbLetter.Text = artLetter.Text
	else
		titleLabel.Text = "Tidak ada lagu"
		artLetter.Text = "M"
		orbLetter.Text = "♪"
		setStatus("Taruh mp3 di workspace / cek repo", ERR)
	end
end

-- ─── HTTP / BASE64 ─────────────────────────────────────────────────────────
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
for i = 1, 64 do B64_LOOKUP[B64_CHARS:byte(i)] = i - 1 end

local function decodeBase64(data)
	data = data:gsub("[^%w%+/]", "")
	local out, n, len, i = {}, 0, #data, 1
	while i <= len - 3 do
		local a, b, c, d = data:byte(i, i + 3)
		local v = B64_LOOKUP[a] * 262144 + B64_LOOKUP[b] * 4096 + B64_LOOKUP[c] * 64 + B64_LOOKUP[d]
		n += 1
		out[n] = string.char(math.floor(v / 65536), math.floor(v / 256) % 256, v % 256)
		i += 4
		if n % 5000 == 0 then task.wait() end
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
	local enc = file:gsub("[^%w%-_%.~]", function(c) return ("%%%02X"):format(c:byte()) end)
	return ("https://raw.githubusercontent.com/%s/%s/%s/%s%s"):format(
		r.owner, r.repo, r.branch or "main", folder, enc)
end

local function fetchRepoList()
	local items, seen = {}, {}
	local function add(r, file, sha, optional)
		local lower = file:lower()
		if not lower:match("%.lua$") or EXCLUDE[lower] then return end
		local key = r.owner .. "/" .. r.repo .. "/" .. file
		if seen[key] then return end
		seen[key] = true

		local meta = SONG_META[file] or SONG_META[lower]
			or { title = file:gsub("%.[Ll][Uu][Aa]$", ""):gsub("_", " "), artist = nil }

		local safe = (meta.title:gsub("[^%w%-_ ]", "")):sub(1, 40)
		if sha and sha ~= "" then safe = safe .. "_" .. sha:sub(1, 7) end

		items[#items + 1] = {
			file     = file,
			name     = meta.title .. ".mp3",
			path     = SONG_DIR .. "/" .. safe .. ".mp3",
			url      = rawUrl(r, file),
			altUrl   = rawUrl(r, lower),
			optional = optional,
			source   = "GitHub",
			meta     = meta,
		}
	end

	for _, r in ipairs(REPOS) do
		local got = false
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
		if not got then
			local idx = httpGet(rawUrl(r, "index.txt"))
			if idx then
				for line in idx:gmatch("[^\r\n]+") do
					add(r, line:gsub("^%s+", ""):gsub("%s+$", ""))
					got = true
				end
			end
		end
		if not got then
			for i = 1, SLOTS do
				add(r, "music" .. i .. ".lua", nil, true)
			end
		end
	end

	table.sort(items, function(a, b)
		local na = tonumber(a.file:lower():match("^music(%d+)%.lua$"))
		local nb = tonumber(b.file:lower():match("^music(%d+)%.lua$"))
		if na and nb then return na < nb end
		if na then return true end
		if nb then return false end
		return a.file:lower() < b.file:lower()
	end)
	return items
end

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
		if ok and exists then return true end
	end

	local src = httpGet(song.url)
	if not src and song.altUrl ~= song.url then src = httpGet(song.altUrl) end
	if not src then return nil, "tidak ada di repo" end

	local chunk = loadstring(src)
	if not chunk then return nil, "file lagu rusak" end
	local okRun, data = pcall(chunk)
	if not okRun or type(data) ~= "table" or type(data.data) ~= "string" then
		return nil, "format file lagu salah"
	end
	local bytes = decodeBase64(data.data)
	if data.size and #bytes ~= data.size then
		return nil, "ukuran file tidak cocok"
	end
	if not pcall(writefile, song.path, bytes) then
		return nil, "gagal menyimpan ke workspace"
	end
	return true
end

local function getSongs()
	local list, seen = {}, {}
	local function add(entry)
		if not seen[entry.name] then
			seen[entry.name] = true
			list[#list + 1] = entry
		end
	end
	for _, rs in ipairs(repoSongs) do add(rs) end

	if type(listfiles) == "function" then
		for _, folder in ipairs({ "", "workspace", SONG_DIR }) do
			local ok, files = pcall(listfiles, folder)
			if ok and type(files) == "table" then
				for _, f in ipairs(files) do
					local path = tostring(f)
					local name = path:match("([^/\\]+)$") or path
					local lower = name:lower()
					if (lower:match("%.mp3$") or lower:match("%.ogg$")) and not seen[name] then
						seen[name] = true
						list[#list + 1] = {
							name = name,
							path = path,
							meta = { title = name:gsub("%.[%w]+$", ""), artist = nil },
						}
					end
				end
			end
		end
	end
	return list
end

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

-- ─── PLAYBACK ──────────────────────────────────────────────────────────────
local function playSong(i)
	local song = songs[i]
	if not song then
		setStatus("Pilih lagu dulu", ERR)
		return
	end
	index, current = i, song
	showNowPlaying()

	playToken += 1
	local myToken = playToken

	local asset, err = resolveAsset(song)
	if not asset then
		sound:Stop()
		setStatus(err, ERR)
		return
	end

	sound:Stop()
	sound.SoundId = asset
	sound.Looped = (repeatMode == 1)
	sound.TimePosition = 0
	setStatus("Memuat...", GREEN)

	local t0 = os.clock()
	while not sound.IsLoaded and os.clock() - t0 < LOAD_TIMEOUT and playToken == myToken do
		task.wait(0.1)
	end
	if playToken ~= myToken then return end
	if not sound.IsLoaded then
		setStatus("Gagal memuat file", ERR)
		return
	end

	sound:Play()
	local m = metaFor(current)
	setStatus(m.artist and (m.artist .. " · GitHub") or "Dari GitHub", GRAY)
end

local function pickNext()
	if #songs == 0 then return nil end
	if shuffleOn and #songs > 1 then
		local n = index
		while n == index do n = math.random(1, #songs) end
		return n
	end
	if repeatMode == 2 then
		return index % #songs + 1
	end
	if index < #songs then
		return index + 1
	end
	return nil  -- end of list, stop
end

local function nextSong()
	local n = pickNext()
	if n then playSong(n) end
end

local function prevSong()
	if #songs == 0 then return end
	if sound.TimePosition > 3 then
		sound.TimePosition = 0
		return
	end
	local p = index - 1
	if p < 1 then p = #songs end
	playSong(p)
end

sound.Ended:Connect(function()
	if not gui.Parent then return end
	if repeatMode == 1 then
		-- already Looped, but safety
		sound.TimePosition = 0
		sound:Play()
		return
	end
	task.spawn(nextSong)
end)

-- ─── CONTROLS ──────────────────────────────────────────────────────────────
playBtn.MouseButton1Click:Connect(function()
	popup.Visible = false
	if sound.IsPlaying then
		sound:Pause()
	elseif sound.IsPaused then
		sound:Resume()
	else
		task.spawn(playSong, index)
	end
end)

nextBtn.MouseButton1Click:Connect(function()
	popup.Visible = false
	task.spawn(nextSong)
end)
prevBtn.MouseButton1Click:Connect(function()
	popup.Visible = false
	task.spawn(prevSong)
end)

shuffleBtn.MouseButton1Click:Connect(function()
	shuffleOn = not shuffleOn
	shuffleBtn.TextColor3 = shuffleOn and GREEN or GRAY
end)

-- Repeat cycle: Off → One → All → Off
local REPEAT_LABEL = { [0] = "Ulang", [1] = "1x", [2] = "All" }
repeatBtn.MouseButton1Click:Connect(function()
	repeatMode = (repeatMode + 1) % 3
	sound.Looped = (repeatMode == 1)
	repeatBtn.Text = REPEAT_LABEL[repeatMode]
	repeatBtn.TextColor3 = repeatMode > 0 and GREEN or GRAY
end)

-- Mute toggle
volTitle.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		muted = not muted
		if muted then
			lastVol = sound.Volume / VOLUME_MAX
			sound.Volume = 0
			volLabel.Text = "Mute"
			volTitle.TextColor3 = ERR
		else
			sound.Volume = lastVol * VOLUME_MAX
			volLabel.Text = math.floor(lastVol * 100 + 0.5) .. "%"
			volTitle.TextColor3 = GRAY
			setFill(volFill, volKnob, lastVol)
		end
	end
end)

-- ─── LIST RENDER ───────────────────────────────────────────────────────────
local function renderList()
	for _, c in ipairs(listScroll:GetChildren()) do
		if c:IsA("TextButton") then c:Destroy() end
	end
	emptyHint.Visible = #songs == 0
	emptyHint.Text = "Belum ada lagu.\nPastikan repo / workspace berisi mp3."
	listScroll.CanvasSize = UDim2.new(0, 0, 0, #songs * 48)

	for i, sg in ipairs(songs) do
		local m = metaFor(sg)
		local isCur = current and current.name == sg.name
		local row = new("TextButton", {
			AutoButtonColor = false,
			Position = UDim2.fromOffset(0, (i - 1) * 48),
			Size = UDim2.new(1, -6, 0, 44),
			BackgroundColor3 = BTN,
			BackgroundTransparency = isCur and 0.35 or 1,
			Text = "",
			BorderSizePixel = 0,
			ZIndex = 22,
		}, listScroll)
		corner(row, 8)

		local thumb = new("Frame", {
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.fromOffset(32, 32),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			ZIndex = 23,
		}, row)
		corner(thumb, 6)
		gradient(thumb, GREEN, Color3.fromRGB(14, 60, 36), 45)
		label(thumb, (m.title:match("%w") or "M"):upper(), 14, FONT_BOLD, WHITE,
			UDim2.new(), UDim2.fromScale(1, 1), Enum.TextXAlignment.Center).ZIndex = 24

		local t = label(row, m.title, 13, FONT_BOLD, isCur and GREEN or WHITE,
			UDim2.fromOffset(46, 4), UDim2.new(1, -54, 0, 20))
		t.TextTruncate = Enum.TextTruncate.AtEnd
		t.ZIndex = 23
		local sb = label(row, m.artist or "Lokal", 10, FONT_MED, GRAY,
			UDim2.fromOffset(46, 22), UDim2.new(1, -54, 0, 16))
		sb.TextTruncate = Enum.TextTruncate.AtEnd
		sb.ZIndex = 23

		row.MouseButton1Click:Connect(function()
			popup.Visible = false
			task.spawn(playSong, i)
		end)
	end
end

listBtn.MouseButton1Click:Connect(function()
	if popup.Visible then
		popup.Visible = false
	else
		songs = getSongs()
		renderList()
		popup.Visible = true
	end
end)

-- ─── VOLUME & PROGRESS ─────────────────────────────────────────────────────
local volumePct = START_VOLUME
local function applyVolume(p)
	if muted then return end
	volumePct = math.clamp(p, 0, 1)
	sound.Volume = volumePct * VOLUME_MAX
	setFill(volFill, volKnob, volumePct)
	volLabel.Text = math.floor(volumePct * 100 + 0.5) .. "%"
end
makeSlider(volHit, volTrack, applyVolume, nil)
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

-- UI tick
task.spawn(function()
	while gui.Parent do
		if not seeking then
			local len, pos = sound.TimeLength, sound.TimePosition
			setFill(progFill, progKnob, len > 0 and pos / len or 0)
			curLabel.Text = fmt(pos)
			totLabel.Text = fmt(len)
		end
		local playing = sound.IsPlaying
		pauseIcon.Visible = playing
		playGlyph.Visible = not playing
		task.wait(0.1)
	end
end)

-- ─── MINIMIZE / RESTORE ────────────────────────────────────────────────────
local function minimize()
	popup.Visible = false
	main.Visible = false
	orb.Visible = true
	-- keep sound running
end

local function restore()
	orb.Visible = false
	main.Visible = true
end

closeBtn.MouseButton1Click:Connect(minimize)

local orbBtn = textBtn(orb, "", 1, WHITE, nil, UDim2.new(), UDim2.fromScale(1, 1))
orbBtn.ZIndex = 102
orbBtn.MouseButton1Click:Connect(restore)

-- ─── BOOT ──────────────────────────────────────────────────────────────────
local function refreshSongs()
	songs = getSongs()
	if current then
		for i, sg in ipairs(songs) do
			if sg.name == current.name then index = i end
		end
	else
		index = 1
		current = songs[1]
		showNowPlaying()
	end
end

task.spawn(function()
	songs = getSongs()
	index = 1
	current = songs[1]
	showNowPlaying()

	if type(getcustomasset) ~= "function" then
		setStatus("Executor tidak mendukung getcustomasset", ERR)
		return
	end
	if type(writefile) ~= "function" then
		setStatus("Executor tidak mendukung writefile", ERR)
		return
	end

	local function info(text, color)
		if gui.Parent and not sound.IsPlaying then setStatus(text, color) end
	end

	info("Memuat daftar lagu...", GREEN)
	local items = fetchRepoList()
	local total, ok, failed = #items, 0, 0
	for i, song in ipairs(items) do
		if not gui.Parent then return end
		info(("Menyalin lagu %d/%d..."):format(i, total), GREEN)
		local done, err = installRepoSong(song)
		if done then
			ok += 1
			repoSongs[#repoSongs + 1] = song
			refreshSongs()
		elseif not song.optional then
			failed += 1
			warn("[Music] " .. song.file .. ": " .. tostring(err))
		end
	end
	if not gui.Parent then return end

	refreshSongs()
	if popup.Visible then renderList() end
	if #songs == 0 then
		info("Tidak ada lagu (cek repo / workspace)", ERR)
	elseif failed > 0 then
		info(("%d lagu siap, %d gagal"):format(ok, failed), ERR)
	else
		info(current and (metaFor(current).artist or "Siap") or "Siap", GRAY)
	end
end)
