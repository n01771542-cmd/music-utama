-- Music Player (gaya Spotify) | 300x368 | ringan, tanpa data lagu di dalam script
-- Lagu diambil dari GitHub (music1.lua ... music15.lua, mp3 embedded base64), otomatis
-- disalin ke folder workspace executor, lalu diputar lewat getcustomasset.
-- Lagu online (Audius) dan mp3 lokal di workspace tetap bisa dipakai.
-- Hanya kamu yang mendengar (suara diputar di sisi client).
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
local W, H = 300, 368
local DEFAULT_SONG = "lagu1.mp3"   -- lagu bawaan (hanya muncul kalau filenya ada di workspace)
local START_VOLUME = 0.6           -- posisi awal slider volume (0 - 1)
local VOLUME_MAX = 5               -- slider 100% = Volume 5 di Roblox (20% = Volume 1 = normal). Maks Roblox: 10
local AUDIUS_HOST = "https://api.audius.co" -- layanan musik terbuka untuk cari lagu online
local AUDIUS_API_KEY = ""          -- isi kalau Audius meminta API key (daftar di audius.co/settings)
local APP_NAME = "RobloxMusicPlayer"
local SEARCH_LIMIT = 15
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
local EXCLUDE = { ["music.lua"] = true, ["music_player.lua"] = true }

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

-- header: [Daftar]  SEDANG DIPUTAR  [X]
local listBtn = pillButton(main, "Daftar", 12, UDim2.fromOffset(12, 8), UDim2.fromOffset(66, 28), 14)
label(main, "SEDANG DIPUTAR", 10, FONT_BOLD, GRAY,
	UDim2.fromOffset(84, 8), UDim2.new(1, -84 - 52, 0, 28), Enum.TextXAlignment.Center)
local closeBtn = pillButton(main, "X", 22, UDim2.new(1, -46, 0, 5), UDim2.fromOffset(34, 34), 17)

-- sampul (placeholder: gradasi hijau + huruf pertama judul)
local art = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 46),
	Size = UDim2.fromOffset(128, 128),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
}, main)
corner(art, 10)
gradient(art, GREEN, Color3.fromRGB(14, 60, 36), 45)
local artLetter = label(art, "M", 54, FONT_BOLD, WHITE, UDim2.new(), UDim2.fromScale(1, 1), Enum.TextXAlignment.Center)

-- judul + keterangan
local titleLabel = label(main, "Tidak ada lagu", 17, FONT_BOLD, WHITE,
	UDim2.fromOffset(20, 182), UDim2.new(1, -40, 0, 22))
titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
local subLabel = label(main, "Lagu lokal", 12, FONT_MED, GRAY,
	UDim2.fromOffset(20, 204), UDim2.new(1, -40, 0, 16))
subLabel.TextTruncate = Enum.TextTruncate.AtEnd

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
		Position = UDim2.fromOffset(x0 - 8, y - 10),
		Size = UDim2.new(1, -(x0 - 8) - (x1Offset - 8), 0, 24),
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

-- progres lagu
local progHit, progTrack, progFill, progKnob = makeBar(main, 236, 20, 20)
progFill.BackgroundColor3 = GREEN
local curLabel = label(main, "0:00", 10, FONT_MED, GRAY,
	UDim2.fromOffset(20, 246), UDim2.new(0.5, -20, 0, 14))
local totLabel = label(main, "0:00", 10, FONT_MED, GRAY,
	UDim2.new(0.5, 0, 0, 246), UDim2.new(0.5, -20, 0, 14), Enum.TextXAlignment.Right)

-- tombol kontrol: Acak | prev | PLAY | next | Ulang
local shuffleBtn = textButton(main, "Acak", 11, GRAY, Vector2.new(0.5, 0.5),
	UDim2.new(0, 36, 0, 292), UDim2.fromOffset(52, 36))
local prevBtn = textButton(main, "|<", 20, WHITE, Vector2.new(0.5, 0.5),
	UDim2.new(0, 94, 0, 292), UDim2.fromOffset(48, 36))
local nextBtn = textButton(main, ">|", 20, WHITE, Vector2.new(0.5, 0.5),
	UDim2.new(1, -94, 0, 292), UDim2.fromOffset(48, 36))
local repeatBtn = textButton(main, "Ulang", 11, GRAY, Vector2.new(0.5, 0.5),
	UDim2.new(1, -36, 0, 292), UDim2.fromOffset(52, 36))

local playBg = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0, 292),
	Size = UDim2.fromOffset(52, 52),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
}, main)
corner(playBg, 26)
local playGlyph = label(playBg, "▶", 22, FONT_BOLD, BLACK,
	UDim2.fromOffset(3, 0), UDim2.fromScale(1, 1), Enum.TextXAlignment.Center)
-- ikon jeda: dua batang hitam
local pauseIcon = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(16, 18),
	BackgroundTransparency = 1,
	Visible = false,
}, playBg)
for _, x in ipairs({ 0, 10 }) do
	local bar = new("Frame", {
		Position = UDim2.fromOffset(x, 0),
		Size = UDim2.fromOffset(6, 18),
		BackgroundColor3 = BLACK,
		BorderSizePixel = 0,
	}, pauseIcon)
	corner(bar, 2)
end
local playBtn = textButton(playBg, "", 14, BLACK, nil, UDim2.new(), UDim2.fromScale(1, 1))

-- volume
label(main, "Vol", 10, FONT_BOLD, GRAY, UDim2.fromOffset(20, 330), UDim2.fromOffset(24, 20))
local volHit, volTrack, volFill, volKnob = makeBar(main, 340, 48, 56)
local volLabel = label(main, "50%", 10, FONT_BOLD, GRAY,
	UDim2.new(1, -48, 0, 330), UDim2.fromOffset(32, 20), Enum.TextXAlignment.Right)

-- panel daftar lagu: kotak cari + tab Lokal / Online (menutupi sampul sampai kontrol)
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

local searchBox = new("TextBox", {
	Position = UDim2.fromOffset(8, 8),
	Size = UDim2.new(1, -86, 0, 30),
	BackgroundColor3 = BTN,
	BorderSizePixel = 0,
	Text = "",
	PlaceholderText = "Cari lagu online...",
	PlaceholderColor3 = GRAY,
	TextColor3 = WHITE,
	TextSize = 12,
	Font = FONT_MED,
	TextXAlignment = Enum.TextXAlignment.Left,
	ClearTextOnFocus = false,
	ZIndex = 21,
}, popup)
corner(searchBox, 8)
new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, searchBox)

local searchGo = new("Frame", {
	Position = UDim2.new(1, -70, 0, 8),
	Size = UDim2.fromOffset(62, 30),
	BackgroundColor3 = GREEN,
	BorderSizePixel = 0,
	ZIndex = 21,
}, popup)
corner(searchGo, 8)
local searchGoBtn = textButton(searchGo, "Cari", 12, BLACK, nil, UDim2.new(), UDim2.fromScale(1, 1))
searchGoBtn.ZIndex = 22

local tabLocal = textButton(popup, "Lokal", 12, GREEN, nil, UDim2.fromOffset(8, 44), UDim2.fromOffset(60, 22))
tabLocal.ZIndex = 21
local tabOnline = textButton(popup, "Online", 12, GRAY, nil, UDim2.fromOffset(70, 44), UDim2.fromOffset(60, 22))
tabOnline.ZIndex = 21
local listInfo = label(popup, "", 10, FONT_MED, GRAY,
	UDim2.new(0, 134, 0, 44), UDim2.new(1, -142, 0, 22), Enum.TextXAlignment.Right)
listInfo.TextTruncate = Enum.TextTruncate.AtEnd
listInfo.ZIndex = 21

local listScroll = new("ScrollingFrame", {
	Position = UDim2.fromOffset(6, 70),
	Size = UDim2.new(1, -12, 1, -76),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 3,
	ScrollBarImageColor3 = GREEN,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	ZIndex = 21,
}, popup)
local emptyHint = label(popup, "", 12, FONT_MED, GRAY,
	UDim2.fromOffset(12, 80), UDim2.new(1, -24, 0, 100), Enum.TextXAlignment.Center)
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
	Volume = START_VOLUME * VOLUME_MAX,
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
	if artist then return artist .. " · " .. (song.source or "Audius") end
	return song.source and "Dari GitHub" or "Lagu lokal"
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

local function decodeBase64(data)
	data = (data:gsub("[^%w%+/]", ""))
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
	local enc = file:gsub("[^%w%-_%.~]", function(c)
		return ("%%%02X"):format(c:byte())
	end)
	return ("https://raw.githubusercontent.com/%s/%s/%s/%s%s"):format(
		r.owner, r.repo, r.branch or "main", folder, enc)
end

-- nama file di GitHub -> nama lagu di UI ("Judul - Artis")
local function repoDisplayName(file)
	local base = (file:gsub("%.[Ll][Uu][Aa]$", ""))
	local num = base:lower():match("^music%s*(%d+)$")
	if num then return "Music " .. num end
	return (base:gsub("_", " "))
end

local function fetchRepoList()
	local items, seen = {}, {}
	local function add(r, file, sha, optional)
		local lower = file:lower()
		if not lower:match("%.lua$") or EXCLUDE[lower] then return end
		local key = r.owner .. "/" .. r.repo .. "/" .. file
		if seen[key] then return end
		seen[key] = true
		local name = repoDisplayName(file)
		local safe = (name:gsub("[^%w%-_ ]", "_"))
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
		local na = tonumber(a.file:lower():match("^music(%d+)%.lua$"))
		local nb = tonumber(b.file:lower():match("^music(%d+)%.lua$"))
		if na and nb then return na < nb end
		if na then return true end
		if nb then return false end
		return a.file:lower() < b.file:lower()
	end)
	return items
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
		if not seen[rs.name] then
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
local shuffleOn, repeatOn = false, false
local seeking, seekRatio = false, 0

local function showNowPlaying()
	if current then
		titleLabel.Text = (splitName(current))
		artLetter.Text = firstLetter(current)
	else
		titleLabel.Text = "Tidak ada lagu"
		artLetter.Text = "M"
		setStatus("Taruh mp3 di folder workspace", ERR)
	end
end

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
	sound.Looped = repeatOn
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
end

local function pickNext()
	if #songs == 0 then return nil end
	if shuffleOn and #songs > 1 then
		local n = index
		while n == index do
			n = math.random(1, #songs)
		end
		return n
	end
	return index % #songs + 1
end

local function nextSong()
	local n = pickNext()
	if n then playSong(n) end
end

local function prevSong()
	if #songs == 0 then return end
	if sound.TimePosition > 3 then
		sound.TimePosition = 0 -- seperti Spotify: lagu yang sudah jalan diulang dulu
		return
	end
	local p = index - 1
	if p < 1 then p = #songs end
	playSong(p)
end

-- lagu selesai -> otomatis lanjut (kalau tidak diulang)
sound.Ended:Connect(function()
	if gui.Parent and not sound.Looped then
		task.spawn(nextSong)
	end
end)

-- tombol utama: jeda / lanjut / mulai
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
repeatBtn.MouseButton1Click:Connect(function()
	repeatOn = not repeatOn
	sound.Looped = repeatOn
	repeatBtn.TextColor3 = repeatOn and GREEN or GRAY
end)

-- ─── DAFTAR LAGU: LOKAL + ONLINE (Audius) ─────────────────────────────────
local mode = "local"
local onlineResults = {}

-- HTTP untuk API (kirim API key kalau ada, baca kode status)
local function apiGet(url)
	local fn = (syn and syn.request) or http_request or request
	if fn then
		local headers = nil
		if AUDIUS_API_KEY ~= "" then
			headers = { Authorization = "Bearer " .. AUDIUS_API_KEY }
		end
		local ok, res = pcall(fn, { Url = url, Method = "GET", Headers = headers })
		if ok and type(res) == "table" then
			local code = tonumber(res.StatusCode) or 200
			if code >= 200 and code < 300 and type(res.Body) == "string" then
				return res.Body
			end
			return nil, code
		end
	end
	local ok, body = pcall(function() return game:HttpGet(url) end)
	if ok and type(body) == "string" then return body end
	return nil
end

-- HTTP untuk mengunduh file audio
local function fileGet(url)
	local ok, body = pcall(function() return game:HttpGet(url) end)
	if ok and type(body) == "string" and #body > 0 then return body end
	local fn = (syn and syn.request) or http_request or request
	if fn then
		local ok2, res = pcall(fn, { Url = url, Method = "GET" })
		if ok2 and type(res) == "table" and type(res.Body) == "string" then
			local code = tonumber(res.StatusCode) or 200
			if code >= 200 and code < 300 then return res.Body end
		end
	end
	return nil
end

local function searchTracks(query)
	local url = ("%s/v1/tracks/search?query=%s&limit=%d&app_name=%s"):format(
		AUDIUS_HOST, HttpService:UrlEncode(query), SEARCH_LIMIT, APP_NAME)
	local body, code = apiGet(url)
	if not body then
		if code == 401 or code == 403 then
			return nil, "Audius minta API key (isi AUDIUS_API_KEY)"
		end
		return nil, "Gagal terhubung ke Audius"
	end
	local ok, decoded = pcall(function() return HttpService:JSONDecode(body) end)
	if not ok or type(decoded) ~= "table" or type(decoded.data) ~= "table" then
		return nil, "Balasan Audius tidak dikenali"
	end
	local list = {}
	for _, t in ipairs(decoded.data) do
		if t.id and t.title and t.is_streamable ~= false then
			list[#list + 1] = {
				id = tostring(t.id),
				title = tostring(t.title),
				artist = type(t.user) == "table" and tostring(t.user.name or "?") or "?",
				duration = tonumber(t.duration) or 0,
			}
		end
	end
	return list
end

-- nama file aman: "Judul - Artis ~id.mp3"
local function cleanName(str, maxLen, fallback)
	local x = tostring(str):gsub("[^%w%s%-_%(%)]", ""):gsub("%s+", " ")
	x = x:match("^%s*(.-)%s*$")
	if x == "" then x = fallback end
	return x:sub(1, maxLen)
end

local function fileNameFor(tr)
	return cleanName(tr.title, 30, "Lagu") .. " - " .. cleanName(tr.artist, 20, "Audius") .. " ~" .. tr.id .. ".mp3"
end

-- unduh lagu online ke workspace (otomatis masuk folder workspace)
local function downloadTrack(tr)
	if type(writefile) ~= "function" then
		return nil, "Executor tidak mendukung writefile"
	end
	local name = fileNameFor(tr)
	if type(isfile) == "function" then
		local ok, exists = pcall(isfile, name)
		if ok and exists then return name end -- sudah pernah diunduh
	end

	local streamUrl
	local meta = apiGet(("%s/v1/tracks/%s/stream?app_name=%s&no_redirect=true"):format(AUDIUS_HOST, tr.id, APP_NAME))
	if meta then
		local ok, d = pcall(function() return HttpService:JSONDecode(meta) end)
		if ok and type(d) == "table" and type(d.data) == "string" then
			streamUrl = d.data
		end
	end
	streamUrl = streamUrl or ("%s/v1/tracks/%s/stream?app_name=%s"):format(AUDIUS_HOST, tr.id, APP_NAME)

	local audio = fileGet(streamUrl)
	if not audio or #audio < 2000 then
		return nil, "Gagal mengunduh lagu"
	end
	local first = audio:sub(1, 1)
	if first == "{" or first == "<" then
		return nil, "Audius tidak memberi file audio"
	end
	if not pcall(writefile, name, audio) then
		return nil, "Gagal menyimpan ke workspace"
	end
	return name
end

local function playOnline(tr)
	popup.Visible = false
	titleLabel.Text = tr.title
	artLetter.Text = (tr.title:match("%w") or "M"):upper()
	setStatus("Mengunduh...", GREEN)
	local name, err = downloadTrack(tr)
	if not name then
		setStatus(err, ERR)
		return
	end
	songs = getSongs()
	for i, sg in ipairs(songs) do
		if sg.name == name then
			playSong(i)
			return
		end
	end
	-- executor tanpa listfiles: tambahkan manual ke daftar
	songs[#songs + 1] = { name = name, path = name }
	playSong(#songs)
end

-- baris daftar (dipakai tab Lokal dan Online)
local function renderRows(items, emptyText)
	for _, c in ipairs(listScroll:GetChildren()) do
		if c:IsA("TextButton") then c:Destroy() end
	end
	emptyHint.Text = emptyText
	emptyHint.Visible = #items == 0
	listScroll.CanvasSize = UDim2.new(0, 0, 0, #items * 48)

	for i, item in ipairs(items) do
		local row = new("TextButton", {
			AutoButtonColor = false,
			Position = UDim2.fromOffset(0, (i - 1) * 48),
			Size = UDim2.new(1, -6, 0, 44),
			BackgroundColor3 = BTN,
			BackgroundTransparency = item.current and 0.4 or 1,
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
		label(thumb, (item.title:match("%w") or "M"):upper(), 15, FONT_BOLD, WHITE,
			UDim2.new(), UDim2.fromScale(1, 1), Enum.TextXAlignment.Center).ZIndex = 24

		local t = label(row, item.title, 13, FONT_BOLD, item.current and GREEN or WHITE,
			UDim2.fromOffset(46, 4), UDim2.new(1, -54, 0, 20))
		t.TextTruncate = Enum.TextTruncate.AtEnd
		t.ZIndex = 23
		local sb = label(row, item.sub, 10, FONT_MED, GRAY,
			UDim2.fromOffset(46, 22), UDim2.new(1, -54, 0, 16))
		sb.TextTruncate = Enum.TextTruncate.AtEnd
		sb.ZIndex = 23

		row.MouseButton1Click:Connect(item.onClick)
	end
end

local function setTabs()
	tabLocal.TextColor3 = mode == "local" and GREEN or GRAY
	tabOnline.TextColor3 = mode == "online" and GREEN or GRAY
end

local function showLocal()
	mode = "local"
	setTabs()
	listInfo.Text = ""
	songs = getSongs()
	if current then
		for i, sg in ipairs(songs) do
			if sg.name == current.name then index = i end
		end
	end
	local items = {}
	for i, sg in ipairs(songs) do
		local title = splitName(sg)
		local _, artist = splitName(sg)
		items[#items + 1] = {
			title = title,
			sub = (artist or sg.source) and subFor(sg) or (sg.name:match("%.(%w+)$") or "mp3"):upper(),
			current = current and current.name == sg.name,
			onClick = function()
				popup.Visible = false
				task.spawn(playSong, i)
			end,
		}
	end
	renderRows(items, "Belum ada lagu di workspace.\nTaruh mp3 di folder workspace, atau cari online lewat kotak di atas.")
end

local function showOnline()
	mode = "online"
	setTabs()
	local items = {}
	for _, tr in ipairs(onlineResults) do
		items[#items + 1] = {
			title = tr.title,
			sub = tr.artist .. " · " .. fmt(tr.duration),
			current = false,
			onClick = function() task.spawn(playOnline, tr) end,
		}
	end
	renderRows(items, "Ketik judul atau nama artis,\nlalu tekan Cari.")
end

local function doSearch()
	local q = searchBox.Text:match("^%s*(.-)%s*$")
	if q == "" then
		listInfo.Text = "Ketik judul/artis dulu"
		return
	end
	listInfo.Text = "Mencari..."
	local res, err = searchTracks(q)
	if not res then
		onlineResults = {}
		showOnline()
		listInfo.Text = err
		return
	end
	onlineResults = res
	showOnline()
	listInfo.Text = #res .. " hasil · via Audius"
	if #res == 0 then emptyHint.Text = "Tidak ada hasil untuk \"" .. q .. "\"" end
end

searchGoBtn.MouseButton1Click:Connect(function() task.spawn(doSearch) end)
searchBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then task.spawn(doSearch) end
end)
tabLocal.MouseButton1Click:Connect(showLocal)
tabOnline.MouseButton1Click:Connect(showOnline)

listBtn.MouseButton1Click:Connect(function()
	if popup.Visible then
		popup.Visible = false
	else
		if mode == "online" then showOnline() else showLocal() end
		popup.Visible = true
	end
end)

-- ─── SLIDER: VOLUME (langsung mengubah sound.Volume) & PROGRES (seek) ─────
local volumePct = START_VOLUME
local function applyVolume(p)
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

-- pembaruan tampilan: progres, waktu, ikon play/jeda
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

-- tutup: hentikan dan hapus suara
closeBtn.MouseButton1Click:Connect(function()
	playToken += 1
	pcall(function()
		sound:Stop()
		sound:Destroy()
	end)
	gui:Destroy()
end)

-- mulai: salin semua lagu GitHub ke workspace, lalu siap diputar
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
	downloadConfigured()
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

	-- pesan proses hanya tampil kalau tidak sedang memutar lagu
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
	if popup.Visible then
		if mode == "online" then showOnline() else showLocal() end
	end
	if #songs == 0 then
		info("Tidak ada lagu (cek repo / workspace)", ERR)
	elseif failed > 0 then
		info(("%d lagu siap, %d gagal"):format(ok, failed), ERR)
	else
		info(current and subFor(current) or "Siap", GRAY)
	end
end)
