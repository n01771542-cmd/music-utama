-- Music Player (ambil lagu dari GitHub repository) | UI hitam + biru halus | 280x320
-- Setiap lagu = 1 file .lua di repository (berisi mp3 base64 / embedded).
-- Saat dipilih: file diunduh, di-decode, disimpan ke folder workspace executor, lalu diputar
-- lewat getcustomasset. Hanya kamu yang mendengar (client side).

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
if not player then
	player = Players.PlayerAdded:Wait()
end
local playerGui = player:WaitForChild("PlayerGui", 8)

-- ─── CONFIG ───────────────────────────────────────────────────────────────
-- Isi daftar repository tempat file lagu (.lua) disimpan. Boleh lebih dari satu.
local REPOS = {
	-- folder = "" artinya file Music1.lua, Music2.lua, ... ada di root repository
	{ owner = "n01771542-cmd", repo = "music_penyimpanan", branch = "main", folder = "" },
	-- tambah repository lain di sini kalau perlu:
	-- { owner = "...", repo = "...", branch = "main", folder = "" },
}

local GUI_NAME = "MusicPlayerUI"
local SOUND_NAME = "MusicPlayerSound"
local TITLE = "Music player"
local W, H = 280, 320
local SONG_DIR = "MusicPlayerSongs" -- folder di workspace executor
local LOOP = true
local START_VOLUME = 0.5
local VOLUME_STEP = 0.1
local MAX_ROWS = 4
local LOAD_TIMEOUT = 8

-- ─── PALETTE ──────────────────────────────────────────────────────────────
local WHITE     = Color3.fromRGB(255, 255, 255)
local ACCENT_HI = Color3.fromRGB(90, 170, 255)
local SOFT_BLUE = Color3.fromRGB(55, 125, 235)
local SUB_TEXT  = Color3.fromRGB(160, 180, 210)
local MUTED     = Color3.fromRGB(100, 120, 150)
local BG_BLACK  = Color3.fromRGB(0, 0, 0)
local CARD_BG   = Color3.fromRGB(14, 16, 22)
local LINE      = Color3.fromRGB(45, 50, 62)
local OK_GREEN  = Color3.fromRGB(110, 240, 160)
local ERR_RED   = Color3.fromRGB(255, 120, 120)

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

local function smallButton(parent, text, textSize, pos, size)
	local bg = new("Frame", {
		Position = pos,
		Size = size,
		BackgroundColor3 = Color3.fromRGB(24, 28, 40),
		BorderSizePixel = 0,
	}, parent)
	corner(bg, 8)
	stroke(bg, SOFT_BLUE, 1.2, 0.25)
	local btn = new("TextButton", {
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = text,
		TextSize = textSize,
		Font = FONT_BOLD,
		TextColor3 = WHITE,
		BorderSizePixel = 0,
	}, bg)
	return btn, bg
end

-- ─── GUI ──────────────────────────────────────────────────────────────────
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
	BackgroundColor3 = BG_BLACK,
	BorderSizePixel = 0,
	ClipsDescendants = true,
}, gui)
corner(main, 14)
stroke(main, SOFT_BLUE, 1.5, 0.35)

label(main, TITLE, 18, FONT_BOLD, WHITE,
	UDim2.fromOffset(16, 14), UDim2.new(1, -84, 0, 26))
label(main, "Lagu diambil dari repository", 11, FONT_MED, MUTED,
	UDim2.fromOffset(16, 40), UDim2.new(1, -84, 0, 16))

local closeBtn = smallButton(main, "X", 28,
	UDim2.new(1, -60, 0, 12), UDim2.fromOffset(46, 46))

local card = new("Frame", {
	Position = UDim2.fromOffset(12, 72),
	Size = UDim2.new(1, -24, 0, 174),
	BackgroundColor3 = CARD_BG,
	BorderSizePixel = 0,
}, main)
corner(card, 12)
stroke(card, SOFT_BLUE, 1.2, 0.4)

label(card, "PILIH LAGU", 10, FONT_MED, MUTED,
	UDim2.fromOffset(16, 10), UDim2.new(1, -32, 0, 14))

local selBtn, selBg = smallButton(card, "-", 12,
	UDim2.fromOffset(16, 26), UDim2.new(1, -32, 0, 34))
selBtn.TextXAlignment = Enum.TextXAlignment.Left
selBtn.TextTruncate = Enum.TextTruncate.AtEnd
new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 34) }, selBtn)
local ARROW_UP, ARROW_DOWN = "▲", "▼"
label(selBg, ARROW_UP .. "\n" .. ARROW_DOWN, 8, FONT_BOLD, ACCENT_HI,
	UDim2.new(1, -28, 0, 0), UDim2.fromOffset(18, 34), Enum.TextXAlignment.Center)

new("Frame", {
	Position = UDim2.fromOffset(16, 68),
	Size = UDim2.new(1, -32, 0, 1),
	BackgroundColor3 = LINE,
	BorderSizePixel = 0,
}, card)

label(card, "VOLUME", 10, FONT_MED, MUTED,
	UDim2.fromOffset(16, 78), UDim2.new(0.5, -16, 0, 14))
local volMinus = smallButton(card, "-", 18,
	UDim2.fromOffset(16, 96), UDim2.fromOffset(30, 30))
local volLabel = label(card, "50%", 13, FONT_BOLD, WHITE,
	UDim2.fromOffset(50, 96), UDim2.fromOffset(44, 30), Enum.TextXAlignment.Center)
local volPlus = smallButton(card, "+", 18,
	UDim2.fromOffset(98, 96), UDim2.fromOffset(30, 30))

label(card, "STATUS", 10, FONT_MED, MUTED,
	UDim2.new(0.5, 8, 0, 78), UDim2.new(0.5, -24, 0, 14))
local statusLabel = label(card, "Siap", 12, FONT_BOLD, WHITE,
	UDim2.new(0.5, 8, 0, 94), UDim2.new(0.5, -24, 0, 34))
statusLabel.TextWrapped = true
statusLabel.TextTruncate = Enum.TextTruncate.AtEnd

local note = label(card, "Lagu (Music1, Music2, ...) diambil dari GitHub dan otomatis disalin ke workspace.",
	10, FONT_MED, MUTED, UDim2.fromOffset(16, 134), UDim2.new(1, -32, 0, 30))
note.TextWrapped = true
note.TextYAlignment = Enum.TextYAlignment.Top

local playBg = new("Frame", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 12, 1, -14),
	Size = UDim2.new(1, -24, 0, 50),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
}, main)
corner(playBg, 12)
gradient(playBg, Color3.fromRGB(30, 38, 58), Color3.fromRGB(12, 14, 20), 90)
stroke(playBg, SOFT_BLUE, 1.5, 0.25)
local playBtn = new("TextButton", {
	AutoButtonColor = false,
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "PLAY",
	TextSize = 14,
	Font = FONT_BOLD,
	TextColor3 = WHITE,
	BorderSizePixel = 0,
}, playBg)

local popup = new("ScrollingFrame", {
	Position = UDim2.fromOffset(28, 134),
	Size = UDim2.fromOffset(W - 56, 30),
	BackgroundColor3 = Color3.fromRGB(18, 21, 30),
	BorderSizePixel = 0,
	ScrollBarThickness = 3,
	ScrollBarImageColor3 = SOFT_BLUE,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	Visible = false,
	ZIndex = 20,
}, main)
corner(popup, 8)
stroke(popup, SOFT_BLUE, 1.2, 0.25)

-- drag dari area atas
do
	local dragging, dragStart, startPos
	main.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			local rel = Vector2.new(input.Position.X, input.Position.Y) - main.AbsolutePosition
			if rel.Y < 68 then
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

local function setStatus(text, color)
	statusLabel.Text = text
	statusLabel.TextColor3 = color or WHITE
end

-- ─── SOUND ────────────────────────────────────────────────────────────────
local sound = new("Sound", {
	Name = SOUND_NAME,
	Volume = START_VOLUME,
	Looped = LOOP,
}, SoundService)

local volume = math.clamp(START_VOLUME, 0, 1)

-- ─── HTTP + BASE64 ────────────────────────────────────────────────────────
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

-- ─── DAFTAR LAGU DARI REPOSITORY ──────────────────────────────────────────
local function rawUrl(r, file)
	local folder = (r.folder and r.folder ~= "") and (r.folder .. "/") or ""
	return ("https://raw.githubusercontent.com/%s/%s/%s/%s%s"):format(
		r.owner, r.repo, r.branch or "main", folder, file)
end

local function displayName(song)
	return song.title
end

local function fetchSongs()
	local list, seen = {}, {}
	local function add(r, file)
		-- hanya file lagu: Music1.lua, Music2.lua, ... (music.lua utama tidak ikut)
		if not file:lower():match("^music%d+%.lua$") then return end
		local key = r.owner .. "/" .. r.repo .. "/" .. file
		if seen[key] then return end
		seen[key] = true
		local base = file:gsub("%.lua$", "")
		list[#list + 1] = {
			title = base,
			mp3 = base .. ".mp3",
			url = rawUrl(r, file),
			altUrl = rawUrl(r, file:lower()),
		}
	end

	for _, r in ipairs(REPOS) do
		local got = false
		-- 1) GitHub API (daftar file di folder)
		local apiUrl = ("https://api.github.com/repos/%s/%s/contents/%s?ref=%s"):format(
			r.owner, r.repo, r.folder or "", r.branch or "main")
		local body = httpGet(apiUrl)
		if body then
			local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
			if ok and type(data) == "table" then
				for _, item in ipairs(data) do
					if type(item) == "table" and item.type == "file" and item.name then
						add(r, item.name)
						got = true
					end
				end
			end
		end
		-- 2) cadangan: index.txt di folder yang sama (satu nama file per baris)
		if not got then
			local idx = httpGet(rawUrl(r, "index.txt"))
			if idx then
				for line in idx:gmatch("[^\r\n]+") do
					add(r, (line:gsub("^%s+", ""):gsub("%s+$", "")))
				end
			end
		end
	end

	table.sort(list, function(a, b)
		local na = tonumber(a.title:match("%d+")) or 0
		local nb = tonumber(b.title:match("%d+")) or 0
		if na ~= nb then return na < nb end
		return a.title:lower() < b.title:lower()
	end)
	return list
end

-- ─── INSTALL LAGU KE WORKSPACE ────────────────────────────────────────────
local function ensureDir()
	if type(isfolder) == "function" and type(makefolder) == "function" then
		pcall(function()
			if not isfolder(SONG_DIR) then makefolder(SONG_DIR) end
		end)
	end
end

-- unduh file lagu (.lua), decode, simpan ke workspace. return path atau nil, error
local function installSong(song)
	if type(writefile) ~= "function" then
		return nil, "Executor tidak mendukung writefile"
	end
	ensureDir()
	local path = SONG_DIR .. "/" .. song.mp3

	if type(isfile) == "function" and isfile(path) then
		return path
	end

	setStatus("Mengunduh...", ACCENT_HI)
	local src = httpGet(song.url)
	if not src and song.altUrl ~= song.url then
		src = httpGet(song.altUrl)
	end
	if not src then return nil, "Gagal mengunduh dari repo" end

	local chunk, cerr = loadstring(src)
	if not chunk then return nil, "File lagu rusak: " .. tostring(cerr) end
	local okRun, data = pcall(chunk)
	if not okRun or type(data) ~= "table" or type(data.data) ~= "string" then
		return nil, "Format file lagu salah"
	end

	setStatus("Menyalin lagu...", ACCENT_HI)
	local bytes = decodeBase64(data.data)
	if data.size and #bytes ~= data.size then
		return nil, "Ukuran file tidak cocok"
	end

	local ok, err = pcall(writefile, path, bytes)
	if not ok then
		warn("[" .. TITLE .. "] writefile gagal:", err)
		return nil, "Gagal menyimpan file"
	end
	return path
end

local function resolveAsset(path)
	if type(getcustomasset) ~= "function" then
		return nil, "Executor tidak mendukung getcustomasset"
	end
	local ok, asset = pcall(getcustomasset, path)
	if ok and type(asset) == "string" and asset ~= "" then
		return asset
	end
	return nil, "Gagal membuat aset suara"
end

-- ─── LOGIKA PEMUTAR ───────────────────────────────────────────────────────
local songs = {}
local current = nil
local playToken = 0

local function refreshSelector()
	selBtn.Text = current and displayName(current) or "Tidak ada lagu"
end

local function stopSong()
	playToken += 1
	sound:Stop()
	playBtn.Text = "PLAY"
	setStatus("Berhenti", SUB_TEXT)
end

local function playSong(song)
	if not song then
		setStatus("Pilih lagu dulu", ERR_RED)
		return
	end
	playToken += 1
	local myToken = playToken
	sound:Stop()

	local path, err = installSong(song)
	if playToken ~= myToken then return end
	if not path then
		setStatus(err, ERR_RED)
		return
	end

	local asset, err2 = resolveAsset(path)
	if not asset then
		setStatus(err2, ERR_RED)
		return
	end

	sound.SoundId = asset
	sound.Volume = volume
	sound.Looped = LOOP
	sound.TimePosition = 0
	setStatus("Memuat...", ACCENT_HI)

	local t0 = os.clock()
	while not sound.IsLoaded and os.clock() - t0 < LOAD_TIMEOUT and playToken == myToken do
		task.wait(0.1)
	end
	if playToken ~= myToken then return end
	if not sound.IsLoaded then
		setStatus("Gagal memuat file", ERR_RED)
		return
	end

	sound:Play()
	playBtn.Text = "STOP"
	setStatus("Memutar", OK_GREEN)
end

sound.Ended:Connect(function()
	if not LOOP and gui.Parent then
		playBtn.Text = "PLAY"
		setStatus("Selesai", SUB_TEXT)
	end
end)

local function buildPopup()
	for _, c in ipairs(popup:GetChildren()) do
		if c:IsA("TextButton") then c:Destroy() end
	end

	local rows = math.max(1, math.min(#songs, MAX_ROWS))
	popup.Size = UDim2.fromOffset(W - 56, rows * 28 + 6)
	popup.CanvasSize = UDim2.new(0, 0, 0, #songs * 28 + 6)

	for i, song in ipairs(songs) do
		local b = new("TextButton", {
			AutoButtonColor = false,
			Position = UDim2.fromOffset(4, 3 + (i - 1) * 28),
			Size = UDim2.new(1, -12, 0, 26),
			BackgroundColor3 = SOFT_BLUE,
			BackgroundTransparency = (current and current.url == song.url) and 0.55 or 1,
			Text = displayName(song),
			TextSize = 12,
			Font = FONT_MED,
			TextColor3 = WHITE,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			BorderSizePixel = 0,
			ZIndex = 21,
		}, popup)
		corner(b, 6)
		new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, b)
		b.MouseButton1Click:Connect(function()
			current = song
			refreshSelector()
			popup.Visible = false
			task.spawn(playSong, song)
		end)
	end
end

local loadingSongs = false
local function reloadSongs()
	if loadingSongs then return end
	loadingSongs = true
	setStatus("Memuat daftar...", ACCENT_HI)
	local list = fetchSongs()
	loadingSongs = false
	if not gui.Parent then return end
	songs = list
	if #songs == 0 then
		current = nil
		refreshSelector()
		setStatus("Daftar lagu kosong / repo salah", ERR_RED)
		return
	end
	if not current then current = songs[1] end
	refreshSelector()

	-- salin semua lagu dari repo ke folder workspace secara otomatis
	local failed = 0
	for i, song in ipairs(songs) do
		if not gui.Parent then return end
		setStatus(("Menyalin %d/%d..."):format(i, #songs), ACCENT_HI)
		local path = installSong(song)
		if not path then failed += 1 end
	end
	if not gui.Parent then return end
	if failed > 0 then
		setStatus(("Siap (%d gagal disalin)"):format(failed), ERR_RED)
	else
		setStatus("Siap (" .. #songs .. " lagu)", OK_GREEN)
	end
end

selBtn.MouseButton1Click:Connect(function()
	if popup.Visible then
		popup.Visible = false
	else
		if #songs == 0 and not loadingSongs then
			task.spawn(reloadSongs) -- coba muat ulang kalau tadi gagal
			return
		end
		buildPopup()
		popup.Visible = true
	end
end)

playBtn.MouseButton1Click:Connect(function()
	popup.Visible = false
	if sound.IsPlaying then
		stopSong()
	else
		task.spawn(playSong, current)
	end
end)

local function setVolume(v)
	volume = math.clamp(math.floor(v * 10 + 0.5) / 10, 0, 1)
	sound.Volume = volume
	volLabel.Text = math.floor(volume * 100 + 0.5) .. "%"
end
volMinus.MouseButton1Click:Connect(function() setVolume(volume - VOLUME_STEP) end)
volPlus.MouseButton1Click:Connect(function() setVolume(volume + VOLUME_STEP) end)
setVolume(volume)

closeBtn.MouseButton1Click:Connect(function()
	playToken += 1
	pcall(function()
		sound:Stop()
		sound:Destroy()
	end)
	gui:Destroy()
end)

refreshSelector()
if type(getcustomasset) ~= "function" then
	setStatus("Executor tidak mendukung getcustomasset", ERR_RED)
else
	task.spawn(reloadSongs)
end

