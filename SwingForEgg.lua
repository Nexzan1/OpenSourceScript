-- Nexzan Hub • Swing For Eggs • reference UI + local HWID key system v3.6.0
-- The key gate/profile/generator layout is retained from the accepted NLQVCG17Bj release.
-- Auto Hatch is a map monitor because placed eggs hatch automatically in this game.

-- Hashing is used for local device matching/file names, NOT tamper-proof authorization.
local function sha256(message)
    local K={0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2}
    local H={0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19}
    local band,bxor,bnot,rshift,ror=bit32.band,bit32.bxor,bit32.bnot,bit32.rshift,bit32.rrotate
    local n=#message
    local tail={128}
    for _=1,(55-n)%64 do table.insert(tail,0) end
    local high=math.floor(n/536870912);local low=(n*8)%4294967296
    for shift=24,0,-8 do table.insert(tail,band(rshift(high,shift),255)) end
    for shift=24,0,-8 do table.insert(tail,band(rshift(low,shift),255)) end
    local data=message..string.char(table.unpack(tail))
    for offset=1,#data,64 do
        local w={}
        for i=0,15 do local a,b,c,d=data:byte(offset+i*4,offset+i*4+3);w[i+1]=a*16777216+b*65536+c*256+d end
        for i=17,64 do
            local x,y=w[i-15],w[i-2]
            local s0=bxor(ror(x,7),ror(x,18),rshift(x,3));local s1=bxor(ror(y,17),ror(y,19),rshift(y,10))
            w[i]=(w[i-16]+s0+w[i-7]+s1)%4294967296
        end
        local a,b,c,d,e,f,g,h=table.unpack(H)
        for i=1,64 do
            local s1=bxor(ror(e,6),ror(e,11),ror(e,25));local ch=bxor(band(e,f),band(bnot(e),g))
            local t1=(h+s1+ch+K[i]+w[i])%4294967296
            local s0=bxor(ror(a,2),ror(a,13),ror(a,22));local maj=bxor(band(a,b),band(a,c),band(b,c))
            local t2=(s0+maj)%4294967296
            h,g,f,e,d,c,b,a=g,f,e,(d+t1)%4294967296,c,b,a,(t1+t2)%4294967296
        end
        for i,v in ipairs({a,b,c,d,e,f,g,h}) do H[i]=(H[i]+v)%4294967296 end
    end
    local output={};for _,v in ipairs(H) do table.insert(output,string.format('%08x',v)) end
    return table.concat(output)
end

local function createLocalStore(options)
    local hash=options.hash
    local lockTable=options.locks or {}
    local path='Nexzan_LocalKey_v3_'..(hash or 'unavailable')..'.json'
    local store={Path=path,DeviceHash=hash,Duration=86400}
    local function fail(text,code) return nil,text,code end
    function store:Ready()
        if not hash then return false,'HWID tidak tersedia pada executor ini.' end
        if type(options.read)~='function' or type(options.write)~='function' or type(options.exists)~='function' then return false,'Penyimpanan key tidak didukung pada executor ini.' end
        return true
    end
    function store:Read()
        local ready,why=self:Ready();if not ready then return fail(why,'UNSUPPORTED') end
        local ok,present=pcall(options.exists,path)
        if not ok then return fail('Penyimpanan key tidak dapat diperiksa.','STORAGE') end
        if not present then return nil,nil,'MISSING' end
        local readOK,raw=pcall(options.read,path)
        if not readOK or type(raw)~='string' or #raw>4096 then return fail('Data key tidak dapat dibaca.','STORAGE') end
        local decoded,row=pcall(options.decode,raw)
        if not decoded or type(row)~='table' then return fail('Data key tidak valid. Periksa penyimpanan executor.','CORRUPT') end
        if row.v~=3 or row.deviceHash~=hash or type(row.key)~='string' or #row.key~=41 or not row.key:match('^NEXZAN%-%d%d%d%d%d%d%-%x%x%x%x%x%x%-%x%x%x%x%x%x%-%x%x%x%x%x%x%-%x%x%x%x%x%x$')
            or type(row.issuedAt)~='number' or row.issuedAt%1~=0 or type(row.expiresAt)~='number' or row.expiresAt-row.issuedAt~=86400
            or type(row.lastSeen)~='number' or row.lastSeen<row.issuedAt then
            return fail('Data key tidak cocok atau rusak.','CORRUPT')
        end
        if options.now()<row.lastSeen-120 then return fail('Tanggal atau waktu perangkat berubah. Periksa jam perangkat.','CLOCK') end
        return row
    end
    local function save(row)
        local encoded,raw=pcall(options.encode,row)
        if not encoded then return fail('Key tidak dapat disiapkan.','STORAGE') end
        local written=pcall(options.write,path,raw)
        if not written then return fail('Key gagal disimpan. Periksa izin penyimpanan.','STORAGE') end
        local confirmed,text,code=store:Read()
        if not confirmed or confirmed.key~=row.key or confirmed.expiresAt~=row.expiresAt or confirmed.lastSeen~=row.lastSeen then return fail(text or 'Penyimpanan key belum terkonfirmasi.',code or 'STORAGE') end
        return confirmed
    end
    function store:GetOrCreate(submittedHwid)
        local ready,why=self:Ready();if not ready then return fail(why,'UNSUPPORTED') end
        if type(submittedHwid)~='string' or submittedHwid:match('^%s*(.-)%s*$')=='' then
            return fail('Tempel HWID yang sudah disalin terlebih dahulu.','HWID_REQUIRED')
        end
        local entered=submittedHwid:match('^%s*(.-)%s*$'):lower()
        if #entered>512 or sha256(entered)~=hash then return fail('HWID tidak cocok dengan perangkat ini.','HWID_MISMATCH') end
        if lockTable[path] then return fail('Key sedang diproses. Coba lagi.','BUSY') end
        lockTable[path]=true
        local succeeded,result,text,code,isNew=pcall(function()
            local current,message,status=self:Read()
            if message then return nil,message,status end
            if current and current.expiresAt>options.now() then return current,nil,nil,false end
            local now=math.floor(options.now())
            local nonce=options.guid()..options.guid()
            local material=sha256(hash..':'..nonce..':'..tostring(now)):upper()
            local digits=100000+(tonumber(material:sub(1,6),16)%900000)
            local part=material:sub(7,30)
            local key='NEXZAN-'..tostring(digits)..'-'..part:sub(1,6)..'-'..part:sub(7,12)..'-'..part:sub(13,18)..'-'..part:sub(19,24)
            local row={v=3,deviceHash=hash,key=key,issuedAt=now,expiresAt=now+86400,lastSeen=now}
            local saved,msg,err=save(row)
            return saved,msg,err,saved~=nil
        end)
        lockTable[path]=nil
        if not succeeded then return fail('Key belum dapat dibuat. Coba lagi.','STORAGE') end
        return result,text,code,isNew
    end
    function store:Validate(key)
        local row,message,code=self:Read()
        if not row then return fail(message or 'Klik Get Key dan buat key perangkat ini dahulu.',code or 'MISSING') end
        if type(key)~='string' or key:match('^%s*(.-)%s*$'):upper()~=row.key then return fail('Key tidak cocok untuk perangkat ini.','INVALID_KEY') end
        if options.now()>=row.expiresAt then return fail('Key kedaluwarsa. Klik Get Key untuk key baru.','EXPIRED') end
        row.lastSeen=math.max(row.lastSeen,math.floor(options.now()))
        return save(row)
    end
    function store:Touch(expected)
        local current,message,code=self:Read()
        if not current then return fail(message or 'Data key tidak ditemukan.',code or 'MISSING') end
        if current.key~=expected.key or current.expiresAt~=expected.expiresAt then return fail('Key telah berubah. Periksa key kembali.','INVALID_KEY') end
        if options.now()>=current.expiresAt then return fail('Key kedaluwarsa. Klik Get Key lagi.','EXPIRED') end
        current.lastSeen=math.max(current.lastSeen,math.floor(options.now()))
        return save(current)
    end
    return store
end

local function loadBundledLibrary()
--!nonstrict
local TweenService      = game:GetService("TweenService")
local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local TextService       = game:GetService("TextService")
local Lighting          = game:GetService("Lighting")
local HttpService       = game:GetService("HttpService")
local GuiService        = game:GetService("GuiService")
 
local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
 
local IsMobileDevice = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
 
local NullUI = {}
NullUI.__index = NullUI
NullUI.Version = "2.8.1"
NullUI.Flags = {}
NullUI._Windows = {}
 
local function GetGlobalTable()
	local ok, g = pcall(function()
		if getgenv then return getgenv() end
		return _G
	end)
	return (ok and g) or _G
end
 
do
	local globalTable = GetGlobalTable()
	local previousUnload = globalTable.__NullUI_Unload
	globalTable.__NullUI_Unload = nil
	if type(previousUnload) == "function" then
		pcall(previousUnload)
	end
end
 
local Janitor = {}
Janitor.__index = Janitor
 
function Janitor.new()
	return setmetatable({ _items = {}, _dead = false }, Janitor)
end
 
function Janitor:Add(item)
	if self._dead then
		if typeof(item) == "RBXScriptConnection" then
			item:Disconnect()
		elseif typeof(item) == "Instance" then
			item:Destroy()
		end
		return item
	end
	table.insert(self._items, item)
	return item
end
 
function Janitor:Destroy()
	if self._dead then return end
	self._dead = true
	for i = #self._items, 1, -1 do
		local item = self._items[i]
		self._items[i] = nil
		local t = typeof(item)
		if t == "RBXScriptConnection" then
			pcall(function() item:Disconnect() end)
		elseif t == "Instance" then
			pcall(function() item:Destroy() end)
		elseif t == "function" then
			pcall(item)
		elseif t == "table" and type(item.Destroy) == "function" then
			pcall(function() item:Destroy() end)
		end
	end
end
 
local LibJanitor = Janitor.new()
 
local function MakeSignal()
	local listeners = {}
	return {
		Fire = function(...)
			for _, fn in ipairs(table.clone(listeners)) do
				task.spawn(fn, ...)
			end
		end,
		Connect = function(fn)
			table.insert(listeners, fn)
			return {
				Disconnect = function()
					local i = table.find(listeners, fn)
					if i then table.remove(listeners, i) end
				end,
			}
		end,
		Clear = function()
			table.clear(listeners)
		end,
	}
end
 
local function SafeClamp(value, lo, hi)
	if hi < lo then return lo end
	return math.clamp(value, lo, hi)
end
 
local function SafeAlpha(value, min, max)
	local range = max - min
	if range == 0 then return 0 end
	return math.clamp((value - min) / range, 0, 1)
end
 
local function SnapToIncrement(raw, min, max, increment)
	if increment <= 0 then increment = 1 end
	local snapped = math.floor((raw - min) / increment + 0.5) * increment + min
	snapped = math.clamp(snapped, min, max)
	local decimals = 0
	local probe = increment
	while decimals < 6 and math.abs(probe - math.floor(probe + 0.5)) > 1e-9 do
		probe = probe * 10
		decimals = decimals + 1
	end
	local factor = 10 ^ decimals
	return math.floor(snapped * factor + (snapped >= 0 and 0.5 or -0.5)) / factor
end
 
local function FormatNumber(v)
	if math.abs(v - math.floor(v + 0.5)) < 1e-9 then
		return tostring(math.floor(v + 0.5))
	end
	return string.format("%.4g", v)
end
 
local ACRYLIC_DOF_NAME = "NullUI_AcrylicDOF"
local ACRYLIC_DISTANCE = 0.001
local ACRYLIC_TRANSPARENCY = 0.98
local AcrylicDOF = nil
local AcrylicControllers = {}
local CameraConnections = {}
local AcrylicShuttingDown = false
 
NullUI.Config = { Blur = true, MaxNotifications = 5 }
 
local function DisconnectCameraSignals()
	for i = #CameraConnections, 1, -1 do
		CameraConnections[i]:Disconnect()
		CameraConnections[i] = nil
	end
end
 
local function EnsureAcrylicDOF()
	if AcrylicDOF and AcrylicDOF.Parent then return AcrylicDOF end
	local stale = Lighting:FindFirstChild(ACRYLIC_DOF_NAME)
	if stale then stale:Destroy() end
 
	local dof = Instance.new("DepthOfFieldEffect")
	dof.Name = ACRYLIC_DOF_NAME
	dof.FarIntensity = 0
	dof.FocusDistance = 0.05
	dof.InFocusRadius = 0.1
	dof.NearIntensity = 1
	dof.Enabled = false
	dof.Parent = Lighting
	AcrylicDOF = dof
	LibJanitor:Add(dof)
	return dof
end
 
local function RefreshAcrylicEffect()
	if AcrylicShuttingDown then return end
	local dof = EnsureAcrylicDOF()
	dof.Enabled = NullUI.Config.Blur ~= false and #AcrylicControllers > 0
end
 
local function UpdateAllAcrylic()
	for index = #AcrylicControllers, 1, -1 do
		local controller = AcrylicControllers[index]
		if controller.Destroyed then
			table.remove(AcrylicControllers, index)
		else
			controller:Update()
		end
	end
end
 
local function BindAcrylicCamera(camera)
	DisconnectCameraSignals()
	if not camera then return end
 
	local function connect(property)
		table.insert(CameraConnections,
			camera:GetPropertyChangedSignal(property):Connect(UpdateAllAcrylic))
	end
	connect("CFrame")
	connect("ViewportSize")
	connect("FieldOfView")
	UpdateAllAcrylic()
end
 
local function CreateWindowAcrylic(guiObject)
	local folder = Instance.new("Folder")
	folder.Name = "NullUI_AcrylicWindow"
 
	local part = Instance.new("Part")
	part.Name = "Glass"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Locked = true
	part.Material = Enum.Material.Glass
	part.Color = Color3.new(0, 0, 0)
	part.Reflectance = 0
	part.Size = Vector3.new(1, 1, 0.001)
	part.Transparency = 1
	part.Parent = folder
 
	local mesh = Instance.new("SpecialMesh")
	mesh.Name = "AcrylicMesh"
	mesh.MeshType = Enum.MeshType.Brick
	mesh.Offset = Vector3.new(0, 0, -0.000001)
	mesh.Scale = Vector3.new(1, 1, 0.001)
	mesh.Parent = part
 
	local controller = {
		Gui = guiObject,
		Folder = folder,
		Part = part,
		Mesh = mesh,
		Connections = {},
		Destroyed = false,
	}
 
	function controller:Update()
		if self.Destroyed then return end
		local camera = workspace.CurrentCamera
		local gui = self.Gui
		if not camera or not gui or not gui.Parent then
			self.Part.Transparency = 1
			return
		end
 
		if self.Folder.Parent ~= camera then
			self.Folder.Parent = camera
		end
 
		local size = gui.AbsoluteSize
		local visible = NullUI.Config.Blur ~= false
			and gui.Visible and size.X > 2 and size.Y > 2
		self.Part.Transparency = visible and ACRYLIC_TRANSPARENCY or 1
		if not visible then return end
 
		local edgeInset = math.clamp(camera.ViewportSize.Y * 0.012, 8, 18)
		local position = gui.AbsolutePosition + Vector2.new(edgeInset, edgeInset)
		local panelSize = Vector2.new(
			math.max(1, size.X - edgeInset * 2),
			math.max(1, size.Y - edgeInset * 2)
		)
 
		local function ScreenToWorld(point)
			local ray = camera:ScreenPointToRay(point.X, point.Y)
			return ray.Origin + ray.Direction * ACRYLIC_DISTANCE
		end
 
		local topLeft3D = ScreenToWorld(position)
		local topRight3D = ScreenToWorld(position + Vector2.new(panelSize.X, 0))
		local bottomRight3D = ScreenToWorld(position + panelSize)
		local width = (topRight3D - topLeft3D).Magnitude
		local height = (bottomRight3D - topRight3D).Magnitude
		local renderCFrame = camera:GetRenderCFrame()
 
		self.Part.CFrame = CFrame.fromMatrix(
			(topLeft3D + bottomRight3D) / 2,
			renderCFrame.XVector,
			renderCFrame.YVector,
			renderCFrame.ZVector
		)
		self.Mesh.Scale = Vector3.new(width, height, 0.001)
	end
 
	function controller:Destroy()
		if self.Destroyed then return end
		self.Destroyed = true
		for _, connection in ipairs(self.Connections) do
			connection:Disconnect()
		end
		table.clear(self.Connections)
		local index = table.find(AcrylicControllers, self)
		if index then table.remove(AcrylicControllers, index) end
		if self.Folder then self.Folder:Destroy() end
		RefreshAcrylicEffect()
	end
 
	for _, property in ipairs({ "AbsolutePosition", "AbsoluteSize", "Visible" }) do
		table.insert(controller.Connections,
			guiObject:GetPropertyChangedSignal(property):Connect(function()
				controller:Update()
			end))
	end
	table.insert(controller.Connections, guiObject.AncestryChanged:Connect(function()
		if not guiObject.Parent then controller:Destroy() end
	end))
 
	table.insert(AcrylicControllers, controller)
	RefreshAcrylicEffect()
	controller:Update()
	return controller
end
 
BindAcrylicCamera(workspace.CurrentCamera)
LibJanitor:Add(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	BindAcrylicCamera(workspace.CurrentCamera)
end))
LibJanitor:Add(function()
	DisconnectCameraSignals()
end)
 
function NullUI:SetBlurEnabled(enabled)
	NullUI.Config.Blur = enabled and true or false
	RefreshAcrylicEffect()
	UpdateAllAcrylic()
end
 
local function DestroyAllAcrylicControllers()
	for index = #AcrylicControllers, 1, -1 do
		AcrylicControllers[index]:Destroy()
	end
	table.clear(AcrylicControllers)
end
 
local ASSETS_FOLDER = "NullUI/Assets"
 
local function hasFn(name)
	local ok, fn = pcall(function()
		if getgenv then
			local v = getgenv()[name]
			if type(v) == "function" then return v end
		end
		if getfenv then
			local v = getfenv(1)[name]
			if type(v) == "function" then return v end
		end
		return _G[name]
	end)
	if ok and type(fn) == "function" then return fn end
	return nil
end
 
local fn_isfolder    = hasFn("isfolder")
local fn_makefolder  = hasFn("makefolder")
local fn_isfile      = hasFn("isfile")
local fn_writefile   = hasFn("writefile")
local fn_readfile    = hasFn("readfile")
local fn_delfile     = hasFn("delfile")
local fn_listfiles   = hasFn("listfiles")
local fn_customasset = hasFn("getcustomasset") or hasFn("getsynasset")
 
local function EnsureAssetsFolder()
	if not (fn_isfolder and fn_makefolder) then return false end
	local ok = pcall(function()
		if not fn_isfolder("NullUI") then fn_makefolder("NullUI") end
		if not fn_isfolder(ASSETS_FOLDER) then fn_makefolder(ASSETS_FOLDER) end
	end)
	return ok
end
 
local function PrivateTabFlagPath(name)
	local safe = tostring(name or ""):gsub("[^%w_%-]", "_")
	return "NullUI/PrivateTab_" .. safe .. ".remember"
end
 
local function IsPrivateTabRemembered(name)
	if not fn_isfile then return false end
	local ok, exists = pcall(fn_isfile, PrivateTabFlagPath(name))
	return ok and exists == true
end
 
local function SetPrivateTabRemembered(name, remember)
	local path = PrivateTabFlagPath(name)
	if remember then
		if not fn_writefile then return end
		EnsureAssetsFolder()
		pcall(fn_writefile, path, "1")
	else
		if not (fn_isfile and fn_delfile) then return end
		local ok, exists = pcall(fn_isfile, path)
		if ok and exists then pcall(fn_delfile, path) end
	end
end
 
local RunCountPath = "NullUI/RunCount.txt"
 
local function BumpRunCount()
	local count = 1
	if fn_isfile and fn_readfile and fn_isfile(RunCountPath) then
		local ok, data = pcall(fn_readfile, RunCountPath)
		local n = ok and tonumber(data)
		if n then count = math.floor(n) + 1 end
	end
	if fn_writefile then
		EnsureAssetsFolder()
		pcall(fn_writefile, RunCountPath, tostring(count))
	end
	return count
end
 
local function GetExecutorName()
	local ok, name, version = pcall(function()
		if identifyexecutor then return identifyexecutor() end
		if getexecutorname then return getexecutorname() end
		if syn and syn.get_executor_name then return syn.get_executor_name() end
		return nil
	end)
	if ok and name and name ~= "" then
		return version and version ~= "" and (tostring(name) .. " " .. tostring(version)) or tostring(name)
	end
	return "Unknown"
end
 
local function FormatClock(minutesAfterMidnight)
	minutesAfterMidnight = minutesAfterMidnight or 0
	local h = math.floor(minutesAfterMidnight / 60) % 24
	local m = math.floor(minutesAfterMidnight % 60)
	local suffix = h >= 12 and "PM" or "AM"
	local h12 = h % 12
	if h12 == 0 then h12 = 12 end
	return string.format("%02d:%02d %s", h12, m, suffix)
end
 
local function LooksLikeFontFile(data)
	if type(data) ~= "string" or #data < 4096 then return false end
	local sig = data:sub(1, 4)
	return sig == "\0\1\0\0"
		or sig == "OTTO"
		or sig == "true"
		or sig == "ttcf"
		or sig == "wOFF"
		or sig == "wOF2"
end
 
local function DownloadFontFile(path, url)
	if not (fn_isfile and fn_writefile) then return false end
 
	local cached = nil
	if fn_isfile(path) and fn_readfile then
		local ok, data = pcall(fn_readfile, path)
		if ok and LooksLikeFontFile(data) then
			return true
		end
		cached = ok and data or nil
	end
 
	if cached ~= nil and fn_delfile then
		pcall(fn_delfile, path)
	end
 
	local ok, body = pcall(function() return game:HttpGet(url) end)
	if not ok or not LooksLikeFontFile(body) then
		return false
	end
 
	local wrote = pcall(fn_writefile, path, body)
	return wrote
end
 
local function LoadCustomFigtree()
	if not (fn_customasset and fn_writefile) then return nil end
 
	local okFolder = EnsureAssetsFolder()
	if not okFolder then return nil end
 
	local base = "https://raw.githubusercontent.com/Skinny-yz/NullUI-Assets/main/fonts/"
	local semiPath = ASSETS_FOLDER .. "/Figtree-SemiBold.ttf"
	local regPath  = ASSETS_FOLDER .. "/Figtree-Medium.ttf"
 
	if not DownloadFontFile(semiPath, base .. "Figtree-SemiBold.ttf") then
		return nil
	end
	local hasRegular = DownloadFontFile(regPath, base .. "Figtree-Medium.ttf")
	if not hasRegular then regPath = semiPath end
 
	local result = nil
	pcall(function()
		local family = {
			name = "Figtree",
			faces = {
				{ name = "Regular",  weight = 400, style = "normal", assetId = fn_customasset(regPath) },
				{ name = "SemiBold", weight = 600, style = "normal", assetId = fn_customasset(semiPath) },
			},
		}
		local familyPath = ASSETS_FOLDER .. "/Figtree.font"
		fn_writefile(familyPath, HttpService:JSONEncode(family))
 
		local asset = fn_customasset(familyPath)
		result = {
			Regular  = Font.new(asset, Enum.FontWeight.Regular,  Enum.FontStyle.Normal),
			SemiBold = Font.new(asset, Enum.FontWeight.SemiBold, Enum.FontStyle.Normal),
		}
	end)
 
	return result
end
 
local function LoadFonts()
	local custom = LoadCustomFigtree()
	if custom and custom.Regular and custom.SemiBold then
		return custom
	end
 
	local ok, native = pcall(function()
		return {
			Regular  = Font.new("rbxasset://fonts/families/Figtree.json", Enum.FontWeight.Regular,  Enum.FontStyle.Normal),
			SemiBold = Font.new("rbxasset://fonts/families/Figtree.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal),
		}
	end)
	if ok and native then return native end
 
	return {
		Regular  = Font.fromEnum(Enum.Font.Gotham),
		SemiBold = Font.fromEnum(Enum.Font.GothamSemibold),
	}
end
 
local Fonts = LoadFonts()
 
NullUI.Theme = {
	Background     = Color3.fromRGB(16, 16, 16),
	Surface        = Color3.fromRGB(24, 24, 24),
	Text           = Color3.fromRGB(240, 240, 240),
	TextDim        = Color3.fromRGB(150, 150, 155),
	Accent         = Color3.fromRGB(255, 255, 255),
	Danger         = Color3.fromRGB(205, 205, 210),
 
	Font           = Fonts.SemiBold,
	FontRegular    = Fonts.Regular,
 
	MeasureFont    = Enum.Font.GothamSemibold,
 
	CornerRadius   = 16,
	CornerRadiusSm = 8,
	Margin         = 14,
	AnimFast       = 0.15,
	AnimSlow       = 0.32,
}
 
local Z = {
	Glass    = 0,
	Window   = 1,
	Content  = 2,
	Backdrop = 390,
	Popup    = 400,
	PopupTop = 410,
	Toast    = 600,
	Modal    = 800,
	ModalTop = 810,
}
 
local function Tween(instance, props, duration, style, direction)
	local t = TweenService:Create(
		instance,
		TweenInfo.new(
			math.max(duration or 0.25, 0),
			style or Enum.EasingStyle.Quint,
			direction or Enum.EasingDirection.Out
		),
		props
	)
	t:Play()
	return t
end
 
local function Corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or NullUI.Theme.CornerRadius)
	c.Parent = parent
	return c
end
 
local function Stroke(parent, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.new(1, 1, 1)
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0.9
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end
 
local function GlassLayer(parent, radius, transparency)
	local glass = Instance.new("Frame")
	glass.Name = "Glass"
	glass.Size = UDim2.fromScale(1, 1)
	glass.BackgroundColor3 = Color3.new(1, 1, 1)
	glass.BackgroundTransparency = transparency or 0.985
	glass.BorderSizePixel = 0
	glass.ZIndex = Z.Glass
	glass.Parent = parent
	Corner(glass, radius)
	return glass
end
 
local function AddScrollbar(scroll)
	scroll.ScrollBarThickness = 0
	scroll.ScrollBarImageTransparency = 1
	scroll.VerticalScrollBarInset = Enum.ScrollBarInset.None
	scroll.HorizontalScrollBarInset = Enum.ScrollBarInset.None
end
 
local function AddContentScrollThumb(scroll, listLayout, thumbParent, janitor)
	local thumb = Instance.new("Frame")
	thumb.Name = "ContentScrollThumb"
	thumb.BackgroundColor3 = NullUI.Theme.TextDim
	thumb.BackgroundTransparency = 0.35
	thumb.BorderSizePixel = 0
	thumb.AnchorPoint = Vector2.new(1, 0)
	thumb.Size = UDim2.new(0, 3, 0, 40)
	thumb.Visible = false
	thumb.ZIndex = (scroll.ZIndex or 0) + 6
	thumb.Parent = thumbParent
	Corner(thumb, 2)
 
	local MARGIN = 4
 
	janitor:Add(RunService.Heartbeat:Connect(function()
		if not thumbParent.Visible then
			thumb.Visible = false
			return
		end
		local windowH = scroll.AbsoluteWindowSize.Y
		local canvasH = scroll.AbsoluteCanvasSize.Y
		local overflow = canvasH - windowH
		if overflow <= 8 or windowH <= 0 then
			thumb.Visible = false
			return
		end
		local trackH = windowH - MARGIN * 2
		if trackH <= 0 then
			thumb.Visible = false
			return
		end
		local parentPos, parentSize = thumbParent.AbsolutePosition, thumbParent.AbsoluteSize
		if parentSize.X <= 0 or parentSize.Y <= 0 then
			thumb.Visible = false
			return
		end
		local thumbH = math.min(trackH, math.max(30, trackH * (windowH / canvasH)))
		local maxThumbY = trackH - thumbH
		local ratio = math.clamp(scroll.CanvasPosition.Y / overflow, 0, 1)
		local topY = (scroll.AbsolutePosition.Y - parentPos.Y) + MARGIN + maxThumbY * ratio
		local rightX = (scroll.AbsolutePosition.X + scroll.AbsoluteSize.X) - parentPos.X - MARGIN
		thumb.Visible = true
		thumb.Size = UDim2.new(0, 3, thumbH / parentSize.Y, 0)
		thumb.Position = UDim2.new(rightX / parentSize.X, 0, topY / parentSize.Y, 0)
	end))
 
	return thumb
end
 
local MEASURE_FUDGE = 1.06
local MeasureCache = {}
 
local function MeasureText(text, size, maxWidth)
	text = tostring(text or "")
	maxWidth = maxWidth or 10000
	local key = text .. "\1" .. size .. "\1" .. math.floor(maxWidth)
	local cached = MeasureCache[key]
	if cached then return cached.X, cached.Y end
 
	local ok, bounds = pcall(function()
		return TextService:GetTextSize(
			text, size, NullUI.Theme.MeasureFont,
			Vector2.new(maxWidth, 100000)
		)
	end)
	local w, h
	if ok and bounds then
		w = math.ceil(bounds.X * MEASURE_FUDGE)
		h = math.ceil(bounds.Y)
	else
		w = math.ceil(#text * size * 0.55)
		h = size + 2
	end
	MeasureCache[key] = Vector2.new(w, h)
	return w, h
end
 
local IconSources = {
	Material = "https://raw.githubusercontent.com/Skinny-yz/NullUI-Assets/main/icons/MaterialIcons.luau",
	Lucide   = "https://raw.githubusercontent.com/Skinny-yz/NullUI-Assets/main/icons/LucideIcons.luau",
	Phosphor = "https://raw.githubusercontent.com/Skinny-yz/NullUI-Assets/main/icons/Phosphor.luau",
	["Phosphor-Filled"] = "https://raw.githubusercontent.com/Skinny-yz/NullUI-Assets/main/icons/Phosphor%20Filled.luau",
	SF       = "https://raw.githubusercontent.com/Skinny-yz/NullUI-Assets/main/icons/SFSymbols.luau",
}
 
local IconCache = {}
local IconLoading = {}
 
local function LoadIconSource(source)
	if IconCache[source] ~= nil then
		return IconCache[source] or nil
	end
 
	if IconLoading[source] then
		local t0 = os.clock()
		while IconLoading[source] and os.clock() - t0 < 10 do
			task.wait()
		end
		return IconCache[source] or nil
	end
 
	local url = IconSources[source]
	if not url then
		IconCache[source] = false
		return nil
	end
 
	IconLoading[source] = true
	local ok, data = pcall(function()
		return loadstring(game:HttpGet(url))()
	end)
	IconLoading[source] = nil
 
	if ok and type(data) == "table" then
		IconCache[source] = data
		return data
	end
 
	IconCache[source] = false
	return nil
end
 
function NullUI:GetIcon(name, source)
	source = source or "Lucide"
	local set = LoadIconSource(source)
	local iconId = set and set[name]
	if not iconId then return "" end
	return "rbxassetid://" .. tostring(iconId)
end
 
local function ResolveIcon(icon)
	if icon == nil or icon == "" then return "" end
	if type(icon) ~= "string" then return icon end
	if icon:match("^%a[%w%+%-%.]*://") then return icon end
	if icon:match("^%d+$") then return "rbxassetid://" .. icon end
	local source, name = icon:match("^(%a[%w%-]*):(.+)$")
	if source and name then
		return NullUI:GetIcon(name, source)
	end
	return NullUI:GetIcon(icon, "Lucide")
end
 
function NullUI:PreloadIcons(sources)
	for _, src in ipairs(sources or { "Lucide" }) do
		task.spawn(LoadIconSource, src)
	end
end
 
local function GetRoot()
	local parent = PlayerGui
	local hidden = hasFn("gethui")
	if hidden then
		local ok, container = pcall(hidden)
		if ok and container then parent = container end
	end
 
	local stale = parent:FindFirstChild("NullUI")
	if stale then stale:Destroy() end
 
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "NullUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = false
	screenGui.DisplayOrder = 9999
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = parent
	return screenGui
end
 
NullUI._Root = GetRoot()
 
local function ViewportSize()
	local root = NullUI._Root
	if root and root.AbsoluteSize.X > 0 then
		return root.AbsoluteSize
	end
	local cam = workspace.CurrentCamera
	return cam and cam.ViewportSize or Vector2.new(1280, 720)
end
 
local UI_SCALE_BASELINE = IsMobileDevice and 380 or 720
local UI_SCALE_MIN = IsMobileDevice and 1.0 or 0.75
local UI_SCALE_MAX = IsMobileDevice and 1.5 or 1.35
 
local function ComputeUIScale()
	return SafeClamp(ViewportSize().Y / UI_SCALE_BASELINE, UI_SCALE_MIN, UI_SCALE_MAX)
end
 
local GlobalScale = Instance.new("UIScale")
GlobalScale.Name = "GlobalScale"
GlobalScale.Scale = ComputeUIScale()
GlobalScale.Parent = NullUI._Root
 
local function GetUIScale()
	return GlobalScale.Scale
end
 
local function RefreshUIScale()
	GlobalScale.Scale = ComputeUIScale()
end
 
local function WatchCamera(cam)
	if not cam then return end
	LibJanitor:Add(cam:GetPropertyChangedSignal("ViewportSize"):Connect(RefreshUIScale))
end
 
WatchCamera(workspace.CurrentCamera)
LibJanitor:Add(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	WatchCamera(workspace.CurrentCamera)
	RefreshUIScale()
end))
 
function NullUI:SetScaleRange(minScale, maxScale)
	UI_SCALE_MIN = minScale or UI_SCALE_MIN
	UI_SCALE_MAX = maxScale or UI_SCALE_MAX
	RefreshUIScale()
end
 
local ActivePopupClose = nil
 
local function RegisterPopupOpen(closeFn)
	if ActivePopupClose and ActivePopupClose ~= closeFn then
		local previous = ActivePopupClose
		ActivePopupClose = nil
		previous()
	end
	ActivePopupClose = closeFn
end
 
local function RegisterPopupClose(closeFn)
	if ActivePopupClose == closeFn then
		ActivePopupClose = nil
	end
end
 
local function CloseAnyOpenPopup()
	if ActivePopupClose then
		local fn = ActivePopupClose
		ActivePopupClose = nil
		fn()
	end
end
 
local function MakePopupBackdrop(onClose)
	local backdrop = Instance.new("TextButton")
	backdrop.Name = "PopupBackdrop"
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.BackgroundTransparency = 1
	backdrop.BorderSizePixel = 0
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.ZIndex = Z.Backdrop
	backdrop.Parent = NullUI._Root
	backdrop.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			onClose()
		end
	end)
	return backdrop
end
 
LibJanitor:Add(UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.Escape and ActivePopupClose then
		CloseAnyOpenPopup()
	end
end))
 
local KeybindCapturing = false
 
local NotificationQueue = {}
 
local function GetNotifyHolder()
	local root = NullUI._Root
	local holder = root:FindFirstChild("NotificationHolder")
	if holder then return holder end
 
	holder = Instance.new("Frame")
	holder.Name = "NotificationHolder"
	holder.AnchorPoint = Vector2.new(1, 1)
	holder.Position = UDim2.new(1, -20, 1, -20)
	holder.Size = UDim2.new(0, 280, 1, -40)
	holder.BackgroundTransparency = 1
	holder.ZIndex = Z.Toast
	holder.Parent = root
 
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.Padding = UDim.new(0, 10)
	layout.Parent = holder
	holder.ClipsDescendants = true
 
	LibJanitor:Add(RunService.Heartbeat:Connect(function()
		if not holder.Parent then return end
		local s = GetUIScale()
		local view = ViewportSize()
		holder.Size = UDim2.fromOffset(math.max(1, math.min(280, view.X / s - 40)), math.max(1, view.Y / s - 40))
		local used, count = 0, 0
		local function fullHeight(card)
			local anim = card:FindFirstChildOfClass("UIScale")
			return card.AbsoluteSize.Y / (anim and math.max(anim.Scale, 0.01) or 1)
		end
		for _, child in ipairs(holder:GetChildren()) do
			if child:IsA("GuiObject") and child.Visible then
				used += fullHeight(child) + (count > 0 and 10 * s or 0)
				count += 1
			end
		end
		while #NotificationQueue > 0 do
			local entry = NotificationQueue[1]
			if not entry.Card.Parent then
				table.remove(NotificationQueue, 1)
			else
				local h = fullHeight(entry.Card)
				if h <= 0 then break end
				local needed = h + (count > 0 and 10 * s or 0)
				if used + needed > holder.AbsoluteSize.Y then break end
				table.remove(NotificationQueue, 1)
				entry.Start()
				used += needed
				count += 1
			end
		end
	end))
 
	return holder
end
 
NullUI._NotifyCounter = 0
 
local NotifyIcons = {
	info    = "info",
	success = "check",
	warning = "triangle-alert",
	error   = "circle-x",
}
 
local NotifyColors = {
	info    = Color3.fromRGB(120, 170, 255),
	success = Color3.fromRGB(110, 220, 140),
	warning = Color3.fromRGB(255, 190, 90),
	error   = Color3.fromRGB(255, 105, 105),
}
 
function NullUI:Notify(opts)
	opts = opts or {}
	local title      = opts.Title or "Notification"
	local text       = opts.Text or ""
	local duration   = opts.Duration or 4
	local notifyType = opts.Type or "info"
	local color      = opts.Color or NotifyColors[notifyType] or NullUI.Theme.Accent
	local iconName   = opts.Icon or NotifyIcons[notifyType] or NotifyIcons.info
 
	local holder = GetNotifyHolder()
	NullUI._NotifyCounter = NullUI._NotifyCounter + 1
 
	local dismiss
 
	local card = Instance.new("Frame")
	card.Name = "Notification"
	card.BackgroundColor3 = NullUI.Theme.Surface
	card.BackgroundTransparency = 1
	card.BorderSizePixel = 0
	card.ClipsDescendants = true
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.Size = UDim2.new(1, 0, 0, 0)
	card.LayoutOrder = NullUI._NotifyCounter
	card.ZIndex = Z.Toast
	card.Visible = false
	card.Parent = holder
	Corner(card, 12)
	local stroke = Stroke(card, Color3.new(1, 1, 1), 1, 1)
	local notificationAcrylic = nil
	local scale = Instance.new("UIScale")
	scale.Scale = 0.88
	scale.Parent = card
 
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = card
 
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = card
 
	local headerRow = Instance.new("Frame")
	headerRow.BackgroundTransparency = 1
	headerRow.AutomaticSize = Enum.AutomaticSize.XY
	headerRow.Size = UDim2.new(0, 0, 0, 0)
	headerRow.LayoutOrder = 1
	headerRow.ZIndex = Z.Toast + 1
	headerRow.Parent = card
 
	local headerLayout = Instance.new("UIListLayout")
	headerLayout.FillDirection = Enum.FillDirection.Horizontal
	headerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	headerLayout.Padding = UDim.new(0, 7)
	headerLayout.SortOrder = Enum.SortOrder.LayoutOrder
	headerLayout.Parent = headerRow
 
	local icon = Instance.new("ImageLabel")
	icon.BackgroundTransparency = 1
	icon.Image = ResolveIcon(iconName)
	icon.ImageColor3 = color
	icon.ImageTransparency = 1
	icon.Size = UDim2.fromOffset(14, 14)
	icon.LayoutOrder = 1
	icon.ZIndex = Z.Toast + 1
	icon.Parent = headerRow
 
	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.FontFace = NullUI.Theme.Font
	titleLabel.Text = title
	titleLabel.TextColor3 = NullUI.Theme.Text
	titleLabel.TextTransparency = 1
	titleLabel.TextSize = 14
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.AutomaticSize = Enum.AutomaticSize.XY
	titleLabel.Size = UDim2.fromOffset(0, 14)
	titleLabel.LayoutOrder = 2
	titleLabel.ZIndex = Z.Toast + 1
	titleLabel.Parent = headerRow
 
	local textLabel
	if text ~= "" then
		textLabel = Instance.new("TextLabel")
		textLabel.BackgroundTransparency = 1
		textLabel.FontFace = NullUI.Theme.FontRegular
		textLabel.Text = text
		textLabel.TextColor3 = NullUI.Theme.TextDim
		textLabel.TextTransparency = 1
		textLabel.TextSize = 12
		textLabel.TextWrapped = true
		textLabel.TextXAlignment = Enum.TextXAlignment.Left
		textLabel.AutomaticSize = Enum.AutomaticSize.Y
		textLabel.LayoutOrder = 2
		textLabel.Size = UDim2.new(1, 0, 0, 14)
		textLabel.ZIndex = Z.Toast + 1
		textLabel.Parent = card
	end
 
	local actionButtons = {}
	if type(opts.Actions) == "table" and #opts.Actions > 0 then
		local actionsRow = Instance.new("Frame")
		actionsRow.Name = "Actions"
		actionsRow.BackgroundTransparency = 1
		actionsRow.AutomaticSize = Enum.AutomaticSize.Y
		actionsRow.Size = UDim2.new(1, 0, 0, 0)
		actionsRow.LayoutOrder = 3
		actionsRow.ZIndex = Z.Toast + 1
		actionsRow.Parent = card
 
		local actionsLayout = Instance.new("UIListLayout")
		actionsLayout.FillDirection = Enum.FillDirection.Horizontal
		actionsLayout.Padding = UDim.new(0, 6)
		actionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
		actionsLayout.Parent = actionsRow
 
		for i, action in ipairs(opts.Actions) do
			local btn = Instance.new("TextButton")
			btn.AutoButtonColor = false
			btn.BackgroundColor3 = color
			btn.BackgroundTransparency = 1
			btn.BorderSizePixel = 0
			btn.Text = ""
			btn.AutomaticSize = Enum.AutomaticSize.X
			btn.Size = UDim2.fromOffset(0, 22)
			btn.LayoutOrder = i
			btn.ZIndex = Z.Toast + 1
			btn.Parent = actionsRow
			Corner(btn, 6)
			local btnStroke = Stroke(btn, color, 1, 1)
 
			local btnPad = Instance.new("UIPadding")
			btnPad.PaddingLeft = UDim.new(0, 8)
			btnPad.PaddingRight = UDim.new(0, 8)
			btnPad.Parent = btn
 
			local lbl = Instance.new("TextLabel")
			lbl.BackgroundTransparency = 1
			lbl.FontFace = NullUI.Theme.Font
			lbl.Text = action.Text or "Action"
			lbl.TextColor3 = color
			lbl.TextTransparency = 1
			lbl.TextSize = 12
			lbl.AutomaticSize = Enum.AutomaticSize.X
			lbl.Size = UDim2.fromOffset(0, 22)
			lbl.ZIndex = Z.Toast + 2
			lbl.Parent = btn
 
			Tween(btn, { BackgroundTransparency = 0.85 }, 0.28)
			Tween(btnStroke, { Transparency = 0.6 }, 0.28)
			Tween(lbl, { TextTransparency = 0 }, 0.28)
 
			btn.MouseEnter:Connect(function() Tween(btn, { BackgroundTransparency = 0.7 }, 0.12) end)
			btn.MouseLeave:Connect(function() Tween(btn, { BackgroundTransparency = 0.85 }, 0.12) end)
			btn.MouseButton1Click:Connect(function()
				if action.Callback then task.spawn(action.Callback) end
				if action.DismissOnClick ~= false then dismiss() end
			end)
 
			table.insert(actionButtons, { Button = btn, Stroke = btnStroke, Label = lbl })
		end
	end
 
	local barHolder = Instance.new("Frame")
	barHolder.BackgroundColor3 = Color3.new(1, 1, 1)
	barHolder.BackgroundTransparency = 1
	barHolder.BorderSizePixel = 0
	barHolder.Size = UDim2.new(1, 0, 0, 3)
	barHolder.LayoutOrder = 4
	barHolder.ZIndex = Z.Toast + 1
	barHolder.Parent = card
	Corner(barHolder, 2)
 
	local bar = Instance.new("Frame")
	bar.BackgroundColor3 = color
	bar.BackgroundTransparency = 1
	bar.BorderSizePixel = 0
	bar.AnchorPoint = Vector2.new(0, 0.5)
	bar.Position = UDim2.new(0, 0, 0.5, 0)
	bar.Size = UDim2.fromScale(1, 1)
	bar.ZIndex = Z.Toast + 2
	bar.Parent = barHolder
	Corner(bar, 2)
 
	local barGradient = Instance.new("UIGradient")
	barGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color:Lerp(Color3.new(1, 1, 1), 0.4)),
		ColorSequenceKeypoint.new(1, color),
	})
	barGradient.Parent = bar
 
 
	local dismissed = false
	function dismiss()
		if dismissed or not card.Parent then return end
		dismissed = true
		if not card.Visible then card:Destroy(); return end
 
		local currentHeight = card.AbsoluteSize.Y / GetUIScale()
		card.AutomaticSize = Enum.AutomaticSize.None
		card.Size = UDim2.new(1, 0, 0, currentHeight)
 
		Tween(card, { BackgroundTransparency = 1 }, 0.16)
		Tween(stroke, { Transparency = 1 }, 0.16)
		Tween(scale, { Scale = 0.9 }, 0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		Tween(icon, { ImageTransparency = 1 }, 0.16)
		Tween(titleLabel, { TextTransparency = 1 }, 0.16)
		if textLabel then Tween(textLabel, { TextTransparency = 1 }, 0.16) end
 
		task.delay(0.1, function()
			if card and card.Parent then
				Tween(card, { Size = UDim2.new(1, 0, 0, 0) }, 0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
			end
		end)
 
		task.delay(0.34, function()
			if notificationAcrylic then
				notificationAcrylic:Destroy()
				notificationAcrylic = nil
			end
			if card then card:Destroy() end
		end)
	end
 
	local function startNotification()
		if dismissed or not card.Parent then return end
		card.Visible = true
		notificationAcrylic = CreateWindowAcrylic(card)
	Tween(card, { BackgroundTransparency = 0.25 }, 0.28)
	Tween(stroke, { Transparency = 0.82 }, 0.28)
	Tween(scale, { Scale = 1 }, 0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	Tween(icon, { ImageTransparency = 0 }, 0.28)
	Tween(titleLabel, { TextTransparency = 0 }, 0.28)
	Tween(barHolder, { BackgroundTransparency = 0.88 }, 0.28)
	Tween(bar, { BackgroundTransparency = 0 }, 0.28)
	if textLabel then
		Tween(textLabel, { TextTransparency = 0 }, 0.28)
	end
 
	task.delay(0.05, function()
		if bar and bar.Parent then
			Tween(bar, { Size = UDim2.new(0, 0, 1, 0) }, duration - 0.05,
				Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
		end
	end)
 
		task.delay(duration, dismiss)
	end
	table.insert(NotificationQueue, { Card = card, Start = startNotification })
 
	return {
		Instance = card,
		Dismiss = dismiss,
	}
end
 
local function ComputeDialogCenter(anchorFrame)
	local view = ViewportSize()
	if not anchorFrame or anchorFrame.AbsoluteSize.X <= 0 then
		return view.X / 2, view.Y / 2
	end
	local pos, size = anchorFrame.AbsolutePosition, anchorFrame.AbsoluteSize
	local cx = SafeClamp(pos.X + size.X / 2, 190, math.max(190, view.X - 190))
	local cy = SafeClamp(pos.Y + size.Y / 2, 110, math.max(110, view.Y - 110))
	return cx, cy
end
 
function NullUI:Confirm(opts)
	opts = opts or {}
	local title       = opts.Title or "Confirm"
	local text        = opts.Text or ""
	local confirmText = opts.ConfirmText or "Confirm"
	local cancelText  = opts.CancelText or "Cancel"
	local danger      = opts.Danger == true
	local anchorFrame = opts.Window
	if type(anchorFrame) == "table" then
		anchorFrame = anchorFrame._gui
	end
 
	local root = NullUI._Root
	local jan = Janitor.new()
 
	local backdrop = Instance.new("TextButton")
	backdrop.Name = "ConfirmBackdrop"
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 1
	backdrop.BorderSizePixel = 0
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.ZIndex = Z.Modal
	backdrop.Parent = root
 
	local dialog = Instance.new("Frame")
	dialog.Name = "ConfirmDialog"
	dialog.AnchorPoint = Vector2.new(0.5, 0.5)
	do
		local cx, cy = ComputeDialogCenter(anchorFrame)
		local s = GetUIScale()
		dialog.Position = UDim2.fromOffset(math.round(cx / s), math.round(cy / s))
	end
	dialog.BackgroundColor3 = NullUI.Theme.Surface
	dialog.BackgroundTransparency = 1
	dialog.BorderSizePixel = 0
	dialog.Active = true
	dialog.ClipsDescendants = true
	dialog.AutomaticSize = Enum.AutomaticSize.Y
	dialog.Size = UDim2.new(0, 340, 0, 0)
	dialog.ZIndex = Z.ModalTop
	dialog.Parent = backdrop
	Corner(dialog, 16)
	local dialogStroke = Stroke(dialog, Color3.new(1, 1, 1), 1, 1)
 
	local scale = Instance.new("UIScale")
	scale.Scale = 0.9
	scale.Parent = dialog
 
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 20)
	padding.PaddingBottom = UDim.new(0, 18)
	padding.PaddingLeft = UDim.new(0, 20)
	padding.PaddingRight = UDim.new(0, 20)
	padding.Parent = dialog
 
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = dialog
 
	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.FontFace = NullUI.Theme.Font
	titleLabel.Text = title
	titleLabel.TextColor3 = danger and NullUI.Theme.Danger or NullUI.Theme.Text
	titleLabel.TextTransparency = 1
	titleLabel.TextSize = 18
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextWrapped = true
	titleLabel.AutomaticSize = Enum.AutomaticSize.Y
	titleLabel.Size = UDim2.new(1, 0, 0, 20)
	titleLabel.LayoutOrder = 1
	titleLabel.ZIndex = Z.ModalTop + 1
	titleLabel.Parent = dialog
 
	local textLabel
	if text ~= "" then
		textLabel = Instance.new("TextLabel")
		textLabel.BackgroundTransparency = 1
		textLabel.FontFace = NullUI.Theme.FontRegular
		textLabel.Text = text
		textLabel.TextColor3 = NullUI.Theme.TextDim
		textLabel.TextTransparency = 1
		textLabel.TextSize = 14
		textLabel.TextWrapped = true
		textLabel.TextXAlignment = Enum.TextXAlignment.Left
		textLabel.LineHeight = 1.25
		textLabel.AutomaticSize = Enum.AutomaticSize.Y
		textLabel.Size = UDim2.new(1, 0, 0, 14)
		textLabel.LayoutOrder = 2
		textLabel.ZIndex = Z.ModalTop + 1
		textLabel.Parent = dialog
	end
 
	local buttonsRow = Instance.new("Frame")
	buttonsRow.BackgroundTransparency = 1
	buttonsRow.Size = UDim2.new(1, 0, 0, 38)
	buttonsRow.LayoutOrder = 3
	buttonsRow.ZIndex = Z.ModalTop + 1
	buttonsRow.Parent = dialog
 
	local rowPad = Instance.new("UIPadding")
	rowPad.PaddingTop = UDim.new(0, 6)
	rowPad.Parent = buttonsRow
 
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.Padding = UDim.new(0, 8)
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Parent = buttonsRow
 
	local function makeButton(text_, order, filled)
		local tint = (filled and danger) and NullUI.Theme.Danger or Color3.new(1, 1, 1)
 
		local btn = Instance.new("TextButton")
		btn.Text = ""
		btn.AutoButtonColor = false
		btn.BackgroundColor3 = tint
		btn.BackgroundTransparency = filled and (danger and 0.55 or 0.82) or 1
		btn.BorderSizePixel = 0
		btn.Size = UDim2.new(0.5, -4, 1, 0)
		btn.LayoutOrder = order
		btn.ZIndex = Z.ModalTop + 1
		btn.Parent = buttonsRow
		Corner(btn, 10)
		local btnStroke = Stroke(btn, tint, 1, filled and 0.7 or 0.85)
 
		local lbl = Instance.new("TextLabel")
		lbl.BackgroundTransparency = 1
		lbl.FontFace = NullUI.Theme.Font
		lbl.Text = text_
		lbl.TextColor3 = (filled and danger) and NullUI.Theme.Danger or NullUI.Theme.Text
		lbl.TextSize = 14
		lbl.Size = UDim2.fromScale(1, 1)
		lbl.ZIndex = Z.ModalTop + 2
		lbl.Parent = btn
 
		local baseBg = btn.BackgroundTransparency
		local baseStroke = btnStroke.Transparency
 
		jan:Add(btn.MouseEnter:Connect(function()
			Tween(btn, { BackgroundTransparency = math.max(baseBg - 0.1, 0) }, 0.12)
			Tween(btnStroke, { Transparency = math.max(baseStroke - 0.15, 0) }, 0.12)
		end))
		jan:Add(btn.MouseLeave:Connect(function()
			Tween(btn, { BackgroundTransparency = baseBg }, 0.12)
			Tween(btnStroke, { Transparency = baseStroke }, 0.12)
		end))
 
		return btn
	end
 
	local cancelBtn  = makeButton(cancelText, 1, false)
	local confirmBtn = makeButton(confirmText, 2, true)
 
	local closed = false
	local function close(confirmed)
		if closed then return end
		closed = true
 
		Tween(scale, { Scale = 0.94 }, 0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		Tween(dialog, { BackgroundTransparency = 1 }, 0.15)
		Tween(dialogStroke, { Transparency = 1 }, 0.15)
		Tween(backdrop, { BackgroundTransparency = 1 }, 0.15)
		Tween(titleLabel, { TextTransparency = 1 }, 0.12)
		if textLabel then Tween(textLabel, { TextTransparency = 1 }, 0.12) end
 
		task.delay(0.18, function()
			jan:Destroy()
			if backdrop then backdrop:Destroy() end
		end)
 
		if opts.Callback then task.spawn(opts.Callback, confirmed) end
	end
 
	jan:Add(backdrop.MouseButton1Click:Connect(function() close(false) end))
	jan:Add(cancelBtn.MouseButton1Click:Connect(function() close(false) end))
	jan:Add(confirmBtn.MouseButton1Click:Connect(function() close(true) end))
 
	jan:Add(UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or closed then return end
		if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter then
			close(true)
		elseif input.KeyCode == Enum.KeyCode.Escape then
			close(false)
		end
	end))
 
	Tween(backdrop, { BackgroundTransparency = 0.5 }, 0.18)
	Tween(dialog, { BackgroundTransparency = 0 }, 0.18)
	Tween(dialogStroke, { Transparency = 0.8 }, 0.18)
	Tween(titleLabel, { TextTransparency = 0 }, 0.2)
	if textLabel then Tween(textLabel, { TextTransparency = 0 }, 0.2) end
	Tween(scale, { Scale = 1 }, 0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
 
	return { Close = close }
end
 
function NullUI:Modal(opts)
	opts = opts or {}
	local title       = opts.Title or "Modal"
	local text        = opts.Text or ""
	local confirmText = opts.ConfirmText or "Confirm"
	local cancelText  = opts.CancelText or "Cancel"
	local danger      = opts.Danger == true
	local fields      = opts.Fields or {}
	local anchorFrame = opts.Window
	if type(anchorFrame) == "table" then
		anchorFrame = anchorFrame._gui
	end
 
	local root = NullUI._Root
	local jan = Janitor.new()
 
	local backdrop = Instance.new("TextButton")
	backdrop.Name = "ModalBackdrop"
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 1
	backdrop.BorderSizePixel = 0
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.ZIndex = Z.Modal
	backdrop.Parent = root
 
	local dialog = Instance.new("Frame")
	dialog.Name = "ModalDialog"
	dialog.AnchorPoint = Vector2.new(0.5, 0.5)
	do
		local cx, cy = ComputeDialogCenter(anchorFrame)
		local s = GetUIScale()
		dialog.Position = UDim2.fromOffset(math.round(cx / s), math.round(cy / s))
	end
	dialog.BackgroundColor3 = NullUI.Theme.Surface
	dialog.BackgroundTransparency = 1
	dialog.BorderSizePixel = 0
	dialog.Active = true
	dialog.ClipsDescendants = true
	dialog.AutomaticSize = Enum.AutomaticSize.Y
	dialog.Size = UDim2.new(0, 360, 0, 0)
	dialog.ZIndex = Z.ModalTop
	dialog.Parent = backdrop
	Corner(dialog, 16)
	local dialogStroke = Stroke(dialog, Color3.new(1, 1, 1), 1, 1)
 
	local scale = Instance.new("UIScale")
	scale.Scale = 0.9
	scale.Parent = dialog
 
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 20)
	padding.PaddingBottom = UDim.new(0, 18)
	padding.PaddingLeft = UDim.new(0, 20)
	padding.PaddingRight = UDim.new(0, 20)
	padding.Parent = dialog
 
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 14)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = dialog
 
	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.FontFace = NullUI.Theme.Font
	titleLabel.Text = title
	titleLabel.TextColor3 = danger and NullUI.Theme.Danger or NullUI.Theme.Text
	titleLabel.TextTransparency = 1
	titleLabel.TextSize = 18
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextWrapped = true
	titleLabel.AutomaticSize = Enum.AutomaticSize.Y
	titleLabel.Size = UDim2.new(1, 0, 0, 20)
	titleLabel.LayoutOrder = 1
	titleLabel.ZIndex = Z.ModalTop + 1
	titleLabel.Parent = dialog
 
	local textLabel
	if text ~= "" then
		textLabel = Instance.new("TextLabel")
		textLabel.BackgroundTransparency = 1
		textLabel.FontFace = NullUI.Theme.FontRegular
		textLabel.Text = text
		textLabel.TextColor3 = NullUI.Theme.TextDim
		textLabel.TextTransparency = 1
		textLabel.TextSize = 13
		textLabel.TextWrapped = true
		textLabel.TextXAlignment = Enum.TextXAlignment.Left
		textLabel.LineHeight = 1.25
		textLabel.AutomaticSize = Enum.AutomaticSize.Y
		textLabel.Size = UDim2.new(1, 0, 0, 14)
		textLabel.LayoutOrder = 2
		textLabel.ZIndex = Z.ModalTop + 1
		textLabel.Parent = dialog
	end
 
	local fieldsHolder = Instance.new("Frame")
	fieldsHolder.BackgroundTransparency = 1
	fieldsHolder.AutomaticSize = Enum.AutomaticSize.Y
	fieldsHolder.Size = UDim2.new(1, 0, 0, 0)
	fieldsHolder.LayoutOrder = 3
	fieldsHolder.ZIndex = Z.ModalTop + 1
	fieldsHolder.Parent = dialog
 
	local fieldsLayout = Instance.new("UIListLayout")
	fieldsLayout.Padding = UDim.new(0, 10)
	fieldsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	fieldsLayout.Parent = fieldsHolder
 
	local fieldBoxes = {}
 
	for i, field in ipairs(fields) do
		local isTextarea = field.Type == "textarea"
		local labelH = field.Label and field.Label ~= "" and 16 or 0
		local boxH = isTextarea and 60 or 34
 
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.AutomaticSize = Enum.AutomaticSize.Y
		holder.Size = UDim2.new(1, 0, 0, 0)
		holder.LayoutOrder = i
		holder.ZIndex = Z.ModalTop + 1
		holder.Parent = fieldsHolder
 
		local holderLayout = Instance.new("UIListLayout")
		holderLayout.Padding = UDim.new(0, 4)
		holderLayout.SortOrder = Enum.SortOrder.LayoutOrder
		holderLayout.Parent = holder
 
		if labelH > 0 then
			local lbl = Instance.new("TextLabel")
			lbl.BackgroundTransparency = 1
			lbl.FontFace = NullUI.Theme.FontRegular
			lbl.Text = string.upper(field.Label)
			lbl.TextColor3 = danger and NullUI.Theme.Danger or NullUI.Theme.TextDim
			lbl.TextSize = 11
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Size = UDim2.new(1, 0, 0, labelH)
			lbl.LayoutOrder = 1
			lbl.ZIndex = Z.ModalTop + 2
			lbl.Parent = holder
		end
 
		local fieldFrame = Instance.new("Frame")
		fieldFrame.BackgroundColor3 = Color3.new(1, 1, 1)
		fieldFrame.BackgroundTransparency = 0.93
		fieldFrame.BorderSizePixel = 0
		fieldFrame.Size = UDim2.new(1, 0, 0, boxH)
		fieldFrame.LayoutOrder = 2
		fieldFrame.ZIndex = Z.ModalTop + 2
		fieldFrame.Parent = holder
		Corner(fieldFrame, 9)
		local fieldStroke = Stroke(fieldFrame, Color3.new(1, 1, 1), 1, 0.88)
 
		local fieldPad = Instance.new("UIPadding")
		fieldPad.PaddingLeft = UDim.new(0, 10)
		fieldPad.PaddingRight = UDim.new(0, 10)
		fieldPad.PaddingTop = UDim.new(0, isTextarea and 8 or 0)
		fieldPad.Parent = fieldFrame
 
		local box = Instance.new("TextBox")
		box.ClearTextOnFocus = false
		box.MultiLine = isTextarea
		box.FontFace = NullUI.Theme.FontRegular
		box.PlaceholderText = field.Placeholder or ""
		box.PlaceholderColor3 = Color3.fromRGB(120, 120, 122)
		box.Text = tostring(field.Default or "")
		box.TextColor3 = NullUI.Theme.Text
		box.TextSize = 13
		box.TextXAlignment = Enum.TextXAlignment.Left
		box.TextYAlignment = isTextarea and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center
		box.TextWrapped = isTextarea
		box.ClipsDescendants = true
		box.BackgroundTransparency = 1
		box.Size = UDim2.fromScale(1, 1)
		box.ZIndex = Z.ModalTop + 3
		box.Parent = fieldFrame
 
		if field.MaxLength then
			jan:Add(box:GetPropertyChangedSignal("Text"):Connect(function()
				if utf8.len(box.Text) and utf8.len(box.Text) > field.MaxLength then
					box.Text = string.sub(box.Text, 1, field.MaxLength)
				end
			end))
		end
 
		jan:Add(box.Focused:Connect(function()
			Tween(fieldStroke, { Color = NullUI.Theme.Accent, Transparency = 0.3 }, 0.15)
			Tween(fieldFrame, { BackgroundTransparency = 0.85 }, 0.15)
		end))
		jan:Add(box.FocusLost:Connect(function()
			Tween(fieldStroke, { Color = Color3.new(1, 1, 1), Transparency = 0.88 }, 0.15)
			Tween(fieldFrame, { BackgroundTransparency = 0.93 }, 0.15)
		end))
 
		fieldBoxes[field.Key or i] = { Type = field.Type, Box = box }
	end
 
	local buttonsRow = Instance.new("Frame")
	buttonsRow.BackgroundTransparency = 1
	buttonsRow.Size = UDim2.new(1, 0, 0, 38)
	buttonsRow.LayoutOrder = 4
	buttonsRow.ZIndex = Z.ModalTop + 1
	buttonsRow.Parent = dialog
 
	local rowPad = Instance.new("UIPadding")
	rowPad.PaddingTop = UDim.new(0, 4)
	rowPad.Parent = buttonsRow
 
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.Padding = UDim.new(0, 8)
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Parent = buttonsRow
 
	local function makeButton(text_, order, filled)
		local tint = (filled and danger) and NullUI.Theme.Danger or Color3.new(1, 1, 1)
 
		local btn = Instance.new("TextButton")
		btn.Text = ""
		btn.AutoButtonColor = false
		btn.BackgroundColor3 = tint
		btn.BackgroundTransparency = filled and (danger and 0.55 or 0.82) or 1
		btn.BorderSizePixel = 0
		btn.Size = UDim2.new(0.5, -4, 1, 0)
		btn.LayoutOrder = order
		btn.ZIndex = Z.ModalTop + 1
		btn.Parent = buttonsRow
		Corner(btn, 10)
		local btnStroke = Stroke(btn, tint, 1, filled and 0.7 or 0.85)
 
		local lbl = Instance.new("TextLabel")
		lbl.BackgroundTransparency = 1
		lbl.FontFace = NullUI.Theme.Font
		lbl.Text = text_
		lbl.TextColor3 = (filled and danger) and NullUI.Theme.Danger or NullUI.Theme.Text
		lbl.TextSize = 14
		lbl.Size = UDim2.fromScale(1, 1)
		lbl.ZIndex = Z.ModalTop + 2
		lbl.Parent = btn
 
		local baseBg = btn.BackgroundTransparency
		local baseStroke = btnStroke.Transparency
 
		jan:Add(btn.MouseEnter:Connect(function()
			Tween(btn, { BackgroundTransparency = math.max(baseBg - 0.1, 0) }, 0.12)
			Tween(btnStroke, { Transparency = math.max(baseStroke - 0.15, 0) }, 0.12)
		end))
		jan:Add(btn.MouseLeave:Connect(function()
			Tween(btn, { BackgroundTransparency = baseBg }, 0.12)
			Tween(btnStroke, { Transparency = baseStroke }, 0.12)
		end))
 
		return btn
	end
 
	local cancelBtn  = makeButton(cancelText, 1, false)
	local confirmBtn = makeButton(confirmText, 2, true)
 
	local function collectValues()
		local values = {}
		for key, entry in pairs(fieldBoxes) do
			if entry.Type == "tags" then
				local list = {}
				for piece in string.gmatch(entry.Box.Text, "[^,]+") do
					local trimmed = piece:gsub("^%s+", ""):gsub("%s+$", "")
					if trimmed ~= "" then table.insert(list, trimmed) end
				end
				values[key] = list
			else
				values[key] = entry.Box.Text
			end
		end
		return values
	end
 
	local closed = false
	local function close(confirmed)
		if closed then return end
		closed = true
 
		Tween(scale, { Scale = 0.94 }, 0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		Tween(dialog, { BackgroundTransparency = 1 }, 0.15)
		Tween(dialogStroke, { Transparency = 1 }, 0.15)
		Tween(backdrop, { BackgroundTransparency = 1 }, 0.15)
		Tween(titleLabel, { TextTransparency = 1 }, 0.12)
		if textLabel then Tween(textLabel, { TextTransparency = 1 }, 0.12) end
 
		task.delay(0.18, function()
			jan:Destroy()
			if backdrop then backdrop:Destroy() end
		end)
 
		if opts.Callback then
			task.spawn(opts.Callback, confirmed, confirmed and collectValues() or nil)
		end
	end
 
	jan:Add(backdrop.MouseButton1Click:Connect(function() close(false) end))
	jan:Add(cancelBtn.MouseButton1Click:Connect(function() close(false) end))
	jan:Add(confirmBtn.MouseButton1Click:Connect(function() close(true) end))
 
	jan:Add(UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or closed then return end
		if input.KeyCode == Enum.KeyCode.Escape then
			close(false)
		end
	end))
 
	Tween(backdrop, { BackgroundTransparency = 0.5 }, 0.18)
	Tween(dialog, { BackgroundTransparency = 0 }, 0.18)
	Tween(dialogStroke, { Transparency = 0.8 }, 0.18)
	Tween(titleLabel, { TextTransparency = 0 }, 0.2)
	if textLabel then Tween(textLabel, { TextTransparency = 0 }, 0.2) end
	Tween(scale, { Scale = 1 }, 0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
 
	return { Close = close }
end
 
local DRAG_SMOOTH_SPEED = 22
 
local function SetupSmoothDrag(frame, handle, janitor)
	handle = handle or frame
 
	local detector = handle:FindFirstChildWhichIsA("UIDragDetector")
	if detector then detector.Enabled = false end
 
	local dragging = false
	local settling = false
	local mouseOffset = Vector2.zero
	local activeInput = nil
 
	local function frameOffset()
		local pos = frame.Position
		local parentSize = ViewportSize()
		if frame.Parent and frame.Parent:IsA("GuiObject") and frame.Parent.AbsoluteSize.X > 0 then
			parentSize = frame.Parent.AbsoluteSize
		end
		local s = GetUIScale()
		return Vector2.new(
			pos.X.Scale * parentSize.X + pos.X.Offset * s,
			pos.Y.Scale * parentSize.Y + pos.Y.Offset * s
		)
	end
 
	local currentPosition = frameOffset()
	local targetPosition = currentPosition
 
	local function clampToScreen(pos)
		local view = ViewportSize()
		local size = frame.AbsoluteSize
		local anchor = frame.AnchorPoint
		local minVisible = 60
		local left = pos.X - size.X * anchor.X
		local top  = pos.Y - size.Y * anchor.Y
		left = SafeClamp(left, -size.X + minVisible, view.X - minVisible)
		-- A ScreenGui vive abaixo do inset do topo, entao travar em 0 era o teto invisivel
		-- que impedia arrastar a janela pra cima. -inset.Y libera ate a borda real da tela.
		top  = SafeClamp(top, -GuiService:GetGuiInset().Y, view.Y - minVisible)
		return Vector2.new(left + size.X * anchor.X, top + size.Y * anchor.Y)
	end
 
	local api = {}
 
	function api.Sync()
		currentPosition = frameOffset()
		targetPosition = currentPosition
		settling = false
	end
 
	janitor:Add(handle.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if dragging then return end
		dragging = true
		settling = true
		activeInput = input
		currentPosition = frameOffset()
		targetPosition = currentPosition
		mouseOffset = Vector2.new(input.Position.X, input.Position.Y) - currentPosition
	end))
 
	janitor:Add(UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if input.UserInputType == Enum.UserInputType.Touch
			and activeInput and input ~= activeInput then
			return
		end
		targetPosition = clampToScreen(
			Vector2.new(input.Position.X, input.Position.Y) - mouseOffset
		)
	end))
 
	janitor:Add(UserInputService.InputEnded:Connect(function(input)
		if input == activeInput
			or (activeInput and activeInput.UserInputType == Enum.UserInputType.MouseButton1
				and input.UserInputType == Enum.UserInputType.MouseButton1) then
			dragging = false
			activeInput = nil
		end
	end))
 
	janitor:Add(RunService.RenderStepped:Connect(function(dt)
		if not dragging and not settling then return end
		if not frame.Parent then return end
 
		local alpha = 1 - math.exp(-DRAG_SMOOTH_SPEED * dt)
		currentPosition = currentPosition:Lerp(targetPosition, alpha)
 
		if not dragging and (currentPosition - targetPosition).Magnitude < 0.5 then
			currentPosition = targetPosition
			settling = false
		end
 
		local s = GetUIScale()
		frame.Position = UDim2.fromOffset(
			math.round(currentPosition.X / s),
			math.round(currentPosition.Y / s)
		)
	end))
 
	return api
end
 
local function SetupResize(frame, handle, janitor, opts)
	opts = opts or {}
	local minSize = opts.MinSize or Vector2.new(420, 300)
	local onResize = opts.OnResize
 
	local resizing = false
	local startSize, startTopLeft, startInput, activeInput
 
	janitor:Add(handle.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if resizing then return end
		resizing = true
		activeInput = input
		startSize = frame.AbsoluteSize
		startTopLeft = frame.AbsolutePosition
		startInput = Vector2.new(input.Position.X, input.Position.Y)
	end))
 
	janitor:Add(UserInputService.InputChanged:Connect(function(input)
		if not resizing then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if input.UserInputType == Enum.UserInputType.Touch
			and activeInput and input ~= activeInput then
			return
		end
 
		local view = ViewportSize()
		local delta = Vector2.new(input.Position.X, input.Position.Y) - startInput
		local maxW = math.max(view.X - startTopLeft.X - 8, 100)
		local maxH = math.max(view.Y - startTopLeft.Y - 8, 100)
		local newW = SafeClamp(startSize.X + delta.X, math.min(minSize.X, maxW), maxW)
		local newH = SafeClamp(startSize.Y + delta.Y, math.min(minSize.Y, maxH), maxH)
 
		local s = GetUIScale()
		frame.Size = UDim2.fromOffset(math.round(newW / s), math.round(newH / s))
 
		local centerX = startTopLeft.X + newW / 2
		local centerY = startTopLeft.Y + newH / 2
		frame.Position = UDim2.fromOffset(math.round(centerX / s), math.round(centerY / s))
 
		if onResize then onResize(frame.Size, false) end
	end))
 
	janitor:Add(UserInputService.InputEnded:Connect(function(input)
		if not resizing then return end
		if input == activeInput
			or (activeInput and activeInput.UserInputType == Enum.UserInputType.MouseButton1
				and input.UserInputType == Enum.UserInputType.MouseButton1) then
			resizing = false
			activeInput = nil
			if onResize then onResize(frame.Size, true) end
		end
	end))
end
 
local DRAG_THRESHOLD = 6
 
local function BaseCard(parent, height)
	local card = Instance.new("Frame")
	card.BackgroundColor3 = Color3.new(1, 1, 1)
	card.BackgroundTransparency = 0.96
	card.BorderSizePixel = 0
	card.Size = UDim2.new(1, 0, 0, height or 44)
	card.ZIndex = Z.Content
	card.Parent = parent
	Corner(card, NullUI.Theme.CornerRadiusSm)
	Stroke(card, Color3.new(1, 1, 1), 1, 0.95)
	return card
end
 
local function AddLeadingIcon(card, icon, height)
	local asset = icon and ResolveIcon(icon) or ""
	if asset == "" then return 14, nil end
 
	local img = Instance.new("ImageLabel")
	img.Name = "LeadingIcon"
	img.BackgroundTransparency = 1
	img.Image = asset
	img.ImageColor3 = NullUI.Theme.TextDim
	img.Size = UDim2.fromOffset(16, 16)
	img.AnchorPoint = Vector2.new(0, 0.5)
	img.Position = UDim2.new(0, 14, 0.5, 0)
	img.ZIndex = Z.Content + 1
	img.Parent = card
	return 14 + 16 + 10, img
end
 
local function AddTitleDesc(card, x, rightReserve, title, description, baseHeight, extraBottom)
	extraBottom = extraBottom or 0
	local hasDesc = description ~= nil and description ~= ""
	local titleH, descH, gap = 16, 14, 3
 
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.FontFace = NullUI.Theme.Font
	titleLabel.Text = title
	titleLabel.TextColor3 = NullUI.Theme.Text
	titleLabel.TextSize = 14
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextYAlignment = Enum.TextYAlignment.Center
	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	titleLabel.Size = UDim2.new(1, -(x + (type(rightReserve) == "function" and rightReserve() or rightReserve)), 0, titleH)
	titleLabel.Position = UDim2.fromOffset(x, 0)
	titleLabel.ZIndex = Z.Content + 1
	titleLabel.Parent = card
 
	local descLabel
	if hasDesc then
		descLabel = Instance.new("TextLabel")
		descLabel.Name = "Description"
		descLabel.BackgroundTransparency = 1
		descLabel.FontFace = NullUI.Theme.FontRegular
		descLabel.Text = description
		descLabel.TextColor3 = NullUI.Theme.TextDim
		descLabel.TextSize = 12
		descLabel.TextWrapped = true
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.TextYAlignment = Enum.TextYAlignment.Top
		descLabel.Size = UDim2.new(1, -(x + (type(rightReserve) == "function" and rightReserve() or rightReserve)), 0, descH)
		descLabel.Position = UDim2.fromOffset(x, titleH + gap)
		descLabel.ZIndex = Z.Content + 1
		descLabel.Parent = card
	end
 
	local lastWidth = -1
	local lastReserve = -1
 
	local function relayout()
		local cardW = card.AbsoluteSize.X / GetUIScale()
		if cardW <= 0 then return end
		local reserve = type(rightReserve) == "function" and rightReserve() or rightReserve
		if math.abs(cardW - lastWidth) < 1 and reserve == lastReserve then return end
		lastReserve = reserve
		titleLabel.Size = UDim2.new(1, -(x + reserve), 0, titleH)
		lastWidth = cardW
 
		local avail = math.max(cardW - x - reserve, 1)
		local realDescH = descH
		if hasDesc then
			local _, h = MeasureText(description, 12, avail)
			realDescH = math.max(descH, h)
			descLabel.Size = UDim2.new(1, -(x + (type(rightReserve) == "function" and rightReserve() or rightReserve)), 0, realDescH)
		end
 
		local blockH = hasDesc and (titleH + gap + realDescH) or titleH
		local topPortion = math.max(baseHeight, blockH + 18)
		card.Size = UDim2.new(1, 0, 0, topPortion + extraBottom)
 
		local top = math.floor((topPortion - blockH) / 2)
		titleLabel.Position = UDim2.fromOffset(x, top)
		if hasDesc then
			descLabel.Position = UDim2.fromOffset(x, top + titleH + gap)
		end
	end
 
	card:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
	task.defer(relayout)
 
	return titleLabel, descLabel, relayout
end
 
local function AddEmptyState(scroll, overlayParent, janitor)
	local emptyState = Instance.new("Frame")
	emptyState.Name = "EmptyState"
	emptyState.BackgroundTransparency = 1
	emptyState.Size = UDim2.fromScale(1, 1)
	emptyState.ZIndex = (scroll.ZIndex or 0) + 5
	emptyState.Parent = overlayParent
 
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.Parent = emptyState
 
	local icon = Instance.new("ImageLabel")
	icon.BackgroundTransparency = 1
	icon.Image = ResolveIcon("frown")
	icon.ImageColor3 = NullUI.Theme.TextDim
	icon.Size = UDim2.fromOffset(26, 26)
	icon.LayoutOrder = 1
	icon.ZIndex = emptyState.ZIndex + 1
	icon.Parent = emptyState
 
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.FontFace = NullUI.Theme.FontRegular
	label.Text = "There's nothing here yet"
	label.TextColor3 = NullUI.Theme.TextDim
	label.TextSize = 13
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Size = UDim2.fromOffset(0, 16)
	label.LayoutOrder = 2
	label.ZIndex = emptyState.ZIndex + 1
	label.Parent = emptyState
 
	local function update()
		local hasContent = false
		for _, child in ipairs(scroll:GetChildren()) do
			local cn = child.ClassName
			if cn ~= "UIListLayout" and cn ~= "UIPadding" then
				hasContent = true
				break
			end
		end
		emptyState.Visible = not hasContent
	end
 
	janitor:Add(scroll.ChildAdded:Connect(update))
	janitor:Add(scroll.ChildRemoved:Connect(update))
	update()
 
	return emptyState
end
 
local Window = {}
Window.__index = Window
 
local Tab = {}
Tab.__index = Tab
 
function NullUI:CreateWindow(opts)
	opts = opts or {}
	local size = opts.Size or UDim2.fromOffset(605, 405)
 
	if IsMobileDevice then
		-- Landscape layout: use the available height instead of flattening the window.
		local vp = ViewportSize()
		local s = GetUIScale()
		size = UDim2.fromOffset(
			math.floor((vp.X / s) * 0.64),
			math.floor((vp.Y / s) * 0.96)
		)
	end
	local margin = NullUI.Theme.Margin
 
	local root = NullUI._Root
	local jan = Janitor.new()
 
	local main = Instance.new("Frame")
	main.Name = "Window"
	main.AnchorPoint = Vector2.new(0.5, 0.5)
	main.Position = UDim2.fromScale(0.5, IsMobileDevice and 0.5 or 0.55)
	main.Size = size
	main.BackgroundColor3 = NullUI.Theme.Background
	main.BackgroundTransparency = 1
	main.BorderSizePixel = 0
	main.ClipsDescendants = true
	main.ZIndex = Z.Window
	main.Parent = root
	Corner(main, NullUI.Theme.CornerRadius)
	Stroke(main, Color3.new(1, 1, 1), 1, 0.92)
	GlassLayer(main, NullUI.Theme.CornerRadius, 0.985)
 
	local topbar = Instance.new("Frame")
	topbar.Name = "TopBar"
	topbar.BackgroundTransparency = 1
	topbar.Size = UDim2.new(1, 0, 0, 52)
	topbar.ZIndex = Z.Content
	topbar.Parent = main
 
	local controlsHolder = Instance.new("Frame")
	controlsHolder.Name = "WindowControls"
	controlsHolder.AnchorPoint = Vector2.new(1, 0.5)
	controlsHolder.Position = UDim2.new(1, -margin, 0.5, 0)
	controlsHolder.Size = UDim2.fromOffset(120, 26)
	controlsHolder.BackgroundTransparency = 1
	controlsHolder.ZIndex = Z.Content + 1
	controlsHolder.Parent = topbar
 
	local controlsLayout = Instance.new("UIListLayout")
	controlsLayout.FillDirection = Enum.FillDirection.Horizontal
	controlsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	controlsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	controlsLayout.Padding = UDim.new(0, 4)
	controlsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	controlsLayout.Parent = controlsHolder
 
	local function addControl(icon, name, order, hoverColor)
		local btn = Instance.new("TextButton")
		btn.Name = name
		btn.Text = ""
		btn.AutoButtonColor = false
		btn.BackgroundColor3 = Color3.new(1, 1, 1)
		btn.BackgroundTransparency = 1
		btn.BorderSizePixel = 0
		btn.Size = UDim2.fromOffset(26, 26)
		btn.LayoutOrder = order
		btn.ZIndex = Z.Content + 1
		btn.Parent = controlsHolder
		Corner(btn, 8)
 
		local ic = Instance.new("ImageLabel")
		ic.BackgroundTransparency = 1
		ic.Image = ResolveIcon(icon)
		ic.ImageColor3 = NullUI.Theme.TextDim
		ic.Size = UDim2.fromOffset(14, 14)
		ic.AnchorPoint = Vector2.new(0.5, 0.5)
		ic.Position = UDim2.fromScale(0.5, 0.5)
		ic.ZIndex = Z.Content + 2
		ic.Parent = btn
 
		jan:Add(btn.MouseEnter:Connect(function()
			Tween(btn, { BackgroundTransparency = 0.9 }, 0.12)
			Tween(ic, { ImageColor3 = hoverColor or NullUI.Theme.Text }, 0.12)
		end))
		jan:Add(btn.MouseLeave:Connect(function()
			Tween(btn, { BackgroundTransparency = 1 }, 0.12)
			Tween(ic, { ImageColor3 = NullUI.Theme.TextDim }, 0.12)
		end))
		return btn
	end
 
	local searchBtn = addControl("search",   "SearchButton",     1)
	local minBtn    = addControl("minus",    "MinimizeButton",   2)
	local fullBtn   = addControl("maximize", "FullscreenButton", 3)
	local closeBtn  = addControl("x",        "CloseButton",      4)
 
	local titleStartX  = margin + 5
	local titleTextPad = 146
 
	local hasIcon = opts.Icon and opts.Icon ~= ""
	if hasIcon then
		local windowIcon = Instance.new("ImageLabel")
		windowIcon.Name = "WindowIcon"
		windowIcon.BackgroundTransparency = 1
		windowIcon.Image = ResolveIcon(opts.Icon)
		windowIcon.ImageColor3 = NullUI.Theme.Text
		windowIcon.Size = UDim2.fromOffset(20, 20)
		windowIcon.AnchorPoint = Vector2.new(0, 0.5)
		windowIcon.Position = UDim2.new(0, titleStartX, 0.5, 0)
		windowIcon.ZIndex = Z.Content
		windowIcon.Parent = topbar
		titleStartX += 20 + 8
	end
 
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.FontFace = NullUI.Theme.Font
	titleLabel.Text = opts.Title or "Window"
	titleLabel.TextColor3 = NullUI.Theme.Text
	titleLabel.TextSize = 16
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextYAlignment = Enum.TextYAlignment.Center
	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	titleLabel.Position = UDim2.fromOffset(titleStartX, opts.Subtitle and 8 or 0)
	titleLabel.Size = UDim2.new(1, -titleStartX - titleTextPad, 0, 20)
	titleLabel.ZIndex = Z.Content
	titleLabel.Parent = topbar
 
	local subLabel
	if opts.Subtitle then
		subLabel = Instance.new("TextLabel")
		subLabel.Name = "Subtitle"
		subLabel.BackgroundTransparency = 1
		subLabel.FontFace = NullUI.Theme.FontRegular
		subLabel.Text = opts.Subtitle
		subLabel.TextColor3 = NullUI.Theme.TextDim
		subLabel.TextSize = 13
		subLabel.TextXAlignment = Enum.TextXAlignment.Left
		subLabel.TextYAlignment = Enum.TextYAlignment.Center
		subLabel.TextTruncate = Enum.TextTruncate.AtEnd
		subLabel.Position = UDim2.fromOffset(titleStartX, 28)
		subLabel.Size = UDim2.new(1, -titleStartX - titleTextPad, 0, 14)
		subLabel.ZIndex = Z.Content
		subLabel.Parent = topbar
	end
 
	local tabBar = Instance.new("ScrollingFrame")
	tabBar.Name = "TabBar"
	tabBar.BackgroundTransparency = 1
	tabBar.BorderSizePixel = 0
	tabBar.Position = UDim2.fromOffset(margin, 58)
	tabBar.Size = UDim2.new(0, 130, 1, -(58 + margin))
	tabBar.ScrollBarThickness = 0
	tabBar.ScrollingDirection = Enum.ScrollingDirection.Y
	tabBar.AutomaticCanvasSize = Enum.AutomaticSize.Y
	tabBar.CanvasSize = UDim2.new(0, 0, 0, 0)
	tabBar.ZIndex = Z.Content
	tabBar.Parent = main
 
	local tabBarLayout = Instance.new("UIListLayout")
	tabBarLayout.Padding = UDim.new(0, 4)
	tabBarLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabBarLayout.Parent = tabBar
 
	AddScrollbar(tabBar)
 
	local tabIndicatorLayer = Instance.new("Frame")
	tabIndicatorLayer.Name = "TabIndicatorLayer"
	tabIndicatorLayer.BackgroundTransparency = 1
	tabIndicatorLayer.ClipsDescendants = true
	tabIndicatorLayer.ZIndex = Z.Window
	tabIndicatorLayer.Position = tabBar.Position
	tabIndicatorLayer.Size = tabBar.Size
	tabIndicatorLayer.Parent = main
 
	local tabIndicator = Instance.new("Frame")
	tabIndicator.Name = "Indicator"
	tabIndicator.BackgroundColor3 = Color3.new(1, 1, 1)
	tabIndicator.BackgroundTransparency = 1
	tabIndicator.BorderSizePixel = 0
	tabIndicator.ZIndex = Z.Window
	tabIndicator.Size = UDim2.new(1, 0, 0, 34)
	tabIndicator.Position = UDim2.new(0, 0, 0, 0)
	tabIndicator.Parent = tabIndicatorLayer
	Corner(tabIndicator, 10)
 
	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.BackgroundColor3 = Color3.new(1, 1, 1)
	divider.BackgroundTransparency = 0.94
	divider.BorderSizePixel = 0
	divider.Position = UDim2.new(0, margin + 144, 0, 58)
	divider.Size = UDim2.new(0, 1, 1, -(58 + margin))
	divider.ZIndex = Z.Content
	divider.Parent = main
 
	local contentX = margin + 144 + 16
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Position = UDim2.new(0, contentX, 0, 58)
	content.Size = UDim2.new(1, -contentX - margin, 1, -(58 + margin))
	content.ZIndex = Z.Content
	content.Parent = main
 
	local resizeHandle = Instance.new("ImageButton")
	resizeHandle.Name = "ResizeHandle"
	resizeHandle.BackgroundTransparency = 1
	resizeHandle.AutoButtonColor = false
	resizeHandle.Image = "rbxassetid://120997033468887"
	resizeHandle.ImageColor3 = NullUI.Theme.TextDim
	resizeHandle.ImageTransparency = 0.35
	resizeHandle.AnchorPoint = Vector2.new(1, 1)
	resizeHandle.Position = UDim2.new(1, -4, 1, -4)
	resizeHandle.Size = UDim2.fromOffset(16, 16)
	resizeHandle.ZIndex = Z.Content + 4
	resizeHandle.Parent = main
 
	jan:Add(resizeHandle.MouseEnter:Connect(function()
		Tween(resizeHandle, { ImageTransparency = 0 }, 0.12)
	end))
	jan:Add(resizeHandle.MouseLeave:Connect(function()
		Tween(resizeHandle, { ImageTransparency = 0.35 }, 0.12)
	end))
 
	Tween(main, { BackgroundTransparency = 0.15 }, 0.6, Enum.EasingStyle.Exponential)
 
	local self = setmetatable({
		_gui            = main,
		_content        = content,
		_tabBar         = tabBar,
		_tabIndicatorLayer = tabIndicatorLayer,
		_tabIndicator   = tabIndicator,
		_titleLabel     = titleLabel,
		_subLabel       = subLabel,
		_tabs           = {},
		_currentTab     = nil,
		_normalSize     = size,
		_fullscreen     = false,
		_janitor        = jan,
		_state          = "open",
		_busy           = false,
		_destroyed      = false,
		_searchIndex    = {},
		_useBlur        = opts.UseBlur ~= false,
		_defaultTabName = opts.DefaultTab,
		_tabChangeListeners = {},
	}, Window)
 
	table.insert(NullUI._Windows, self)
 
	if opts.Draggable ~= false then
		self._drag = SetupSmoothDrag(main, topbar, jan)
	end
 
	if opts.Resizable ~= false then
		SetupResize(main, resizeHandle, jan, {
			-- No mobile o minimo nao pode ser maior que a janela ja clampada, senao um
			-- resize devolve a janela pro tamanho cortado.
			MinSize = Vector2.new(
				math.min((opts.MinSize or Vector2.new(420, 300)).X, size.X.Offset),
				math.min((opts.MinSize or Vector2.new(420, 300)).Y, size.Y.Offset)
			),
			OnResize = function(newSize, finished)
				if self._fullscreen then return end
				if finished then
					self._normalSize = newSize
					self._sizeBeforeMinimize = newSize
				end
			end,
		})
	else
		resizeHandle.Visible = false
	end
 
	if self._useBlur then
		self._acrylic = CreateWindowAcrylic(main)
		jan:Add(self._acrylic)
	end
 
	jan:Add(closeBtn.MouseButton1Click:Connect(function()
		NullUI:Confirm({
			Title = "Close Window",
			Text = "Do you want to close this window? You will not be able to open it again. "
				.. "If you just want to hide it, use the minimize button instead.",
			ConfirmText = "Close Window",
			CancelText = "Cancel",
			Danger = true,
			Window = self,
			Callback = function(confirmed)
				if confirmed then self:Destroy() end
			end,
		})
	end))
 
	jan:Add(minBtn.MouseButton1Click:Connect(function() self:Toggle() end))
	jan:Add(fullBtn.MouseButton1Click:Connect(function() self:ToggleFullscreen() end))
	jan:Add(searchBtn.MouseButton1Click:Connect(function() self:_OpenSearch() end))
 
	jan:Add(UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or KeybindCapturing then return end
		if self._state ~= "open" then return end
		local ctrlDown = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
			or UserInputService:IsKeyDown(Enum.KeyCode.LeftMeta)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightMeta)
		if ctrlDown and input.KeyCode == Enum.KeyCode.K then
			self:_OpenSearch()
		end
	end))
 
	local toggleKey = opts.ToggleKeybind
	if toggleKey == nil then
		toggleKey = Enum.KeyCode.RightShift
	end
 
	if toggleKey then
		jan:Add(UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed or KeybindCapturing then return end
			if UserInputService:GetFocusedTextBox() then return end
			if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == toggleKey then
				self:Toggle()
			end
		end))
	end
 
	if IsMobileDevice then
		local mobileToggle = Instance.new("ImageButton")
		mobileToggle.Name = "MobileToggleButton"
		mobileToggle.BackgroundColor3 = Color3.fromRGB(1, 1, 1)
		mobileToggle.BackgroundTransparency = 1
		mobileToggle.BorderSizePixel = 0
		-- Alinhado com a barra do Roblox: a ScreenGui comeca abaixo do inset, entao
		-- subir inset.Y coloca o botao na mesma faixa das pilulas do topo.
		local topInset  = GuiService:GetGuiInset().Y
		local toggleSize = 45
		local bandY = -(topInset / GetUIScale()) + ((topInset / GetUIScale()) - toggleSize) / 2
 
		mobileToggle.AnchorPoint = Vector2.new(0, 0)
		mobileToggle.Position = opts.TogglePosition or UDim2.fromOffset(300, math.floor(bandY))
		mobileToggle.Size = UDim2.fromOffset(toggleSize, toggleSize)
		mobileToggle.Image = "rbxassetid://114231177950533"
		mobileToggle.ZIndex = Z.Toast
		mobileToggle.Parent = root
 
		local mobileToggleCorner = Instance.new("UICorner")
		mobileToggleCorner.CornerRadius = UDim.new(1, 0)
		mobileToggleCorner.Parent = mobileToggle
 
		-- Draggable is deprecated and swallows touch input (Activated never fires),
		-- so drive the drag by hand and treat a touch that barely moved as a tap.
		local DRAG_SLOP = 8
		local dragInput, dragStart, startPos, dragged
 
		jan:Add(mobileToggle.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.Touch
				and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return
			end
			if dragInput then return end
			dragInput = input
			dragStart = input.Position
			startPos  = mobileToggle.Position
			dragged   = false
		end))
 
		jan:Add(UserInputService.InputChanged:Connect(function(input)
			if input ~= dragInput or not dragStart then return end
			local delta = input.Position - dragStart
			if not dragged and delta.Magnitude > DRAG_SLOP then dragged = true end
			if not dragged then return end
			local s = GetUIScale()
			mobileToggle.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X / s,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y / s
			)
		end))
 
		jan:Add(UserInputService.InputEnded:Connect(function(input)
			if input ~= dragInput then return end
			dragInput, dragStart = nil, nil
			if not dragged then
				self:Toggle()
			end
		end))
 
		jan:Add(mobileToggle)
	elseif toggleKey then
		NullUI:Notify({
			Title = "Minimize Keybind",
			Text  = "Press " .. toggleKey.Name .. " to minimize or open this panel.",
			Type  = "info",
			Duration = 15,
		})
	end
 
	return self
end
 
function Window:SetTitle(title, subtitle)
	if self._titleLabel then self._titleLabel.Text = title or self._titleLabel.Text end
	if subtitle and self._subLabel then self._subLabel.Text = subtitle end
end
 
function Window:IsOpen()
	return self._state == "open"
end
 
function Window:Destroy()
	if self._destroyed then return end
	self._destroyed = true
 
	local idx = table.find(NullUI._Windows, self)
	if idx then table.remove(NullUI._Windows, idx) end
 
	CloseAnyOpenPopup()
 
	local gui = self._gui
 
	Tween(gui, {
		Size = UDim2.new(gui.Size.X.Scale, gui.Size.X.Offset, 0, 0),
	}, 0.34, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	Tween(gui, { BackgroundTransparency = 1 }, 0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
 
	task.delay(0.34, function()
		self._janitor:Destroy()
		if gui then gui:Destroy() end
	end)
end
 
function Window:Toggle()
	if self._destroyed or self._busy then return end
	if self._state == "open" then
		self:Close()
	else
		self:Open()
	end
end
 
function Window:Close()
	if self._destroyed or self._busy or self._state ~= "open" then return end
	self._busy = true
	self._state = "closed"
 
	CloseAnyOpenPopup()
 
	local gui = self._gui
	self._sizeBeforeMinimize = self._fullscreen
		and UDim2.new(0.94, 0, 0.9, 0)
		or (self._normalSize or gui.Size)
 
	Tween(gui, {
		Size = UDim2.new(gui.Size.X.Scale, gui.Size.X.Offset, 0, 0),
	}, 0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	Tween(gui, { BackgroundTransparency = 1 }, 0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
 
	task.delay(0.28, function()
		if self._destroyed then return end
		if self._state == "closed" and gui and gui.Parent then
			gui.Visible = false
		end
		self._busy = false
	end)
 
end
 
function Window:Open()
	if self._destroyed or self._busy or self._state ~= "closed" then return end
	self._busy = true
	self._state = "open"
 
	local gui = self._gui
	gui.Visible = true
 
	local targetSize = self._sizeBeforeMinimize or self._normalSize
	Tween(gui, {
		Size = targetSize,
		BackgroundTransparency = 0.15,
	}, 0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
 
	task.delay(0.33, function()
		self._busy = false
		if self._drag then self._drag.Sync() end
	end)
end
 
function Window:ToggleFullscreen()
	if self._destroyed then return end
	local gui = self._gui
	self._fullscreen = not self._fullscreen
 
	CloseAnyOpenPopup()
 
	if self._fullscreen then
		self._preFullscreenPosition = gui.Position
		Tween(gui, {
			Size = UDim2.new(0.94, 0, 0.9, 0),
			Position = UDim2.fromScale(0.5, 0.5),
		}, 0.35, Enum.EasingStyle.Quint)
	else
		Tween(gui, {
			Size = self._normalSize,
			Position = self._preFullscreenPosition or UDim2.fromScale(0.5, 0.55),
		}, 0.35, Enum.EasingStyle.Quint)
	end
 
	task.delay(0.36, function()
		if self._drag then self._drag.Sync() end
	end)
end
 
function Window:AddTabLine()
	local holder = Instance.new("Frame")
	holder.Name = "TabLine"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, 9)
	holder.ZIndex = Z.Content
	holder.Parent = self._tabBar
 
	local line = Instance.new("Frame")
	line.AnchorPoint = Vector2.new(0, 0.5)
	line.Position = UDim2.new(0, 4, 0.5, 0)
	line.Size = UDim2.new(1, -8, 0, 1)
	line.BackgroundColor3 = Color3.new(1, 1, 1)
	line.BackgroundTransparency = 0.92
	line.BorderSizePixel = 0
	line.ZIndex = Z.Content
	line.Parent = holder
 
	return holder
end
 
local DOCK_ICON_SIZE = 28
local DOCK_HEIGHT    = 34
 
function Window:AddDockButton(opts)
	opts = opts or {}
	local jan = self._janitor
	local margin = NullUI.Theme.Margin
 
	if not self._dock then
		local shrunkSize = UDim2.new(0, 130, 1, -(58 + margin + DOCK_HEIGHT + 10))
		self._tabBar.Size = shrunkSize
		self._tabIndicatorLayer.Size = shrunkSize
 
		local dock = Instance.new("Frame")
		dock.Name = "Dock"
		dock.BackgroundTransparency = 1
		dock.AnchorPoint = Vector2.new(0, 1)
		dock.Position = UDim2.new(0, margin, 1, -margin)
		dock.Size = UDim2.new(0, 130, 0, DOCK_HEIGHT)
		dock.ZIndex = Z.Content
		dock.Parent = self._gui
 
		local dockLayout = Instance.new("UIListLayout")
		dockLayout.FillDirection = Enum.FillDirection.Horizontal
		dockLayout.Padding = UDim.new(0, 6)
		dockLayout.SortOrder = Enum.SortOrder.LayoutOrder
		dockLayout.Parent = dock
 
		self._dock = dock
	end
 
	local btn = Instance.new("TextButton")
	btn.Name = opts.Name or "DockButton"
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.BackgroundColor3 = Color3.new(1, 1, 1)
	btn.BackgroundTransparency = 0.95
	btn.BorderSizePixel = 0
	btn.Size = UDim2.fromOffset(DOCK_ICON_SIZE, DOCK_ICON_SIZE)
	btn.LayoutOrder = #self._dock:GetChildren()
	btn.ZIndex = Z.Content + 1
	btn.Parent = self._dock
	Corner(btn, 8)
 
	local icon = Instance.new("ImageLabel")
	icon.BackgroundTransparency = 1
	icon.Image = opts.Icon and ResolveIcon(opts.Icon) or ""
	icon.ImageColor3 = NullUI.Theme.TextDim
	icon.Size = UDim2.fromOffset(15, 15)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.ZIndex = Z.Content + 2
	icon.Parent = btn
 
	local active = false
 
	jan:Add(btn.MouseEnter:Connect(function()
		if active then return end
		Tween(btn, { BackgroundTransparency = 0.85 }, 0.12)
		Tween(icon, { ImageColor3 = NullUI.Theme.Text }, 0.12)
	end))
	jan:Add(btn.MouseLeave:Connect(function()
		if active then return end
		Tween(btn, { BackgroundTransparency = 0.95 }, 0.12)
		Tween(icon, { ImageColor3 = NullUI.Theme.TextDim }, 0.12)
	end))
	jan:Add(btn.MouseButton1Click:Connect(function()
		if opts.Callback then task.spawn(opts.Callback) end
	end))
 
	return {
		Instance = btn,
		Icon = icon,
		SetActive = function(_, isActive)
			active = isActive and true or false
			Tween(btn, { BackgroundTransparency = active and 0.8 or 0.95 }, 0.12)
			Tween(icon, { ImageColor3 = active and NullUI.Theme.Text or NullUI.Theme.TextDim }, 0.12)
		end,
	}
end
 
local CHAT_CODE_FONT = "rbxasset://fonts/families/RobotoMono.json"
 
local function EscapeRichText(text)
	text = text:gsub("&", "&amp;")
	text = text:gsub("<", "&lt;")
	text = text:gsub(">", "&gt;")
	return text
end
 
local function MarkdownToRichText(text)
	text = EscapeRichText(text)
 
	text = text:gsub("`([^`\n]+)`", "<font family=\"" .. CHAT_CODE_FONT .. "\">%1</font>")
 
	text = text:gsub("%*%*(.-)%*%*", "<b>%1</b>")
	text = text:gsub("__(.-)__", "<b>%1</b>")
 
	text = text:gsub("%*([^%s*][^*]-)%*", "<i>%1</i>")
	text = text:gsub("_([^%s_][^_]-)_", "<i>%1</i>")
 
	return text
end
 
local function SplitMessageSegments(text)
	local segments = {}
	local pos = 1
	while true do
		local s, e, lang, code = text:find("```(%w*)\n?(.-)```", pos)
		if not s then
			local rest = text:sub(pos)
			if rest ~= "" then table.insert(segments, { kind = "text", content = rest }) end
			break
		end
		if s > pos then
			local before = text:sub(pos, s - 1)
			if before:match("%S") then
				table.insert(segments, { kind = "text", content = before })
			end
		end
		code = code:gsub("^%s+", ""):gsub("%s+$", "")
		table.insert(segments, { kind = "code", lang = lang ~= "" and lang or "lua", content = code })
		pos = e + 1
	end
	if #segments == 0 then
		table.insert(segments, { kind = "text", content = text })
	end
	return segments
end
 
local LUA_KEYWORDS = {
	["and"] = true, ["break"] = true, ["do"] = true, ["else"] = true, ["elseif"] = true,
	["end"] = true, ["false"] = true, ["for"] = true, ["function"] = true, ["if"] = true,
	["in"] = true, ["local"] = true, ["nil"] = true, ["not"] = true, ["or"] = true,
	["repeat"] = true, ["return"] = true, ["then"] = true, ["true"] = true,
	["until"] = true, ["while"] = true, ["continue"] = true,
}
 
local function HighlightLua(code)
	local out = {}
	local n = #code
	local i = 1
 
	while i <= n do
		local c = code:sub(i, i)
 
		if code:sub(i, i + 3) == "--[[" then
			local closeEnd = select(2, code:find("%]%]", i + 4))
			local stop = closeEnd or n
			out[#out + 1] = "<font color=\"#6A9955\">" .. code:sub(i, stop) .. "</font>"
			i = stop + 1
		elseif code:sub(i, i + 1) == "--" then
			local nl = code:find("\n", i, true)
			local stop = (nl or (n + 1)) - 1
			out[#out + 1] = "<font color=\"#6A9955\">" .. code:sub(i, stop) .. "</font>"
			i = stop + 1
		elseif c == '"' or c == "'" then
			local quote = c
			local j = i + 1
			while j <= n do
				local jc = code:sub(j, j)
				if jc == "\\" then
					j = j + 2
				elseif jc == quote or jc == "\n" then
					break
				else
					j = j + 1
				end
			end
			j = math.min(j, n)
			out[#out + 1] = "<font color=\"#CE9178\">" .. code:sub(i, j) .. "</font>"
			i = j + 1
		elseif c:match("%a") or c == "_" then
			local j = i
			while j <= n and code:sub(j, j):match("[%w_]") do j = j + 1 end
			local word = code:sub(i, j - 1)
			out[#out + 1] = LUA_KEYWORDS[word] and ("<font color=\"#C586C0\">" .. word .. "</font>") or word
			i = j
		elseif c:match("%d") then
			local j = i
			while j <= n and code:sub(j, j):match("[%d%.]") do j = j + 1 end
			out[#out + 1] = "<font color=\"#B5CEA8\">" .. code:sub(i, j - 1) .. "</font>"
			i = j
		else
			out[#out + 1] = c
			i = i + 1
		end
	end
 
	return table.concat(out)
end
 
function Window:AddPanelTab(opts)
	opts = opts or {}
	local self_ = self
	local tabObj = self:AddTab({
		Name   = opts.Name,
		Icon   = opts.Icon,
		Hidden = opts.Hidden ~= false,
	})
	tabObj._page.Visible = false
	local staleEmptyState = tabObj._group:FindFirstChild("EmptyState")
	if staleEmptyState then staleEmptyState.Visible = false end
 
	if opts.OnToggle then
		table.insert(self._tabChangeListeners, function(selected)
			task.spawn(opts.OnToggle, selected == tabObj)
		end)
	end
 
	local lastRealTab = nil
	local function openPanel()
		if self_._currentTab == tabObj then return end
		if self_._currentTab and not self_._currentTab.Hidden then
			lastRealTab = self_._currentTab
		end
		tabObj._select()
	end
	local function closePanel()
		if self_._currentTab ~= tabObj then return end
		if lastRealTab and not lastRealTab.Hidden then
			lastRealTab._select()
		elseif self_._tabs[1] and self_._tabs[1] ~= tabObj then
			self_._tabs[1]._select()
		end
	end
 
	return {
		Instance = tabObj._group,
		Tab = tabObj,
		Open = openPanel,
		Close = closePanel,
		Toggle = function()
			if self_._currentTab == tabObj then closePanel() else openPanel() end
		end,
		IsOpen = function() return self_._currentTab == tabObj end,
	}
end
 
function Window:AddDefaultCreditsPanel()
	local jan = self._janitor
	local dockBtn
	local panel = self:AddPanelTab({
		Name = "Credits",
		Icon = "Lucide:heart-handshake",
		OnToggle = function(isOpen)
			if dockBtn then dockBtn:SetActive(isOpen) end
		end,
	})
 
	local CREDITS = {
		{ Name = "Skinny",   Role = "~90% of the UI, and organization of the Touchline script and its functions", Color = Color3.fromRGB(120, 150, 255) },
		{ Name = "Shezz",    Role = "Sub-tabs, and suggestions for the UI and script", Color = Color3.fromRGB(110, 210, 170) },
		{ Name = "NoSkills", Role = "Suggestions for the UI, and developer of Touchline script functions", Color = Color3.fromRGB(190, 150, 255) },
		{ Name = "Luxy_00",  Role = "Mobile UI tester, and developer of Touchline script functions", Color = Color3.fromRGB(255, 190, 110) },
		{ Name = "Elusive",  Role = "Suggestions for the UI, and main contributor to getting it launched fast", Color = Color3.fromRGB(255, 140, 170) },
	}
 
	local HEADER_H = 38
 
	local header = Instance.new("Frame")
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, HEADER_H)
	header.ZIndex = Z.Content + 1
	header.Parent = panel.Instance
 
	local headerPad = Instance.new("UIPadding")
	headerPad.PaddingLeft = UDim.new(0, 14)
	headerPad.PaddingRight = UDim.new(0, 8)
	headerPad.Parent = header
 
	local titleRow = Instance.new("Frame")
	titleRow.BackgroundTransparency = 1
	titleRow.Size = UDim2.new(1, -40, 1, 0)
	titleRow.ZIndex = Z.Content + 2
	titleRow.Parent = header
 
	local titleLayout = Instance.new("UIListLayout")
	titleLayout.FillDirection = Enum.FillDirection.Horizontal
	titleLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	titleLayout.Padding = UDim.new(0, 7)
	titleLayout.Parent = titleRow
 
	local titleIcon = Instance.new("ImageLabel")
	titleIcon.BackgroundTransparency = 1
	titleIcon.Image = ResolveIcon("heart-handshake")
	titleIcon.ImageColor3 = NullUI.Theme.Text
	titleIcon.Size = UDim2.fromOffset(14, 14)
	titleIcon.LayoutOrder = 1
	titleIcon.ZIndex = Z.Content + 3
	titleIcon.Parent = titleRow
 
	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.FontFace = NullUI.Theme.Font
	titleLabel.Text = "Credits"
	titleLabel.TextColor3 = NullUI.Theme.Text
	titleLabel.TextSize = 14
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.AutomaticSize = Enum.AutomaticSize.X
	titleLabel.Size = UDim2.fromOffset(0, 14)
	titleLabel.LayoutOrder = 2
	titleLabel.ZIndex = Z.Content + 3
	titleLabel.Parent = titleRow
 
	local closeBtn = Instance.new("TextButton")
	closeBtn.Text = ""
	closeBtn.AutoButtonColor = false
	closeBtn.BackgroundColor3 = Color3.new(1, 1, 1)
	closeBtn.BackgroundTransparency = 1
	closeBtn.BorderSizePixel = 0
	closeBtn.AnchorPoint = Vector2.new(1, 0.5)
	closeBtn.Position = UDim2.new(1, 0, 0.5, 0)
	closeBtn.Size = UDim2.fromOffset(26, 26)
	closeBtn.ZIndex = Z.Content + 2
	closeBtn.Parent = header
 
	local closeIcon = Instance.new("ImageLabel")
	closeIcon.BackgroundTransparency = 1
	closeIcon.Image = ResolveIcon("x")
	closeIcon.ImageColor3 = NullUI.Theme.TextDim
	closeIcon.Size = UDim2.fromOffset(13, 13)
	closeIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	closeIcon.Position = UDim2.fromScale(0.5, 0.5)
	closeIcon.ZIndex = Z.Content + 3
	closeIcon.Parent = closeBtn
 
	closeBtn.MouseEnter:Connect(function() closeIcon.ImageColor3 = NullUI.Theme.Text end)
	closeBtn.MouseLeave:Connect(function() closeIcon.ImageColor3 = NullUI.Theme.TextDim end)
	closeBtn.MouseButton1Click:Connect(function() panel.Close() end)
 
	local divider = Instance.new("Frame")
	divider.BackgroundColor3 = Color3.new(1, 1, 1)
	divider.BackgroundTransparency = 0.94
	divider.BorderSizePixel = 0
	divider.Position = UDim2.fromOffset(0, HEADER_H)
	divider.Size = UDim2.new(1, 0, 0, 1)
	divider.ZIndex = Z.Content + 1
	divider.Parent = panel.Instance
 
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(0, HEADER_H + 1)
	scroll.Size = UDim2.new(1, 0, 1, -(HEADER_H + 1))
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.ScrollBarThickness = 0
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.ZIndex = Z.Content + 1
	scroll.Parent = panel.Instance
 
	local scrollPad = Instance.new("UIPadding")
	scrollPad.PaddingTop = UDim.new(0, 12)
	scrollPad.PaddingBottom = UDim.new(0, 12)
	scrollPad.PaddingLeft = UDim.new(0, 14)
	scrollPad.PaddingRight = UDim.new(0, 14)
	scrollPad.Parent = scroll
 
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = scroll
 
	AddScrollbar(scroll)
	AddContentScrollThumb(scroll, listLayout, panel.Instance, jan)
 
	for i, credit in ipairs(CREDITS) do
		local row = Instance.new("Frame")
		row.Name = credit.Name
		row.BackgroundColor3 = Color3.new(1, 1, 1)
		row.BackgroundTransparency = 0.96
		row.BorderSizePixel = 0
		row.LayoutOrder = i
		row.Size = UDim2.new(1, 0, 0, 60)
		row.ZIndex = Z.Content + 2
		row.Parent = scroll
 
		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 10)
		rowCorner.Parent = row
 
		local rowStroke = Instance.new("UIStroke")
		rowStroke.Color = Color3.new(1, 1, 1)
		rowStroke.Transparency = 0.94
		rowStroke.Thickness = 1
		rowStroke.Parent = row
 
		row.MouseEnter:Connect(function() row.BackgroundTransparency = 0.92 end)
		row.MouseLeave:Connect(function() row.BackgroundTransparency = 0.96 end)
 
		local avatar = Instance.new("Frame")
		avatar.AnchorPoint = Vector2.new(0, 0.5)
		avatar.Position = UDim2.new(0, 12, 0.5, 0)
		avatar.Size = UDim2.fromOffset(38, 38)
		avatar.BackgroundColor3 = credit.Color
		avatar.BackgroundTransparency = 0.82
		avatar.BorderSizePixel = 0
		avatar.ZIndex = Z.Content + 2
		avatar.Parent = row
 
		local avCorner = Instance.new("UICorner")
		avCorner.CornerRadius = UDim.new(1, 0)
		avCorner.Parent = avatar
 
		local avStroke = Instance.new("UIStroke")
		avStroke.Color = credit.Color
		avStroke.Transparency = 0.55
		avStroke.Thickness = 1
		avStroke.Parent = avatar
 
		local avIcon = Instance.new("ImageLabel")
		avIcon.BackgroundTransparency = 1
		avIcon.Image = ResolveIcon("user-round")
		avIcon.ImageColor3 = credit.Color
		avIcon.Size = UDim2.fromOffset(17, 17)
		avIcon.AnchorPoint = Vector2.new(0.5, 0.5)
		avIcon.Position = UDim2.fromScale(0.5, 0.5)
		avIcon.ZIndex = Z.Content + 3
		avIcon.Parent = avatar
 
		local nameLabel = Instance.new("TextLabel")
		nameLabel.BackgroundTransparency = 1
		nameLabel.FontFace = NullUI.Theme.Font
		nameLabel.Text = credit.Name
		nameLabel.TextColor3 = NullUI.Theme.Text
		nameLabel.TextSize = 13.5
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Position = UDim2.fromOffset(62, 8)
		nameLabel.Size = UDim2.new(1, -74, 0, 16)
		nameLabel.ZIndex = Z.Content + 2
		nameLabel.Parent = row
 
		local roleLabel = Instance.new("TextLabel")
		roleLabel.BackgroundTransparency = 1
		roleLabel.FontFace = NullUI.Theme.FontRegular
		roleLabel.Text = credit.Role
		roleLabel.TextColor3 = NullUI.Theme.TextDim
		roleLabel.TextSize = 11.5
		roleLabel.TextWrapped = true
		roleLabel.TextXAlignment = Enum.TextXAlignment.Left
		roleLabel.TextYAlignment = Enum.TextYAlignment.Top
		roleLabel.Position = UDim2.fromOffset(62, 25)
		roleLabel.Size = UDim2.new(1, -74, 0, 28)
		roleLabel.ZIndex = Z.Content + 2
		roleLabel.Parent = row
	end
 
	dockBtn = self:AddDockButton({
		Icon = "Lucide:heart-handshake",
		Callback = function() panel.Toggle() end,
	})
 
	return panel
end
 
function Window:AddSpotifyPanel(opts)
	opts = opts or {}
	local jan = self._janitor
	local dockBtn
	local connectBridge
	local hasOpenedSpotify = false
	local panel
	panel = self:AddPanelTab({
		Name = opts.Name or "Spotify",
		Icon = opts.Icon or "Lucide:music-2",
		OnToggle = function(isOpen)
			if dockBtn then dockBtn:SetActive(isOpen) end
			if isOpen and not hasOpenedSpotify then
				hasOpenedSpotify = true
				if opts.AutoConnect == true and opts.BridgeUrl ~= "" then
					task.defer(function()
						if connectBridge then connectBridge() end
					end)
				end
			end
			if opts.OnToggle then task.spawn(opts.OnToggle, isOpen) end
		end,
	})
 
	local function websocketConnect()
		local candidates = {}
		pcall(function()
			if WebSocket and type(WebSocket.connect) == "function" then
				table.insert(candidates, WebSocket.connect)
			end
		end)
		pcall(function()
			if websocket and type(websocket.connect) == "function" then
				table.insert(candidates, websocket.connect)
			end
		end)
		pcall(function()
			if syn and syn.websocket and type(syn.websocket.connect) == "function" then
				table.insert(candidates, syn.websocket.connect)
			end
		end)
		return candidates[1]
	end
 
	local HEADER_H = 0
	local header = Instance.new("Frame")
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, HEADER_H)
	header.ZIndex = Z.Content + 1
	header.Parent = panel.Instance
	header.Visible = false
 
	local headerPad = Instance.new("UIPadding")
	headerPad.PaddingLeft = UDim.new(0, 14)
	headerPad.PaddingRight = UDim.new(0, 8)
	headerPad.Parent = header
 
	local titleIcon = Instance.new("ImageLabel")
	titleIcon.BackgroundTransparency = 1
	titleIcon.Image = ResolveIcon(opts.Icon or "Lucide:music-2")
	titleIcon.ImageColor3 = Color3.fromRGB(30, 215, 96)
	titleIcon.AnchorPoint = Vector2.new(0, 0.5)
	titleIcon.Position = UDim2.new(0, 0, 0.5, 0)
	titleIcon.Size = UDim2.fromOffset(15, 15)
	titleIcon.ZIndex = Z.Content + 2
	titleIcon.Parent = header
 
	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.FontFace = NullUI.Theme.Font
	titleLabel.Text = opts.Title or "Spotify Player"
	titleLabel.TextColor3 = NullUI.Theme.Text
	titleLabel.TextSize = 14
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.AnchorPoint = Vector2.new(0, 0.5)
	titleLabel.Position = UDim2.new(0, 22, 0.5, 0)
	titleLabel.Size = UDim2.new(1, -62, 0, 18)
	titleLabel.ZIndex = Z.Content + 2
	titleLabel.Parent = header
 
	local closeBtn = Instance.new("TextButton")
	closeBtn.Text = ""
	closeBtn.AutoButtonColor = false
	closeBtn.BackgroundTransparency = 1
	closeBtn.AnchorPoint = Vector2.new(1, 0.5)
	closeBtn.Position = UDim2.new(1, 0, 0.5, 0)
	closeBtn.Size = UDim2.fromOffset(26, 26)
	closeBtn.ZIndex = Z.Content + 2
	closeBtn.Parent = header
 
	local closeIcon = Instance.new("ImageLabel")
	closeIcon.BackgroundTransparency = 1
	closeIcon.Image = ResolveIcon("x")
	closeIcon.ImageColor3 = NullUI.Theme.TextDim
	closeIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	closeIcon.Position = UDim2.fromScale(0.5, 0.5)
	closeIcon.Size = UDim2.fromOffset(13, 13)
	closeIcon.ZIndex = Z.Content + 3
	closeIcon.Parent = closeBtn
	jan:Add(closeBtn.MouseButton1Click:Connect(function() panel.Close() end))
 
	local divider = Instance.new("Frame")
	divider.BackgroundColor3 = Color3.new(1, 1, 1)
	divider.BackgroundTransparency = 0.94
	divider.BorderSizePixel = 0
	divider.Position = UDim2.fromOffset(0, HEADER_H)
	divider.Size = UDim2.new(1, 0, 0, 1)
	divider.ZIndex = Z.Content + 1
	divider.Parent = panel.Instance
	divider.Visible = false
 
	local subTabHost = Instance.new("ScrollingFrame")
	subTabHost.Name = "SpotifySubTabs"
	subTabHost.BackgroundTransparency = 1
	subTabHost.BorderSizePixel = 0
	subTabHost.Position = UDim2.fromOffset(0, HEADER_H)
	subTabHost.Size = UDim2.new(1, 0, 1, -HEADER_H)
	subTabHost.ScrollBarThickness = 0
	subTabHost.ZIndex = Z.Content + 1
	subTabHost.Parent = panel.Instance
 
	local subTabRoot = setmetatable({
		Name = "Spotify Player",
		_page = subTabHost,
		_window = self,
		_janitor = jan,
		_group = panel.Instance,
	}, Tab)
	local playerSubTab = subTabRoot:AddSubTab({ Name = "Spotify Player", Icon = "Lucide:music-2" })
	local favoritesSubTab = subTabRoot:AddSubTab({ Name = "Favorites", Icon = "Lucide:heart" })
	local scroll = playerSubTab._page
	local list = scroll:FindFirstChild("PageLayout")
	local scrollPad = scroll:FindFirstChild("PagePadding")
	if scrollPad then
		scrollPad.PaddingTop = UDim.new(0, 0)
		scrollPad.PaddingLeft = UDim.new(0, 0)
		scrollPad.PaddingRight = UDim.new(0, 12)
		scrollPad.PaddingBottom = UDim.new(0, 6)
	end
	local favoritesPad = favoritesSubTab._page:FindFirstChild("PagePadding")
	if favoritesPad then
		favoritesPad.PaddingTop = UDim.new(0, 0)
		favoritesPad.PaddingLeft = UDim.new(0, 0)
		favoritesPad.PaddingRight = UDim.new(0, 12)
		favoritesPad.PaddingBottom = UDim.new(0, 6)
	end
 
	local function makeCard(height, order, parent)
		local card = Instance.new("Frame")
		card.BackgroundColor3 = Color3.new(1, 1, 1)
		card.BackgroundTransparency = 0.96
		card.BorderSizePixel = 0
		card.Size = UDim2.new(1, 0, 0, height)
		card.LayoutOrder = order
		card.ZIndex = Z.Content + 2
		card.Parent = parent or scroll
		Corner(card, 10)
		Stroke(card, Color3.new(1, 1, 1), 1, 0.94)
		return card
	end
 
	local guideParagraph = playerSubTab:AddParagraph({
		Title = "Quick setup",
		Icon = "Lucide:link-2",
		Text = "Copy the player link, keep it open in your browser, load a playlist and press Play once.",
	})
	guideParagraph.Instance.LayoutOrder = 1
 
	local statusCard = makeCard(30, 6)
	local statusDot = Instance.new("Frame")
	statusDot.BackgroundColor3 = Color3.fromRGB(125, 130, 128)
	statusDot.BorderSizePixel = 0
	statusDot.AnchorPoint = Vector2.new(0, 0.5)
	statusDot.Position = UDim2.new(0, 11, 0.5, 0)
	statusDot.Size = UDim2.fromOffset(7, 7)
	statusDot.ZIndex = Z.Content + 3
	statusDot.Parent = statusCard
	Corner(statusDot, 4)
 
	local statusLabel = Instance.new("TextLabel")
	statusLabel.BackgroundTransparency = 1
	statusLabel.FontFace = NullUI.Theme.FontRegular
	statusLabel.Text = "Bridge disconnected"
	statusLabel.TextColor3 = NullUI.Theme.TextDim
	statusLabel.TextSize = 12
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.Position = UDim2.fromOffset(27, 0)
	statusLabel.Size = UDim2.new(1, -38, 1, 0)
	statusLabel.ZIndex = Z.Content + 3
	statusLabel.Parent = statusCard
 
	local nowCard = makeCard(164, 7)
	nowCard.ClipsDescendants = true
	local art = Instance.new("ImageLabel")
	art.BackgroundColor3 = Color3.fromRGB(30, 215, 96)
	art.BackgroundTransparency = 0.84
	art.BorderSizePixel = 0
	art.Image = ""
	art.ImageColor3 = Color3.new(1, 1, 1)
	art.ScaleType = Enum.ScaleType.Crop
	art.AnchorPoint = Vector2.new(0, 0)
	art.Position = UDim2.fromOffset(0, 12)
	art.Size = UDim2.fromOffset(88, 88)
	art.ZIndex = Z.Content + 3
	art.Parent = nowCard
	Corner(art, 12)
	Stroke(art, Color3.new(1, 1, 1), 1, 0.9)
 
	local artIcon = Instance.new("ImageLabel")
	artIcon.BackgroundTransparency = 1
	artIcon.Image = ResolveIcon("music-2")
	artIcon.ImageColor3 = Color3.fromRGB(30, 215, 96)
	artIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	artIcon.Position = UDim2.fromScale(0.5, 0.5)
	artIcon.Size = UDim2.fromOffset(28, 28)
	artIcon.ZIndex = Z.Content + 4
	artIcon.Parent = art
 
	local coverToken = 0
	local coverCache = {}
	local function showCover(url)
		coverToken += 1
		local token = coverToken
		url = type(url) == "string" and url or ""
		if url == "" then
			art.BackgroundTransparency = 0.84
			art.Image = ""
			artIcon.Visible = true
			artIcon.Image = ResolveIcon("music-2")
			artIcon.ImageColor3 = Color3.fromRGB(30, 215, 96)
			artIcon.BackgroundTransparency = 1
			artIcon.AnchorPoint = Vector2.new(0.5, 0.5)
			artIcon.Size = UDim2.fromOffset(28, 28)
			artIcon.Position = UDim2.fromScale(0.5, 0.5)
			return
		end
		task.spawn(function()
			local asset = coverCache[url]
			if not asset and fn_customasset and fn_writefile and EnsureAssetsFolder() then
				local hash = 7
				for index = 1, #url do hash = (hash * 31 + url:byte(index)) % 2147483647 end
				local path = ASSETS_FOLDER .. "/spotify-cover-" .. tostring(hash) .. ".jpg"
				if not (fn_isfile and fn_isfile(path)) then
					local ok, body = pcall(function() return game:HttpGet(url) end)
					if ok and type(body) == "string" and #body > 256 then pcall(fn_writefile, path, body) end
				end
				if not fn_isfile or fn_isfile(path) then
					local ok, result = pcall(fn_customasset, path)
					if ok then asset = result; coverCache[url] = result end
				end
			end
			if token ~= coverToken or not asset then return end
			art.BackgroundTransparency = 1
			art.Image = asset
			artIcon.Visible = false
		end)
	end
 
	local nowPlayingTag = Instance.new("TextLabel")
	nowPlayingTag.BackgroundTransparency = 1
	nowPlayingTag.FontFace = NullUI.Theme.Font
	nowPlayingTag.Text = "NOW PLAYING"
	nowPlayingTag.TextColor3 = Color3.fromRGB(30, 215, 96)
	nowPlayingTag.TextSize = 9
	nowPlayingTag.TextXAlignment = Enum.TextXAlignment.Left
	nowPlayingTag.Position = UDim2.fromOffset(100, 9)
	nowPlayingTag.Size = UDim2.new(1, -100, 0, 12)
	nowPlayingTag.ZIndex = Z.Content + 3
	nowPlayingTag.Parent = nowCard
 
	local trackLabel = Instance.new("TextLabel")
	trackLabel.BackgroundTransparency = 1
	trackLabel.FontFace = NullUI.Theme.Font
	trackLabel.Text = "Nothing playing"
	trackLabel.TextColor3 = NullUI.Theme.Text
	trackLabel.TextSize = 15
	trackLabel.TextXAlignment = Enum.TextXAlignment.Left
	trackLabel.TextTruncate = Enum.TextTruncate.AtEnd
	trackLabel.Position = UDim2.fromOffset(100, 25)
	trackLabel.Size = UDim2.new(1, -100, 0, 20)
	trackLabel.ZIndex = Z.Content + 3
	trackLabel.Parent = nowCard
 
	local artistLabel = Instance.new("TextLabel")
	artistLabel.BackgroundTransparency = 1
	artistLabel.FontFace = NullUI.Theme.FontRegular
	artistLabel.Text = "Connect your Spotify bridge"
	artistLabel.TextColor3 = NullUI.Theme.TextDim
	artistLabel.TextSize = 12
	artistLabel.TextXAlignment = Enum.TextXAlignment.Left
	artistLabel.TextTruncate = Enum.TextTruncate.AtEnd
	artistLabel.Position = UDim2.fromOffset(100, 47)
	artistLabel.Size = UDim2.new(1, -100, 0, 16)
	artistLabel.ZIndex = Z.Content + 3
	artistLabel.Parent = nowCard
 
	local progressTrack = Instance.new("Frame")
	progressTrack.BackgroundColor3 = Color3.fromRGB(95, 100, 98)
	progressTrack.BackgroundTransparency = 0.45
	progressTrack.BorderSizePixel = 0
	progressTrack.Position = UDim2.fromOffset(100, 76)
	progressTrack.Size = UDim2.new(1, -100, 0, 5)
	progressTrack.ZIndex = Z.Content + 3
	progressTrack.Parent = nowCard
	Corner(progressTrack, 2)
 
	local progressFill = Instance.new("Frame")
	progressFill.BackgroundColor3 = Color3.fromRGB(30, 215, 96)
	progressFill.BorderSizePixel = 0
	progressFill.Size = UDim2.new(0, 0, 1, 0)
	progressFill.ZIndex = Z.Content + 4
	progressFill.Parent = progressTrack
	Corner(progressFill, 2)
 
	local progressKnob = Instance.new("Frame")
	progressKnob.BackgroundColor3 = Color3.fromRGB(235, 239, 237)
	progressKnob.BorderSizePixel = 0
	progressKnob.AnchorPoint = Vector2.new(0.5, 0.5)
	progressKnob.Position = UDim2.new(0, 0, 0.5, 0)
	progressKnob.Size = UDim2.fromOffset(9, 9)
	progressKnob.ZIndex = Z.Content + 6
	progressKnob.Parent = progressTrack
	Corner(progressKnob, 5)
 
	local seekBubble = Instance.new("Frame")
	seekBubble.BackgroundColor3 = Color3.fromRGB(21, 26, 24)
	seekBubble.BackgroundTransparency = 0.04
	seekBubble.BorderSizePixel = 0
	seekBubble.AnchorPoint = Vector2.new(0.5, 1)
	seekBubble.Position = UDim2.new(0, 0, 0, -8)
	seekBubble.Size = UDim2.fromOffset(48, 25)
	seekBubble.Visible = false
	seekBubble.ZIndex = Z.Content + 8
	seekBubble.Parent = progressTrack
	Corner(seekBubble, 7)
	Stroke(seekBubble, Color3.new(1, 1, 1), 1, 0.9)
	local seekBubbleLabel = Instance.new("TextLabel")
	seekBubbleLabel.BackgroundTransparency = 1
	seekBubbleLabel.FontFace = NullUI.Theme.Font
	seekBubbleLabel.Text = "0:00"
	seekBubbleLabel.TextColor3 = NullUI.Theme.Text
	seekBubbleLabel.TextSize = 10
	seekBubbleLabel.Size = UDim2.fromScale(1, 1)
	seekBubbleLabel.ZIndex = Z.Content + 9
	seekBubbleLabel.Parent = seekBubble
 
	local progressHitbox = Instance.new("TextButton")
	progressHitbox.Text = ""
	progressHitbox.AutoButtonColor = false
	progressHitbox.BackgroundTransparency = 1
	progressHitbox.BorderSizePixel = 0
	progressHitbox.Position = UDim2.fromOffset(100, 68)
	progressHitbox.Size = UDim2.new(1, -100, 0, 21)
	progressHitbox.ZIndex = Z.Content + 7
	progressHitbox.Parent = nowCard
 
	local timeLabel = Instance.new("TextLabel")
	timeLabel.BackgroundTransparency = 1
	timeLabel.FontFace = NullUI.Theme.FontRegular
	timeLabel.Text = "0:00"
	timeLabel.TextColor3 = NullUI.Theme.TextDim
	timeLabel.TextSize = 10
	timeLabel.TextXAlignment = Enum.TextXAlignment.Left
	timeLabel.Position = UDim2.fromOffset(100, 87)
	timeLabel.Size = UDim2.new(0.5, -50, 0, 14)
	timeLabel.ZIndex = Z.Content + 3
	timeLabel.Parent = nowCard
 
	local durationLabel = Instance.new("TextLabel")
	durationLabel.BackgroundTransparency = 1
	durationLabel.FontFace = NullUI.Theme.FontRegular
	durationLabel.Text = "0:00"
	durationLabel.TextColor3 = NullUI.Theme.TextDim
	durationLabel.TextSize = 10
	durationLabel.TextXAlignment = Enum.TextXAlignment.Right
	durationLabel.Position = UDim2.new(0.5, 50, 0, 87)
	durationLabel.Size = UDim2.new(0.5, -50, 0, 14)
	durationLabel.ZIndex = Z.Content + 3
	durationLabel.Parent = nowCard
 
	local controlsDivider = Instance.new("Frame")
	controlsDivider.BackgroundColor3 = Color3.new(1, 1, 1)
	controlsDivider.BackgroundTransparency = 0.93
	controlsDivider.BorderSizePixel = 0
	controlsDivider.Position = UDim2.fromOffset(0, 111)
	controlsDivider.Size = UDim2.new(1, 0, 0, 1)
	controlsDivider.ZIndex = Z.Content + 3
	controlsDivider.Parent = nowCard
 
	local controls = Instance.new("Frame")
	controls.BackgroundTransparency = 1
	controls.BorderSizePixel = 0
	controls.Position = UDim2.fromOffset(0, 114)
	controls.Size = UDim2.new(1, 0, 0, 44)
	controls.ZIndex = Z.Content + 3
	controls.Parent = nowCard
	local controlsLayout = Instance.new("UIListLayout")
	controlsLayout.FillDirection = Enum.FillDirection.Horizontal
	controlsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	controlsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	controlsLayout.Padding = UDim.new(0, 12)
	controlsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	controlsLayout.Parent = controls
 
	local controlRefs = {}
	local function makeControl(name, icon, order, primary)
		local button = Instance.new("TextButton")
		button.Name = name
		button.Text = ""
		button.AutoButtonColor = false
		button.BackgroundColor3 = primary and Color3.fromRGB(30, 215, 96) or Color3.new(1, 1, 1)
		button.BackgroundTransparency = primary and 0.05 or 0.94
		button.BorderSizePixel = 0
		button.Size = UDim2.fromOffset(primary and 36 or 32, primary and 36 or 32)
		button.LayoutOrder = order
		button.ZIndex = Z.Content + 3
		button.Parent = controls
		Corner(button, primary and 18 or 10)
 
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Image = ResolveIcon(icon)
		image.ImageColor3 = primary and Color3.fromRGB(12, 28, 18) or NullUI.Theme.TextDim
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.Size = UDim2.fromOffset(primary and 17 or 15, primary and 17 or 15)
		image.ZIndex = Z.Content + 4
		image.Parent = button
		controlRefs[name] = { Button = button, Icon = image }
		return button
	end
 
	local shuffleBtn = makeControl("Shuffle", "shuffle", 1, false)
	local previousBtn = makeControl("Previous", "skip-back", 2, false)
	local playBtn = makeControl("PlayPause", "play", 3, true)
	local nextBtn = makeControl("Next", "skip-forward", 4, false)
	local repeatBtn = makeControl("Repeat", "repeat", 5, false)
 
	local function makeInputCard(order, title, placeholder, buttonIcon)
		local card = makeCard(66, order)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.FontFace = NullUI.Theme.Font
		label.Text = title
		label.TextColor3 = NullUI.Theme.Text
		label.TextSize = 12
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Position = UDim2.fromOffset(11, 6)
		label.Size = UDim2.new(1, -22, 0, 16)
		label.ZIndex = Z.Content + 3
		label.Parent = card
 
		local pill = Instance.new("Frame")
		pill.BackgroundColor3 = Color3.new(1, 1, 1)
		pill.BackgroundTransparency = 0.94
		pill.BorderSizePixel = 0
		pill.Position = UDim2.fromOffset(10, 27)
		pill.Size = UDim2.new(1, -20, 0, 30)
		pill.ZIndex = Z.Content + 3
		pill.Parent = card
		Corner(pill, 8)
 
		local button = Instance.new("TextButton")
		button.Text = ""
		button.AutoButtonColor = false
		button.BackgroundColor3 = Color3.new(1, 1, 1)
		button.BackgroundTransparency = 0.91
		button.BorderSizePixel = 0
		button.AnchorPoint = Vector2.new(1, 0)
		button.Position = UDim2.new(1, -3, 0, 3)
		button.Size = UDim2.fromOffset(34, 24)
		button.ZIndex = Z.Content + 5
		button.Parent = pill
		Corner(button, 7)
		Stroke(button, Color3.new(1, 1, 1), 1, 0.94)
		local buttonImage = Instance.new("ImageLabel")
		buttonImage.BackgroundTransparency = 1
		buttonImage.Image = ResolveIcon(buttonIcon)
		buttonImage.ImageColor3 = NullUI.Theme.Text
		buttonImage.AnchorPoint = Vector2.new(0.5, 0.5)
		buttonImage.Position = UDim2.fromScale(0.5, 0.5)
		buttonImage.Size = UDim2.fromOffset(14, 14)
		buttonImage.ZIndex = Z.Content + 6
		buttonImage.Parent = button
 
		local box = Instance.new("TextBox")
		box.ClearTextOnFocus = false
		box.FontFace = NullUI.Theme.FontRegular
		box.PlaceholderText = placeholder
		box.PlaceholderColor3 = Color3.fromRGB(115, 120, 118)
		box.Text = ""
		box.TextColor3 = NullUI.Theme.Text
		box.TextSize = 11
		box.TextXAlignment = Enum.TextXAlignment.Left
		box.BackgroundTransparency = 1
		box.Position = UDim2.fromOffset(9, 0)
		box.Size = UDim2.new(1, -52, 1, 0)
		box.ZIndex = Z.Content + 4
		box.Parent = pill
		return box, button, card, label, pill
	end
 
	local searchBox, searchBtn, searchCard, searchTitle, searchPill = makeInputCard(3, "", "Search this playlist...", "search")
	local pairBox, connectBtn, pairCard = makeInputCard(3, "Spotify Connect", "Pairing code", "link-2")
	local connectBtnIcon = connectBtn:FindFirstChildOfClass("ImageLabel")
	pairBox.TextEditable = false
	pairBox.Text = HttpService:GenerateGUID(false):gsub("%-", ""):sub(1, 8):upper()
	local playlistBox, loadBtn, playlistCard, playlistTitle, playlistPill = makeInputCard(4, "", "Paste a Spotify playlist link...", "play")
 
	local connectSection = playerSubTab:AddLineText("Spotify Connect")
	connectSection.Instance.LayoutOrder = 2
	local playerSection = playerSubTab:AddLineText("Player")
	playerSection.Instance.LayoutOrder = 4
	local playerShell = makeCard(286, 5)
	local function flattenIntoPlayer(card, y, height)
		card.Parent = playerShell
		card.BackgroundTransparency = 1
		card.Position = UDim2.fromOffset(12, y)
		card.Size = UDim2.new(1, -24, 0, height)
		for _, child in ipairs(card:GetChildren()) do
			if child:IsA("UIStroke") then child.Transparency = 1 end
		end
	end
	flattenIntoPlayer(searchCard, 12, 40)
	searchTitle.Visible = false
	searchPill.Position = UDim2.fromOffset(0, 0)
	searchPill.Size = UDim2.fromScale(1, 1)
	searchPill.BackgroundTransparency = 0.92
	searchBtn.AnchorPoint = Vector2.zero
	searchBtn.Position = UDim2.fromOffset(4, 4)
	searchBtn.Size = UDim2.fromOffset(32, 32)
	searchBtn.BackgroundTransparency = 1
	for _, child in ipairs(searchBtn:GetChildren()) do
		if child:IsA("UIStroke") then child.Transparency = 1 end
	end
	searchBox.Position = UDim2.fromOffset(38, 0)
	searchBox.Size = UDim2.new(1, -46, 1, 0)
	searchBox.TextSize = 13
 
	flattenIntoPlayer(playlistCard, 60, 40)
	playlistTitle.Visible = false
	playlistPill.Position = UDim2.fromOffset(0, 0)
	playlistPill.Size = UDim2.fromScale(1, 1)
	playlistPill.BackgroundTransparency = 0.92
	loadBtn.Position = UDim2.new(1, -4, 0, 4)
	loadBtn.Size = UDim2.fromOffset(32, 32)
	playlistBox.Position = UDim2.fromOffset(12, 0)
	playlistBox.Size = UDim2.new(1, -56, 1, 0)
 
	statusCard.Parent = playerShell
	statusCard.Position = UDim2.fromOffset(12, 108)
	statusCard.Size = UDim2.new(1, -24, 0, 30)
	statusCard.Visible = false
	nowCard.Parent = playerShell
	nowCard.Position = UDim2.fromOffset(12, 108)
	nowCard.Size = UDim2.new(1, -24, 0, 164)
	nowCard.BackgroundTransparency = 1
	for _, child in ipairs(nowCard:GetChildren()) do
		if child:IsA("UIStroke") then child.Transparency = 1 end
	end
 
	local favoritesSection = favoritesSubTab:AddLineText("Saved Playlists")
	favoritesSection.Instance.LayoutOrder = 1
	local favoritesHeader = makeCard(137, 2, favoritesSubTab._page)
	local favoritesTitle = Instance.new("TextLabel")
	favoritesTitle.BackgroundTransparency = 1
	favoritesTitle.FontFace = NullUI.Theme.Font
	favoritesTitle.Text = "Favorite playlists"
	favoritesTitle.TextColor3 = NullUI.Theme.Text
	favoritesTitle.TextSize = 14
	favoritesTitle.TextXAlignment = Enum.TextXAlignment.Left
	favoritesTitle.Position = UDim2.fromOffset(12, 8)
	favoritesTitle.Size = UDim2.new(1, -112, 0, 20)
	favoritesTitle.ZIndex = Z.Content + 3
	favoritesTitle.Parent = favoritesHeader
	favoritesTitle.Visible = false
	local favoritesHint = Instance.new("TextLabel")
	favoritesHint.BackgroundTransparency = 1
	favoritesHint.FontFace = NullUI.Theme.FontRegular
	favoritesHint.Text = "Save and load your playlists with one tap"
	favoritesHint.TextColor3 = NullUI.Theme.TextDim
	favoritesHint.TextSize = 10
	favoritesHint.TextXAlignment = Enum.TextXAlignment.Left
	favoritesHint.Position = UDim2.fromOffset(12, 29)
	favoritesHint.Size = UDim2.new(1, -112, 0, 16)
	favoritesHint.ZIndex = Z.Content + 3
	favoritesHint.Parent = favoritesHeader
	favoritesHint.Visible = false
	local favoritesSearchPill = Instance.new("Frame")
	favoritesSearchPill.BackgroundColor3 = Color3.new(1, 1, 1)
	favoritesSearchPill.BackgroundTransparency = 0.94
	favoritesSearchPill.BorderSizePixel = 0
	favoritesSearchPill.Position = UDim2.fromOffset(8, 7)
	favoritesSearchPill.Size = UDim2.new(1, -16, 0, 36)
	favoritesSearchPill.ZIndex = Z.Content + 3
	favoritesSearchPill.Parent = favoritesHeader
	Corner(favoritesSearchPill, 9)
	local favoritesSearchIcon = Instance.new("ImageLabel")
	favoritesSearchIcon.BackgroundTransparency = 1
	favoritesSearchIcon.Image = ResolveIcon("search")
	favoritesSearchIcon.ImageColor3 = NullUI.Theme.TextDim
	favoritesSearchIcon.AnchorPoint = Vector2.new(0, 0.5)
	favoritesSearchIcon.Position = UDim2.new(0, 11, 0.5, 0)
	favoritesSearchIcon.Size = UDim2.fromOffset(15, 15)
	favoritesSearchIcon.ZIndex = Z.Content + 4
	favoritesSearchIcon.Parent = favoritesSearchPill
	local favoritesSearchBox = Instance.new("TextBox")
	favoritesSearchBox.BackgroundTransparency = 1
	favoritesSearchBox.ClearTextOnFocus = false
	favoritesSearchBox.FontFace = NullUI.Theme.FontRegular
	favoritesSearchBox.PlaceholderText = "Search favorite playlists..."
	favoritesSearchBox.PlaceholderColor3 = Color3.fromRGB(115, 120, 118)
	favoritesSearchBox.Text = ""
	favoritesSearchBox.TextColor3 = NullUI.Theme.Text
	favoritesSearchBox.TextSize = 11
	favoritesSearchBox.TextXAlignment = Enum.TextXAlignment.Left
	favoritesSearchBox.Position = UDim2.fromOffset(36, 0)
	favoritesSearchBox.Size = UDim2.new(1, -44, 1, 0)
	favoritesSearchBox.ZIndex = Z.Content + 4
	favoritesSearchBox.Parent = favoritesSearchPill
	local addFavoriteBtn = Instance.new("TextButton")
	addFavoriteBtn.Text = ""
	addFavoriteBtn.AutoButtonColor = false
	addFavoriteBtn.BackgroundColor3 = Color3.new(1, 1, 1)
	addFavoriteBtn.BackgroundTransparency = 0.96
	addFavoriteBtn.BorderSizePixel = 0
	addFavoriteBtn.Position = UDim2.fromOffset(8, 113)
	addFavoriteBtn.Size = UDim2.new(1, -16, 0, 56)
	addFavoriteBtn.ZIndex = Z.Content + 4
	addFavoriteBtn.Parent = favoritesHeader
	Corner(addFavoriteBtn, 10)
	Stroke(addFavoriteBtn, Color3.new(1, 1, 1), 1, 0.94)
	local addFavoriteIcon = Instance.new("ImageLabel")
	addFavoriteIcon.BackgroundTransparency = 1
	addFavoriteIcon.Image = ResolveIcon("heart-plus")
	addFavoriteIcon.ImageColor3 = NullUI.Theme.Text
	addFavoriteIcon.AnchorPoint = Vector2.new(0, 0.5)
	addFavoriteIcon.Position = UDim2.new(0, 16, 0.5, 0)
	addFavoriteIcon.Size = UDim2.fromOffset(17, 17)
	addFavoriteIcon.ZIndex = Z.Content + 5
	addFavoriteIcon.Parent = addFavoriteBtn
	local saveFavoriteTitle = Instance.new("TextLabel")
	saveFavoriteTitle.BackgroundTransparency = 1
	saveFavoriteTitle.FontFace = NullUI.Theme.Font
	saveFavoriteTitle.Text = "Save current playlist"
	saveFavoriteTitle.TextColor3 = NullUI.Theme.Text
	saveFavoriteTitle.TextSize = 12
	saveFavoriteTitle.TextXAlignment = Enum.TextXAlignment.Left
	saveFavoriteTitle.Position = UDim2.fromOffset(44, 7)
	saveFavoriteTitle.Size = UDim2.new(1, -84, 0, 20)
	saveFavoriteTitle.ZIndex = Z.Content + 5
	saveFavoriteTitle.Parent = addFavoriteBtn
	local saveFavoriteHint = Instance.new("TextLabel")
	saveFavoriteHint.BackgroundTransparency = 1
	saveFavoriteHint.FontFace = NullUI.Theme.FontRegular
	saveFavoriteHint.Text = "Add the playlist loaded in the player to Favorites"
	saveFavoriteHint.TextColor3 = NullUI.Theme.TextDim
	saveFavoriteHint.TextSize = 9
	saveFavoriteHint.TextXAlignment = Enum.TextXAlignment.Left
	saveFavoriteHint.Position = UDim2.fromOffset(44, 27)
	saveFavoriteHint.Size = UDim2.new(1, -84, 0, 17)
	saveFavoriteHint.ZIndex = Z.Content + 5
	saveFavoriteHint.Parent = addFavoriteBtn
	local saveFavoriteChevron = Instance.new("ImageLabel")
	saveFavoriteChevron.BackgroundTransparency = 1
	saveFavoriteChevron.Image = ResolveIcon("chevron-right")
	saveFavoriteChevron.ImageColor3 = NullUI.Theme.TextDim
	saveFavoriteChevron.AnchorPoint = Vector2.new(1, 0.5)
	saveFavoriteChevron.Position = UDim2.new(1, -16, 0.5, 0)
	saveFavoriteChevron.Size = UDim2.fromOffset(14, 14)
	saveFavoriteChevron.ZIndex = Z.Content + 5
	saveFavoriteChevron.Parent = addFavoriteBtn
	local saveFavoriteDivider = Instance.new("Frame")
	saveFavoriteDivider.BackgroundColor3 = Color3.new(1, 1, 1)
	saveFavoriteDivider.BackgroundTransparency = 0.92
	saveFavoriteDivider.BorderSizePixel = 0
	saveFavoriteDivider.Position = UDim2.fromOffset(8, 103)
	saveFavoriteDivider.Size = UDim2.new(1, -16, 0, 1)
	saveFavoriteDivider.ZIndex = Z.Content + 3
	saveFavoriteDivider.Parent = favoritesHeader
 
	local favoritesList = Instance.new("Frame")
	favoritesList.BackgroundTransparency = 1
	favoritesList.BorderSizePixel = 0
	favoritesList.Position = UDim2.fromOffset(8, 51)
	favoritesList.Size = UDim2.new(1, -16, 0, 78)
	favoritesList.ZIndex = Z.Content + 2
	favoritesList.Parent = favoritesHeader
	local favoriteRows = {}
	local favorites = {}
	local currentPlaylistName = "Spotify playlist"
	local favoritesPath = ASSETS_FOLDER .. "/spotify-favorites.json"
	if fn_readfile and fn_isfile and fn_isfile(favoritesPath) then
		pcall(function()
			local decoded = HttpService:JSONDecode(fn_readfile(favoritesPath))
			if type(decoded) == "table" then favorites = decoded end
		end)
	end
	local function saveFavorites()
		if not (fn_writefile and EnsureAssetsFolder()) then return end
		pcall(fn_writefile, favoritesPath, HttpService:JSONEncode(favorites))
	end
 
	local socket
	local socketConnections = {}
	local isConnected = false
	local isPlaying = false
	local shuffle = false
	local repeatMode = "off"
	local durationMs = 0
	local progressMs = 0
	local lastStateClock = os.clock()
	local seekDragging = false
	local seekPreviewMs = 0
 
	local function setStatus(text, color)
		statusLabel.Text = tostring(text or "")
		statusDot.BackgroundColor3 = color or Color3.fromRGB(125, 130, 128)
	end
 
	local notifyTimes = {}
	local function spotifyNotify(key, title, text, notifyType, icon, duration, actions)
		if not panel.IsOpen() then return end
		local now = os.clock()
		if notifyTimes[key] and now - notifyTimes[key] < 2.5 then return end
		notifyTimes[key] = now
		NullUI:Notify({
			Title = title,
			Text = text,
			Type = notifyType or "info",
			Icon = icon,
			Duration = duration or 5,
			Actions = actions,
		})
	end
 
	local function formatTime(ms)
		local seconds = math.max(0, math.floor((tonumber(ms) or 0) / 1000))
		return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
	end
 
	local function renderProgress()
		local shownProgress = progressMs
		if isPlaying and durationMs > 0 then
			shownProgress = math.min(durationMs, progressMs + (os.clock() - lastStateClock) * 1000)
		end
		local alpha = durationMs > 0 and math.clamp(shownProgress / durationMs, 0, 1) or 0
		if not seekDragging then
			progressFill.Size = UDim2.new(alpha, 0, 1, 0)
			progressKnob.Position = UDim2.new(alpha, 0, 0.5, 0)
			timeLabel.Text = formatTime(shownProgress)
		end
		durationLabel.Text = formatTime(durationMs)
	end
	jan:Add(RunService.Heartbeat:Connect(renderProgress))
 
	local function send(action, extra)
		if not (isConnected and socket) then
			setStatus("Connect the bridge first", Color3.fromRGB(255, 190, 90))
			return false
		end
		local payload = extra or {}
		payload.type = "command"
		payload.action = action
		local ok, err = pcall(function()
			socket:Send(HttpService:JSONEncode(payload))
		end)
		if not ok then
			setStatus("Could not send command: " .. tostring(err), Color3.fromRGB(255, 105, 105))
		end
		return ok
	end
 
	local function setView(name)
		subTabRoot:SelectSubTabByName(name)
	end
 
	local function renderFavorites()
		for _, row in ipairs(favoriteRows) do row:Destroy() end
		table.clear(favoriteRows)
		local query = favoritesSearchBox.Text:lower():gsub("^%s+", ""):gsub("%s+$", "")
		local filtered = {}
		for originalIndex, favorite in ipairs(favorites) do
			local searchable = (tostring(favorite.name or "") .. " " .. tostring(favorite.url or "")):lower()
			if query == "" or searchable:find(query, 1, true) then
				table.insert(filtered, { Favorite = favorite, Index = originalIndex })
			end
		end
		local count = math.min(#filtered, 8)
		local listHeight = count == 0 and 52 or count * 64
		favoritesList.Size = UDim2.new(1, -16, 0, listHeight)
		local dividerY = 51 + listHeight + 7
		saveFavoriteDivider.Position = UDim2.fromOffset(8, dividerY)
		addFavoriteBtn.Position = UDim2.fromOffset(8, dividerY + 10)
		favoritesHeader.Size = UDim2.new(1, 0, 0, dividerY + 74)
		if count == 0 then
			local empty = Instance.new("TextLabel")
			empty.BackgroundTransparency = 1
			empty.FontFace = NullUI.Theme.FontRegular
			empty.Text = query ~= "" and "No saved playlist matches your search" or "No saved playlists yet"
			empty.TextColor3 = NullUI.Theme.TextDim
			empty.TextSize = 11
			empty.Size = UDim2.fromScale(1, 1)
			empty.ZIndex = Z.Content + 3
			empty.Parent = favoritesList
			table.insert(favoriteRows, empty)
		else
		for visibleIndex = 1, count do
			local entry = filtered[visibleIndex]
			local favorite = entry.Favorite
			local originalIndex = entry.Index
			local row = Instance.new("Frame")
			row.BackgroundColor3 = Color3.new(1, 1, 1)
			row.BackgroundTransparency = 0.96
			row.BorderSizePixel = 0
			row.Position = UDim2.fromOffset(0, (visibleIndex - 1) * 64)
			row.Size = UDim2.new(1, 0, 0, 58)
			row.ZIndex = Z.Content + 3
			row.Parent = favoritesList
			Corner(row, 10)
			Stroke(row, Color3.new(1, 1, 1), 1, 0.94)
			local playlistIconBox = Instance.new("Frame")
			playlistIconBox.BackgroundColor3 = Color3.new(1, 1, 1)
			playlistIconBox.BackgroundTransparency = 0.91
			playlistIconBox.BorderSizePixel = 0
			playlistIconBox.Position = UDim2.fromOffset(10, 9)
			playlistIconBox.Size = UDim2.fromOffset(40, 40)
			playlistIconBox.ZIndex = Z.Content + 4
			playlistIconBox.Parent = row
			Corner(playlistIconBox, 8)
			local playlistIcon = Instance.new("ImageLabel")
			playlistIcon.BackgroundTransparency = 1
			playlistIcon.Image = ResolveIcon("list-music")
			playlistIcon.ImageColor3 = NullUI.Theme.Text
			playlistIcon.AnchorPoint = Vector2.new(0.5, 0.5)
			playlistIcon.Position = UDim2.fromScale(0.5, 0.5)
			playlistIcon.Size = UDim2.fromOffset(15, 15)
			playlistIcon.ZIndex = Z.Content + 5
			playlistIcon.Parent = playlistIconBox
			local name = Instance.new("TextLabel")
			name.BackgroundTransparency = 1
			name.FontFace = NullUI.Theme.Font
			name.Text = tostring(favorite.name or "Spotify playlist")
			name.TextColor3 = NullUI.Theme.Text
			name.TextSize = 11
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.TextTruncate = Enum.TextTruncate.AtEnd
			name.Position = UDim2.fromOffset(60, 8)
			name.Size = UDim2.new(1, -152, 0, 20)
			name.ZIndex = Z.Content + 4
			name.Parent = row
			local subtitle = Instance.new("TextLabel")
			subtitle.BackgroundTransparency = 1
			subtitle.FontFace = NullUI.Theme.FontRegular
			subtitle.Text = "Spotify playlist"
			subtitle.TextColor3 = NullUI.Theme.TextDim
			subtitle.TextSize = 9
			subtitle.TextXAlignment = Enum.TextXAlignment.Left
			subtitle.Position = UDim2.fromOffset(60, 30)
			subtitle.Size = UDim2.new(1, -152, 0, 16)
			subtitle.ZIndex = Z.Content + 4
			subtitle.Parent = row
			local loadFavorite = Instance.new("TextButton")
			loadFavorite.Text = ""
			loadFavorite.AutoButtonColor = false
			loadFavorite.BackgroundColor3 = Color3.new(1, 1, 1)
			loadFavorite.BackgroundTransparency = 0.91
			loadFavorite.BorderSizePixel = 0
			loadFavorite.Position = UDim2.new(1, -76, 0, 13)
			loadFavorite.Size = UDim2.fromOffset(32, 32)
			loadFavorite.ZIndex = Z.Content + 5
			loadFavorite.Parent = row
			Corner(loadFavorite, 8)
			local loadFavoriteIcon = Instance.new("ImageLabel")
			loadFavoriteIcon.BackgroundTransparency = 1
			loadFavoriteIcon.Image = ResolveIcon("play")
			loadFavoriteIcon.ImageColor3 = NullUI.Theme.Text
			loadFavoriteIcon.AnchorPoint = Vector2.new(0.5, 0.5)
			loadFavoriteIcon.Position = UDim2.fromScale(0.5, 0.5)
			loadFavoriteIcon.Size = UDim2.fromOffset(13, 13)
			loadFavoriteIcon.ZIndex = Z.Content + 6
			loadFavoriteIcon.Parent = loadFavorite
			local removeFavorite = Instance.new("TextButton")
			removeFavorite.Text = ""
			removeFavorite.BackgroundColor3 = Color3.new(1, 1, 1)
			removeFavorite.BackgroundTransparency = 0.94
			removeFavorite.Position = UDim2.new(1, -38, 0, 13)
			removeFavorite.Size = UDim2.fromOffset(30, 32)
			removeFavorite.ZIndex = Z.Content + 5
			removeFavorite.Parent = row
			Corner(removeFavorite, 8)
			local removeFavoriteIcon = Instance.new("ImageLabel")
			removeFavoriteIcon.BackgroundTransparency = 1
			removeFavoriteIcon.Image = ResolveIcon("trash-2")
			removeFavoriteIcon.ImageColor3 = Color3.fromRGB(220, 125, 125)
			removeFavoriteIcon.AnchorPoint = Vector2.new(0.5, 0.5)
			removeFavoriteIcon.Position = UDim2.fromScale(0.5, 0.5)
			removeFavoriteIcon.Size = UDim2.fromOffset(13, 13)
			removeFavoriteIcon.ZIndex = Z.Content + 6
			removeFavoriteIcon.Parent = removeFavorite
			jan:Add(loadFavorite.MouseButton1Click:Connect(function()
				playlistBox.Text = tostring(favorite.url or "")
				setView("Spotify Player")
				if send("load_playlist", { url = playlistBox.Text }) then
					setStatus("Loading favorite playlist...", Color3.fromRGB(30, 215, 96))
					spotifyNotify("favorite_load", "Open Spotify Bridge", "Open the browser site, wait for the playlist and press Play once. Then return to Roblox to control it here.", "warning", "external-link", 8)
				end
			end))
			jan:Add(removeFavorite.MouseButton1Click:Connect(function()
				local removedName = tostring(favorite.name or "Spotify playlist")
				table.remove(favorites, originalIndex)
				saveFavorites()
				renderFavorites()
				spotifyNotify("favorite_removed", "Favorite removed", removedName, "success", "trash-2", 3)
			end))
			table.insert(favoriteRows, row)
		end
		end
	end
	jan:Add(favoritesSearchBox:GetPropertyChangedSignal("Text"):Connect(renderFavorites))
 
	jan:Add(addFavoriteBtn.MouseButton1Click:Connect(function()
		local url = playlistBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
		if url == "" then
			spotifyNotify("favorite_missing", "Nothing to save", "Paste or load a Spotify playlist first.", "warning", "heart", 4)
			return
		end
		for _, favorite in ipairs(favorites) do
			if favorite.url == url then
				spotifyNotify("favorite_duplicate", "Already saved", "This playlist is already in your favorites.", "warning", "heart", 4)
				return
			end
		end
		table.insert(favorites, 1, { name = currentPlaylistName, url = url })
		saveFavorites()
		renderFavorites()
		spotifyNotify("favorite_saved", "Playlist saved", currentPlaylistName .. " was added to Favorites.", "success", "heart", 4)
	end))
	renderFavorites()
 
	local function paintModes()
		controlRefs.PlayPause.Icon.Image = ResolveIcon(isPlaying and "pause" or "play")
		controlRefs.Shuffle.Icon.ImageColor3 = shuffle and Color3.fromRGB(30, 215, 96) or NullUI.Theme.TextDim
		controlRefs.Repeat.Icon.ImageColor3 = repeatMode ~= "off" and Color3.fromRGB(30, 215, 96) or NullUI.Theme.TextDim
	end
 
	local function applyState(data)
		local track = data.track or data.item or {}
		local artists = track.artist or track.artists or data.artist
		if type(artists) == "table" then
			local names = {}
			for _, artist in ipairs(artists) do
				table.insert(names, type(artist) == "table" and tostring(artist.name or "") or tostring(artist))
			end
			artists = table.concat(names, ", ")
		end
		trackLabel.Text = tostring(track.name or data.trackName or "Nothing playing")
		artistLabel.Text = tostring(artists or "Spotify")
		showCover(track.image or track.imageUrl or track.albumArt or data.image or data.imageUrl)
		isPlaying = data.isPlaying == true or data.playing == true
		shuffle = data.shuffle == true or data.shuffleState == true
		repeatMode = tostring(data.repeatMode or data.repeat_state or "off")
		durationMs = tonumber(track.durationMs or track.duration_ms or data.durationMs or data.duration_ms) or 0
		progressMs = tonumber(data.progressMs or data.progress_ms or data.positionMs or data.position_ms) or 0
		lastStateClock = os.clock()
		paintModes()
		renderProgress()
		if trackLabel.Text ~= "Playlist ready" and trackLabel.Text ~= "Nothing playing" then
			setStatus(isPlaying and "Playing — controls synced" or "Paused — controls synced", Color3.fromRGB(30, 215, 96))
		end
	end
 
	local function clearSocketConnections()
		for _, connection in ipairs(socketConnections) do
			pcall(function() connection:Disconnect() end)
		end
		table.clear(socketConnections)
	end
 
	local function disconnectBridge(silent)
		clearSocketConnections()
		local oldSocket = socket
		socket = nil
		isConnected = false
		if connectBtnIcon then connectBtnIcon.Image = ResolveIcon("link-2") end
		if oldSocket then pcall(function() oldSocket:Close() end) end
		if not silent then setStatus("Bridge disconnected", Color3.fromRGB(125, 130, 128)) end
	end
 
	local function bindSocketEvent(event, callback)
		if event and type(event.Connect) == "function" then
			local ok, connection = pcall(function() return event:Connect(callback) end)
			if ok and connection then table.insert(socketConnections, connection) end
		end
	end
 
	connectBridge = function()
		if isConnected then
			local pageUrl = tostring(opts.ConnectUrl or "")
			local pairUrl = pageUrl .. (pageUrl:find("?", 1, true) and "&" or "?") .. "code=" .. pairBox.Text
			local copy = hasFn("setclipboard")
			if copy then
				pcall(copy, pairUrl)
				setStatus("Player link copied — open it in your browser", Color3.fromRGB(30, 215, 96))
				spotifyNotify("link_copied", "Player link copied", "Open the link in your browser and keep that tab running.", "success", "external-link", 6, {
					{ Text = "Copy again", Callback = function() pcall(copy, pairUrl) end },
				})
			else
				setStatus("Open the player page and enter code " .. pairBox.Text, Color3.fromRGB(255, 190, 90))
				spotifyNotify("manual_code", "Open Spotify Bridge", "Clipboard is unavailable. Open the player page and enter code " .. pairBox.Text .. ".", "warning", "monitor-up", 7)
			end
			return
		end
		local bridgeUrl = tostring(opts.BridgeUrl or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if not bridgeUrl:match("^wss?://") then
			setStatus("Spotify bridge is not configured by the script owner", Color3.fromRGB(255, 105, 105))
			return
		end
		local url = bridgeUrl
			.. (bridgeUrl:find("?", 1, true) and "&" or "?")
			.. "code=" .. pairBox.Text .. "&role=game"
		local connect = websocketConnect()
		if not connect then
			setStatus("This executor has no WebSocket support", Color3.fromRGB(255, 105, 105))
			return
		end
		setStatus("Connecting...", Color3.fromRGB(255, 190, 90))
		if connectBtnIcon then connectBtnIcon.Image = ResolveIcon("loader-circle") end
		task.spawn(function()
			local ok, result = pcall(connect, url)
			if not ok or not result then
				if connectBtnIcon then connectBtnIcon.Image = ResolveIcon("link-2") end
				setStatus("Connection failed: " .. tostring(result), Color3.fromRGB(255, 105, 105))
				return
			end
			socket = result
			isConnected = true
			if connectBtnIcon then connectBtnIcon.Image = ResolveIcon("copy") end
			local pageUrl = tostring(opts.ConnectUrl or "")
			local pairUrl = pageUrl .. (pageUrl:find("?", 1, true) and "&" or "?") .. "code=" .. pairBox.Text
			local copy = hasFn("setclipboard")
			if copy then pcall(copy, pairUrl) end
			setStatus(copy and "Player link copied — open it in your browser" or ("Open player page; code " .. pairBox.Text), Color3.fromRGB(30, 215, 96))
			if copy then
				spotifyNotify("initial_link", "Spotify Connect ready", "The player link was copied. Open it now and keep the browser tab running.", "success", "copy-check", 7, {
					{ Text = "Copy again", Callback = function() pcall(copy, pairUrl) end },
				})
			else
				spotifyNotify("manual_code", "Open Spotify Bridge", "Enter pairing code " .. pairBox.Text .. " on the player page.", "warning", "monitor-up", 7)
			end
 
			bindSocketEvent(socket.OnMessage, function(raw)
				local decoded
				local decodedOk = pcall(function() decoded = HttpService:JSONDecode(tostring(raw)) end)
				if not decodedOk or type(decoded) ~= "table" then return end
				if decoded.type == "state" or decoded.event == "state" then
					applyState(decoded)
				elseif decoded.type == "queue" then
					local playlist = decoded.playlist or {}
					currentPlaylistName = tostring(playlist.name or "Spotify playlist")
					local trackCount = tonumber(decoded.count) or 0
					setStatus(string.format("%s — %d tracks ready", currentPlaylistName, trackCount), Color3.fromRGB(30, 215, 96))
					spotifyNotify("queue_ready_" .. currentPlaylistName, "Playlist ready", string.format("%s loaded with %d tracks.", currentPlaylistName, trackCount), "success", "list-music", 4)
				elseif decoded.type == "ready" or decoded.event == "ready" then
					local message = tostring(decoded.message or "Spotify ready")
					setStatus(message, Color3.fromRGB(30, 215, 96))
					local lower = message:lower()
					if lower:find("press", 1, true) or lower:find("open", 1, true) or lower:find("tap", 1, true) then
						spotifyNotify("browser_action", "Browser action needed", "Open Spotify Bridge and press Play once to unlock remote controls.", "warning", "monitor-play", 7)
					end
				elseif decoded.type == "needs_browser" then
					local message = tostring(decoded.message or "Open the Spotify player tab once to continue playback")
					setStatus(message, Color3.fromRGB(255, 190, 90))
					spotifyNotify("browser_attention", "Spotify needs attention", message, "warning", "external-link", 7)
				elseif decoded.type == "error" or decoded.event == "error" then
					local message = tostring(decoded.message or decoded.error or "Spotify bridge error")
					setStatus(message, Color3.fromRGB(255, 105, 105))
					spotifyNotify("spotify_error_" .. message, "Spotify error", message, "error", "circle-x", 6)
				end
			end)
			bindSocketEvent(socket.OnClose, function()
				disconnectBridge(false)
			end)
			send("hello", { client = "NullUI", protocol = 1 })
		end)
	end
 
	jan:Add(connectBtn.MouseButton1Click:Connect(connectBridge))
	jan:Add(loadBtn.MouseButton1Click:Connect(function()
		local url = playlistBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
		if url == "" then
			setStatus("Paste a Spotify playlist link", Color3.fromRGB(255, 190, 90))
			return
		end
		if send("load_playlist", { url = url }) then
			setStatus("Playlist sent to Spotify", Color3.fromRGB(30, 215, 96))
			spotifyNotify("playlist_sent", "Open Spotify Bridge", "Open the browser site, wait for the playlist and press Play once. Then return to Roblox to control it here.", "warning", "external-link", 8)
		end
	end))
	local function searchPlaylist()
		local query = searchBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
		if query == "" then setStatus("Type a song or artist to search", Color3.fromRGB(255, 190, 90)); return end
		if send("search", { query = query }) then setStatus("Searching this playlist...", Color3.fromRGB(30, 215, 96)) end
	end
	jan:Add(searchBtn.MouseButton1Click:Connect(searchPlaylist))
	jan:Add(searchBox.FocusLost:Connect(function(enterPressed) if enterPressed then searchPlaylist() end end))
	jan:Add(shuffleBtn.MouseButton1Click:Connect(function() send("toggle_shuffle") end))
	jan:Add(previousBtn.MouseButton1Click:Connect(function() send("previous") end))
	jan:Add(playBtn.MouseButton1Click:Connect(function() send("play_pause") end))
	jan:Add(nextBtn.MouseButton1Click:Connect(function() send("next") end))
	jan:Add(repeatBtn.MouseButton1Click:Connect(function() send("cycle_repeat") end))
	local seekInput
	local function updateSeekPreview(screenX)
		if durationMs <= 0 or progressTrack.AbsoluteSize.X <= 0 then return end
		local alpha = math.clamp((screenX - progressTrack.AbsolutePosition.X) / progressTrack.AbsoluteSize.X, 0, 1)
		seekPreviewMs = math.floor(durationMs * alpha)
		progressFill.Size = UDim2.new(alpha, 0, 1, 0)
		progressKnob.Position = UDim2.new(alpha, 0, 0.5, 0)
		seekBubble.Position = UDim2.new(math.clamp(alpha, 0.04, 0.96), 0, 0, -8)
		seekBubbleLabel.Text = formatTime(seekPreviewMs)
		timeLabel.Text = formatTime(seekPreviewMs)
	end
	jan:Add(progressHitbox.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch then return end
		if durationMs <= 0 then return end
		seekDragging = true
		seekInput = input
		seekBubble.Visible = true
		updateSeekPreview(input.Position.X)
	end))
	jan:Add(UserInputService.InputChanged:Connect(function(input)
		if not seekDragging then return end
		if input == seekInput or input.UserInputType == Enum.UserInputType.MouseMovement then
			updateSeekPreview(input.Position.X)
		end
	end))
	jan:Add(UserInputService.InputEnded:Connect(function(input)
		if not seekDragging then return end
		if input ~= seekInput and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		updateSeekPreview(input.Position.X)
		seekDragging = false
		seekInput = nil
		seekBubble.Visible = false
		if send("seek", { positionMs = seekPreviewMs }) then
			progressMs = seekPreviewMs
			lastStateClock = os.clock()
		end
		renderProgress()
	end))
 
	jan:Add(function() disconnectBridge(true) end)
	dockBtn = self:AddDockButton({
		Icon = opts.Icon or "Lucide:music-2",
		Callback = function() panel.Toggle() end,
	})
 
	panel.Connect = connectBridge
	panel.Disconnect = disconnectBridge
	panel.Send = send
	panel.SetState = applyState
	if opts.BridgeUrl == nil or opts.BridgeUrl == "" then
		setStatus("Spotify bridge is not configured by the script owner", Color3.fromRGB(255, 190, 90))
	else
		setStatus("Tap Connect, then open the copied browser link", Color3.fromRGB(125, 130, 128))
	end
	return panel
end
 
function Window:_BuildDefaultChatTools()
	local windowSelf = self
 
	return {
		{
			Name = "list_ui_elements",
			Description = "Lists every UI element that has a Flag, with its kind and current value.",
			Parameters = { type = "object", properties = {}, required = {} },
			Handler = function()
				return NullUI:ListUIElements()
			end,
		},
		{
			Name = "set_ui_element_value",
			Description = "Sets a UI element's value by its flag name. Use list_ui_elements first to find valid flags.",
			Parameters = {
				type = "object",
				properties = {
					flag  = { type = "string", description = "The Flag of the UI element to change." },
					value = { description = "The new value: true/false for a Toggle, a number for a Slider, a string for a Textbox/Dropdown." },
				},
				required = { "flag", "value" },
			},
			Handler = function(args)
				local ok, err = NullUI:SetUIElementValue(args.flag, args.value)
				if not ok then error(err, 0) end
				return true
			end,
		},
		{
			Name = "select_tab",
			Description = "Switches the panel to one of its top-level sidebar tabs.",
			Parameters = {
				type = "object",
				properties = {
					tab = { type = "string", description = "The tab's name." },
				},
				required = { "tab" },
			},
			Handler = function(args)
				local tabObj = windowSelf:SelectTab(args.tab)
				if not tabObj then error("No tab named '" .. tostring(args.tab) .. "'", 0) end
				return "Switched to " .. tabObj.Name
			end,
		},
		{
			Name = "select_subtab",
			Description = "Switches to a sub-tab nested under one of the top-level tabs. Selects the "
				.. "parent tab first automatically -- no need to call select_tab beforehand.",
			Parameters = {
				type = "object",
				properties = {
					tab    = { type = "string", description = "The top-level tab that contains the sub-tab." },
					subtab = { type = "string", description = "The sub-tab's name." },
				},
				required = { "tab", "subtab" },
			},
			Handler = function(args)
				local tabObj = windowSelf:SelectTab(args.tab)
				if not tabObj then error("No tab named '" .. tostring(args.tab) .. "'", 0) end
				local sub = tabObj:SelectSubTabByName(args.subtab)
				if not sub then
					error("No sub-tab named '" .. tostring(args.subtab) .. "' under " .. tabObj.Name, 0)
				end
				return "Switched to " .. tabObj.Name .. " > " .. sub.Name
			end,
		},
		{
			Name = "find_and_highlight_element",
			Description = "Finds a UI element (button, toggle, card, slider, etc.) by its visible label, "
				.. "jumps to whichever tab or sub-tab it lives on, scrolls to it, and flashes a highlight "
				.. "on it -- the same thing Ctrl+K search does when you click a result.",
			Parameters = {
				type = "object",
				properties = {
					query = { type = "string", description = "The element's visible text. Partial matches are fine." },
				},
				required = { "query" },
			},
			Handler = function(args)
				local ok, titleOrErr = windowSelf:JumpToElement(args.query)
				if not ok then error(titleOrErr, 0) end
				return "Highlighted: " .. titleOrErr
			end,
		},
	}
end
 
function Window:_BuildDefaultSystemPrompt()
	local names = {}
	for _, t in ipairs(self._tabs) do
		if not t.Hidden then table.insert(names, t.Name) end
	end
 
	return "You are a helpful assistant embedded in a Roblox UI panel built with NullUI. Your tools "
		.. "only affect THIS PANEL -- they inspect/adjust the panel's own toggles/sliders/etc, switch "
		.. "between its top-level tabs (" .. table.concat(names, ", ") .. "), switch to a specific "
		.. "sub-tab within one of those, and jump to/highlight a specific UI element on the panel by "
		.. "its visible label. Only use select_tab, select_subtab, or find_and_highlight_element when "
		.. "the user is asking to be taken somewhere IN THIS PANEL, or to interact with a control "
		.. "that's actually on it. If the user asks you to write a script, explain something, or "
		.. "anything else that isn't about navigating this panel, just answer directly in chat -- do "
		.. "not call a tool just because the message happens to mention a word that sounds like a "
		.. "setting. When you write a Luau script for the user, put it in a normal ```lua fenced block "
		.. "-- the panel automatically adds a Run button to it that the user can click themselves, so "
		.. "you don't need to explain how to run it or tell them you can't execute code; you're just "
		.. "not the one who decides to run it -- they click Run after reading it. Keep answers short "
		.. "and to the point. None of your tools execute anything outside this panel, and you have no "
		.. "way to trigger the Run button yourself."
end
 
function Window:AddChatPanel(opts)
	opts = opts or {}
	opts.Tools = opts.Tools or self:_BuildDefaultChatTools()
	local jan = self._janitor
 
	local tabObj = self:AddTab({
		Name   = opts.Name or "Assistant",
		Icon   = opts.Icon or "bot",
		Hidden = true,
	})
	tabObj._page.Visible = false
 
	local staleEmptyState = tabObj._group:FindFirstChild("EmptyState")
	if staleEmptyState then staleEmptyState.Visible = false end
 
	local toolByName = {}
	for _, tool in ipairs(opts.Tools or {}) do
		if tool.Name then toolByName[tool.Name] = tool end
	end
 
	local INPUT_H = 38
	local HEADER_H = 38
 
	local panel = Instance.new("Frame")
	panel.Name = "ChatPanel"
	panel.BackgroundTransparency = 1
	panel.ClipsDescendants = true
	panel.Size = UDim2.fromScale(1, 1)
	panel.ZIndex = Z.Content
	panel.Parent = tabObj._group
 
	local BASE_Z = panel.ZIndex + 1
 
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Size = UDim2.fromScale(1, 1)
	content.ZIndex = panel.ZIndex
	content.Parent = panel
 
	local header = Instance.new("Frame")
	header.BackgroundTransparency = 1
	header.Active = true
	header.Size = UDim2.new(1, 0, 0, HEADER_H)
	header.ZIndex = BASE_Z
	header.Parent = content
 
	local headerPad = Instance.new("UIPadding")
	headerPad.PaddingLeft = UDim.new(0, 14)
	headerPad.PaddingRight = UDim.new(0, 8)
	headerPad.Parent = header
 
	local titleRow = Instance.new("Frame")
	titleRow.BackgroundTransparency = 1
	titleRow.Size = UDim2.new(1, -84, 1, 0)
	titleRow.ZIndex = BASE_Z + 1
	titleRow.Parent = header
 
	local titleLayout = Instance.new("UIListLayout")
	titleLayout.FillDirection = Enum.FillDirection.Horizontal
	titleLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	titleLayout.Padding = UDim.new(0, 7)
	titleLayout.Parent = titleRow
 
	local titleIcon = Instance.new("ImageLabel")
	titleIcon.BackgroundTransparency = 1
	titleIcon.Image = ResolveIcon(opts.Icon or "bot")
	titleIcon.ImageColor3 = NullUI.Theme.Text
	titleIcon.Size = UDim2.fromOffset(14, 14)
	titleIcon.LayoutOrder = 1
	titleIcon.ZIndex = BASE_Z + 2
	titleIcon.Parent = titleRow
 
	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.FontFace = NullUI.Theme.Font
	titleLabel.Text = opts.Title or "Assistant"
	titleLabel.TextColor3 = NullUI.Theme.Text
	titleLabel.TextSize = 14
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.AutomaticSize = Enum.AutomaticSize.X
	titleLabel.Size = UDim2.fromOffset(0, 16)
	titleLabel.LayoutOrder = 2
	titleLabel.ZIndex = BASE_Z + 2
	titleLabel.Parent = titleRow
 
	local controls = Instance.new("Frame")
	controls.BackgroundTransparency = 1
	controls.AnchorPoint = Vector2.new(1, 0.5)
	controls.Position = UDim2.new(1, 0, 0.5, 0)
	controls.Size = UDim2.fromOffset(100, 22)
	controls.ZIndex = BASE_Z + 1
	controls.Parent = header
 
	local controlsLayout = Instance.new("UIListLayout")
	controlsLayout.FillDirection = Enum.FillDirection.Horizontal
	controlsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	controlsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	controlsLayout.Padding = UDim.new(0, 4)
	controlsLayout.Parent = controls
 
	local function headerIconButton(icon, layoutOrder)
		local btn = Instance.new("TextButton")
		btn.Text = ""
		btn.AutoButtonColor = false
		btn.BackgroundColor3 = Color3.new(1, 1, 1)
		btn.BackgroundTransparency = 1
		btn.BorderSizePixel = 0
		btn.Size = UDim2.fromOffset(22, 22)
		btn.LayoutOrder = layoutOrder
		btn.ZIndex = BASE_Z + 1
		btn.Parent = controls
		Corner(btn, 6)
 
		local ic = Instance.new("ImageLabel")
		ic.BackgroundTransparency = 1
		ic.Image = ResolveIcon(icon)
		ic.ImageColor3 = NullUI.Theme.TextDim
		ic.Size = UDim2.fromOffset(13, 13)
		ic.AnchorPoint = Vector2.new(0.5, 0.5)
		ic.Position = UDim2.fromScale(0.5, 0.5)
		ic.ZIndex = BASE_Z + 2
		ic.Parent = btn
 
		jan:Add(btn.MouseEnter:Connect(function()
			Tween(btn, { BackgroundTransparency = 0.9 }, 0.12)
			Tween(ic, { ImageColor3 = NullUI.Theme.Text }, 0.12)
		end))
		jan:Add(btn.MouseLeave:Connect(function()
			Tween(btn, { BackgroundTransparency = 1 }, 0.12)
			Tween(ic, { ImageColor3 = NullUI.Theme.TextDim }, 0.12)
		end))
 
		return btn, ic
	end
 
	local copyBtn, copyIcon = headerIconButton("copy", 1)
	local regenBtn, regenIcon = headerIconButton("refresh-cw", 2)
	local clearBtn = headerIconButton("trash-2", 3)
	local closeBtn = headerIconButton("x", 4)
 
	local headerDivider = Instance.new("Frame")
	headerDivider.BackgroundColor3 = Color3.new(1, 1, 1)
	headerDivider.BackgroundTransparency = 0.94
	headerDivider.BorderSizePixel = 0
	headerDivider.Position = UDim2.fromOffset(0, HEADER_H)
	headerDivider.Size = UDim2.new(1, 0, 0, 1)
	headerDivider.ZIndex = BASE_Z
	headerDivider.Parent = content
 
	local contentPad = Instance.new("UIPadding")
	contentPad.PaddingLeft = UDim.new(0, 14)
	contentPad.PaddingRight = UDim.new(0, 14)
	contentPad.PaddingBottom = UDim.new(0, 12)
	contentPad.Parent = content
 
	local inputRow = Instance.new("Frame")
	inputRow.BackgroundTransparency = 1
	inputRow.Active = true
	inputRow.AnchorPoint = Vector2.new(0, 1)
	inputRow.Position = UDim2.new(0, 0, 1, 0)
	inputRow.Size = UDim2.new(1, 0, 0, INPUT_H)
	inputRow.ZIndex = BASE_Z
	inputRow.Parent = content
 
	local pill = Instance.new("Frame")
	pill.BackgroundColor3 = Color3.new(1, 1, 1)
	pill.BackgroundTransparency = 0.95
	pill.BorderSizePixel = 0
	pill.Size = UDim2.new(1, -(INPUT_H + 6), 1, 0)
	pill.ZIndex = BASE_Z + 1
	pill.Parent = inputRow
	Corner(pill, 9)
	local pillStroke = Stroke(pill, Color3.new(1, 1, 1), 1, 0.9)
 
	local pillPad = Instance.new("UIPadding")
	pillPad.PaddingLeft = UDim.new(0, 10)
	pillPad.PaddingRight = UDim.new(0, 10)
	pillPad.Parent = pill
 
	local inputBox = Instance.new("TextBox")
	inputBox.BackgroundTransparency = 1
	inputBox.ClearTextOnFocus = false
	inputBox.FontFace = NullUI.Theme.FontRegular
	inputBox.PlaceholderText = opts.Placeholder or "Ask me anything..."
	inputBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 122)
	inputBox.Text = ""
	inputBox.TextColor3 = NullUI.Theme.Text
	inputBox.TextSize = 13
	inputBox.TextXAlignment = Enum.TextXAlignment.Left
	inputBox.TextYAlignment = Enum.TextYAlignment.Center
	inputBox.ClipsDescendants = true
	inputBox.Size = UDim2.fromScale(1, 1)
	inputBox.ZIndex = BASE_Z + 2
	inputBox.Parent = pill
 
	jan:Add(inputBox.Focused:Connect(function()
		Tween(pillStroke, { Color = NullUI.Theme.Accent, Transparency = 0.3 }, 0.15)
	end))
	jan:Add(inputBox.FocusLost:Connect(function()
		Tween(pillStroke, { Color = Color3.new(1, 1, 1), Transparency = 0.9 }, 0.15)
	end))
 
	local sendBtn = Instance.new("TextButton")
	sendBtn.Name = "Send"
	sendBtn.Text = ""
	sendBtn.AutoButtonColor = false
	sendBtn.BackgroundColor3 = Color3.new(1, 1, 1)
	sendBtn.BackgroundTransparency = 0.9
	sendBtn.BorderSizePixel = 0
	sendBtn.AnchorPoint = Vector2.new(1, 0)
	sendBtn.Position = UDim2.new(1, 0, 0, 0)
	sendBtn.Size = UDim2.fromOffset(INPUT_H, INPUT_H)
	sendBtn.ZIndex = BASE_Z + 1
	sendBtn.Parent = inputRow
	Corner(sendBtn, 9)
 
	local sendIcon = Instance.new("ImageLabel")
	sendIcon.BackgroundTransparency = 1
	sendIcon.Image = ResolveIcon("send")
	sendIcon.ImageColor3 = NullUI.Theme.Text
	sendIcon.Size = UDim2.fromOffset(14, 14)
	sendIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	sendIcon.Position = UDim2.fromScale(0.5, 0.5)
	sendIcon.ZIndex = BASE_Z + 2
	sendIcon.Parent = sendBtn
 
	jan:Add(sendBtn.MouseEnter:Connect(function() Tween(sendBtn, { BackgroundTransparency = 0.8 }, 0.12) end))
	jan:Add(sendBtn.MouseLeave:Connect(function() Tween(sendBtn, { BackgroundTransparency = 0.9 }, 0.12) end))
 
	local msgScroll = Instance.new("ScrollingFrame")
	msgScroll.BackgroundTransparency = 1
	msgScroll.BorderSizePixel = 0
	msgScroll.Position = UDim2.fromOffset(0, HEADER_H + 9)
	msgScroll.Size = UDim2.new(1, 0, 1, -(HEADER_H + 9 + INPUT_H + 10))
	msgScroll.ScrollingDirection = Enum.ScrollingDirection.Y
	msgScroll.ScrollBarThickness = 0
	msgScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	msgScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	msgScroll.ZIndex = BASE_Z
	msgScroll.Parent = content
 
	local msgPad = Instance.new("UIPadding")
	msgPad.PaddingRight = UDim.new(0, 18)
	msgPad.Parent = msgScroll
 
	local msgLayout = Instance.new("UIListLayout")
	msgLayout.Padding = UDim.new(0, 8)
	msgLayout.SortOrder = Enum.SortOrder.LayoutOrder
	msgLayout.Parent = msgScroll
 
	AddScrollbar(msgScroll)
	AddContentScrollThumb(msgScroll, msgLayout, panel, jan)
 
	local order = 0
	local transcript = {}
 
	local pinnedToBottom = true
	jan:Add(msgScroll:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(function()
		if pinnedToBottom then
			msgScroll.CanvasPosition = Vector2.new(0, msgScroll.AbsoluteCanvasSize.Y)
		end
	end))
	jan:Add(msgScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		local atBottom = msgScroll.CanvasPosition.Y
			>= msgScroll.AbsoluteCanvasSize.Y - msgScroll.AbsoluteWindowSize.Y - 20
		pinnedToBottom = atBottom
	end))
 
	local function scrollToBottom()
		pinnedToBottom = true
		task.defer(function()
			if msgScroll and msgScroll.Parent then
				msgScroll.CanvasPosition = Vector2.new(0, msgScroll.AbsoluteCanvasSize.Y)
			end
		end)
	end
 
	local AVATAR = 26
 
	local function addBubble(text, role)
		local isUser = role == "user"
		order = order + 1
 
		text = text:gsub("^%s+", ""):gsub("%s+$", ""):gsub("\n\n\n+", "\n\n")
 
		local row = Instance.new("Frame")
		row.Name = "MessageRow"
		row.BackgroundTransparency = 1
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.Size = UDim2.new(1, 0, 0, 0)
		row.LayoutOrder = order
		row.ZIndex = BASE_Z + 1
		row.Parent = msgScroll
 
		local rowScale = Instance.new("UIScale")
		rowScale.Scale = 0.92
		rowScale.Parent = row
 
		local rowLayout = Instance.new("UIListLayout")
		rowLayout.FillDirection = Enum.FillDirection.Horizontal
		rowLayout.HorizontalAlignment = isUser and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left
		rowLayout.VerticalAlignment = Enum.VerticalAlignment.Top
		rowLayout.Padding = UDim.new(0, 8)
		rowLayout.Parent = row
 
		local avatarFinalTransparency = isUser and 0.85 or 0.82
		local avatar = Instance.new("Frame")
		avatar.Name = "Avatar"
		avatar.BackgroundColor3 = isUser and Color3.new(1, 1, 1) or NullUI.Theme.Accent
		avatar.BackgroundTransparency = 1
		avatar.BorderSizePixel = 0
		avatar.Size = UDim2.fromOffset(AVATAR, AVATAR)
		avatar.LayoutOrder = isUser and 2 or 1
		avatar.ZIndex = BASE_Z + 2
		avatar.Parent = row
		Corner(avatar, AVATAR / 2)
 
		local avatarIcon
		if isUser then
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.ImageTransparency = 1
			img.ScaleType = Enum.ScaleType.Crop
			img.Size = UDim2.fromScale(1, 1)
			img.ZIndex = BASE_Z + 3
			img.Parent = avatar
			Corner(img, AVATAR / 2)
			avatarIcon = img
			task.spawn(function()
				local ok, content = pcall(
					Players.GetUserThumbnailAsync,
					Players,
					LocalPlayer.UserId,
					Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size100x100
				)
				if ok and content and img.Parent then
					img.Image = content
				end
			end)
		else
			local botIcon = Instance.new("ImageLabel")
			botIcon.BackgroundTransparency = 1
			botIcon.ImageTransparency = 1
			botIcon.Image = ResolveIcon("bot")
			botIcon.ImageColor3 = NullUI.Theme.Accent
			botIcon.Size = UDim2.fromOffset(14, 14)
			botIcon.AnchorPoint = Vector2.new(0.5, 0.5)
			botIcon.Position = UDim2.fromScale(0.5, 0.5)
			botIcon.ZIndex = BASE_Z + 3
			botIcon.Parent = avatar
			avatarIcon = botIcon
		end
 
		local segments = SplitMessageSegments(text)
		local hasCode = false
		for _, seg in ipairs(segments) do
			if seg.kind == "code" then hasCode = true end
		end
 
		local H_PAD, V_PAD = 10, 8
		local BUBBLE_MAX_WIDTH = hasCode and 380 or 260
		local bubbleWidth
		if hasCode then
			bubbleWidth = BUBBLE_MAX_WIDTH
		else
			local naturalW = MeasureText(segments[1].content, 13, 10000)
			bubbleWidth = math.min(naturalW, BUBBLE_MAX_WIDTH - H_PAD * 2) + H_PAD * 2
		end
		if msgScroll.AbsoluteSize.X > 0 then
			bubbleWidth = math.min(bubbleWidth, math.max(200, msgScroll.AbsoluteSize.X - 20))
		end
 
		local bubbleFinalTransparency = isUser and 0.72 or 0.9
		local bubble = Instance.new("Frame")
		bubble.Name = "Bubble"
		bubble.BackgroundColor3 = isUser and NullUI.Theme.Accent or Color3.new(1, 1, 1)
		bubble.BackgroundTransparency = 1
		bubble.BorderSizePixel = 0
		bubble.AutomaticSize = Enum.AutomaticSize.Y
		bubble.Size = UDim2.fromOffset(bubbleWidth, 0)
		bubble.LayoutOrder = isUser and 1 or 2
		bubble.ZIndex = BASE_Z + 2
		bubble.Parent = row
		Corner(bubble, 12)
		local strokeFinalTransparency = isUser and 0.8 or 0.9
		local bubbleStroke = Stroke(bubble, Color3.new(1, 1, 1), 1, 1)
 
		local bubblePad = Instance.new("UIPadding")
		bubblePad.PaddingTop = UDim.new(0, V_PAD)
		bubblePad.PaddingBottom = UDim.new(0, V_PAD)
		bubblePad.PaddingLeft = UDim.new(0, H_PAD)
		bubblePad.PaddingRight = UDim.new(0, H_PAD)
		bubblePad.Parent = bubble
 
		local bubbleLayout = Instance.new("UIListLayout")
		bubbleLayout.FillDirection = Enum.FillDirection.Vertical
		bubbleLayout.Padding = UDim.new(0, 8)
		bubbleLayout.SortOrder = Enum.SortOrder.LayoutOrder
		bubbleLayout.Parent = bubble
 
		Tween(avatar, { BackgroundTransparency = avatarFinalTransparency }, 0.16)
		Tween(avatarIcon, { ImageTransparency = 0 }, 0.16)
		Tween(bubble, { BackgroundTransparency = bubbleFinalTransparency }, 0.16)
		Tween(bubbleStroke, { Transparency = strokeFinalTransparency }, 0.16)
		Tween(rowScale, { Scale = 1 }, 0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
 
		local TYPE_START_DELAY = 0.08
		local maxTypeDuration = 0
 
		for i, seg in ipairs(segments) do
			if seg.kind == "code" then
				local card = Instance.new("Frame")
				card.Name = "CodeBlock"
				card.BackgroundColor3 = NullUI.Theme.Background
				card.BackgroundTransparency = 0.1
				card.BorderSizePixel = 0
				card.ClipsDescendants = true
				card.AutomaticSize = Enum.AutomaticSize.Y
				card.Size = UDim2.new(1, 0, 0, 0)
				card.LayoutOrder = i
				card.ZIndex = BASE_Z + 3
				card.Parent = bubble
				Corner(card, 8)
				Stroke(card, Color3.new(1, 1, 1), 1, 0.92)
 
				local cardLayout = Instance.new("UIListLayout")
				cardLayout.FillDirection = Enum.FillDirection.Vertical
				cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
				cardLayout.Parent = card
 
				local header = Instance.new("Frame")
				header.BackgroundTransparency = 1
				header.Size = UDim2.new(1, 0, 0, 24)
				header.LayoutOrder = 1
				header.ZIndex = BASE_Z + 4
				header.Parent = card
 
				local langLabel = Instance.new("TextLabel")
				langLabel.BackgroundTransparency = 1
				langLabel.FontFace = NullUI.Theme.FontRegular
				langLabel.Text = seg.lang
				langLabel.TextColor3 = NullUI.Theme.TextDim
				langLabel.TextSize = 11
				langLabel.TextXAlignment = Enum.TextXAlignment.Left
				langLabel.Position = UDim2.fromOffset(10, 0)
				langLabel.Size = UDim2.new(1, -70, 1, 0)
				langLabel.ZIndex = BASE_Z + 5
				langLabel.Parent = header
 
				local function codeHeaderButton(icon, rightOffset)
					local btn = Instance.new("TextButton")
					btn.Text = ""
					btn.AutoButtonColor = false
					btn.BackgroundColor3 = Color3.new(1, 1, 1)
					btn.BackgroundTransparency = 1
					btn.BorderSizePixel = 0
					btn.AnchorPoint = Vector2.new(1, 0.5)
					btn.Position = UDim2.new(1, -rightOffset, 0.5, 0)
					btn.Size = UDim2.fromOffset(20, 20)
					btn.ZIndex = BASE_Z + 5
					btn.Parent = header
					Corner(btn, 5)
 
					local ic = Instance.new("ImageLabel")
					ic.BackgroundTransparency = 1
					ic.Image = ResolveIcon(icon)
					ic.ImageColor3 = NullUI.Theme.TextDim
					ic.Size = UDim2.fromOffset(12, 12)
					ic.AnchorPoint = Vector2.new(0.5, 0.5)
					ic.Position = UDim2.fromScale(0.5, 0.5)
					ic.ZIndex = BASE_Z + 6
					ic.Parent = btn
 
					jan:Add(btn.MouseEnter:Connect(function()
						Tween(btn, { BackgroundTransparency = 0.85 }, 0.12)
						Tween(ic, { ImageColor3 = NullUI.Theme.Text }, 0.12)
					end))
					jan:Add(btn.MouseLeave:Connect(function()
						Tween(btn, { BackgroundTransparency = 1 }, 0.12)
						Tween(ic, { ImageColor3 = NullUI.Theme.TextDim }, 0.12)
					end))
 
					return btn, ic
				end
 
				local copyBtn, copyIcon = codeHeaderButton("copy", 8)
				jan:Add(copyBtn.MouseButton1Click:Connect(function()
					local setclipboard = hasFn("setclipboard")
					if not setclipboard then return end
					pcall(setclipboard, seg.content)
					Tween(copyIcon, { ImageColor3 = Color3.fromRGB(120, 220, 140) }, 0.1)
					task.delay(0.4, function()
						if copyIcon.Parent then
							Tween(copyIcon, { ImageColor3 = NullUI.Theme.TextDim }, 0.15)
						end
					end)
				end))
 
				if opts.OnRunCode then
					local runBtn, runIcon = codeHeaderButton("play", 32)
					jan:Add(runBtn.MouseButton1Click:Connect(function()
						NullUI:Confirm({
							Title = "Run this code?",
							Text = "This runs exactly what's shown above, right now, in this game.",
							ConfirmText = "Run",
							CancelText = "Cancel",
							Danger = true,
							Window = self,
							Callback = function(confirmed)
								if not confirmed then return end
								local ok, err = pcall(opts.OnRunCode, seg.content, seg.lang)
								NullUI:Notify({
									Title = ok and "Ran" or "Run failed",
									Text = ok and "Code executed." or tostring(err),
									Type = ok and "success" or "error",
									Duration = 3,
								})
							end,
						})
					end))
				end
 
				local headerDivider = Instance.new("Frame")
				headerDivider.BackgroundColor3 = Color3.new(1, 1, 1)
				headerDivider.BackgroundTransparency = 0.92
				headerDivider.BorderSizePixel = 0
				headerDivider.Size = UDim2.new(1, 0, 0, 1)
				headerDivider.LayoutOrder = 2
				headerDivider.ZIndex = BASE_Z + 4
				headerDivider.Parent = card
 
				local codeContainer = Instance.new("Frame")
				codeContainer.BackgroundTransparency = 1
				codeContainer.AutomaticSize = Enum.AutomaticSize.Y
				codeContainer.Size = UDim2.new(1, 0, 0, 0)
				codeContainer.LayoutOrder = 3
				codeContainer.ZIndex = BASE_Z + 4
				codeContainer.Parent = card
 
				local codePad = Instance.new("UIPadding")
				codePad.PaddingTop = UDim.new(0, 8)
				codePad.PaddingBottom = UDim.new(0, 8)
				codePad.PaddingLeft = UDim.new(0, 10)
				codePad.PaddingRight = UDim.new(0, 10)
				codePad.Parent = codeContainer
 
				local codeLabel = Instance.new("TextLabel")
				codeLabel.BackgroundTransparency = 1
				codeLabel.FontFace = Font.new(CHAT_CODE_FONT, Enum.FontWeight.Regular, Enum.FontStyle.Normal)
				codeLabel.RichText = true
				codeLabel.Text = HighlightLua(EscapeRichText(seg.content))
				codeLabel.TextColor3 = NullUI.Theme.Text
				codeLabel.TextSize = 12
				codeLabel.TextWrapped = true
				codeLabel.TextXAlignment = Enum.TextXAlignment.Left
				codeLabel.TextYAlignment = Enum.TextYAlignment.Top
				codeLabel.LineHeight = 1.3
				codeLabel.AutomaticSize = Enum.AutomaticSize.Y
				codeLabel.Size = UDim2.new(1, 0, 0, 16)
				codeLabel.ZIndex = BASE_Z + 5
				codeLabel.Parent = codeContainer
			else
				local label = Instance.new("TextLabel")
				label.Name = "Prose"
				label.BackgroundTransparency = 1
				label.FontFace = NullUI.Theme.FontRegular
				label.RichText = true
				label.Text = MarkdownToRichText(seg.content)
				label.TextColor3 = NullUI.Theme.Text
				label.TextTransparency = 1
				label.TextSize = 13
				label.TextWrapped = true
				label.TextXAlignment = Enum.TextXAlignment.Left
				label.TextYAlignment = Enum.TextYAlignment.Top
				label.LineHeight = 1.3
				label.AutomaticSize = Enum.AutomaticSize.Y
				label.Size = UDim2.new(1, 0, 0, 16)
				label.LayoutOrder = i
				label.ZIndex = BASE_Z + 3
 
				label.MaxVisibleGraphemes = 0
				label.Parent = bubble
 
				Tween(label, { TextTransparency = 0 }, 0.16)
 
				local graphemeCount = utf8.len(seg.content) or #seg.content
				local typeDuration = math.clamp(graphemeCount * 0.014, 0.12, 1.6)
				maxTypeDuration = math.max(maxTypeDuration, typeDuration)
				task.delay(TYPE_START_DELAY, function()
					if label and label.Parent then
						TweenService:Create(
							label,
							TweenInfo.new(typeDuration, Enum.EasingStyle.Linear),
							{ MaxVisibleGraphemes = graphemeCount }
						):Play()
					end
				end)
			end
		end
 
		scrollToBottom()
		table.insert(transcript, (isUser and "You" or "Assistant") .. ": " .. text)
 
		return TYPE_START_DELAY + maxTypeDuration
	end
 
	local bumpTypingToBottom
 
	local function addToolLine(name)
		order = order + 1
		local row = Instance.new("Frame")
		row.Name = "ToolCall"
		row.BackgroundTransparency = 1
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.Size = UDim2.new(1, 0, 0, 18)
		row.LayoutOrder = order
		row.ZIndex = BASE_Z + 1
		row.Parent = msgScroll
 
		local rowLayout = Instance.new("UIListLayout")
		rowLayout.FillDirection = Enum.FillDirection.Horizontal
		rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		rowLayout.Padding = UDim.new(0, 6)
		rowLayout.Parent = row
 
		local toolIcon = Instance.new("ImageLabel")
		toolIcon.BackgroundTransparency = 1
		toolIcon.Image = ResolveIcon("wrench")
		toolIcon.ImageColor3 = NullUI.Theme.Accent
		toolIcon.Size = UDim2.fromOffset(11, 11)
		toolIcon.LayoutOrder = 1
		toolIcon.ZIndex = BASE_Z + 2
		toolIcon.Parent = row
 
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.FontFace = NullUI.Theme.FontRegular
		label.Text = "Called tool: " .. tostring(name)
		label.TextColor3 = NullUI.Theme.TextDim
		label.TextSize = 11
		label.AutomaticSize = Enum.AutomaticSize.XY
		label.Size = UDim2.fromOffset(0, 14)
		label.LayoutOrder = 2
		label.ZIndex = BASE_Z + 2
		label.Parent = row
 
		scrollToBottom()
		table.insert(transcript, "[Called tool: " .. tostring(name) .. "]")
		if bumpTypingToBottom then bumpTypingToBottom() end
	end
 
	local typingRow, typingTweens, typingActive = nil, nil, false
 
	local function destroyTypingRow()
		if not typingRow then return end
		for _, tw in ipairs(typingTweens) do tw:Cancel() end
		local row = typingRow
		typingRow, typingTweens = nil, nil
		row:Destroy()
	end
 
	local function buildTypingRow()
		order = order + 1
 
		local row = Instance.new("Frame")
		row.Name = "TypingRow"
		row.BackgroundTransparency = 1
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.Size = UDim2.new(1, 0, 0, 0)
		row.LayoutOrder = order
		row.ZIndex = BASE_Z + 1
		row.Parent = msgScroll
 
		local rowLayout = Instance.new("UIListLayout")
		rowLayout.FillDirection = Enum.FillDirection.Horizontal
		rowLayout.VerticalAlignment = Enum.VerticalAlignment.Top
		rowLayout.Padding = UDim.new(0, 8)
		rowLayout.Parent = row
 
		local avatar = Instance.new("Frame")
		avatar.BackgroundColor3 = NullUI.Theme.Accent
		avatar.BackgroundTransparency = 1
		avatar.BorderSizePixel = 0
		avatar.Size = UDim2.fromOffset(AVATAR, AVATAR)
		avatar.LayoutOrder = 1
		avatar.ZIndex = BASE_Z + 2
		avatar.Parent = row
		Corner(avatar, AVATAR / 2)
 
		local botIcon = Instance.new("ImageLabel")
		botIcon.BackgroundTransparency = 1
		botIcon.ImageTransparency = 1
		botIcon.Image = ResolveIcon("bot")
		botIcon.ImageColor3 = NullUI.Theme.Accent
		botIcon.Size = UDim2.fromOffset(14, 14)
		botIcon.AnchorPoint = Vector2.new(0.5, 0.5)
		botIcon.Position = UDim2.fromScale(0.5, 0.5)
		botIcon.ZIndex = BASE_Z + 3
		botIcon.Parent = avatar
 
		local bubble = Instance.new("Frame")
		bubble.BackgroundColor3 = Color3.new(1, 1, 1)
		bubble.BackgroundTransparency = 1
		bubble.BorderSizePixel = 0
		bubble.Size = UDim2.fromOffset(38, AVATAR)
		bubble.LayoutOrder = 2
		bubble.ZIndex = BASE_Z + 2
		bubble.Parent = row
		Corner(bubble, 12)
		local bubbleStroke = Stroke(bubble, Color3.new(1, 1, 1), 1, 1)
 
		local tweens = {}
		for i = 1, 3 do
			local baseX = 10 + (i - 1) * 9
			local dot = Instance.new("Frame")
			dot.BackgroundColor3 = NullUI.Theme.TextDim
			dot.BackgroundTransparency = 1
			dot.BorderSizePixel = 0
			dot.AnchorPoint = Vector2.new(0.5, 0.5)
			dot.Position = UDim2.new(0, baseX, 0.5, 0)
			dot.Size = UDim2.fromOffset(4, 4)
			dot.ZIndex = BASE_Z + 3
			dot.Parent = bubble
			Corner(dot, 2)
			Tween(dot, { BackgroundTransparency = 0 }, 0.15)
 
			tweens[i] = TweenService:Create(
				dot,
				TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, (i - 1) * 0.15),
				{ Position = UDim2.new(0, baseX, 0.5, -3) }
			)
			tweens[i]:Play()
		end
 
		Tween(avatar, { BackgroundTransparency = 0.82 }, 0.15)
		Tween(botIcon, { ImageTransparency = 0 }, 0.15)
		Tween(bubble, { BackgroundTransparency = 0.9 }, 0.15)
		Tween(bubbleStroke, { Transparency = 0.9 }, 0.15)
 
		typingRow, typingTweens = row, tweens
		scrollToBottom()
	end
 
	local function showTyping()
		if typingRow then return end
		typingActive = true
		buildTypingRow()
	end
 
	function bumpTypingToBottom()
		if not typingRow then return end
		destroyTypingRow()
		buildTypingRow()
	end
 
	local function hideTyping()
		if not typingActive then return end
		typingActive = false
		destroyTypingRow()
	end
 
	local function addMessage(role, text)
		text = tostring(text or "")
		if text == "" then return end
		hideTyping()
		if role == "tool" then
			addToolLine(text)
			return nil
		end
		return addBubble(text, role)
	end
 
	local function handleToolCall(name, args)
		local tool = toolByName[name]
		addToolLine(name)
		if not tool or not tool.Handler then
			addMessage("assistant", "Unknown tool: " .. tostring(name))
			return nil
		end
		local ok, result = pcall(tool.Handler, args)
		if not ok then
			addMessage("assistant", "Tool error: " .. tostring(result))
			return nil
		end
		return result
	end
 
	local api
 
	local sending = false
	local lastUserText = nil
 
	local function setSending(value)
		sending = value
		sendIcon.Image = ResolveIcon(value and "square" or "send")
	end
 
	local function trySend(overrideText)
		local text = overrideText or inputBox.Text
		if sending or text == "" then return end
		setSending(true)
		if not overrideText then inputBox.Text = "" end
		lastUserText = text
		local revealTime = addMessage("user", text)
		if opts.OnSend then
			local finished = false
 
			task.spawn(function()
 
				if revealTime and revealTime > 0 then task.wait(revealTime) end
				local ok, err = pcall(opts.OnSend, api, text)
				if not ok then
					addMessage("assistant", "Error: " .. tostring(err))
				end
				finished = true
				setSending(false)
			end)
 
			task.delay(opts.SendTimeout or 30, function()
				if not finished and sending then
					setSending(false)
					hideTyping()
					addMessage("assistant", "(Taking too long -- you can try sending again.)")
				end
			end)
		else
			setSending(false)
		end
	end
 
	local function tryRegenerate()
		if sending or not lastUserText then return end
		if opts.OnRegenerate then
			task.spawn(opts.OnRegenerate, api, lastUserText)
		else
			trySend(lastUserText)
		end
	end
 
	local lastRealTab = nil
 
	local function openChat()
		if self._currentTab == tabObj then return end
		if self._currentTab and not self._currentTab.Hidden then
			lastRealTab = self._currentTab
		end
		tabObj._select()
	end
 
	local function closeChat()
		if self._currentTab ~= tabObj then return end
		if lastRealTab and not lastRealTab.Hidden then
			lastRealTab._select()
		elseif self._tabs[1] and self._tabs[1] ~= tabObj then
			self._tabs[1]._select()
		end
	end
 
	table.insert(self._tabChangeListeners, function(selected)
		if opts.OnToggle then task.spawn(opts.OnToggle, selected == tabObj) end
	end)
 
	local function clearChat()
		hideTyping()
		for _, child in ipairs(msgScroll:GetChildren()) do
			if child.Name == "MessageRow" or child.Name == "ToolCall" then
				child:Destroy()
			end
		end
		table.clear(transcript)
		if opts.OnClear then task.spawn(opts.OnClear) end
	end
 
	jan:Add(sendBtn.MouseButton1Click:Connect(function()
		if sending then
			if opts.OnStop then task.spawn(opts.OnStop, api) end
		else
			trySend()
		end
	end))
	jan:Add(inputBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then trySend() end
	end))
	jan:Add(closeBtn.MouseButton1Click:Connect(closeChat))
 
	jan:Add(copyBtn.MouseButton1Click:Connect(function()
		local setclipboard = hasFn("setclipboard")
		if not setclipboard or #transcript == 0 then return end
		pcall(setclipboard, table.concat(transcript, "\n\n"))
		Tween(copyIcon, { ImageColor3 = Color3.fromRGB(120, 220, 140) }, 0.1)
		task.delay(0.4, function()
			if copyIcon.Parent then
				Tween(copyIcon, { ImageColor3 = NullUI.Theme.TextDim }, 0.15)
			end
		end)
	end))
	jan:Add(regenBtn.MouseButton1Click:Connect(function()
		if sending or not lastUserText then return end
		Tween(regenIcon, { Rotation = regenIcon.Rotation + 180 }, 0.25)
		tryRegenerate()
	end))
	jan:Add(clearBtn.MouseButton1Click:Connect(function()
		clearChat()
		lastUserText = nil
	end))
 
	api = {
		Instance = panel,
		Tab = tabObj,
		Open = openChat,
		Close = closeChat,
		Toggle = function()
			if self._currentTab == tabObj then closeChat() else openChat() end
		end,
		IsOpen = function() return self._currentTab == tabObj end,
		AddMessage = function(_, role, text) addMessage(role, text) end,
		LogToolCall = function(_, name) addToolLine(name) end,
		HandleToolCall = function(_, name, args) return handleToolCall(name, args) end,
		ShowTyping = function() showTyping() end,
		HideTyping = function() hideTyping() end,
		IsSending = function() return sending end,
		Clear = function() clearChat() end,
		Destroy = function() panel:Destroy() end,
	}
 
	return api
end
 
function Window:AddCloudPanel(opts)
	opts = opts or {}
	local service = opts.Service
 
	local tabObj = self:AddTab({
		Name   = opts.Name or "Cloud",
		Icon   = opts.Icon or "cloud",
		Hidden = opts.Hidden ~= false,
	})
 
	table.insert(self._tabChangeListeners, function(selected)
		if opts.OnToggle then task.spawn(opts.OnToggle, selected == tabObj) end
	end)
 
	local mineGrid, publicGrid, localGrid
	local function relativeTime(timestamp)
		local seconds = math.max(0, os.time() - tonumber(timestamp or os.time()))
		if seconds < 60 then return "updated just now" end
		if seconds < 3600 then return "updated " .. math.floor(seconds / 60) .. "m ago" end
		if seconds < 86400 then return "updated " .. math.floor(seconds / 3600) .. "h ago" end
		return "updated " .. math.floor(seconds / 86400) .. "d ago"
	end
 
	local CloudTabs = {
		Local = tabObj:AddSubTab({ Name = "Local Configs", Icon = "Lucide:hard-drive" }),
		Mine = tabObj:AddSubTab({ Name = "Publish Public Config", Icon = "Lucide:cloud-cog" }),
		Explore = tabObj:AddSubTab({ Name = "Public Configs", Icon = "Lucide:cloud" }),
	}
 
	CloudTabs.Local:AddParagraph({
		Title = "Local Library",
		Icon = "Lucide:hard-drive",
		Text = "Private presets saved only on this device. Load, create and manage them without uploading anything.",
	})
 
	CloudTabs.Local:AddSection("Quick Actions", "Lucide:zap")
	CloudTabs.Local:AddButton({
		Text = "Save Current Settings Locally",
		Description = "Stays on this device only",
		Icon = "Lucide:save",
		Callback = function()
			NullUI:Modal({
				Title = "Save Config Locally",
				Text  = "Stays only on this device -- never sent anywhere.",
				ConfirmText = "Save",
				CancelText  = "Cancel",
				Window = self,
				Fields = {
					{ Key = "Name", Label = "Name", Placeholder = "Enter a name...", MaxLength = 60 },
					{ Key = "Description", Label = "Description (optional)", Type = "textarea",
						Placeholder = "What's different about this one?", MaxLength = 280 },
				},
				Callback = function(confirmed, values)
					if not confirmed then return end
					if not values.Name or values.Name:gsub("%s+", "") == "" then
						NullUI:Notify({ Title = "Local Save", Text = "Name can't be empty.", Type = "warning", Duration = 3 })
						return
					end
					local function saveNow()
						local ok, err = NullUI:SaveConfig(values.Name, { Description = values.Description })
						NullUI:Notify({
							Title = ok and "Saved" or "Could not save", Text = ok and "Saved locally." or tostring(err),
							Type = ok and "success" or "error", Duration = 3,
						})
						if ok and localGrid then localGrid.Refresh() end
					end
					if NullUI:GetConfigMeta(values.Name) then
						NullUI:Confirm({
							Title = "Overwrite \"" .. tostring(values.Name) .. "\"?",
							Text = "A local config already uses this name.", ConfirmText = "Overwrite", CancelText = "Cancel",
							Danger = true, Window = self,
							Callback = function(overwrite) if overwrite then saveNow() end end,
						})
					else
						saveNow()
					end
				end,
			})
		end,
	})
 
	localGrid = CloudTabs.Local:AddCardGrid({
		Title = "Local Configs",
		Height = 224,
		FixedHeight = true,
		Search = true,
		SearchPlaceholder = "Search local configs...",
		CardHeight = 68,
		AutoCardHeight = false,
		CardMinWidth = 180,
		Columns = 2,
		MaxColumns = 2,
		OuterPadding = 12,
		CardPadding = 8,
		ShowScrollbar = true,
		EmptyText = "No local configs saved yet.",
		ErrorText = "Your executor doesn't support local file access.",
		Fetch = function(state)
			local items, err = NullUI:ListConfigs()
			if err and #items == 0 then return nil, err end
			local query = string.lower(tostring(state and state.Query or ""))
			local out = {}
			for _, cfg in ipairs(items) do
				local searchable = string.lower(table.concat({
					tostring(cfg.Name or ""),
					tostring(cfg.Description or ""),
					table.concat(cfg.Tags or {}, " "),
				}, " "))
				if query ~= "" and not string.find(searchable, query, 1, true) then continue end
 
				local function loadLocalConfig()
					NullUI:Confirm({
						Title = "Load \"" .. tostring(cfg.Name) .. "\"?",
						Text = "This overwrites your current settings. A snapshot is kept for instant undo.",
						ConfirmText = "Load", CancelText = "Cancel", Window = self,
						Callback = function(confirmedLoad)
							if not confirmedLoad then return end
							local snapshot = NullUI:CreateSnapshot()
							local ok, loadErr = NullUI:LoadConfig(cfg.Name, false)
							if not ok then
								NullUI:Notify({ Title = "Could not load", Text = tostring(loadErr), Type = "error", Duration = 4 })
								return
							end
							NullUI:Notify({
								Title = "Loaded", Text = tostring(cfg.Name) .. " is now active.", Type = "success", Duration = 6,
								Actions = {{ Text = "Undo", Callback = function() NullUI:RestoreSnapshot(snapshot, false) end }},
							})
						end,
					})
				end
 
				local function renameLocalConfig()
					NullUI:Modal({
						Title = "Rename Config", Text = "Choose a new name for \"" .. tostring(cfg.Name) .. "\".",
						ConfirmText = "Rename", CancelText = "Cancel", Window = self,
						Fields = {{ Key = "Name", Label = "New name", Default = cfg.Name, MaxLength = 60 }},
						Callback = function(confirmed, values)
							if not confirmed then return end
							local newName = tostring(values.Name or ""):match("^%s*(.-)%s*$")
							if newName == "" then return end
							local existing = NullUI:GetConfigMeta(newName)
							if existing and newName ~= cfg.Name then
								NullUI:Notify({ Title = "Name already used", Text = "Choose another config name.", Type = "warning", Duration = 3 })
								return
							end
							local ok, renameErr = NullUI:RenameConfig(cfg.Name, newName)
							NullUI:Notify({ Title = ok and "Renamed" or "Could not rename", Text = ok and "Config name updated." or tostring(renameErr), Type = ok and "success" or "error", Duration = 3 })
							if ok and localGrid then localGrid.Refresh() end
						end,
					})
				end
 
				local function publishLocalConfig()
					if not service then
						NullUI:Notify({ Title = "Cloud", Text = "No cloud service configured.", Type = "warning", Duration = 3 })
						return
					end
					local saved, savedErr = NullUI:GetSavedConfig(cfg.Name)
					if not saved then
						NullUI:Notify({ Title = "Could not read config", Text = tostring(savedErr), Type = "error", Duration = 3 })
						return
					end
					local result, publishErr = service:Publish({ Name = cfg.Name, Description = cfg.Description, Tags = cfg.Tags }, saved.Data)
					NullUI:Notify({ Title = result and "Published" or "Could not publish", Text = result and "Config published successfully." or tostring(publishErr), Type = result and "success" or "error", Duration = 4 })
					if result then
						if mineGrid then mineGrid.Refresh() end
						if publicGrid then publicGrid.Refresh() end
					end
				end
 
				local function deleteLocalConfig()
					NullUI:Confirm({
						Title = "Delete \"" .. tostring(cfg.Name) .. "\"?", Text = "This local config will be permanently removed.",
						ConfirmText = "Delete", CancelText = "Cancel", Danger = true, Window = self,
						Callback = function(confirmed)
							if not confirmed then return end
							local ok, deleteErr = NullUI:DeleteConfig(cfg.Name)
							NullUI:Notify({ Title = ok and "Deleted" or "Could not delete", Text = ok and "Config removed." or tostring(deleteErr), Type = ok and "success" or "error", Duration = 3 })
							if ok and localGrid then localGrid.Refresh() end
						end,
					})
				end
 
				table.insert(out, {
					Title = cfg.Name,
					Description = cfg.Description,
					Byline = relativeTime(cfg.CreatedAt)
						.. ((cfg.Tags and #cfg.Tags > 0) and ("  •  " .. table.concat(cfg.Tags, ", ")) or ""),
					Icon = "Lucide:file-text",
					ActionIcon = "download",
					Callback = loadLocalConfig,
					SecondaryIcon = "trash-2",
					SecondaryCallback = deleteLocalConfig,
					SecondaryDanger = true,
				})
			end
			return out
		end,
	})
 
	local function publishFlow()
		if not service then
			NullUI:Notify({ Title = "Cloud", Text = "No cloud service configured.", Type = "warning", Duration = 3 })
			return
		end
		NullUI:Modal({
			Title = "New Config",
			ConfirmText = "Publish",
			CancelText = "Cancel",
			Window = self,
			Fields = {
				{ Key = "Name", Label = "Name", Placeholder = "Enter profile name...", MaxLength = 60 },
				{ Key = "Description", Label = "Description", Type = "textarea",
					Placeholder = "Enter profile's description...", MaxLength = 280 },
				{ Key = "Tags", Label = "Tags (optional)", Type = "tags",
					Placeholder = "Enter tags separated by commas..." },
			},
			Callback = function(confirmed, values)
				if not confirmed then return end
				local result, err = service:Publish({
					Name = values.Name,
					Description = values.Description,
					Tags = values.Tags,
				})
				NullUI:Notify({
					Title = result and "Published" or "Could not publish",
					Text  = result and "Your config is now public." or tostring(err),
					Type  = result and "success" or "error",
					Duration = 4,
				})
				if result then
					if mineGrid then mineGrid.Refresh() end
					if publicGrid then publicGrid.Refresh() end
				end
			end,
		})
	end
 
	CloudTabs.Mine:AddParagraph({
		Title = "My Cloud Library",
		Icon = "Lucide:cloud",
		Text = "Publish your current setup, review what you shared and remove old uploads from one place.",
	})
 
	CloudTabs.Mine:AddSection("Publishing", "Lucide:upload-cloud")
	CloudTabs.Mine:AddButton({
		Text = "Publish Current Settings",
		Description = "Share your current config publicly",
		Icon = "Lucide:upload-cloud",
		Callback = publishFlow,
	})
 
	mineGrid = CloudTabs.Mine:AddCardGrid({
		Title = "Your Configs",
		Height = 210,
		FixedHeight = true,
		Search = false,
		CardHeight = 104,
		AutoCardHeight = false,
		DescriptionHeight = 24,
		CardMinWidth = 180,
		Columns = 2,
		MaxColumns = 2,
		OuterPadding = 12,
		CardPadding = 8,
		ShowScrollbar = true,
		EmptyText = service and "You haven't published anything yet." or "No cloud service configured.",
		ErrorText = "Couldn't load your configs.",
		Fetch = function()
			if not service then
				return {}, nil
			end
			local items, err = service:ListMine()
			if not items then return nil, err end
			local out = {}
			for _, cfg in ipairs(items) do
				local function deletePublishedConfig()
					NullUI:Confirm({
						Title = "Delete \"" .. tostring(cfg.Name) .. "\"?",
						Text = "This removes it from the public library. This cannot be undone.",
						ConfirmText = "Delete", CancelText = "Cancel", Danger = true, Window = self,
						Callback = function(confirmedDelete)
							if not confirmedDelete then return end
							local ok, delErr = service:Delete(cfg.Id)
							NullUI:Notify({ Title = ok and "Deleted" or "Could not delete", Text = ok and "Config removed." or tostring(delErr), Type = ok and "success" or "error", Duration = 3 })
							if ok then
								if mineGrid then mineGrid.Refresh() end
								if publicGrid then publicGrid.Refresh() end
							end
						end,
					})
				end
				table.insert(out, {
					Title = cfg.Name,
					Description = cfg.Description,
					Byline = cfg.CreatedAtText or "",
					Icon = "Lucide:cloud",
					Stats = {
						{ Icon = "thumbs-up", Text = tostring(cfg.Likes or 0) },
						{ Icon = "download", Text = tostring(cfg.Downloads or 0) },
					},
					Menu = {
						{ Text = "Delete publication", Icon = "trash-2", Danger = true, Callback = deletePublishedConfig },
					},
				})
			end
			return out
		end,
	})
 
	CloudTabs.Explore:AddParagraph({
		Title = "Community Library",
		Icon = "Lucide:compass",
		Text = "Discover public configs, compare popularity and apply a setup with an instant undo snapshot.",
	})
 
	CloudTabs.Explore:AddSection("Browse Configs", "Lucide:layout-grid")
 
	local SORT_MAP = { ["Top Rated"] = "top", ["Most Downloaded"] = "downloads", ["Newest"] = "new" }
 
	publicGrid = CloudTabs.Explore:AddCardGrid({
		Title = "Public Configs",
		Height = 230,
		FixedHeight = true,
		Sorts = { "Top Rated", "Most Downloaded", "Newest" },
		SearchPlaceholder = "Search config by name / tags...",
		CardHeight = 112,
		AutoCardHeight = false,
		DescriptionHeight = 24,
		CardMinWidth = 180,
		Columns = 2,
		MaxColumns = 2,
		OuterPadding = 12,
		CardPadding = 8,
		ShowScrollbar = true,
		EmptyText = "No public configs match your search.",
		ErrorText = "Couldn't reach the cloud service.",
		Fetch = function(state)
			if not service then return nil, "No cloud service configured." end
			local items, err = service:List({
				Query = state.Query,
				Sort = SORT_MAP[state.Sort] or "top",
				PageSize = state.PageSize,
			})
			if not items then return nil, err end
			local out = {}
			for _, cfg in ipairs(items) do
				local byline = cfg.OwnerName or "anonymous"
				if cfg.CreatedAtText then byline = byline .. " \226\128\162 " .. cfg.CreatedAtText end
				table.insert(out, {
					Title = cfg.Name,
					Description = cfg.Description,
					Byline = byline,
					Icon = "Lucide:cloud-download",
					ActionIcon = "download",
					Stats = {
						{
							Icon = "thumbs-up",
							Text = tostring(cfg.Likes or 0),
							Callback = function()
								local liked, likeErr = service:Like(cfg.Id)
								if not liked then
									NullUI:Notify({
										Title = "Could not like",
										Text  = tostring(likeErr),
										Type  = "error",
										Duration = 3,
									})
									return
								end
								if publicGrid then publicGrid.Refresh() end
							end,
						},
						{ Icon = "download", Text = tostring(cfg.Downloads or 0) },
					},
					Callback = function()
						NullUI:Confirm({
							Title = "Apply \"" .. tostring(cfg.Name) .. "\"?",
							Text  = "This overwrites your current settings. A snapshot of what you have now "
								.. "is kept so you can undo it right after.",
							ConfirmText = "Apply",
							CancelText  = "Cancel",
							Window = self,
							Callback = function(confirmedApply)
								if not confirmedApply then return end
								local result, dlErr = service:Download(cfg.Id)
								if not result or not result.Data then
									NullUI:Notify({
										Title = "Could not apply",
										Text  = tostring(dlErr),
										Type  = "error",
										Duration = 4,
									})
									return
								end
 
								local snapshot = NullUI:CreateSnapshot()
 
								NullUI:SetConfig(result.Data, false)
								NullUI:Notify({
									Title = "Applied",
									Text  = tostring(cfg.Name) .. " is now active.",
									Type  = "success",
									Duration = 6,
									Actions = {
										{
											Text = "Undo",
											Callback = function()
												NullUI:RestoreSnapshot(snapshot, false)
												NullUI:Notify({
													Title = "Reverted",
													Text  = "Your previous settings are back.",
													Type  = "info",
													Duration = 3,
												})
											end,
										},
									},
								})
 
								if publicGrid then publicGrid.Refresh() end
								if opts.OnApplied then task.spawn(opts.OnApplied, cfg) end
							end,
						})
					end,
				})
			end
			return out
		end,
	})
 
	local lastRealTab = nil
	local function openPanel()
		if self._currentTab == tabObj then return end
		if self._currentTab and not self._currentTab.Hidden then
			lastRealTab = self._currentTab
		end
		tabObj._select()
	end
	local function closePanel()
		if self._currentTab ~= tabObj then return end
		if lastRealTab and not lastRealTab.Hidden then
			lastRealTab._select()
		elseif self._tabs[1] and self._tabs[1] ~= tabObj then
			self._tabs[1]._select()
		end
	end
 
	return {
		Instance = tabObj._group,
		Tab = tabObj,
		Open = openPanel,
		Close = closePanel,
		Toggle = function()
			if self._currentTab == tabObj then closePanel() else openPanel() end
		end,
		IsOpen = function() return self._currentTab == tabObj end,
		RefreshMine = function() if mineGrid then mineGrid.Refresh() end end,
		RefreshPublic = function() if publicGrid then publicGrid.Refresh() end end,
	}
end
 
function Window:AddGlobalChatPanel(opts)
	opts = opts or {}
	local service = opts.Service
	local jan = self._janitor
 
	local tabObj = self:AddTab({
		Name   = opts.Name or "Chat",
		Icon   = opts.Icon or "messages-square",
		Hidden = opts.Hidden ~= false,
	})
	tabObj._page.Visible = false
	local staleEmptyState = tabObj._group:FindFirstChild("EmptyState")
	if staleEmptyState then staleEmptyState.Visible = false end
 
	table.insert(self._tabChangeListeners, function(selected)
		if opts.OnToggle then task.spawn(opts.OnToggle, selected == tabObj) end
	end)
 
	local INPUT_H, HEADER_H = 38, 38
 
	local panel = Instance.new("Frame")
	panel.Name = "GlobalChatPanel"
	panel.BackgroundTransparency = 1
	panel.ClipsDescendants = true
	panel.Size = UDim2.fromScale(1, 1)
	panel.ZIndex = Z.Content
	panel.Parent = tabObj._group
 
	local BASE_Z = panel.ZIndex + 1
 
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Size = UDim2.fromScale(1, 1)
	content.ZIndex = panel.ZIndex
	content.Parent = panel
 
	local header = Instance.new("Frame")
	header.BackgroundTransparency = 1
	header.Active = true
	header.Size = UDim2.new(1, 0, 0, HEADER_H)
	header.ZIndex = BASE_Z
	header.Parent = content
 
	local headerPad = Instance.new("UIPadding")
	headerPad.PaddingLeft = UDim.new(0, 14)
	headerPad.PaddingRight = UDim.new(0, 8)
	headerPad.Parent = header
 
	local titleRow = Instance.new("Frame")
	titleRow.BackgroundTransparency = 1
	titleRow.Size = UDim2.new(1, -136, 1, 0)
	titleRow.ZIndex = BASE_Z + 1
	titleRow.Parent = header
 
	local titleLayout = Instance.new("UIListLayout")
	titleLayout.FillDirection = Enum.FillDirection.Horizontal
	titleLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	titleLayout.Padding = UDim.new(0, 7)
	titleLayout.Parent = titleRow
 
	local titleIcon = Instance.new("ImageLabel")
	titleIcon.BackgroundTransparency = 1
	titleIcon.Image = ResolveIcon(opts.Icon or "messages-square")
	titleIcon.ImageColor3 = NullUI.Theme.Text
	titleIcon.Size = UDim2.fromOffset(14, 14)
	titleIcon.LayoutOrder = 1
	titleIcon.ZIndex = BASE_Z + 2
	titleIcon.Parent = titleRow
 
	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.FontFace = NullUI.Theme.Font
	titleLabel.Text = opts.Title or "Chat"
	titleLabel.TextColor3 = NullUI.Theme.Text
	titleLabel.TextSize = 14
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.AutomaticSize = Enum.AutomaticSize.X
	titleLabel.Size = UDim2.fromOffset(0, 16)
	titleLabel.LayoutOrder = 2
	titleLabel.ZIndex = BASE_Z + 2
	titleLabel.Parent = titleRow
 
	local controls = Instance.new("Frame")
	controls.BackgroundTransparency = 1
	controls.AnchorPoint = Vector2.new(1, 0.5)
	controls.Position = UDim2.new(1, 0, 0.5, 0)
	controls.Size = UDim2.fromOffset(126, 22)
	controls.ZIndex = BASE_Z + 1
	controls.Parent = header
 
	local controlsLayout = Instance.new("UIListLayout")
	controlsLayout.FillDirection = Enum.FillDirection.Horizontal
	controlsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	controlsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	controlsLayout.Padding = UDim.new(0, 4)
	controlsLayout.Parent = controls
 
	local function headerIconButton(icon, layoutOrder)
		local btn = Instance.new("TextButton")
		btn.Text = ""
		btn.AutoButtonColor = false
		btn.BackgroundColor3 = Color3.new(1, 1, 1)
		btn.BackgroundTransparency = 1
		btn.BorderSizePixel = 0
		btn.Size = UDim2.fromOffset(22, 22)
		btn.LayoutOrder = layoutOrder
		btn.ZIndex = BASE_Z + 1
		btn.Parent = controls
		Corner(btn, 6)
 
		local ic = Instance.new("ImageLabel")
		ic.BackgroundTransparency = 1
		ic.Image = ResolveIcon(icon)
		ic.ImageColor3 = NullUI.Theme.TextDim
		ic.Size = UDim2.fromOffset(13, 13)
		ic.AnchorPoint = Vector2.new(0.5, 0.5)
		ic.Position = UDim2.fromScale(0.5, 0.5)
		ic.ZIndex = BASE_Z + 2
		ic.Parent = btn
 
		jan:Add(btn.MouseEnter:Connect(function()
			Tween(btn, { BackgroundTransparency = 0.9 }, 0.12)
			Tween(ic, { ImageColor3 = NullUI.Theme.Text }, 0.12)
		end))
		jan:Add(btn.MouseLeave:Connect(function()
			Tween(btn, { BackgroundTransparency = 1 }, 0.12)
			Tween(ic, { ImageColor3 = NullUI.Theme.TextDim }, 0.12)
		end))
 
		return btn, ic
	end
 
	local anonymousMode = opts.AnonymousByDefault ~= false
	local showTimestamps = true
	local notifySound = false
	local pollInterval = opts.PollInterval or 2.5
 
	local copyBtn, copyIcon = headerIconButton("copy", 1)
	local anonBtn, anonIcon = headerIconButton(anonymousMode and "eye-off" or "eye", 2)
	local clearBtn, clearIcon = headerIconButton("trash-2", 3)
	local settingsBtn, settingsIcon = headerIconButton("settings", 4)
	local closeBtn, closeIcon = headerIconButton("x", 5)
 
	local headerDivider = Instance.new("Frame")
	headerDivider.BackgroundColor3 = Color3.new(1, 1, 1)
	headerDivider.BackgroundTransparency = 0.94
	headerDivider.BorderSizePixel = 0
	headerDivider.Position = UDim2.fromOffset(0, HEADER_H)
	headerDivider.Size = UDim2.new(1, 0, 0, 1)
	headerDivider.ZIndex = BASE_Z
	headerDivider.Parent = content
 
	local contentPad = Instance.new("UIPadding")
	contentPad.PaddingLeft = UDim.new(0, 14)
	contentPad.PaddingRight = UDim.new(0, 14)
	contentPad.PaddingBottom = UDim.new(0, 12)
	contentPad.Parent = content
 
	local inputRow = Instance.new("Frame")
	inputRow.BackgroundTransparency = 1
	inputRow.Active = true
	inputRow.AnchorPoint = Vector2.new(0, 1)
	inputRow.Position = UDim2.new(0, 0, 1, 0)
	inputRow.Size = UDim2.new(1, 0, 0, INPUT_H)
	inputRow.ZIndex = BASE_Z
	inputRow.Parent = content
 
	local pill = Instance.new("Frame")
	pill.BackgroundColor3 = Color3.new(1, 1, 1)
	pill.BackgroundTransparency = 0.95
	pill.BorderSizePixel = 0
	pill.Size = UDim2.new(1, -(INPUT_H + 6), 1, 0)
	pill.ZIndex = BASE_Z + 1
	pill.Parent = inputRow
	Corner(pill, 9)
	local pillStroke = Stroke(pill, Color3.new(1, 1, 1), 1, 0.9)
 
	local pillPad = Instance.new("UIPadding")
	pillPad.PaddingLeft = UDim.new(0, 10)
	pillPad.PaddingRight = UDim.new(0, 10)
	pillPad.Parent = pill
 
	local inputBox = Instance.new("TextBox")
	inputBox.BackgroundTransparency = 1
	inputBox.ClearTextOnFocus = false
	inputBox.FontFace = NullUI.Theme.FontRegular
	inputBox.PlaceholderText = opts.Placeholder or "Message everyone using this script..."
	inputBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 122)
	inputBox.Text = ""
	inputBox.TextColor3 = NullUI.Theme.Text
	inputBox.TextSize = 13
	inputBox.TextXAlignment = Enum.TextXAlignment.Left
	inputBox.TextYAlignment = Enum.TextYAlignment.Center
	inputBox.ClipsDescendants = true
	inputBox.Size = UDim2.fromScale(1, 1)
	inputBox.ZIndex = BASE_Z + 2
	inputBox.Parent = pill
 
	jan:Add(inputBox.Focused:Connect(function()
		Tween(pillStroke, { Color = NullUI.Theme.Accent, Transparency = 0.3 }, 0.15)
	end))
	jan:Add(inputBox.FocusLost:Connect(function()
		Tween(pillStroke, { Color = Color3.new(1, 1, 1), Transparency = 0.9 }, 0.15)
	end))
 
	local sendBtn = Instance.new("TextButton")
	sendBtn.Text = ""
	sendBtn.AutoButtonColor = false
	sendBtn.BackgroundColor3 = Color3.new(1, 1, 1)
	sendBtn.BackgroundTransparency = 0.9
	sendBtn.BorderSizePixel = 0
	sendBtn.AnchorPoint = Vector2.new(1, 0)
	sendBtn.Position = UDim2.new(1, 0, 0, 0)
	sendBtn.Size = UDim2.fromOffset(INPUT_H, INPUT_H)
	sendBtn.ZIndex = BASE_Z + 1
	sendBtn.Parent = inputRow
	Corner(sendBtn, 9)
 
	local sendIcon = Instance.new("ImageLabel")
	sendIcon.BackgroundTransparency = 1
	sendIcon.Image = ResolveIcon("send")
	sendIcon.ImageColor3 = NullUI.Theme.Text
	sendIcon.Size = UDim2.fromOffset(14, 14)
	sendIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	sendIcon.Position = UDim2.fromScale(0.5, 0.5)
	sendIcon.ZIndex = BASE_Z + 2
	sendIcon.Parent = sendBtn
 
	jan:Add(sendBtn.MouseEnter:Connect(function() Tween(sendBtn, { BackgroundTransparency = 0.8 }, 0.12) end))
	jan:Add(sendBtn.MouseLeave:Connect(function() Tween(sendBtn, { BackgroundTransparency = 0.9 }, 0.12) end))
 
	local msgScroll = Instance.new("ScrollingFrame")
	msgScroll.BackgroundTransparency = 1
	msgScroll.BorderSizePixel = 0
	msgScroll.Position = UDim2.fromOffset(0, HEADER_H + 9)
	msgScroll.Size = UDim2.new(1, 0, 1, -(HEADER_H + 9 + INPUT_H + 10))
	msgScroll.ScrollingDirection = Enum.ScrollingDirection.Y
	msgScroll.ScrollBarThickness = 0
	msgScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	msgScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	msgScroll.ZIndex = BASE_Z
	msgScroll.Parent = content
 
	local msgPad = Instance.new("UIPadding")
	msgPad.PaddingRight = UDim.new(0, 18)
	msgPad.Parent = msgScroll
 
	local msgLayout = Instance.new("UIListLayout")
	msgLayout.Padding = UDim.new(0, 8)
	msgLayout.SortOrder = Enum.SortOrder.LayoutOrder
	msgLayout.Parent = msgScroll
 
	AddScrollbar(msgScroll)
	AddContentScrollThumb(msgScroll, msgLayout, panel, jan)
 
	local order = 0
	local transcript = {}
	local timestampLabels = {}
	local pinnedToBottom = true
	jan:Add(msgScroll:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(function()
		if pinnedToBottom then
			msgScroll.CanvasPosition = Vector2.new(0, msgScroll.AbsoluteCanvasSize.Y)
		end
	end))
	jan:Add(msgScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		local atBottom = msgScroll.CanvasPosition.Y
			>= msgScroll.AbsoluteCanvasSize.Y - msgScroll.AbsoluteWindowSize.Y - 20
		pinnedToBottom = atBottom
	end))
 
	local function scrollToBottom()
		pinnedToBottom = true
		task.defer(function()
			if msgScroll and msgScroll.Parent then
				msgScroll.CanvasPosition = Vector2.new(0, msgScroll.AbsoluteCanvasSize.Y)
			end
		end)
	end
 
	local AVATAR = 26
 
	local function addBubble(msg, isOwn)
		order = order + 1
		local text = tostring(msg.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if text == "" then return end
 
		local row = Instance.new("Frame")
		row.Name = "ChatRow"
		row.BackgroundTransparency = 1
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.Size = UDim2.new(1, 0, 0, 0)
		row.LayoutOrder = order
		row.ZIndex = BASE_Z + 1
		row.Parent = msgScroll
 
		local rowScale = Instance.new("UIScale")
		rowScale.Scale = 0.92
		rowScale.Parent = row
 
		local rowLayout = Instance.new("UIListLayout")
		rowLayout.FillDirection = Enum.FillDirection.Horizontal
		rowLayout.HorizontalAlignment = isOwn and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left
		rowLayout.VerticalAlignment = Enum.VerticalAlignment.Top
		rowLayout.Padding = UDim.new(0, 8)
		rowLayout.Parent = row
 
		local isAnon = not msg.UserId or msg.UserId == 0
 
		local avatar = Instance.new("Frame")
		avatar.Name = "Avatar"
 
		avatar.BackgroundColor3 = isAnon and Color3.fromRGB(196, 143, 105) or NullUI.Theme.Accent
		avatar.BackgroundTransparency = 1
		avatar.BorderSizePixel = 0
		avatar.Size = UDim2.fromOffset(AVATAR, AVATAR)
		avatar.LayoutOrder = isOwn and 2 or 1
		avatar.ZIndex = BASE_Z + 2
		avatar.Parent = row
		Corner(avatar, AVATAR / 2)
 
		if isAnon then
			local anonIconImg = Instance.new("ImageLabel")
			anonIconImg.BackgroundTransparency = 1
			anonIconImg.ImageTransparency = 1
			anonIconImg.Image = ResolveIcon("user-round")
			anonIconImg.ImageColor3 = Color3.fromRGB(90, 61, 40)
			anonIconImg.Size = UDim2.fromOffset(15, 15)
			anonIconImg.AnchorPoint = Vector2.new(0.5, 0.5)
			anonIconImg.Position = UDim2.fromScale(0.5, 0.5)
			anonIconImg.ZIndex = BASE_Z + 3
			anonIconImg.Parent = avatar
			Tween(anonIconImg, { ImageTransparency = 0 }, 0.16)
		else
			local avatarImg = Instance.new("ImageLabel")
			avatarImg.BackgroundTransparency = 1
			avatarImg.ImageTransparency = 1
			avatarImg.ScaleType = Enum.ScaleType.Crop
			avatarImg.Size = UDim2.fromScale(1, 1)
			avatarImg.ZIndex = BASE_Z + 3
			avatarImg.Parent = avatar
			Corner(avatarImg, AVATAR / 2)
			Tween(avatarImg, { ImageTransparency = 0 }, 0.16)
			task.spawn(function()
				local ok, content = pcall(
					Players.GetUserThumbnailAsync,
					Players,
					msg.UserId,
					Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size100x100
				)
				if ok and content and avatarImg.Parent then
					avatarImg.Image = content
				end
			end)
		end
 
		local H_PAD, V_PAD = 10, 8
		local BUBBLE_MAX_WIDTH = 240
 
		local MIN_BUBBLE_WIDTH = 64
		local naturalW = MeasureText(text, 13, 10000)
		local bubbleWidth = math.min(naturalW, BUBBLE_MAX_WIDTH - H_PAD * 2) + H_PAD * 2
		bubbleWidth = math.max(bubbleWidth, MIN_BUBBLE_WIDTH)
		if msgScroll.AbsoluteSize.X > 0 then
			bubbleWidth = math.min(bubbleWidth, math.max(160, msgScroll.AbsoluteSize.X - 20))
		end
 
		local bubble = Instance.new("Frame")
		bubble.Name = "Bubble"
		bubble.BackgroundColor3 = isOwn and NullUI.Theme.Accent or Color3.new(1, 1, 1)
		bubble.BackgroundTransparency = 1
		bubble.BorderSizePixel = 0
		bubble.ClipsDescendants = true
		bubble.AutomaticSize = Enum.AutomaticSize.Y
		bubble.Size = UDim2.fromOffset(bubbleWidth, 0)
		bubble.LayoutOrder = isOwn and 1 or 2
		bubble.ZIndex = BASE_Z + 2
		bubble.Parent = row
		Corner(bubble, 12)
		local bubbleStroke = Stroke(bubble, Color3.new(1, 1, 1), 1, 1)
 
		local bubblePad = Instance.new("UIPadding")
		bubblePad.PaddingTop = UDim.new(0, V_PAD)
		bubblePad.PaddingBottom = UDim.new(0, V_PAD)
		bubblePad.PaddingLeft = UDim.new(0, H_PAD)
		bubblePad.PaddingRight = UDim.new(0, H_PAD)
		bubblePad.Parent = bubble
 
		local bubbleLayout = Instance.new("UIListLayout")
		bubbleLayout.SortOrder = Enum.SortOrder.LayoutOrder
		bubbleLayout.Parent = bubble
 
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.FontFace = NullUI.Theme.FontRegular
		label.Text = text
		label.TextColor3 = NullUI.Theme.Text
		label.TextTransparency = 1
		label.TextSize = 13
		label.TextWrapped = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.LineHeight = 1.3
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.Size = UDim2.new(1, 0, 0, 16)
		label.LayoutOrder = 1
		label.ZIndex = BASE_Z + 3
		label.Parent = bubble
 
		if msg.CreatedAt then
			local timeLbl = Instance.new("TextLabel")
			timeLbl.BackgroundTransparency = 1
			timeLbl.FontFace = NullUI.Theme.FontRegular
			timeLbl.Text = os.date("%H:%M", math.floor(msg.CreatedAt / 1000))
			timeLbl.TextColor3 = isOwn and Color3.new(1, 1, 1) or NullUI.Theme.TextDim
			timeLbl.TextTransparency = isOwn and 0.5 or 0.4
			timeLbl.TextSize = 10
			timeLbl.TextXAlignment = Enum.TextXAlignment.Left
			timeLbl.AutomaticSize = Enum.AutomaticSize.Y
			timeLbl.Size = UDim2.new(1, 0, 0, 12)
			timeLbl.LayoutOrder = 2
			timeLbl.ZIndex = BASE_Z + 3
 
			timeLbl.Visible = showTimestamps
			timeLbl.Parent = bubble
			table.insert(timestampLabels, timeLbl)
		end
 
		if not isOwn and msg.Id and service then
			local reportBtn = Instance.new("TextButton")
			reportBtn.Text = ""
			reportBtn.AutoButtonColor = false
			reportBtn.BackgroundColor3 = Color3.new(1, 1, 1)
			reportBtn.BackgroundTransparency = 1
			reportBtn.BorderSizePixel = 0
			reportBtn.Size = UDim2.fromOffset(20, 20)
			reportBtn.LayoutOrder = 3
			reportBtn.ZIndex = BASE_Z + 2
			reportBtn.Parent = row
			Corner(reportBtn, 6)
 
			local reportIcon = Instance.new("ImageLabel")
			reportIcon.BackgroundTransparency = 1
			reportIcon.ImageTransparency = 1
			reportIcon.Image = ResolveIcon("flag")
			reportIcon.ImageColor3 = NullUI.Theme.TextDim
			reportIcon.Size = UDim2.fromOffset(11, 11)
			reportIcon.AnchorPoint = Vector2.new(0.5, 0.5)
			reportIcon.Position = UDim2.fromScale(0.5, 0.5)
			reportIcon.ZIndex = BASE_Z + 3
			reportIcon.Parent = reportBtn
 
			jan:Add(row.MouseEnter:Connect(function()
				Tween(reportIcon, { ImageTransparency = 0.3 }, 0.12)
			end))
			jan:Add(row.MouseLeave:Connect(function()
				Tween(reportIcon, { ImageTransparency = 1 }, 0.12)
			end))
			jan:Add(reportBtn.MouseEnter:Connect(function()
				Tween(reportBtn, { BackgroundTransparency = 0.88 }, 0.1)
				Tween(reportIcon, { ImageColor3 = NullUI.Theme.Danger, ImageTransparency = 0 }, 0.1)
			end))
			jan:Add(reportBtn.MouseLeave:Connect(function()
				Tween(reportBtn, { BackgroundTransparency = 1 }, 0.1)
				Tween(reportIcon, { ImageColor3 = NullUI.Theme.TextDim }, 0.1)
			end))
			jan:Add(reportBtn.MouseButton1Click:Connect(function()
				NullUI:Confirm({
					Title = "Report this message?",
					Text  = "Hides it for everyone once enough people report it.",
					ConfirmText = "Report",
					CancelText  = "Cancel",
					Danger = true,
					Window = self,
					Callback = function(confirmed)
						if not confirmed then return end
						local ok, err = service:ReportChatMessage(msg.Id)
						NullUI:Notify({
							Title = ok and "Reported" or "Could not report",
							Text  = ok and "Thanks -- our filters will take it from here." or tostring(err),
							Type  = ok and "success" or "error",
							Duration = 3,
						})
					end,
				})
			end))
		end
 
		local avatarFinalTransparency = isOwn and 0.85 or 0.82
		local bubbleFinalTransparency = isOwn and 0.72 or 0.9
		local strokeFinalTransparency = isOwn and 0.8 or 0.9
		Tween(avatar, { BackgroundTransparency = avatarFinalTransparency }, 0.16)
		Tween(bubble, { BackgroundTransparency = bubbleFinalTransparency }, 0.16)
		Tween(bubbleStroke, { Transparency = strokeFinalTransparency }, 0.16)
		Tween(label, { TextTransparency = 0 }, 0.16)
		Tween(rowScale, { Scale = 1 }, 0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
 
		scrollToBottom()
		table.insert(transcript, (isOwn and "You" or "Someone") .. ": " .. text)
	end
 
	jan:Add(copyBtn.MouseButton1Click:Connect(function()
		local setclipboard = hasFn("setclipboard")
		if not setclipboard or #transcript == 0 then return end
		pcall(setclipboard, table.concat(transcript, "\n"))
		Tween(copyIcon, { ImageColor3 = Color3.fromRGB(120, 220, 140) }, 0.1)
		task.delay(0.4, function()
			if copyIcon.Parent then
				Tween(copyIcon, { ImageColor3 = NullUI.Theme.TextDim }, 0.15)
			end
		end)
	end))
 
	local seenIds = { [0] = true }
	local lastSeenId = 0
 
	local function trySend()
		local text = inputBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
		if text == "" or not service then return end
		inputBox.Text = ""
		local sendUserId = anonymousMode and 0 or LocalPlayer.UserId
		task.spawn(function()
			local result, err = service:SendChatMessage(sendUserId, text)
			if not result then
				NullUI:Notify({ Title = "Chat", Text = tostring(err), Type = "error", Duration = 3 })
				return
			end
			seenIds[result.Id] = true
			if result.Id > lastSeenId then lastSeenId = result.Id end
			addBubble({ UserId = sendUserId, Text = text, CreatedAt = os.time() * 1000 }, true)
		end)
	end
 
	jan:Add(sendBtn.MouseButton1Click:Connect(trySend))
	jan:Add(inputBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then trySend() end
	end))
	jan:Add(anonBtn.MouseButton1Click:Connect(function()
		anonymousMode = not anonymousMode
		anonIcon.Image = ResolveIcon(anonymousMode and "eye-off" or "eye")
		NullUI:Notify({
			Title = "Chat",
			Text  = anonymousMode
				and "Anonymous mode on -- new messages won't reveal your avatar."
				or "Anonymous mode off -- new messages show your avatar.",
			Type  = "info",
			Duration = 3,
		})
	end))
	jan:Add(clearBtn.MouseButton1Click:Connect(function()
 
		for _, child in ipairs(msgScroll:GetChildren()) do
			if child.Name == "ChatRow" then child:Destroy() end
		end
		table.clear(transcript)
		table.clear(timestampLabels)
	end))
	jan:Add(closeBtn.MouseButton1Click:Connect(function()
		if self._currentTab == tabObj then
			if self._tabs[1] and self._tabs[1] ~= tabObj then self._tabs[1]._select() end
		end
	end))
 
	local settingsPopup
	local function closeSettingsPopup()
		if settingsPopup then
			settingsPopup:Destroy()
			settingsPopup = nil
		end
	end
 
	local function openSettingsPopup()
		if settingsPopup then closeSettingsPopup(); return end
 
		local popup = Instance.new("Frame")
		popup.Name = "ChatSettingsPopup"
		popup.BackgroundColor3 = NullUI.Theme.Surface
		popup.BackgroundTransparency = 0.05
		popup.BorderSizePixel = 0
		popup.AnchorPoint = Vector2.new(1, 0)
		popup.Position = UDim2.new(1, 0, 0, HEADER_H + 4)
		popup.Size = UDim2.new(0, 190, 0, 0)
		popup.AutomaticSize = Enum.AutomaticSize.Y
		popup.ClipsDescendants = true
		popup.ZIndex = BASE_Z + 10
		popup.Parent = panel
		Corner(popup, 10)
		local popupStroke = Stroke(popup, Color3.new(1, 1, 1), 1, 0.88)
 
		local popupPad = Instance.new("UIPadding")
		popupPad.PaddingTop = UDim.new(0, 10)
		popupPad.PaddingBottom = UDim.new(0, 10)
		popupPad.PaddingLeft = UDim.new(0, 12)
		popupPad.PaddingRight = UDim.new(0, 12)
		popupPad.Parent = popup
 
		local popupLayout = Instance.new("UIListLayout")
		popupLayout.Padding = UDim.new(0, 8)
		popupLayout.SortOrder = Enum.SortOrder.LayoutOrder
		popupLayout.Parent = popup
 
		local function toggleRow(order, label, getValue, onToggle)
			local row = Instance.new("Frame")
			row.BackgroundTransparency = 1
			row.Size = UDim2.new(1, 0, 0, 20)
			row.LayoutOrder = order
			row.ZIndex = BASE_Z + 11
			row.Parent = popup
 
			local lbl = Instance.new("TextLabel")
			lbl.BackgroundTransparency = 1
			lbl.FontFace = NullUI.Theme.FontRegular
			lbl.Text = label
			lbl.TextColor3 = NullUI.Theme.Text
			lbl.TextSize = 12
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Size = UDim2.new(1, -30, 1, 0)
			lbl.ZIndex = BASE_Z + 12
			lbl.Parent = row
 
			local check = Instance.new("TextButton")
			check.Text = ""
			check.AutoButtonColor = false
			check.BackgroundColor3 = Color3.new(1, 1, 1)
			check.BackgroundTransparency = getValue() and 0.7 or 0.92
			check.BorderSizePixel = 0
			check.AnchorPoint = Vector2.new(1, 0.5)
			check.Position = UDim2.new(1, 0, 0.5, 0)
			check.Size = UDim2.fromOffset(20, 20)
			check.ZIndex = BASE_Z + 12
			check.Parent = row
			Corner(check, 6)
 
			local checkIcon = Instance.new("ImageLabel")
			checkIcon.BackgroundTransparency = 1
			checkIcon.Image = ResolveIcon("check")
			checkIcon.ImageColor3 = NullUI.Theme.Accent
			checkIcon.ImageTransparency = getValue() and 0 or 1
			checkIcon.Size = UDim2.fromOffset(11, 11)
			checkIcon.AnchorPoint = Vector2.new(0.5, 0.5)
			checkIcon.Position = UDim2.fromScale(0.5, 0.5)
			checkIcon.ZIndex = BASE_Z + 13
			checkIcon.Parent = check
 
			jan:Add(check.MouseButton1Click:Connect(function()
				local newValue = onToggle()
				Tween(check, { BackgroundTransparency = newValue and 0.7 or 0.92 }, 0.12)
				Tween(checkIcon, { ImageTransparency = newValue and 0 or 1 }, 0.12)
			end))
		end
 
		toggleRow(1, "Show timestamps", function() return showTimestamps end, function()
			showTimestamps = not showTimestamps
			for _, lbl in ipairs(timestampLabels) do
				if lbl.Parent then lbl.Visible = showTimestamps end
			end
			return showTimestamps
		end)
		toggleRow(2, "Sound on new message", function() return notifySound end, function()
			notifySound = not notifySound
			return notifySound
		end)
		toggleRow(3, "Fast updates (1s)", function() return pollInterval <= 1 end, function()
			pollInterval = (pollInterval <= 1) and (opts.PollInterval or 2.5) or 1
			return pollInterval <= 1
		end)
 
		settingsPopup = popup
	end
 
	jan:Add(settingsBtn.MouseButton1Click:Connect(function()
		if settingsPopup then closeSettingsPopup() else openSettingsPopup() end
	end))
 
	local notifySoundInstance = Instance.new("Sound")
	notifySoundInstance.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	notifySoundInstance.Volume = 0.5
	notifySoundInstance.Parent = panel
 
	if service then
		task.spawn(function()
			local backlog = service:PollChatMessages(0)
			if backlog then
				local historyLimit = opts.HistoryLimit or 3
				local startIdx = math.max(1, #backlog - historyLimit + 1)
				for i = startIdx, #backlog do
					local m = backlog[i]
					if not seenIds[m.Id] then
						seenIds[m.Id] = true
						addBubble(m, m.UserId == LocalPlayer.UserId)
					end
					if m.Id > lastSeenId then lastSeenId = m.Id end
				end
			end
			while panel and panel.Parent do
				task.wait(pollInterval)
				local newMsgs = service:PollChatMessages(lastSeenId)
				if newMsgs then
					for _, m in ipairs(newMsgs) do
						if not seenIds[m.Id] then
							seenIds[m.Id] = true
							local isOwn = m.UserId == LocalPlayer.UserId
							addBubble(m, isOwn)
 
							if notifySound and not isOwn and notifySoundInstance.Parent then
								notifySoundInstance:Play()
							end
						end
						if m.Id > lastSeenId then lastSeenId = m.Id end
					end
				end
			end
		end)
	end
 
	local lastRealTab = nil
	local function openPanel()
		if self._currentTab == tabObj then return end
		if self._currentTab and not self._currentTab.Hidden then
			lastRealTab = self._currentTab
		end
		tabObj._select()
	end
	local function closePanel()
		if self._currentTab ~= tabObj then return end
		if lastRealTab and not lastRealTab.Hidden then
			lastRealTab._select()
		elseif self._tabs[1] and self._tabs[1] ~= tabObj then
			self._tabs[1]._select()
		end
	end
 
	return {
		Instance = panel,
		Tab = tabObj,
		Open = openPanel,
		Close = closePanel,
		Toggle = function()
			if self._currentTab == tabObj then closePanel() else openPanel() end
		end,
		IsOpen = function() return self._currentTab == tabObj end,
		Destroy = function() panel:Destroy() end,
	}
end
 
local TRANSITION_EXIT  = 0.18
local TRANSITION_GAP   = 0.08
local TRANSITION_ENTER = 0.32
 
function Window:AddTab(nameOrOpts)
	local opts = type(nameOrOpts) == "table" and nameOrOpts or { Name = nameOrOpts }
	local name = opts.Name or opts.Title or "Tab"
	local iconAsset = opts.Icon and ResolveIcon(opts.Icon) or nil
	local hasIcon = iconAsset ~= nil and iconAsset ~= ""
	local jan = self._janitor
 
	local hidden = opts.Hidden == true
 
	local tabButton = Instance.new("TextButton")
	tabButton.Name = name
	tabButton.Text = ""
	tabButton.AutoButtonColor = false
	tabButton.BackgroundColor3 = Color3.new(1, 1, 1)
	tabButton.BackgroundTransparency = 1
	tabButton.BorderSizePixel = 0
	tabButton.Size = UDim2.new(1, 0, 0, 34)
	tabButton.ZIndex = Z.Content
	if not hidden then
		tabButton.Parent = self._tabBar
	end
	Corner(tabButton, 10)
 
	local isPrivate = opts.Password ~= nil and opts.Password ~= ""
	local remembered = isPrivate and IsPrivateTabRemembered(name)
	local unlocked = not isPrivate or remembered
	local glowColor = opts.GlowColor or NullUI.Theme.Accent
	local glowStroke, lockBadge, glowPulse
 
	if isPrivate then
		glowStroke = Stroke(tabButton, glowColor, 1, remembered and 0.9 or 0.82)
 
		if not remembered then
			glowPulse = TweenService:Create(
				glowStroke,
				TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Transparency = 0.94 }
			)
			glowPulse:Play()
		end
	end
 
	if isPrivate and not remembered then
		lockBadge = Instance.new("Frame")
		lockBadge.Name = "LockBadge"
		lockBadge.BackgroundColor3 = NullUI.Theme.Background
		lockBadge.BackgroundTransparency = 0
		lockBadge.BorderSizePixel = 0
		lockBadge.Size = UDim2.fromOffset(13, 13)
		lockBadge.AnchorPoint = Vector2.new(1, 0)
		lockBadge.Position = UDim2.new(1, -2, 0, -3)
		lockBadge.ZIndex = Z.Content + 3
		lockBadge.Parent = tabButton
		Corner(lockBadge, 7)
		Stroke(lockBadge, glowColor, 1, 0.7)
 
		local lockIcon = Instance.new("ImageLabel")
		lockIcon.BackgroundTransparency = 1
		lockIcon.Image = ResolveIcon("lock")
		lockIcon.ImageColor3 = glowColor
		lockIcon.Size = UDim2.fromOffset(7, 7)
		lockIcon.AnchorPoint = Vector2.new(0.5, 0.5)
		lockIcon.Position = UDim2.fromScale(0.5, 0.5)
		lockIcon.ZIndex = Z.Content + 4
		lockIcon.Parent = lockBadge
	end
 
	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 1)
	row.ZIndex = Z.Content
	row.Parent = tabButton
 
	local rowPad = Instance.new("UIPadding")
	rowPad.PaddingLeft = UDim.new(0, 12)
	rowPad.PaddingRight = UDim.new(0, 12)
	rowPad.Parent = row
 
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	rowLayout.Padding = UDim.new(0, 10)
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Parent = row
 
	local iconLabel
	if hasIcon then
		iconLabel = Instance.new("ImageLabel")
		iconLabel.Name = "Icon"
		iconLabel.BackgroundTransparency = 1
		iconLabel.Image = iconAsset
		iconLabel.ImageColor3 = NullUI.Theme.TextDim
		iconLabel.Size = UDim2.fromOffset(16, 16)
		iconLabel.LayoutOrder = 1
		iconLabel.ZIndex = Z.Content + 1
		iconLabel.Parent = row
	end
 
	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "Label"
	textLabel.BackgroundTransparency = 1
	textLabel.FontFace = NullUI.Theme.Font
	textLabel.Text = name
	textLabel.TextColor3 = NullUI.Theme.TextDim
	textLabel.TextSize = 14
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.TextTruncate = Enum.TextTruncate.AtEnd
	textLabel.Size = UDim2.new(1, hasIcon and -26 or 0, 1, 0)
	textLabel.LayoutOrder = 2
	textLabel.ZIndex = Z.Content + 1
	textLabel.Parent = row
 
	local pageGroup = Instance.new("CanvasGroup")
	pageGroup.Name = name .. "Group"
	pageGroup.BackgroundTransparency = 1
	pageGroup.Size = UDim2.fromScale(1, 1)
	pageGroup.GroupTransparency = 0
	pageGroup.Visible = false
	pageGroup.ZIndex = Z.Content
	pageGroup.Parent = self._content
 
	local page = Instance.new("ScrollingFrame")
	page.Name = name .. "Page"
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.Size = UDim2.fromScale(1, 1)
	page.ScrollingDirection = Enum.ScrollingDirection.Y
	page.ScrollBarThickness = 0
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.CanvasSize = UDim2.new(0, 0, 0, 0)
	page.ZIndex = Z.Content
	page.Parent = pageGroup
 
	local pagePad = Instance.new("UIPadding")
	pagePad.Name = "PagePadding"
	pagePad.PaddingRight = UDim.new(0, 12)
	pagePad.PaddingBottom = UDim.new(0, 6)
	pagePad.Parent = page
 
	local pageLayout = Instance.new("UIListLayout")
	pageLayout.Name = "PageLayout"
	pageLayout.Padding = UDim.new(0, 8)
	pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
	pageLayout.Parent = page
 
	AddScrollbar(page)
	AddContentScrollThumb(page, pageLayout, pageGroup, jan)
	AddEmptyState(page, pageGroup, jan)
 
	local tabObj = setmetatable({
		Name      = name,
		_page     = page,
		_group    = pageGroup,
		_button   = tabButton,
		_icon     = iconLabel,
		_label    = textLabel,
		_window   = self,
		_janitor  = jan,
		_password = opts.Password,
	}, Tab)
 
	local myIndex = #self._tabs + 1
 
	local function indicatorY()
		return (tabButton.AbsolutePosition.Y - self._tabBar.AbsolutePosition.Y) / GetUIScale()
	end
 
	local function selectTab()
		if self._currentTab == tabObj then return end
 
		self._tabSwitchToken = (self._tabSwitchToken or 0) + 1
		local myToken = self._tabSwitchToken
 
		local direction = 0
		if self._currentIndex then
			direction = (myIndex > self._currentIndex) and 1 or -1
		end
		self._currentIndex = myIndex
 
		local previousTab = self._currentTab
		self._currentTab = tabObj
		for _, fn in ipairs(self._tabChangeListeners) do
			task.spawn(fn, tabObj)
		end
 
		for _, t in pairs(self._tabs) do
			local isSelected = (t == tabObj)
			Tween(t._label, { TextColor3 = isSelected and NullUI.Theme.Text or NullUI.Theme.TextDim }, 0.22)
			if t._icon then
				Tween(t._icon, { ImageColor3 = isSelected and NullUI.Theme.Text or NullUI.Theme.TextDim }, 0.22)
			end
			if not isSelected then
				Tween(t._button, { BackgroundTransparency = 1 }, 0.15)
			end
		end
 
		if hidden then
			Tween(self._tabIndicator, { BackgroundTransparency = 1 }, 0.15)
		else
			Tween(self._tabIndicator, {
				Position = UDim2.new(0, 0, 0, indicatorY()),
				BackgroundTransparency = 0.88,
			}, 0.38, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		end
 
		for _, t in pairs(self._tabs) do
			if t ~= tabObj and t ~= previousTab and t._group.Visible then
				t._group.Visible = false
			end
		end
 
		local function playEnter()
			if self._tabSwitchToken ~= myToken then return end
			pageGroup.Visible = true
			pageGroup.GroupTransparency = 1
			pageGroup.Position = UDim2.fromOffset(direction * 20, 0)
			Tween(pageGroup, {
				GroupTransparency = 0,
				Position = UDim2.fromOffset(0, 0),
			}, TRANSITION_ENTER, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		end
 
		if previousTab and previousTab._group.Visible then
			local g = previousTab._group
			Tween(g, {
				GroupTransparency = 1,
				Position = UDim2.fromOffset(-direction * 20, 0),
			}, TRANSITION_EXIT, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
			task.delay(TRANSITION_EXIT, function()
				if g then g.Visible = false end
				task.delay(TRANSITION_GAP, playEnter)
			end)
		else
			playEnter()
		end
	end
 
	local promptOpen = false
	local function guardedSelect()
		if isPrivate and not unlocked then
			if promptOpen then return end
			promptOpen = true
			self:_PromptTabPassword(tabObj, function(success, remember)
				promptOpen = false
				if not success then return end
				SetPrivateTabRemembered(tabObj.Name, remember == true)
				unlocked = true
				tabObj.Unlocked = true
				if glowPulse then glowPulse:Cancel() end
				if glowStroke then Tween(glowStroke, { Transparency = 0.9 }, 0.4) end
				if lockBadge then
					Tween(lockBadge, { BackgroundTransparency = 1 }, 0.25)
					task.delay(0.25, function()
						if lockBadge then lockBadge:Destroy(); lockBadge = nil end
					end)
				end
				selectTab()
			end)
			return
		end
		selectTab()
	end
 
	tabObj._select = guardedSelect
	tabObj.IsPrivate = isPrivate
	tabObj.Unlocked = unlocked
	tabObj.Hidden = hidden
 
	if not hidden then
		jan:Add(tabButton:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
			if self._currentTab == tabObj then
				self._tabIndicator.Position = UDim2.new(0, 0, 0, indicatorY())
			end
		end))
 
		jan:Add(tabButton.MouseButton1Click:Connect(guardedSelect))
 
		jan:Add(tabButton.MouseEnter:Connect(function()
			if self._currentTab ~= tabObj then
				Tween(tabButton, { BackgroundTransparency = 0.95 }, 0.15)
			end
		end))
		jan:Add(tabButton.MouseLeave:Connect(function()
			if self._currentTab ~= tabObj then
				Tween(tabButton, { BackgroundTransparency = 1 }, 0.15)
			end
		end))
	end
 
	table.insert(self._tabs, tabObj)
	if not hidden then
 
		self._visibleTabCount = (self._visibleTabCount or 0) + 1
		if self._visibleTabCount == 1 then
			guardedSelect()
		end
		if self._defaultTabName and name == self._defaultTabName then
			guardedSelect()
		end
	end
 
	return tabObj
end
 
function Window:AddPrivateTab(opts)
	opts = type(opts) == "table" and opts or { Name = opts }
	assert(opts.Password and opts.Password ~= "", "AddPrivateTab requires opts.Password")
	return self:AddTab(opts)
end
 
function Window:_PromptTabPassword(tabObj, callback)
	local root = NullUI._Root
	local jan = Janitor.new()
	local closed = false
	local settled = false
 
	local backdrop = Instance.new("TextButton")
	backdrop.Name = "TabPasswordBackdrop"
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 1
	backdrop.BorderSizePixel = 0
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.ZIndex = Z.Modal
	backdrop.Parent = root
 
	local dialog = Instance.new("Frame")
	dialog.Name = "TabPasswordDialog"
	dialog.AnchorPoint = Vector2.new(0.5, 0.5)
	do
		local cx, cy = ComputeDialogCenter(self._gui)
		local s = GetUIScale()
		dialog.Position = UDim2.fromOffset(math.round(cx / s), math.round(cy / s))
	end
	dialog.BackgroundColor3 = NullUI.Theme.Background
	dialog.BackgroundTransparency = 1
	dialog.BorderSizePixel = 0
	dialog.ClipsDescendants = true
	dialog.AutomaticSize = Enum.AutomaticSize.Y
	dialog.Size = UDim2.new(0, 300, 0, 0)
	dialog.ZIndex = Z.ModalTop
	dialog.Parent = backdrop
	Corner(dialog, 14)
	local dialogStroke = Stroke(dialog, Color3.new(1, 1, 1), 1, 0.9)
 
	local scale = Instance.new("UIScale")
	scale.Scale = 0.94
	scale.Parent = dialog
 
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 18)
	pad.PaddingBottom = UDim.new(0, 18)
	pad.PaddingLeft = UDim.new(0, 18)
	pad.PaddingRight = UDim.new(0, 18)
	pad.Parent = dialog
 
	local dialogLayout = Instance.new("UIListLayout")
	dialogLayout.Padding = UDim.new(0, 8)
	dialogLayout.SortOrder = Enum.SortOrder.LayoutOrder
	dialogLayout.Parent = dialog
 
	local header = Instance.new("Frame")
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 20)
	header.LayoutOrder = 1
	header.ZIndex = Z.ModalTop + 1
	header.Parent = dialog
 
	local lockIcon = Instance.new("ImageLabel")
	lockIcon.BackgroundTransparency = 1
	lockIcon.Image = ResolveIcon("lock")
	lockIcon.ImageColor3 = NullUI.Theme.TextDim
	lockIcon.Size = UDim2.fromOffset(18, 18)
	lockIcon.Position = UDim2.fromOffset(0, 0)
	lockIcon.ZIndex = Z.ModalTop + 2
	lockIcon.Parent = header
 
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.FontFace = NullUI.Theme.Font
	title.Text = "Private Tab"
	title.TextColor3 = NullUI.Theme.Text
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Size = UDim2.new(1, -26, 1, 0)
	title.Position = UDim2.fromOffset(26, 0)
	title.ZIndex = Z.ModalTop + 2
	title.Parent = header
 
	local subtitle = Instance.new("TextLabel")
	subtitle.BackgroundTransparency = 1
	subtitle.FontFace = NullUI.Theme.FontRegular
	subtitle.Text = ("Enter the password to unlock \"%s\""):format(tabObj.Name or "")
	subtitle.TextColor3 = NullUI.Theme.TextDim
	subtitle.TextSize = 12
	subtitle.TextWrapped = true
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.TextYAlignment = Enum.TextYAlignment.Top
	subtitle.AutomaticSize = Enum.AutomaticSize.Y
	subtitle.Size = UDim2.new(1, 0, 0, 0)
	subtitle.LayoutOrder = 2
	subtitle.ZIndex = Z.ModalTop + 1
	subtitle.Parent = dialog
 
	local fieldHolder = Instance.new("Frame")
	fieldHolder.BackgroundColor3 = Color3.new(1, 1, 1)
	fieldHolder.BackgroundTransparency = 0.94
	fieldHolder.BorderSizePixel = 0
	fieldHolder.ClipsDescendants = true
	fieldHolder.Size = UDim2.new(1, 0, 0, 36)
	fieldHolder.LayoutOrder = 3
	fieldHolder.ZIndex = Z.ModalTop + 1
	fieldHolder.Parent = dialog
	Corner(fieldHolder, 8)
	local fieldStroke = Stroke(fieldHolder, Color3.new(1, 1, 1), 1, 0.88)
 
	local box = Instance.new("TextBox")
	box.BackgroundTransparency = 1
	box.FontFace = NullUI.Theme.FontRegular
	box.PlaceholderText = ""
	box.Text = ""
	box.TextColor3 = NullUI.Theme.Text
	box.TextTransparency = 1
	box.TextSize = 14
	box.ClearTextOnFocus = false
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.Position = UDim2.fromOffset(10, 0)
	box.Size = UDim2.new(1, -20, 1, 0)
	box.ZIndex = Z.ModalTop + 2
	box.Parent = fieldHolder
 
	local maskLabel = Instance.new("TextLabel")
	maskLabel.BackgroundTransparency = 1
	maskLabel.FontFace = NullUI.Theme.FontRegular
	maskLabel.Text = ""
	maskLabel.TextColor3 = NullUI.Theme.Text
	maskLabel.TextSize = 14
	maskLabel.TextXAlignment = Enum.TextXAlignment.Left
	maskLabel.Position = box.Position
	maskLabel.Size = box.Size
	maskLabel.ZIndex = box.ZIndex + 1
	maskLabel.Parent = fieldHolder
 
	local placeholderLabel = Instance.new("TextLabel")
	placeholderLabel.BackgroundTransparency = 1
	placeholderLabel.FontFace = NullUI.Theme.FontRegular
	placeholderLabel.Text = "Password"
	placeholderLabel.TextColor3 = NullUI.Theme.TextDim
	placeholderLabel.TextSize = 14
	placeholderLabel.TextXAlignment = Enum.TextXAlignment.Left
	placeholderLabel.Position = box.Position
	placeholderLabel.Size = box.Size
	placeholderLabel.ZIndex = box.ZIndex + 1
	placeholderLabel.Parent = fieldHolder
 
	jan:Add(box:GetPropertyChangedSignal("Text"):Connect(function()
		maskLabel.Text = string.rep("\226\128\162", #box.Text)
		placeholderLabel.Visible = (#box.Text == 0)
	end))
 
	local rememberRow = Instance.new("Frame")
	rememberRow.BackgroundTransparency = 1
	rememberRow.Size = UDim2.new(1, 0, 0, 18)
	rememberRow.LayoutOrder = 4
	rememberRow.ZIndex = Z.ModalTop + 1
	rememberRow.Parent = dialog
 
	local remember = IsPrivateTabRemembered(tabObj.Name)
 
	local rememberSwitch = Instance.new("Frame")
	rememberSwitch.AnchorPoint = Vector2.new(0, 0.5)
	rememberSwitch.Position = UDim2.new(0, 0, 0.5, 0)
	rememberSwitch.Size = UDim2.fromOffset(32, 18)
	rememberSwitch.BackgroundColor3 = remember and Color3.new(1, 1, 1) or Color3.fromRGB(60, 60, 60)
	rememberSwitch.BorderSizePixel = 0
	rememberSwitch.ZIndex = Z.ModalTop + 2
	rememberSwitch.Parent = rememberRow
	Corner(rememberSwitch, 9)
 
	local rememberLabel = Instance.new("TextLabel")
	rememberLabel.BackgroundTransparency = 1
	rememberLabel.FontFace = NullUI.Theme.FontRegular
	rememberLabel.Text = "Remember me"
	rememberLabel.TextColor3 = NullUI.Theme.TextDim
	rememberLabel.TextSize = 12
	rememberLabel.TextXAlignment = Enum.TextXAlignment.Left
	rememberLabel.AnchorPoint = Vector2.new(0, 0.5)
	rememberLabel.Position = UDim2.new(0, 42, 0.5, 0)
	rememberLabel.Size = UDim2.new(1, -42, 1, 0)
	rememberLabel.ZIndex = Z.ModalTop + 2
	rememberLabel.Parent = rememberRow
 
	local rememberKnob = Instance.new("Frame")
	rememberKnob.Size = UDim2.fromOffset(14, 14)
	rememberKnob.AnchorPoint = Vector2.new(0, 0.5)
	rememberKnob.Position = remember and UDim2.new(1, -16, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
	rememberKnob.BackgroundColor3 = remember and Color3.fromRGB(18, 18, 18) or Color3.new(1, 1, 1)
	rememberKnob.BorderSizePixel = 0
	rememberKnob.ZIndex = Z.ModalTop + 3
	rememberKnob.Parent = rememberSwitch
	Corner(rememberKnob, 7)
 
	local rememberClick = Instance.new("TextButton")
	rememberClick.Text = ""
	rememberClick.AutoButtonColor = false
	rememberClick.BackgroundTransparency = 1
	rememberClick.Size = UDim2.fromScale(1, 1)
	rememberClick.ZIndex = Z.ModalTop + 3
	rememberClick.Parent = rememberRow
 
	jan:Add(rememberClick.MouseButton1Click:Connect(function()
		remember = not remember
		Tween(rememberSwitch, {
			BackgroundColor3 = remember and Color3.new(1, 1, 1) or Color3.fromRGB(60, 60, 60),
		}, 0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
		Tween(rememberKnob, {
			BackgroundColor3 = remember and Color3.fromRGB(18, 18, 18) or Color3.new(1, 1, 1),
			Position = remember and UDim2.new(1, -16, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
		}, 0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
	end))
 
	local buttonsRow = Instance.new("Frame")
	buttonsRow.BackgroundTransparency = 1
	buttonsRow.Size = UDim2.new(1, 0, 0, 34)
	buttonsRow.LayoutOrder = 5
	buttonsRow.ZIndex = Z.ModalTop + 1
	buttonsRow.Parent = dialog
 
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.Padding = UDim.new(0, 8)
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Parent = buttonsRow
 
	local function makeButton(text_, order, filled)
		local btn = Instance.new("TextButton")
		btn.Text = ""
		btn.AutoButtonColor = false
		btn.BackgroundColor3 = Color3.new(1, 1, 1)
		btn.BackgroundTransparency = filled and 0.82 or 1
		btn.BorderSizePixel = 0
		btn.Size = UDim2.new(0.5, -4, 1, 0)
		btn.LayoutOrder = order
		btn.ZIndex = Z.ModalTop + 1
		btn.Parent = buttonsRow
		Corner(btn, 10)
		local btnStroke = Stroke(btn, Color3.new(1, 1, 1), 1, filled and 0.7 or 0.85)
 
		local lbl = Instance.new("TextLabel")
		lbl.BackgroundTransparency = 1
		lbl.FontFace = NullUI.Theme.Font
		lbl.Text = text_
		lbl.TextColor3 = NullUI.Theme.Text
		lbl.TextSize = 13
		lbl.Size = UDim2.fromScale(1, 1)
		lbl.ZIndex = Z.ModalTop + 2
		lbl.Parent = btn
 
		jan:Add(btn.MouseEnter:Connect(function()
			Tween(btn, { BackgroundTransparency = math.max((filled and 0.82 or 1) - 0.1, 0) }, 0.12)
		end))
		jan:Add(btn.MouseLeave:Connect(function()
			Tween(btn, { BackgroundTransparency = filled and 0.82 or 1 }, 0.12)
		end))
 
		return btn
	end
 
	local cancelBtn  = makeButton("Cancel", 1, false)
	local unlockBtn  = makeButton("Unlock", 2, true)
 
	local function close(success)
		if closed then return end
		closed = true
 
		Tween(scale, { Scale = 0.94 }, 0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		Tween(dialog, { BackgroundTransparency = 1 }, 0.15)
		Tween(dialogStroke, { Transparency = 1 }, 0.15)
		Tween(backdrop, { BackgroundTransparency = 1 }, 0.15)
		task.delay(0.16, function()
			jan:Destroy()
			backdrop:Destroy()
		end)
 
		task.spawn(callback, success, remember)
	end
 
	local function shakeError()
		Tween(fieldStroke, { Color = NullUI.Theme.Danger, Transparency = 0.4 }, 0.12)
		placeholderLabel.Text = "Incorrect password"
		Tween(placeholderLabel, { TextColor3 = NullUI.Theme.Danger }, 0.12)
 
		local baseX = dialog.Position.X.Offset
		local seq = { 8, -7, 5, -4, 0 }
		local t = 0
		for _, dx in ipairs(seq) do
			t = t + 0.05
			task.delay(t, function()
				if closed then return end
				Tween(dialog, {
					Position = UDim2.fromOffset(baseX + dx, dialog.Position.Y.Offset),
				}, 0.05, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
			end)
		end
 
		task.delay(1.4, function()
			if closed then return end
			Tween(fieldStroke, { Color = Color3.new(1, 1, 1), Transparency = 0.88 }, 0.3)
			Tween(placeholderLabel, { TextColor3 = NullUI.Theme.TextDim }, 0.3)
			task.delay(0.3, function()
				if not closed then placeholderLabel.Text = "Password" end
			end)
		end)
	end
 
	local function attempt()
		if closed or settled then return end
		if box.Text == tabObj._password then
			settled = true
			close(true)
		else
			shakeError()
			box.Text = ""
		end
	end
 
	jan:Add(cancelBtn.MouseButton1Click:Connect(function() close(false) end))
	jan:Add(unlockBtn.MouseButton1Click:Connect(attempt))
	jan:Add(backdrop.MouseButton1Click:Connect(function() close(false) end))
 
	jan:Add(UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if closed then return end
		if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter then
			attempt()
		elseif input.KeyCode == Enum.KeyCode.Escape and not gameProcessed then
			close(false)
		end
	end))
 
	Tween(backdrop, { BackgroundTransparency = 0.5 }, 0.18)
	Tween(dialog, { BackgroundTransparency = 0 }, 0.18)
	Tween(dialogStroke, { Transparency = 0.8 }, 0.18)
	Tween(scale, { Scale = 1 }, 0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
 
	task.defer(function()
		if box.Parent then box:CaptureFocus() end
	end)
end
 
function Window:SelectTab(nameOrIndex)
	if type(nameOrIndex) == "number" then
		local t = self._tabs[nameOrIndex]
		if t then t._select() end
		return t
	end
	for _, t in ipairs(self._tabs) do
		if t.Name == nameOrIndex then
			t._select()
			return t
		end
	end
	return nil
end
 
function Window:_RegisterSearchable(tabObj, title, instance)
	if not title or title == "" or not instance then return end
	table.insert(self._searchIndex, { title = title, instance = instance, tabObj = tabObj })
end
 
local function SearchEntryPath(tabObj)
	if not tabObj then return "" end
	if tabObj._parentTabName then
		return tabObj._parentTabName .. " \226\128\186 " .. tabObj.Name
	end
	return tabObj.Name or ""
end
 
function Window:_JumpToSearchable(entry)
	local tabObj = entry.tabObj
	local inst = entry.instance
	if not tabObj or not inst or not inst.Parent then return end
 
	if tabObj._parentTab then
		tabObj._parentTab._select()
		tabObj._parentTab:SelectSubTab(tabObj._subTabIdx)
	elseif tabObj._select then
		tabObj._select()
	end
 
	task.delay(0.6, function()
		if not inst.Parent then return end
		local page = tabObj._page
		if not page then return end
		local targetY = math.max(
			0,
			(inst.AbsolutePosition.Y - page.AbsolutePosition.Y) + page.CanvasPosition.Y - 40
		)
		page.CanvasPosition = Vector2.new(page.CanvasPosition.X, targetY)
 
		local baseColor = inst.BackgroundColor3
		local baseBg = inst.BackgroundTransparency
 
		inst.BackgroundColor3 = NullUI.Theme.Accent
		Tween(inst, { BackgroundTransparency = 0.85 }, 0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
 
		task.delay(0.5, function()
			if not inst.Parent then return end
			Tween(inst, { BackgroundTransparency = baseBg }, 0.7, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
			task.delay(0.7, function()
				if inst.Parent then inst.BackgroundColor3 = baseColor end
			end)
		end)
	end)
end
 
function Window:JumpToElement(query)
	query = tostring(query or "")
	if query == "" then return false, "No element name given" end
 
	local q = query:lower()
	local best, bestScore = nil, 0
	for _, entry in ipairs(self._searchIndex) do
		local title = tostring(entry.title or ""):lower()
		if title == q then
			best, bestScore = entry, math.huge
			break
		elseif title:find(q, 1, true) then
			local score = 1000 - math.abs(#title - #q)
			if score > bestScore then best, bestScore = entry, score end
		end
	end
 
	if not best then
		return false, "No element found matching '" .. query .. "'"
	end
 
	self:_JumpToSearchable(best)
	return true, best.title
end
 
function Window:_OpenSearch()
	local self_ = self
	local root = NullUI._Root
	local panelW = math.min(440, ViewportSize().X / GetUIScale() - 40)
	local HEADER_H = 50
	local MAX_RESULTS_H = 280
	local ROW_H = 40
 
	local open = true
	local backdrop, panel, scale
	local heartbeatConn, textConn, focusConn
	local lastMatches = {}
 
	local restY
 
	local function closeSearch()
		if not open then return end
		open = false
		RegisterPopupClose(closeSearch)
		if heartbeatConn then heartbeatConn:Disconnect(); heartbeatConn = nil end
		if textConn then textConn:Disconnect(); textConn = nil end
		if focusConn then focusConn:Disconnect(); focusConn = nil end
 
		local b, p = backdrop, panel
		backdrop, panel = nil, nil
		if p then
			Tween(p, { Size = UDim2.new(p.Size.X.Scale, p.Size.X.Offset, 0, 0) }, 0.32,
				Enum.EasingStyle.Quint, Enum.EasingDirection.In)
			Tween(p, { GroupTransparency = 1 }, 0.26, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		end
		if b then Tween(b, { BackgroundTransparency = 1 }, 0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.In) end
		task.delay(0.32, function()
			if b then b:Destroy() end
			if p then p:Destroy() end
		end)
	end
 
	RegisterPopupOpen(closeSearch)
	backdrop = MakePopupBackdrop(closeSearch)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	Tween(backdrop, { BackgroundTransparency = 0.4 }, 0.36, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
 
	panel = Instance.new("CanvasGroup")
	panel.Name = "SearchPalette"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	do
		local cx, cy = ComputeDialogCenter(self_._gui)
		local s = GetUIScale()
		local px, py = math.round(cx / s), math.round(cy / s)
		restY = py
		panel.Position = UDim2.fromOffset(px, py - 18)
	end
	panel.Size = UDim2.new(0, panelW, 0, HEADER_H)
	panel.BackgroundColor3 = NullUI.Theme.Background
	panel.BackgroundTransparency = 0.05
	panel.GroupTransparency = 1
	panel.BorderSizePixel = 0
	panel.ClipsDescendants = true
	panel.ZIndex = Z.Modal
	panel.Parent = root
	Corner(panel, 14)
	Stroke(panel, Color3.new(1, 1, 1), 1, 0.8)
	GlassLayer(panel, 14, 0.985)
 
	scale = Instance.new("UIScale")
	scale.Scale = 0.94
	scale.Parent = panel
 
	local searchIcon = Instance.new("ImageLabel")
	searchIcon.BackgroundTransparency = 1
	searchIcon.Image = ResolveIcon("search")
	searchIcon.ImageColor3 = NullUI.Theme.TextDim
	searchIcon.Size = UDim2.fromOffset(16, 16)
	searchIcon.AnchorPoint = Vector2.new(0, 0.5)
	searchIcon.Position = UDim2.new(0, 16, 0, HEADER_H / 2)
	searchIcon.ZIndex = Z.Modal + 2
	searchIcon.Parent = panel
 
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Text = ""
	closeBtn.AutoButtonColor = false
	closeBtn.BackgroundColor3 = Color3.new(1, 1, 1)
	closeBtn.BackgroundTransparency = 1
	closeBtn.BorderSizePixel = 0
	closeBtn.AnchorPoint = Vector2.new(1, 0.5)
	closeBtn.Size = UDim2.fromOffset(24, 24)
	closeBtn.Position = UDim2.new(1, -10, 0, HEADER_H / 2)
	closeBtn.ZIndex = Z.Modal + 2
	closeBtn.Parent = panel
	Corner(closeBtn, 7)
 
	local closeIcon = Instance.new("ImageLabel")
	closeIcon.BackgroundTransparency = 1
	closeIcon.Image = ResolveIcon("x")
	closeIcon.ImageColor3 = NullUI.Theme.TextDim
	closeIcon.Size = UDim2.fromOffset(12, 12)
	closeIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	closeIcon.Position = UDim2.fromScale(0.5, 0.5)
	closeIcon.ZIndex = Z.Modal + 3
	closeIcon.Parent = closeBtn
 
	closeBtn.MouseEnter:Connect(function()
		Tween(closeBtn, { BackgroundTransparency = 0.9 }, 0.12)
		Tween(closeIcon, { ImageColor3 = NullUI.Theme.Text }, 0.12)
	end)
	closeBtn.MouseLeave:Connect(function()
		Tween(closeBtn, { BackgroundTransparency = 1 }, 0.12)
		Tween(closeIcon, { ImageColor3 = NullUI.Theme.TextDim }, 0.12)
	end)
	closeBtn.MouseButton1Click:Connect(closeSearch)
 
	local box = Instance.new("TextBox")
	box.Name = "SearchBox"
	box.BackgroundTransparency = 1
	box.FontFace = NullUI.Theme.FontRegular
	box.PlaceholderText = "Search everything..."
	box.Text = ""
	box.TextColor3 = NullUI.Theme.Text
	box.PlaceholderColor3 = NullUI.Theme.TextDim
	box.TextSize = 15
	box.ClearTextOnFocus = false
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.Position = UDim2.new(0, 40, 0, 0)
	box.Size = UDim2.new(1, -78, 0, HEADER_H)
	box.ZIndex = Z.Modal + 2
	box.Parent = panel
 
	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.BackgroundColor3 = Color3.new(1, 1, 1)
	divider.BackgroundTransparency = 0.92
	divider.BorderSizePixel = 0
	divider.Position = UDim2.new(0, 0, 0, HEADER_H)
	divider.Size = UDim2.new(1, 0, 0, 1)
	divider.Visible = false
	divider.ZIndex = Z.Modal + 1
	divider.Parent = panel
 
	local resultsHolder = Instance.new("ScrollingFrame")
	resultsHolder.Name = "Results"
	resultsHolder.BackgroundTransparency = 1
	resultsHolder.BorderSizePixel = 0
	resultsHolder.Position = UDim2.new(0, 0, 0, HEADER_H + 1)
	resultsHolder.Size = UDim2.new(1, 0, 0, 0)
	resultsHolder.Visible = false
	resultsHolder.ScrollingDirection = Enum.ScrollingDirection.Y
	resultsHolder.ScrollBarThickness = 0
	resultsHolder.AutomaticCanvasSize = Enum.AutomaticSize.Y
	resultsHolder.CanvasSize = UDim2.new(0, 0, 0, 0)
	resultsHolder.ZIndex = Z.Modal + 1
	resultsHolder.Parent = panel
 
	local resultsPad = Instance.new("UIPadding")
	resultsPad.PaddingTop = UDim.new(0, 6)
	resultsPad.PaddingBottom = UDim.new(0, 6)
	resultsPad.PaddingLeft = UDim.new(0, 6)
	resultsPad.PaddingRight = UDim.new(0, 16)
	resultsPad.Parent = resultsHolder
 
	local resultsLayout = Instance.new("UIListLayout")
	resultsLayout.Padding = UDim.new(0, 2)
	resultsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	resultsLayout.Parent = resultsHolder
 
	AddScrollbar(resultsHolder)
	AddContentScrollThumb(resultsHolder, resultsLayout, panel, {
		Add = function(_, conn) heartbeatConn = conn end,
	})
 
	local emptyLabel = Instance.new("TextLabel")
	emptyLabel.BackgroundTransparency = 1
	emptyLabel.FontFace = NullUI.Theme.FontRegular
	emptyLabel.Text = "No results"
	emptyLabel.TextColor3 = NullUI.Theme.TextDim
	emptyLabel.TextSize = 13
	emptyLabel.Visible = false
	emptyLabel.Position = UDim2.new(0, 0, 0, HEADER_H + 9)
	emptyLabel.Size = UDim2.new(1, 0, 0, 26)
	emptyLabel.ZIndex = Z.Modal + 1
	emptyLabel.Parent = panel
 
	local function activate(entry)
		closeSearch()
		self_:_JumpToSearchable(entry)
	end
 
	local function rebuild(query)
		for _, child in ipairs(resultsHolder:GetChildren()) do
			if child:IsA("TextButton") then child:Destroy() end
		end
 
		local q = query:lower():match("^%s*(.-)%s*$")
		local matches = {}
		for _, entry in ipairs(self_._searchIndex) do
			if entry.instance and entry.instance.Parent then
				if q == "" or entry.title:lower():find(q, 1, true) then
					table.insert(matches, entry)
					if #matches >= 15 then break end
				end
			end
		end
		lastMatches = matches
 
		local showEmpty = (#matches == 0 and q ~= "")
		emptyLabel.Visible = showEmpty
		resultsHolder.Visible = (#matches > 0)
		divider.Visible = (#matches > 0) or showEmpty
 
		for i, entry in ipairs(matches) do
			local row = Instance.new("TextButton")
			row.Text = ""
			row.AutoButtonColor = false
			row.BackgroundColor3 = Color3.new(1, 1, 1)
			row.BackgroundTransparency = 1
			row.BorderSizePixel = 0
			row.Size = UDim2.new(1, 0, 0, ROW_H)
			row.LayoutOrder = i
			row.ZIndex = Z.Modal + 2
			row.Parent = resultsHolder
			Corner(row, 8)
 
			local titleLbl = Instance.new("TextLabel")
			titleLbl.BackgroundTransparency = 1
			titleLbl.FontFace = NullUI.Theme.Font
			titleLbl.Text = entry.title
			titleLbl.TextColor3 = NullUI.Theme.Text
			titleLbl.TextSize = 13
			titleLbl.TextXAlignment = Enum.TextXAlignment.Left
			titleLbl.TextTruncate = Enum.TextTruncate.AtEnd
			titleLbl.Position = UDim2.fromOffset(12, 5)
			titleLbl.Size = UDim2.new(1, -24, 0, 16)
			titleLbl.ZIndex = Z.Modal + 3
			titleLbl.Parent = row
 
			local pathLbl = Instance.new("TextLabel")
			pathLbl.BackgroundTransparency = 1
			pathLbl.FontFace = NullUI.Theme.FontRegular
			pathLbl.Text = SearchEntryPath(entry.tabObj)
			pathLbl.TextColor3 = NullUI.Theme.TextDim
			pathLbl.TextSize = 11
			pathLbl.TextXAlignment = Enum.TextXAlignment.Left
			pathLbl.TextTruncate = Enum.TextTruncate.AtEnd
			pathLbl.Position = UDim2.fromOffset(12, 21)
			pathLbl.Size = UDim2.new(1, -24, 0, 12)
			pathLbl.ZIndex = Z.Modal + 3
			pathLbl.Parent = row
 
			row.MouseEnter:Connect(function()
				Tween(row, { BackgroundTransparency = 0.92 }, 0.1)
			end)
			row.MouseLeave:Connect(function()
				Tween(row, { BackgroundTransparency = 1 }, 0.1)
			end)
			row.MouseButton1Click:Connect(function()
				activate(entry)
			end)
		end
 
		local resultsH = math.min(#matches * (ROW_H + 2), MAX_RESULTS_H)
 
		local extraH = 0
		if resultsH > 0 then
			extraH = resultsH + 1
		elseif showEmpty then
			extraH = 36
		end
 
		Tween(resultsHolder, { Size = UDim2.new(1, 0, 0, resultsH) }, 0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
		Tween(panel, { Size = UDim2.new(0, panelW, 0, HEADER_H + extraH) }, 0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
	end
 
	local rebuildToken = 0
	textConn = box:GetPropertyChangedSignal("Text"):Connect(function()
		rebuildToken = rebuildToken + 1
		local myToken = rebuildToken
		local text = box.Text
		task.delay(0.12, function()
			if rebuildToken == myToken and box.Parent then
				rebuild(text)
			end
		end)
	end)
 
	focusConn = box.FocusLost:Connect(function(enterPressed)
		if enterPressed and lastMatches[1] then
			activate(lastMatches[1])
		end
	end)
 
	rebuild("")
 
	scale.Scale = 0.94
	Tween(panel, {
		GroupTransparency = 0,
		Position = UDim2.fromOffset(panel.Position.X.Offset, restY),
	}, 0.34, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	Tween(scale, { Scale = 1 }, 0.34, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
 
	task.defer(function()
		if box.Parent then box:CaptureFocus() end
	end)
end
 
local SUBTAB_EXIT  = 0.18
local SUBTAB_GAP   = 0.08
local SUBTAB_ENTER = 0.30
 
function Tab:AddSubTab(nameOrOpts)
	local opts = type(nameOrOpts) == "table" and nameOrOpts or { Name = nameOrOpts }
	local title = opts.Name or "SubTab"
	local iconAsset = opts.Icon and ResolveIcon(opts.Icon) or nil
	local jan = self._janitor
 
	self._subTabCount = (self._subTabCount or 0) + 1
	local idx = self._subTabCount
 
	if not self._subTabHolder then
		local page = self._page
		page.ScrollingEnabled = false
		page.AutomaticCanvasSize = Enum.AutomaticSize.None
		page.CanvasSize = UDim2.new(0, 0, 0, 0)
 
		local pl = page:FindFirstChildOfClass("UIListLayout")
		if pl then pl:Destroy() end
		local pp = page:FindFirstChildOfClass("UIPadding")
		if pp then pp:Destroy() end
		local oldTrack = page:FindFirstChild("ScrollTrack")
		if oldTrack then oldTrack:Destroy() end
 
		self._subTabHolder = Instance.new("ScrollingFrame")
		self._subTabHolder.Name = "SubTabBar"
		self._subTabHolder.Size = UDim2.new(1, -12, 0, 40)
		self._subTabHolder.Position = UDim2.fromOffset(2, 6)
		self._subTabHolder.BackgroundTransparency = 1
		self._subTabHolder.BorderSizePixel = 0
		self._subTabHolder.ScrollingDirection = Enum.ScrollingDirection.X
		self._subTabHolder.ScrollBarThickness = 0
		self._subTabHolder.AutomaticCanvasSize = Enum.AutomaticSize.X
		self._subTabHolder.CanvasSize = UDim2.new(0, 0, 0, 40)
		self._subTabHolder.ZIndex = Z.Content
		self._subTabHolder.Parent = page
		AddScrollbar(self._subTabHolder)
 
		self._subTabIndicatorLayer = Instance.new("Frame")
		self._subTabIndicatorLayer.Name = "SubTabIndicatorLayer"
		self._subTabIndicatorLayer.BackgroundTransparency = 1
		self._subTabIndicatorLayer.ClipsDescendants = true
		self._subTabIndicatorLayer.ZIndex = Z.Window
		self._subTabIndicatorLayer.Position = self._subTabHolder.Position
		self._subTabIndicatorLayer.Size = self._subTabHolder.Size
		self._subTabIndicatorLayer.Parent = page
 
		self._subTabIndicator = Instance.new("Frame")
		self._subTabIndicator.Name = "Indicator"
		self._subTabIndicator.BackgroundColor3 = Color3.new(1, 1, 1)
		self._subTabIndicator.BackgroundTransparency = 1
		self._subTabIndicator.BorderSizePixel = 0
		self._subTabIndicator.ZIndex = Z.Window
		self._subTabIndicator.Size = UDim2.fromOffset(0, 32)
		self._subTabIndicator.Position = UDim2.fromOffset(0, 4)
		self._subTabIndicator.Parent = self._subTabIndicatorLayer
		Corner(self._subTabIndicator, 8)
 
		local sl = Instance.new("UIListLayout")
		sl.FillDirection = Enum.FillDirection.Horizontal
		sl.VerticalAlignment = Enum.VerticalAlignment.Center
		sl.Padding = UDim.new(0, 6)
		sl.SortOrder = Enum.SortOrder.LayoutOrder
		sl.Parent = self._subTabHolder
 
		self._subTabBody = Instance.new("Frame")
		self._subTabBody.Name = "SubTabBody"
		self._subTabBody.Size = UDim2.new(1, -4, 1, -62)
		self._subTabBody.Position = UDim2.fromOffset(2, 56)
		self._subTabBody.BackgroundTransparency = 1
		self._subTabBody.BorderSizePixel = 0
		self._subTabBody.ClipsDescendants = true
		self._subTabBody.ZIndex = Z.Content
		self._subTabBody.Parent = page
 
		self._subTabScrollTrack = Instance.new("Frame")
		self._subTabScrollTrack.Name = "SubTabScrollTrack"
		self._subTabScrollTrack.BackgroundColor3 = NullUI.Theme.TextDim
		self._subTabScrollTrack.BackgroundTransparency = 0.85
		self._subTabScrollTrack.BorderSizePixel = 0
		self._subTabScrollTrack.Position = UDim2.new(0, 2, 0, 48)
		self._subTabScrollTrack.Size = UDim2.new(1, -12, 0, 3)
		self._subTabScrollTrack.Visible = false
		self._subTabScrollTrack.ZIndex = Z.Content
		self._subTabScrollTrack.Parent = page
		Corner(self._subTabScrollTrack, 2)
 
		self._subTabScrollThumb = Instance.new("Frame")
		self._subTabScrollThumb.Name = "Thumb"
		self._subTabScrollThumb.BackgroundColor3 = NullUI.Theme.TextDim
		self._subTabScrollThumb.BackgroundTransparency = 0.35
		self._subTabScrollThumb.BorderSizePixel = 0
		self._subTabScrollThumb.Size = UDim2.new(0, 40, 1, 0)
		self._subTabScrollThumb.ZIndex = Z.Content + 1
		self._subTabScrollThumb.Parent = self._subTabScrollTrack
		Corner(self._subTabScrollThumb, 2)
 
		function self._updateSubTabScrollbar()
			local holder = self._subTabHolder
			local track = self._subTabScrollTrack
			if not holder or not track then return end
			if not self._group or not self._group.Visible then
				track.Visible = false
				return
			end
			local windowW = holder.AbsoluteWindowSize.X
			local canvasW = holder.AbsoluteCanvasSize.X
			local overflow = canvasW - windowW
			if overflow <= 1 or windowW <= 0 then
				track.Visible = false
				return
			end
			track.Visible = true
			local trackW = track.AbsoluteSize.X
			if trackW <= 0 then return end
			local thumbW = math.min(trackW, math.max(30, trackW * (windowW / canvasW)))
			local maxThumbX = trackW - thumbW
			local ratio = math.clamp(holder.CanvasPosition.X / overflow, 0, 1)
			self._subTabScrollThumb.Size = UDim2.new(thumbW / trackW, 0, 1, 0)
			self._subTabScrollThumb.Position = UDim2.new((maxThumbX / trackW) * ratio, 0, 0, 0)
		end
 
		jan:Add(RunService.Heartbeat:Connect(self._updateSubTabScrollbar))
 
		self._subTabs = {}
 
		function self._syncSubIndicator(animated)
			local sel = self._subTabs and self._subTabs[self.SelectedSubTab]
			if not sel or not sel.Button.Parent then return end
			local holder = self._subTabHolder
			local s = GetUIScale()
			local relX = (sel.Button.AbsolutePosition.X - holder.AbsolutePosition.X) / s
			local w = sel.Button.AbsoluteSize.X / s
			if w <= 0 then return end
			local goal = {
				Position = UDim2.fromOffset(math.round(relX), 4),
				Size = UDim2.fromOffset(math.round(w), 32),
				BackgroundTransparency = 0.86,
			}
			if animated then
				Tween(self._subTabIndicator, goal, 0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
			else
				self._subTabIndicator.Position = goal.Position
				self._subTabIndicator.Size = goal.Size
				self._subTabIndicator.BackgroundTransparency = goal.BackgroundTransparency
			end
		end
 
		jan:Add(self._subTabHolder:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
			self._syncSubIndicator(false)
			self._updateSubTabScrollbar()
		end))
	end
 
	local btn = Instance.new("TextButton")
	btn.Name = "SubTab_" .. title:gsub("%s", "")
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.BackgroundColor3 = Color3.new(1, 1, 1)
	btn.BackgroundTransparency = 1
	btn.BorderSizePixel = 0
	btn.AutomaticSize = Enum.AutomaticSize.X
	btn.Size = UDim2.fromOffset(0, 32)
	btn.LayoutOrder = idx
	btn.ZIndex = Z.Content
	btn.Parent = self._subTabHolder
	Corner(btn, 8)
 
	local bl = Instance.new("UIListLayout")
	bl.FillDirection = Enum.FillDirection.Horizontal
	bl.VerticalAlignment = Enum.VerticalAlignment.Center
	bl.SortOrder = Enum.SortOrder.LayoutOrder
	bl.Padding = UDim.new(0, 6)
	bl.Parent = btn
 
	local bpad = Instance.new("UIPadding")
	bpad.PaddingLeft = UDim.new(0, 12)
	bpad.PaddingRight = UDim.new(0, 12)
	bpad.Parent = btn
 
	local ic = nil
	if iconAsset and iconAsset ~= "" then
		ic = Instance.new("ImageLabel")
		ic.BackgroundTransparency = 1
		ic.Image = iconAsset
		ic.ImageColor3 = NullUI.Theme.TextDim
		ic.Size = UDim2.fromOffset(16, 16)
		ic.LayoutOrder = 1
		ic.ZIndex = Z.Content + 1
		ic.Parent = btn
	end
 
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.FontFace = NullUI.Theme.Font
	lbl.Text = title
	lbl.TextColor3 = NullUI.Theme.TextDim
	lbl.TextSize = 13
	lbl.TextXAlignment = Enum.TextXAlignment.Center
	lbl.TextYAlignment = Enum.TextYAlignment.Center
	lbl.Size = UDim2.new(0, 0, 0, 32)
	lbl.AutomaticSize = Enum.AutomaticSize.X
	lbl.LayoutOrder = 2
	lbl.ZIndex = Z.Content + 1
	lbl.Parent = btn
 
	local group = Instance.new("Frame")
	group.Name = title .. "Group"
	group.Size = UDim2.fromScale(1, 1)
	group.BackgroundTransparency = 1
	group.Visible = false
	group.ZIndex = Z.Content
	group.Parent = self._subTabBody
 
	local container = Instance.new("ScrollingFrame")
	container.Name = title .. "Page"
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0
	container.ScrollingDirection = Enum.ScrollingDirection.Y
	container.ScrollBarThickness = 0
	container.AutomaticCanvasSize = Enum.AutomaticSize.Y
	container.CanvasSize = UDim2.new(0, 0, 0, 0)
	container.ZIndex = Z.Content
	container.Parent = group
 
	local cpad = Instance.new("UIPadding")
	cpad.Name = "PagePadding"
	cpad.PaddingRight = UDim.new(0, 12)
	cpad.PaddingBottom = UDim.new(0, 6)
	cpad.Parent = container
 
	local clayout = Instance.new("UIListLayout")
	clayout.Name = "PageLayout"
	clayout.Padding = UDim.new(0, 8)
	clayout.SortOrder = Enum.SortOrder.LayoutOrder
	clayout.Parent = container
 
	AddScrollbar(container)
	AddContentScrollThumb(container, clayout, group, jan)
	AddEmptyState(container, group, jan)
 
	local sub = setmetatable({
		Name           = title,
		_page          = container,
		_window        = self._window,
		_janitor       = jan,
		_parentTab     = self,
		_parentTabName = self.Name,
		_subTabIdx     = idx,
		Button    = btn,
		Label     = lbl,
		Icon      = ic,
		Container = container,
		Group     = group,
		Selected  = false,
	}, Tab)
 
	self._subTabs[idx] = sub
 
	jan:Add(btn:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
		if self.SelectedSubTab == idx then
			self._syncSubIndicator(false)
		end
	end))
	jan:Add(btn:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if self.SelectedSubTab == idx then
			self._syncSubIndicator(false)
		end
	end))
 
	jan:Add(btn.MouseEnter:Connect(function()
		if idx ~= self.SelectedSubTab then
			Tween(btn, { BackgroundTransparency = 0.94 }, 0.15)
		end
	end))
	jan:Add(btn.MouseLeave:Connect(function()
		if idx ~= self.SelectedSubTab then
			Tween(btn, { BackgroundTransparency = 1 }, 0.15)
		end
	end))
 
	local downPos = nil
	jan:Add(btn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			downPos = input.Position
		end
	end))
	jan:Add(btn.InputEnded:Connect(function(input)
		if (input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch) and downPos then
			if (input.Position - downPos).Magnitude < DRAG_THRESHOLD then
				self:SelectSubTab(idx)
			end
			downPos = nil
		end
	end))
 
	if not self.SelectedSubTab then
		self:SelectSubTab(idx)
	end
 
	return sub
end
 
function Tab:SelectSubTab(idx)
	if not self._subTabs then return end
	local previous = self.SelectedSubTab
	if previous == idx then return end
 
	self._subTabSwitchToken = (self._subTabSwitchToken or 0) + 1
	local myToken = self._subTabSwitchToken
 
	local direction = 0
	if previous then
		direction = (idx > previous) and 1 or -1
	end
 
	self.SelectedSubTab = idx
	local target = self._subTabs[idx]
	local previousSub = previous and self._subTabs[previous]
	if not target then return end
 
	self._syncSubIndicator(previous ~= nil)
 
	for i, st in pairs(self._subTabs) do
		local sel = (i == idx)
		st.Selected = sel
		if not sel then
			Tween(st.Button, { BackgroundTransparency = 1 }, 0.15)
		end
		Tween(st.Label, { TextColor3 = sel and NullUI.Theme.Text or NullUI.Theme.TextDim }, 0.22)
		if st.Icon then
			Tween(st.Icon, { ImageColor3 = sel and NullUI.Theme.Text or NullUI.Theme.TextDim }, 0.22)
		end
	end
 
	for _, st in pairs(self._subTabs) do
		if st ~= target and st ~= previousSub and st.Group.Visible then
			st.Group.Visible = false
		end
	end
 
	local function playEnter()
		if self._subTabSwitchToken ~= myToken then return end
		target.Group.Visible = true
		target.Group.Position = UDim2.fromOffset(direction * 20, 0)
		Tween(target.Group, {
			Position = UDim2.fromOffset(0, 0),
		}, SUBTAB_ENTER, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	end
 
	if previousSub and previousSub.Group.Visible then
		local g = previousSub.Group
		Tween(g, {
			Position = UDim2.fromOffset(-direction * 20, 0),
		}, SUBTAB_EXIT, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		task.delay(SUBTAB_EXIT, function()
			if g then g.Visible = false end
			task.delay(SUBTAB_GAP, playEnter)
		end)
	else
		playEnter()
	end
end
 
function Tab:SelectSubTabByName(name)
	if not self._subTabs then return nil end
	for idx, st in pairs(self._subTabs) do
		if st.Name == name then
			self:SelectSubTab(idx)
			return st
		end
	end
	return nil
end
 
local function RegisterFlag(opts, api, kind)
	if opts.Flag then
		NullUI.Flags[opts.Flag] = api
		api.Flag = opts.Flag
		api.Kind = kind
		api.Label = opts.Text or opts.Label or opts.Flag
	end
	return api
end
 
function Tab:AddLabel(text)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.FontFace = NullUI.Theme.FontRegular
	label.Text = text
	label.TextColor3 = NullUI.Theme.TextDim
	label.TextSize = 13
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.Size = UDim2.new(1, 0, 0, 16)
	label.ZIndex = Z.Content
	label.Parent = self._page
 
	return {
		Instance = label,
		Set = function(_, v) label.Text = v end,
		Get = function() return label.Text end,
		Destroy = function() label:Destroy() end,
	}
end
 
function Tab:AddSection(textOrOpts, maybeIcon)
	local opts = type(textOrOpts) == "table" and textOrOpts or { Text = textOrOpts, Icon = maybeIcon }
	local text = opts.Text or "Section"
	local iconAsset = opts.Icon and ResolveIcon(opts.Icon) or ""
 
	local holder = Instance.new("Frame")
	holder.Name = "Section"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, 24)
	holder.ZIndex = Z.Content
	holder.Parent = self._page
 
	local x = 2
	if iconAsset ~= "" then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Image = iconAsset
		img.ImageColor3 = NullUI.Theme.TextDim
		img.Size = UDim2.fromOffset(13, 13)
		img.Position = UDim2.fromOffset(2, 8)
		img.ZIndex = Z.Content + 1
		img.Parent = holder
		x = 2 + 13 + 7
	end
 
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.FontFace = NullUI.Theme.Font
	label.Text = string.upper(text)
	label.TextColor3 = NullUI.Theme.TextDim
	label.TextSize = 12
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Position = UDim2.fromOffset(x, 8)
	label.Size = UDim2.new(1, -(x + 2), 0, 14)
	label.ZIndex = Z.Content + 1
	label.Parent = holder
 
	return {
		Instance = holder,
		Set = function(_, v) label.Text = string.upper(v) end,
		Destroy = function() holder:Destroy() end,
	}
end
 
function Tab:AddDivider()
	local holder = Instance.new("Frame")
	holder.Name = "Divider"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, 13)
	holder.ZIndex = Z.Content
	holder.Parent = self._page
 
	local line = Instance.new("Frame")
	line.AnchorPoint = Vector2.new(0, 0.5)
	line.Position = UDim2.new(0, 0, 0.5, 0)
	line.Size = UDim2.new(1, 0, 0, 1)
	line.BackgroundColor3 = Color3.new(1, 1, 1)
	line.BackgroundTransparency = 0.92
	line.BorderSizePixel = 0
	line.ZIndex = Z.Content
	line.Parent = holder
 
	return { Instance = holder, Destroy = function() holder:Destroy() end }
end
 
Tab.AddLine = Tab.AddDivider
 
function Tab:AddLineText(text)
	text = tostring(text or "")
 
	local holder = Instance.new("Frame")
	holder.Name = "LineText"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, 20)
	holder.ZIndex = Z.Content
	holder.Parent = self._page
 
	local left = Instance.new("Frame")
	left.Name = "Left"
	left.AnchorPoint = Vector2.new(0, 0.5)
	left.Position = UDim2.fromScale(0, 0.5)
	left.Size = UDim2.new(0.5, -10, 0, 1)
	left.BackgroundColor3 = Color3.new(1, 1, 1)
	left.BackgroundTransparency = 0.92
	left.BorderSizePixel = 0
	left.ZIndex = Z.Content
	left.Parent = holder
 
	local right = Instance.new("Frame")
	right.Name = "Right"
	right.AnchorPoint = Vector2.new(1, 0.5)
	right.Position = UDim2.fromScale(1, 0.5)
	right.Size = UDim2.new(0.5, -10, 0, 1)
	right.BackgroundColor3 = Color3.new(1, 1, 1)
	right.BackgroundTransparency = 0.92
	right.BorderSizePixel = 0
	right.ZIndex = Z.Content
	right.Parent = holder
 
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.FontFace = NullUI.Theme.FontRegular
	label.Text = text
	label.TextColor3 = NullUI.Theme.TextDim
	label.TextSize = 12
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Size = UDim2.fromOffset(0, 16)
	label.ZIndex = Z.Content + 1
	label.Parent = holder
 
	local gap = 10
	local minSide = 6
	local lastW = -1
 
	local function relayout()
		local w = holder.AbsoluteSize.X / GetUIScale()
		if w <= 0 or math.abs(w - lastW) < 1 then return end
		lastW = w
 
		local textW = MeasureText(text, 12, w)
		local sideW = math.max((w - textW) / 2 - gap, minSide)
		left.Size = UDim2.new(0, sideW, 0, 1)
		right.Size = UDim2.new(0, sideW, 0, 1)
	end
 
	holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
	task.defer(relayout)
 
	return {
		Instance = holder,
		Set = function(_, v)
			text = tostring(v or "")
			label.Text = text
			lastW = -1
			relayout()
		end,
		Destroy = function() holder:Destroy() end,
	}
end
 
function Tab:AddParagraph(opts)
	opts = opts or {}
 
	local card = BaseCard(self._page, 10)
	card.AutomaticSize = Enum.AutomaticSize.Y
 
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 12)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = card
 
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = card
 
	local titleLabel
	if opts.Title then
		local titleRow = Instance.new("Frame")
		titleRow.BackgroundTransparency = 1
		titleRow.Size = UDim2.new(1, 0, 0, 18)
		titleRow.AutomaticSize = Enum.AutomaticSize.Y
		titleRow.LayoutOrder = 1
		titleRow.ZIndex = Z.Content + 1
		titleRow.Parent = card
 
		local rowLayout = Instance.new("UIListLayout")
		rowLayout.FillDirection = Enum.FillDirection.Horizontal
		rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
		rowLayout.Padding = UDim.new(0, 7)
		rowLayout.Parent = titleRow
 
		local iconAsset = opts.Icon and ResolveIcon(opts.Icon) or ""
		if iconAsset ~= "" then
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.Image = iconAsset
			img.ImageColor3 = NullUI.Theme.Text
			img.Size = UDim2.fromOffset(15, 15)
			img.LayoutOrder = 1
			img.ZIndex = Z.Content + 2
			img.Parent = titleRow
		end
 
		titleLabel = Instance.new("TextLabel")
		titleLabel.BackgroundTransparency = 1
		titleLabel.FontFace = NullUI.Theme.Font
		titleLabel.Text = opts.Title
		titleLabel.TextColor3 = NullUI.Theme.Text
		titleLabel.TextSize = 14
		titleLabel.TextXAlignment = Enum.TextXAlignment.Left
		titleLabel.TextYAlignment = Enum.TextYAlignment.Center
		titleLabel.AutomaticSize = Enum.AutomaticSize.X
		titleLabel.Size = UDim2.fromOffset(0, 18)
		titleLabel.LayoutOrder = 2
		titleLabel.ZIndex = Z.Content + 2
		titleLabel.Parent = titleRow
 
		local titlePadding = Instance.new("UIPadding")
		titlePadding.PaddingTop = UDim.new(0, 2)
		titlePadding.Parent = titleLabel
	end
 
	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.FontFace = NullUI.Theme.FontRegular
	textLabel.Text = opts.Text or ""
	textLabel.TextColor3 = NullUI.Theme.TextDim
	textLabel.TextSize = 13
	textLabel.TextWrapped = true
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.AutomaticSize = Enum.AutomaticSize.Y
	textLabel.Size = UDim2.new(1, 0, 0, 16)
	textLabel.LayoutOrder = 2
	textLabel.ZIndex = Z.Content + 1
	textLabel.Parent = card
 
	return {
		Instance = card,
		Set = function(_, v) textLabel.Text = v end,
		Get = function() return textLabel.Text end,
		SetTitle = function(_, v) if titleLabel then titleLabel.Text = v end end,
		Destroy = function() card:Destroy() end,
	}
end
 
local function BuildStarRow(parent, layoutOrder, maxStars, starColor, starSize, default)
	local starOutline = ResolveIcon("Phosphor:star")
	local starFilled = ResolveIcon("Material:star")
 
	local row = Instance.new("Frame")
	row.Name = "Stars"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, starSize)
	row.LayoutOrder = layoutOrder
	row.ZIndex = Z.Content + 1
	row.Parent = parent
 
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	rowLayout.Padding = UDim.new(0, 8)
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Parent = row
 
	local stars = {}
	local selected = math.clamp(default or 0, 0, maxStars)
 
	local function paint(previewCount)
		local count = previewCount or selected
		for i, button in ipairs(stars) do
			local on = i <= count
			button.Image = on and starFilled or starOutline
			Tween(button, { ImageColor3 = on and starColor or NullUI.Theme.TextDim }, 0.12)
		end
	end
 
	for i = 1, maxStars do
		local button = Instance.new("ImageButton")
		button.Name = "Star" .. i
		button.BackgroundTransparency = 1
		button.AutoButtonColor = false
		button.Image = starOutline
		button.ImageColor3 = NullUI.Theme.TextDim
		button.Size = UDim2.fromOffset(starSize, starSize)
		button.LayoutOrder = i
		button.ZIndex = Z.Content + 2
		button.Parent = row
 
		button.MouseEnter:Connect(function() paint(i) end)
		button.MouseLeave:Connect(function() paint() end)
		button.MouseButton1Click:Connect(function()
			selected = i
			paint()
		end)
 
		stars[i] = button
	end
	paint()
 
	return {
		Row = row,
		Get = function() return selected end,
		Set = function(v)
			selected = math.clamp(v or 0, 0, maxStars)
			paint()
		end,
		Nudge = function()
			for _, button in ipairs(stars) do Tween(button, { Rotation = 8 }, 0.06) end
			task.delay(0.06, function()
				for _, button in ipairs(stars) do Tween(button, { Rotation = 0 }, 0.12) end
			end)
		end,
	}
end
 
local function NormalizeFeedbackText(text)
	local invisibleChars = {
		["\226\128\139"] = "", ["\226\128\142"] = "", ["\226\128\143"] = "",
		["\239\187\191"] = "", ["\194\173"] = "",
	}
	for char, replacement in pairs(invisibleChars) do
		text = text:gsub(char, replacement)
	end
	text = text:gsub("%s+", " ")
	text = text:gsub("^%s+", "")
	text = text:gsub("%s+$", "")
	return text
end
 
local FeedbackEvasionPatterns = {
	{pattern = "d%s*i%s*s%s*c%s*o%s*r%s*d", name = "discord"},
	{pattern = "t%s*e%s*l%s*e%s*g%s*r%s*a%s*m", name = "telegram"},
	{pattern = "w%s*h%s*a%s*t%s*s%s*a%s*p%s*p", name = "whatsapp"},
	{pattern = "h%s*t%s*t%s*p", name = "http"},
	{pattern = "h%s*t%s*t%s*p%s*s", name = "https"},
	{pattern = "w%s*w%s*w", name = "www"},
	{pattern = "c%s*o%s*m", name = "com"},
	{pattern = "o%s*r%s*g", name = "org"},
	{pattern = "n%s*e%s*t", name = "net"},
	{pattern = ".%s*g%s*g", name = ".gg"},
	{pattern = ".%s*c%s*o%s*m", name = ".com"},
	{pattern = "/%s*i%s*n%s*v%s*i%s*t%s*e", name = "/invite"},
	{pattern = "d%s*o%s*t%s*%s*c%s*o%s*m", name = "dot com"},
	{pattern = "a%s*t%s*%s*%s*h%s*e%s*r%s*e", name = "@here"},
	{pattern = "a%s*t%s*%s*%s*e%s*v%s*e%s*r%s*y%s*o%s*n%s*e", name = "@everyone"},
}
 
local function DetectFeedbackEvasion(text)
	for _, evasion in ipairs(FeedbackEvasionPatterns) do
		if text:match(evasion.pattern) then
			return true, evasion.name
		end
	end
	local dotCount, slashCount = 0, 0
	for i = 1, #text do
		local char = text:sub(i, i)
		if char == "." then dotCount = dotCount + 1 end
		if char == "/" then slashCount = slashCount + 1 end
	end
	if dotCount >= 3 or slashCount >= 3 then
		return true, "suspicious link/invite"
	end
	return false, nil
end
 
local FeedbackAsciiMap = {
	["á"] = "a", ["à"] = "a", ["ã"] = "a", ["â"] = "a", ["ä"] = "a",
	["Á"] = "A", ["À"] = "A", ["Ã"] = "A", ["Â"] = "A", ["Ä"] = "A",
	["é"] = "e", ["è"] = "e", ["ê"] = "e", ["ë"] = "e",
	["É"] = "E", ["È"] = "E", ["Ê"] = "E", ["Ë"] = "E",
	["í"] = "i", ["ì"] = "i", ["î"] = "i", ["ï"] = "i",
	["Í"] = "I", ["Ì"] = "I", ["Î"] = "I", ["Ï"] = "I",
	["ó"] = "o", ["ò"] = "o", ["õ"] = "o", ["ô"] = "o", ["ö"] = "o",
	["Ó"] = "O", ["Ò"] = "O", ["Õ"] = "O", ["Ô"] = "O", ["Ö"] = "O",
	["ú"] = "u", ["ù"] = "u", ["û"] = "u", ["ü"] = "u",
	["Ú"] = "U", ["Ù"] = "U", ["Û"] = "U", ["Ü"] = "U",
	["ç"] = "c", ["Ç"] = "C", ["ñ"] = "n", ["Ñ"] = "N",
	["°"] = " ", ["º"] = " ", ["ª"] = " ",
}
 
local FeedbackAllowedChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 .,!?;:()[]{}@#%&*+-=/_\"'"
 
local function SanitizeFeedbackText(text)
	if not text or text == "" then
		return "_No message_"
	end
 
	text = NormalizeFeedbackText(text)
 
	local hasEvasion, evasionType = DetectFeedbackEvasion(text)
	if hasEvasion then
		return "[Message blocked - " .. evasionType .. "]"
	end
 
	text = text:gsub("@everyone", "@\226\128\139everyone")
	text = text:gsub("@here", "@\226\128\139here")
	text = text:gsub("<@!?(%d+)>", "[user]")
	text = text:gsub("<@&(%d+)>", "[role]")
 
	text = text:gsub("d[iI][sS][cC][oO][rR][dD]%.?[gG][gG]%s*/?%s*[%w%-_]+", "[invite removed]")
	text = text:gsub("d[iI][sS][cC][oO][rR][dD]%.?[cC][oO][mM]%s*/?%s*[iI][nN][vV][iI][tT][eE]%s*/?%s*[%w%-_]+", "[invite removed]")
	text = text:gsub("https?%s*:%s*//%s*[%w%-%.]+%s*%.%s*[%w]+[%w%-%./?=&%%]*", "[link removed]")
	text = text:gsub("www%s*%.%s*[%w%-]+%s*%.%s*[%w]+", "[link removed]")
	text = text:gsub("t[eE][lL][eE][gG][rR][aA][mM]%.?%s*[mM][eE]%s*/%s*[%w%-_]+", "[invite removed]")
 
	for old, new in pairs(FeedbackAsciiMap) do
		text = text:gsub(old, new)
	end
 
	local cleaned = ""
	for i = 1, #text do
		local char = text:sub(i, i)
		if FeedbackAllowedChars:find(char, 1, true) then
			cleaned = cleaned .. char
		else
			cleaned = cleaned .. " "
		end
	end
	text = cleaned
 
	text = text:gsub("%s+", " ")
	text = text:gsub("^%s+", "")
	text = text:gsub("%s+$", "")
 
	local hasEvasionAfter = DetectFeedbackEvasion(text)
	if hasEvasionAfter then
		return "[Message blocked - suspicious content]"
	end
 
	if #text > 500 then
		text = text:sub(1, 500) .. "..."
	end
 
	return text
end
 
function NullUI:SanitizeText(text, opts)
	opts = opts or {}
	local maxLength = opts.MaxLength or 500
 
	if not text or text == "" then
		return "", false, nil
	end
 
	local normalized = NormalizeFeedbackText(tostring(text))
	local hasEvasion, evasionType = DetectFeedbackEvasion(normalized)
	if hasEvasion then
		return "", true, evasionType
	end
 
	local cleaned = SanitizeFeedbackText(text)
	if cleaned == "_No message_" then
		return "", false, nil
	end
	if cleaned:find("^%[Message blocked") then
		return "", true, "blocked content"
	end
 
	if #cleaned > maxLength then
		cleaned = cleaned:sub(1, maxLength)
	end
 
	return cleaned, false, nil
end
 
local FEEDBACK_WEBHOOK_COOLDOWN = 30
local LastFeedbackWebhookAt = 0
 
function NullUI:SendFeedbackWebhook(webhookUrl, stars, message, opts)
	opts = opts or {}
	stars = math.clamp(math.floor((stars or 0) + 0.5), 0, 5)
 
	local now = os.clock()
	if now - LastFeedbackWebhookAt < FEEDBACK_WEBHOOK_COOLDOWN then
		self:Notify({
			Title = "Feedback",
			Text  = string.format(
				"Please wait %ds before sending more feedback.",
				math.ceil(FEEDBACK_WEBHOOK_COOLDOWN - (now - LastFeedbackWebhookAt))
			),
			Type  = "warning",
			Duration = 3,
		})
		return false
	end
 
	if not webhookUrl or webhookUrl == "" then
		self:Notify({
			Title = "Feedback",
			Text  = "No webhook configured.",
			Type  = "warning",
			Duration = 4,
		})
		return false
	end
 
	local httpRequest = (syn and syn.request) or http_request or request
	if not httpRequest then
		self:Notify({
			Title = "Feedback",
			Text  = "Your executor doesn't support HTTP requests.",
			Type  = "error",
			Duration = 4,
		})
		return false
	end
 
	local normalizedMessage = NormalizeFeedbackText(message or "")
	local hasEvasion = DetectFeedbackEvasion(normalizedMessage)
	local cleanMessage = SanitizeFeedbackText(message)
 
	if hasEvasion or cleanMessage:find("blocked") then
		LastFeedbackWebhookAt = now
		self:Notify({
			Title = "Blocked",
			Text = "Unallowed content detected.",
			Type = "error",
			Duration = 4,
		})
		return false
	end
 
	LastFeedbackWebhookAt = now
 
	local starDisplay = string.rep("\226\152\133", stars) .. string.rep("\226\152\134", 5 - stars)
	local embedColor = opts.Color or 0xFFC440
	local hasInvite = cleanMessage:find("%[invite removed%]") or cleanMessage:find("%[link removed%]")
 
	local body = HttpService:JSONEncode({
		allowed_mentions = { parse = {} },
		embeds = {{
			title = opts.Title or "New UI Feedback",
			description = starDisplay .. "  (" .. stars .. "/5)",
			color = embedColor,
			fields = {
				{ name = "Message", value = cleanMessage, inline = false },
			},
			footer = { text = hasInvite and "Invites removed" or "Submitted anonymously" },
			timestamp = DateTime.now():ToIsoDate(),
		}},
	})
 
	task.spawn(function()
		local ok, err = pcall(httpRequest, {
			Url = webhookUrl,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = body,
		})
		self:Notify({
			Title = ok and "Feedback Sent" or "Failed to Send",
			Text  = ok and "Thanks for rating the UI!" or tostring(err),
			Type  = ok and "success" or "error",
			Duration = 3,
		})
	end)
 
	return true
end
 
local function BuildFeedbackRow(parent, layoutOrder, rowH, placeholder, buttonIcon)
	local row = Instance.new("Frame")
	row.Name = "Feedback"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, rowH)
	row.LayoutOrder = layoutOrder
	row.ZIndex = Z.Content + 1
	row.Parent = parent
 
	local pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.BackgroundColor3 = Color3.new(1, 1, 1)
	pill.BackgroundTransparency = 0.95
	pill.BorderSizePixel = 0
	pill.Size = UDim2.new(1, -(rowH + 6), 1, 0)
	pill.ZIndex = Z.Content + 1
	pill.Parent = row
	Corner(pill, 9)
	local pillStroke = Stroke(pill, Color3.new(1, 1, 1), 1, 0.9)
 
	local pillPad = Instance.new("UIPadding")
	pillPad.PaddingLeft = UDim.new(0, 10)
	pillPad.PaddingRight = UDim.new(0, 10)
	pillPad.Parent = pill
 
	local box = Instance.new("TextBox")
	box.BackgroundTransparency = 1
	box.ClearTextOnFocus = false
	box.FontFace = NullUI.Theme.FontRegular
	box.PlaceholderText = placeholder or "Give us some feedback!"
	box.PlaceholderColor3 = Color3.fromRGB(120, 120, 122)
	box.Text = ""
	box.TextColor3 = NullUI.Theme.Text
	box.TextSize = 13
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.TextYAlignment = Enum.TextYAlignment.Center
	box.TextTruncate = Enum.TextTruncate.AtEnd
	box.ClipsDescendants = true
	box.Size = UDim2.fromScale(1, 1)
	box.ZIndex = Z.Content + 2
	box.Parent = pill
 
	box.Focused:Connect(function()
		Tween(pillStroke, { Color = NullUI.Theme.Accent, Transparency = 0.3 }, 0.15)
	end)
	box.FocusLost:Connect(function()
		Tween(pillStroke, { Color = Color3.new(1, 1, 1), Transparency = 0.9 }, 0.15)
	end)
 
	local sendBtn = Instance.new("TextButton")
	sendBtn.Name = "Send"
	sendBtn.Text = ""
	sendBtn.AutoButtonColor = false
	sendBtn.BackgroundColor3 = Color3.new(1, 1, 1)
	sendBtn.BackgroundTransparency = 0.9
	sendBtn.BorderSizePixel = 0
	sendBtn.AnchorPoint = Vector2.new(1, 0)
	sendBtn.Position = UDim2.new(1, 0, 0, 0)
	sendBtn.Size = UDim2.fromOffset(rowH, rowH)
	sendBtn.ZIndex = Z.Content + 1
	sendBtn.Parent = row
	Corner(sendBtn, 9)
 
	local sendIcon = Instance.new("ImageLabel")
	sendIcon.BackgroundTransparency = 1
	sendIcon.Image = ResolveIcon(buttonIcon or "send")
	sendIcon.ImageColor3 = NullUI.Theme.Text
	sendIcon.Size = UDim2.fromOffset(12, 12)
	sendIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	sendIcon.Position = UDim2.fromScale(0.5, 0.5)
	sendIcon.ZIndex = Z.Content + 2
	sendIcon.Parent = sendBtn
 
	sendBtn.MouseEnter:Connect(function() Tween(sendBtn, { BackgroundTransparency = 0.8 }, 0.12) end)
	sendBtn.MouseLeave:Connect(function() Tween(sendBtn, { BackgroundTransparency = 0.9 }, 0.12) end)
 
	return { Row = row, Box = box, SendBtn = sendBtn }
end
 
function Tab:AddRating(opts)
	opts = opts or {}
	local maxStars = math.max(1, opts.MaxStars or 5)
	local starColor = opts.StarColor or Color3.fromRGB(255, 196, 64)
	local hasTitle = opts.Title and opts.Title ~= ""
 
	local card = BaseCard(self._page, 10)
	card.AutomaticSize = Enum.AutomaticSize.Y
 
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = card
 
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = card
 
	if hasTitle then
		local titleLabel = Instance.new("TextLabel")
		titleLabel.BackgroundTransparency = 1
		titleLabel.FontFace = NullUI.Theme.Font
		titleLabel.Text = opts.Title
		titleLabel.TextColor3 = NullUI.Theme.Text
		titleLabel.TextSize = 14
		titleLabel.TextXAlignment = Enum.TextXAlignment.Left
		titleLabel.Size = UDim2.new(1, 0, 0, 16)
		titleLabel.LayoutOrder = 1
		titleLabel.ZIndex = Z.Content + 1
		titleLabel.Parent = card
 
		self._window:_RegisterSearchable(self, opts.Title, card)
	end
 
	local starBar = BuildStarRow(card, 2, maxStars, starColor, 20, opts.Default)
	local feedback = BuildFeedbackRow(card, 3, 26, opts.Placeholder, opts.ButtonIcon)
 
	local clearOnSubmit = opts.ClearOnSubmit ~= false
	feedback.SendBtn.MouseButton1Click:Connect(function()
		local selected = starBar.Get()
		if selected <= 0 then
			starBar.Nudge()
			return
		end
		if opts.Callback then task.spawn(opts.Callback, selected, feedback.Box.Text) end
		if opts.WebhookUrl then
			task.spawn(function()
				NullUI:SendFeedbackWebhook(opts.WebhookUrl, selected, feedback.Box.Text, opts.WebhookOptions)
			end)
		end
		if clearOnSubmit then
			feedback.Box.Text = ""
			starBar.Set(opts.Default or 0)
		end
	end)
 
	return {
		Instance = card,
		Get = function() return starBar.Get(), feedback.Box.Text end,
		Set = function(_, newStars, newText)
			starBar.Set(newStars)
			if newText ~= nil then feedback.Box.Text = newText end
		end,
		Destroy = function() card:Destroy() end,
	}
end
 
function Tab:AddButton(opts)
	opts = opts or {}
	local hasDesc = opts.Description and opts.Description ~= ""
	local height = hasDesc and 56 or 44
	local card = BaseCard(self._page, height)
 
	local textX = AddLeadingIcon(card, opts.Icon, height)
	AddTitleDesc(card, textX, 44, opts.Text or "Button", opts.Description, height)
	self._window:_RegisterSearchable(self, opts.Text or "Button", card)
 
	local chev = Instance.new("ImageLabel")
	chev.BackgroundTransparency = 1
	chev.Image = ResolveIcon("chevron-right")
	chev.ImageColor3 = NullUI.Theme.TextDim
	chev.Size = UDim2.fromOffset(14, 14)
	chev.AnchorPoint = Vector2.new(1, 0.5)
	chev.Position = UDim2.new(1, -16, 0.5, 0)
	chev.ZIndex = Z.Content + 1
	chev.Parent = card
 
	local click = Instance.new("TextButton")
	click.Text = ""
	click.AutoButtonColor = false
	click.BackgroundTransparency = 1
	click.Size = UDim2.fromScale(1, 1)
	click.ZIndex = Z.Content + 3
	click.Parent = card
 
	click.MouseEnter:Connect(function()
		Tween(card, { BackgroundTransparency = 0.9 }, 0.15)
		Tween(chev, { ImageColor3 = NullUI.Theme.Text, Position = UDim2.new(1, -12, 0.5, 0) }, 0.15)
	end)
	click.MouseLeave:Connect(function()
		Tween(card, { BackgroundTransparency = 0.96 }, 0.15)
		Tween(chev, { ImageColor3 = NullUI.Theme.TextDim, Position = UDim2.new(1, -16, 0.5, 0) }, 0.15)
	end)
	click.MouseButton1Click:Connect(function()
		Tween(card, { BackgroundTransparency = 0.8 }, 0.08)
		Tween(chev, { ImageColor3 = NullUI.Theme.Accent }, 0.08)
		task.delay(0.08, function()
			if not card.Parent then return end
			Tween(card, { BackgroundTransparency = 0.9 }, 0.15)
			Tween(chev, { ImageColor3 = NullUI.Theme.Text }, 0.15)
		end)
		if opts.Callback then task.spawn(opts.Callback) end
	end)
 
	return {
		Instance = card,
		Destroy = function() card:Destroy() end,
	}
end
 
function Tab:AddCard(opts)
	opts = opts or {}
	local hasDesc = opts.Description and opts.Description ~= ""
	local hasImage = (opts.Image and opts.Image ~= "") or opts.UserId ~= nil
	local hasButton = opts.ButtonText ~= nil and opts.ButtonText ~= ""
	local BUTTON_H, BUTTON_GAP, BUTTON_MARGIN = 32, 6, 4
	local buttonReserve = hasButton and (BUTTON_GAP + BUTTON_H + BUTTON_MARGIN) or 0
 
	local hasRating = type(opts.Rating) == "table"
	local RATING_LABEL_H, RATING_STAR_H, RATING_INPUT_H = 14, 20, 26
	local RATING_ROW_GAP, RATING_TOP_GAP, RATING_BOTTOM_MARGIN = 6, 10, 8
	local ratingHasTitle = hasRating and opts.Rating.Title and opts.Rating.Title ~= ""
	local ratingBlockH = 0
	if hasRating then
		local bodyH = (ratingHasTitle and (RATING_LABEL_H + RATING_ROW_GAP) or 0)
			+ RATING_STAR_H + RATING_ROW_GAP + RATING_INPUT_H
		ratingBlockH = RATING_TOP_GAP + bodyH + RATING_BOTTOM_MARGIN
	end
 
	local extraBottom = buttonReserve + ratingBlockH
	local topHeight = hasDesc and 56 or 44
	local height = topHeight + extraBottom
	local imgSize, imgPad = 34, 10
 
	local card = BaseCard(self._page, height)
	local textX = 14
 
	if hasImage then
		local imgHolder = Instance.new("Frame")
		imgHolder.Name = "Image"
		imgHolder.AnchorPoint = Vector2.new(0, 0.5)
		imgHolder.Position = UDim2.fromOffset(10, topHeight / 2)
		imgHolder.Size = UDim2.fromOffset(imgSize, imgSize)
		imgHolder.BackgroundTransparency = 1
		imgHolder.BorderSizePixel = 0
		imgHolder.ClipsDescendants = true
		imgHolder.ZIndex = Z.Content + 1
		imgHolder.Parent = card
		Corner(imgHolder, NullUI.Theme.CornerRadiusSm)
		Stroke(imgHolder, Color3.new(1, 1, 1), 1, 0.85)
 
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.ScaleType = Enum.ScaleType.Crop
		img.Size = UDim2.fromScale(1, 1)
		img.ZIndex = Z.Content + 2
		img.Parent = imgHolder
		Corner(img, NullUI.Theme.CornerRadiusSm)
 
		if opts.UserId then
			task.spawn(function()
				local ok, content = pcall(
					Players.GetUserThumbnailAsync,
					Players,
					opts.UserId,
					opts.ThumbnailType or Enum.ThumbnailType.HeadShot,
					opts.ThumbnailSize or Enum.ThumbnailSize.Size100x100
				)
				if ok and content and img.Parent then
					img.Image = content
				end
			end)
		else
			img.Image = ResolveIcon(opts.Image)
		end
 
		textX = 10 + imgSize + imgPad
	end
 
	local rightReserve = opts.Callback and 44 or 14
	AddTitleDesc(card, textX, rightReserve, opts.Title or "Card", opts.Description, topHeight, extraBottom)
	self._window:_RegisterSearchable(self, opts.Title or "Card", card)
 
	if opts.Callback then
		local chev = Instance.new("ImageLabel")
		chev.BackgroundTransparency = 1
		chev.Image = ResolveIcon("chevron-right")
		chev.ImageColor3 = NullUI.Theme.TextDim
		chev.Size = UDim2.fromOffset(14, 14)
		chev.AnchorPoint = Vector2.new(1, 0.5)
		chev.Position = UDim2.new(1, -16, 0.5, 0)
		chev.ZIndex = Z.Content + 1
		chev.Parent = card
 
		local click = Instance.new("TextButton")
		click.Text = ""
		click.AutoButtonColor = false
		click.BackgroundTransparency = 1
		click.Size = UDim2.fromScale(1, 1)
		click.ZIndex = Z.Content + 3
		click.Parent = card
 
		click.MouseEnter:Connect(function()
			Tween(card, { BackgroundTransparency = 0.9 }, 0.15)
			Tween(chev, { ImageColor3 = NullUI.Theme.Text, Position = UDim2.new(1, -12, 0.5, 0) }, 0.15)
		end)
		click.MouseLeave:Connect(function()
			Tween(card, { BackgroundTransparency = 0.96 }, 0.15)
			Tween(chev, { ImageColor3 = NullUI.Theme.TextDim, Position = UDim2.new(1, -16, 0.5, 0) }, 0.15)
		end)
		click.MouseButton1Click:Connect(function()
			Tween(card, { BackgroundTransparency = 0.8 }, 0.08)
			task.delay(0.08, function()
				if card.Parent then Tween(card, { BackgroundTransparency = 0.9 }, 0.15) end
			end)
			task.spawn(opts.Callback)
		end)
	end
 
	if hasButton then
		local footerBtn = Instance.new("TextButton")
		footerBtn.Name = "FooterButton"
		footerBtn.Text = ""
		footerBtn.AutoButtonColor = false
		footerBtn.BackgroundColor3 = Color3.new(1, 1, 1)
		footerBtn.BackgroundTransparency = 0.85
		footerBtn.BorderSizePixel = 0
		footerBtn.Position = UDim2.new(0, 10, 1, -(BUTTON_H + BUTTON_MARGIN))
		footerBtn.Size = UDim2.new(1, -20, 0, BUTTON_H)
		footerBtn.ZIndex = Z.Content + 1
		footerBtn.Parent = card
		Corner(footerBtn, 8)
		local footerStroke = Stroke(footerBtn, Color3.new(1, 1, 1), 1, 0.85)
 
		local footerLabel = Instance.new("TextLabel")
		footerLabel.BackgroundTransparency = 1
		footerLabel.FontFace = NullUI.Theme.Font
		footerLabel.Text = opts.ButtonText
		footerLabel.TextColor3 = NullUI.Theme.Text
		footerLabel.TextSize = 13
		footerLabel.Size = UDim2.fromScale(1, 1)
		footerLabel.ZIndex = Z.Content + 2
		footerLabel.Parent = footerBtn
 
		footerBtn.MouseEnter:Connect(function()
			Tween(footerBtn, { BackgroundTransparency = 0.7 }, 0.12)
			Tween(footerStroke, { Transparency = 0.7 }, 0.12)
		end)
		footerBtn.MouseLeave:Connect(function()
			Tween(footerBtn, { BackgroundTransparency = 0.85 }, 0.12)
			Tween(footerStroke, { Transparency = 0.85 }, 0.12)
		end)
		footerBtn.MouseButton1Click:Connect(function()
			Tween(footerBtn, { BackgroundTransparency = 0.55 }, 0.08)
			task.delay(0.08, function()
				if footerBtn.Parent then Tween(footerBtn, { BackgroundTransparency = 0.7 }, 0.15) end
			end)
			if opts.ButtonCallback then task.spawn(opts.ButtonCallback) end
		end)
	end
 
	local ratingBar
	if hasRating then
		local ratingOpts = opts.Rating
 
		local ratingHolder = Instance.new("Frame")
		ratingHolder.Name = "Rating"
		ratingHolder.BackgroundTransparency = 1
		ratingHolder.Position = UDim2.new(0, 10, 1, -(ratingBlockH + buttonReserve))
		ratingHolder.Size = UDim2.new(1, -20, 0, ratingBlockH - RATING_BOTTOM_MARGIN)
		ratingHolder.ZIndex = Z.Content + 1
		ratingHolder.Parent = card
 
		local divider = Instance.new("Frame")
		divider.Name = "Divider"
		divider.BackgroundColor3 = Color3.new(1, 1, 1)
		divider.BackgroundTransparency = 0.94
		divider.BorderSizePixel = 0
		divider.Size = UDim2.new(1, 0, 0, 1)
		divider.ZIndex = Z.Content + 1
		divider.Parent = ratingHolder
 
		local ratingBody = Instance.new("Frame")
		ratingBody.BackgroundTransparency = 1
		ratingBody.Position = UDim2.new(0, 0, 0, RATING_TOP_GAP)
		ratingBody.Size = UDim2.new(1, 0, 1, -RATING_TOP_GAP)
		ratingBody.ZIndex = Z.Content + 1
		ratingBody.Parent = ratingHolder
 
		local ratingLayout = Instance.new("UIListLayout")
		ratingLayout.Padding = UDim.new(0, RATING_ROW_GAP)
		ratingLayout.SortOrder = Enum.SortOrder.LayoutOrder
		ratingLayout.Parent = ratingBody
 
		if ratingHasTitle then
			local ratingLabel = Instance.new("TextLabel")
			ratingLabel.BackgroundTransparency = 1
			ratingLabel.FontFace = NullUI.Theme.Font
			ratingLabel.Text = ratingOpts.Title
			ratingLabel.TextColor3 = NullUI.Theme.Text
			ratingLabel.TextSize = 13
			ratingLabel.TextXAlignment = Enum.TextXAlignment.Left
			ratingLabel.Size = UDim2.new(1, 0, 0, RATING_LABEL_H)
			ratingLabel.LayoutOrder = 1
			ratingLabel.ZIndex = Z.Content + 1
			ratingLabel.Parent = ratingBody
		end
 
		local starBar = BuildStarRow(ratingBody, 2, math.max(1, ratingOpts.MaxStars or 5),
			ratingOpts.StarColor or Color3.fromRGB(255, 196, 64), RATING_STAR_H, ratingOpts.Default)
		local feedback = BuildFeedbackRow(ratingBody, 3, RATING_INPUT_H, ratingOpts.Placeholder, ratingOpts.ButtonIcon)
 
		local clearOnSubmit = ratingOpts.ClearOnSubmit ~= false
		feedback.SendBtn.MouseButton1Click:Connect(function()
			local sel = starBar.Get()
			if sel <= 0 then
				starBar.Nudge()
				return
			end
			if ratingOpts.Callback then task.spawn(ratingOpts.Callback, sel, feedback.Box.Text) end
			if ratingOpts.WebhookUrl then
				task.spawn(function()
					NullUI:SendFeedbackWebhook(ratingOpts.WebhookUrl, sel, feedback.Box.Text, ratingOpts.WebhookOptions)
				end)
			end
			if clearOnSubmit then
				feedback.Box.Text = ""
				starBar.Set(ratingOpts.Default or 0)
			end
		end)
 
		ratingBar = {
			Get = function() return starBar.Get(), feedback.Box.Text end,
			Set = function(newStars, newText)
				starBar.Set(newStars)
				if newText ~= nil then feedback.Box.Text = newText end
			end,
		}
	end
 
	return {
		Instance = card,
		Rating = ratingBar,
		Destroy = function() card:Destroy() end,
	}
end
 
local CHANGELOG_TYPES = {
	Added   = { Color = Color3.fromRGB(120, 210, 140), Icon = "plus" },
	Fixed   = { Color = Color3.fromRGB(120, 170, 255), Icon = "wrench" },
	Changed = { Color = Color3.fromRGB(255, 190, 90),  Icon = "refresh-cw" },
	Removed = { Color = Color3.fromRGB(230, 120, 120), Icon = "minus" },
}
 
function Tab:AddChangelogEntry(opts)
	opts = opts or {}
	local version = opts.Version or "Update"
	local date = opts.Date
	local changes = opts.Changes or {}
 
	local PAD = 12
	local HEADER_H = 18
	local ROW_H = 22
	local ROW_GAP = 2
	local height = PAD * 2 + HEADER_H + (#changes > 0 and 8 or 0)
 
	local card = BaseCard(self._page, height)
	card.AutomaticSize = Enum.AutomaticSize.Y
	self._window:_RegisterSearchable(self, version, card)
 
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, PAD)
	pad.PaddingBottom = UDim.new(0, PAD)
	pad.PaddingLeft = UDim.new(0, PAD)
	pad.PaddingRight = UDim.new(0, PAD)
	pad.Parent = card
 
	local versionLabel = Instance.new("TextLabel")
	versionLabel.BackgroundTransparency = 1
	versionLabel.FontFace = NullUI.Theme.Font
	versionLabel.Text = version
	versionLabel.TextColor3 = NullUI.Theme.Text
	versionLabel.TextSize = 14
	versionLabel.TextXAlignment = Enum.TextXAlignment.Left
	versionLabel.TextTruncate = Enum.TextTruncate.AtEnd
	versionLabel.Size = UDim2.new(1, date and -90 or 0, 0, HEADER_H)
	versionLabel.ZIndex = Z.Content + 1
	versionLabel.Parent = card
 
	if date then
		local dateLabel = Instance.new("TextLabel")
		dateLabel.BackgroundTransparency = 1
		dateLabel.FontFace = NullUI.Theme.FontRegular
		dateLabel.Text = date
		dateLabel.TextColor3 = NullUI.Theme.TextDim
		dateLabel.TextSize = 12
		dateLabel.TextXAlignment = Enum.TextXAlignment.Right
		dateLabel.AnchorPoint = Vector2.new(1, 0)
		dateLabel.Position = UDim2.new(1, 0, 0, 2)
		dateLabel.Size = UDim2.fromOffset(90, HEADER_H)
		dateLabel.ZIndex = Z.Content + 1
		dateLabel.Parent = card
	end
 
	local rowsHolder = Instance.new("Frame")
	rowsHolder.Name = "Rows"
	rowsHolder.BackgroundTransparency = 1
	rowsHolder.Position = UDim2.fromOffset(0, HEADER_H + 8)
	rowsHolder.Size = UDim2.new(1, 0, 0, 0)
	rowsHolder.AutomaticSize = Enum.AutomaticSize.Y
	rowsHolder.ZIndex = Z.Content + 1
	rowsHolder.Parent = card
 
	local rowsLayout = Instance.new("UIListLayout")
	rowsLayout.FillDirection = Enum.FillDirection.Vertical
	rowsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowsLayout.Padding = UDim.new(0, ROW_GAP)
	rowsLayout.Parent = rowsHolder
 
	for i, change in ipairs(changes) do
		local kind = CHANGELOG_TYPES[change.Type] and change.Type or "Changed"
		local meta = CHANGELOG_TYPES[kind]
 
		local row = Instance.new("Frame")
		row.Name = "Row" .. i
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, ROW_H)
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.LayoutOrder = i * 2 - 1
		row.ZIndex = Z.Content + 1
		row.Parent = rowsHolder
 
		local pill = Instance.new("Frame")
		pill.BackgroundColor3 = meta.Color
		pill.BackgroundTransparency = 0.85
		pill.BorderSizePixel = 0
		pill.AnchorPoint = Vector2.zero
		pill.Position = UDim2.fromOffset(0, 1)
		pill.Size = UDim2.fromOffset(66, 18)
		pill.ZIndex = Z.Content + 2
		pill.Parent = row
		Corner(pill, 5)
 
		local pillLayout = Instance.new("UIListLayout")
		pillLayout.FillDirection = Enum.FillDirection.Horizontal
		pillLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		pillLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		pillLayout.Padding = UDim.new(0, 3)
		pillLayout.Parent = pill
 
		local pillIcon = Instance.new("ImageLabel")
		pillIcon.BackgroundTransparency = 1
		pillIcon.Image = ResolveIcon(meta.Icon)
		pillIcon.ImageColor3 = meta.Color
		pillIcon.Size = UDim2.fromOffset(9, 9)
		pillIcon.LayoutOrder = 1
		pillIcon.ZIndex = Z.Content + 3
		pillIcon.Parent = pill
 
		local pillLabel = Instance.new("TextLabel")
		pillLabel.BackgroundTransparency = 1
		pillLabel.FontFace = NullUI.Theme.Font
		pillLabel.Text = string.upper(kind)
		pillLabel.TextColor3 = meta.Color
		pillLabel.TextSize = 9
		pillLabel.AutomaticSize = Enum.AutomaticSize.X
		pillLabel.Size = UDim2.fromOffset(0, 12)
		pillLabel.LayoutOrder = 2
		pillLabel.ZIndex = Z.Content + 3
		pillLabel.Parent = pill
 
		local changeLabel = Instance.new("TextLabel")
		changeLabel.BackgroundTransparency = 1
		changeLabel.FontFace = NullUI.Theme.FontRegular
		changeLabel.Text = tostring(change.Text or "")
		changeLabel.TextColor3 = NullUI.Theme.TextDim
		changeLabel.TextSize = 12
		changeLabel.TextXAlignment = Enum.TextXAlignment.Left
		changeLabel.TextYAlignment = Enum.TextYAlignment.Top
		changeLabel.TextWrapped = true
		changeLabel.TextTruncate = Enum.TextTruncate.None
		changeLabel.AutomaticSize = Enum.AutomaticSize.Y
		changeLabel.Position = UDim2.fromOffset(76, 0)
		changeLabel.Size = UDim2.new(1, -76, 0, ROW_H)
		changeLabel.ZIndex = Z.Content + 2
		changeLabel.Parent = row
 
		local function alignChangelogRow()
			local isMultiline = changeLabel.TextBounds.Y > 18
			if isMultiline then
				pill.AnchorPoint = Vector2.zero
				pill.Position = UDim2.fromOffset(0, 1)
				changeLabel.TextYAlignment = Enum.TextYAlignment.Top
			else
				pill.AnchorPoint = Vector2.new(0, 0.5)
				pill.Position = UDim2.new(0, 0, 0.5, 0)
				changeLabel.TextYAlignment = Enum.TextYAlignment.Center
			end
		end
		changeLabel:GetPropertyChangedSignal("TextBounds"):Connect(alignChangelogRow)
		task.defer(alignChangelogRow)
 
		if i < #changes then
			local separator = Instance.new("Frame")
			separator.Name = "Separator" .. i
			separator.BackgroundColor3 = Color3.new(1, 1, 1)
			separator.BackgroundTransparency = 0.93
			separator.BorderSizePixel = 0
			separator.Size = UDim2.new(1, 0, 0, 1)
			separator.LayoutOrder = i * 2
			separator.ZIndex = Z.Content + 1
			separator.Parent = rowsHolder
		end
	end
 
	return { Instance = card, Destroy = function() card:Destroy() end }
end
 
function Tab:AddLoadoutGroup(opts)
	opts = opts or {}
	local title = opts.Title or "Loadout"
	local color = opts.Color or NullUI.Theme.Accent
	local icons = opts.Icons or {}
	local buttonText = opts.ButtonText or "Equip"
 
	local PAD = 12
	local HEADER_H = 16
	local ICON_SIZE = 44
	local ROW_GAP = 8
	local BUTTON_H = 30
	local GAP1, GAP2 = 8, 10
	local height = PAD * 2 + HEADER_H + GAP1 + ICON_SIZE + GAP2 + BUTTON_H
 
	local card = BaseCard(self._page, height)
	self._window:_RegisterSearchable(self, title, card)
 
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, PAD)
	pad.PaddingBottom = UDim.new(0, PAD)
	pad.PaddingLeft = UDim.new(0, PAD)
	pad.PaddingRight = UDim.new(0, PAD)
	pad.Parent = card
 
	local header = Instance.new("Frame")
	header.BackgroundTransparency = 1
	header.Position = UDim2.fromOffset(0, 0)
	header.Size = UDim2.new(1, 0, 0, HEADER_H)
	header.ZIndex = Z.Content + 1
	header.Parent = card
 
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0, 0.5)
	dot.Position = UDim2.new(0, 1, 0.5, 0)
	dot.Size = UDim2.fromOffset(6, 6)
	dot.BackgroundColor3 = color
	dot.BorderSizePixel = 0
	dot.ZIndex = Z.Content + 2
	dot.Parent = header
	Corner(dot, 3)
 
	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.FontFace = NullUI.Theme.Font
	titleLabel.Text = string.upper(title)
	titleLabel.TextColor3 = NullUI.Theme.TextDim
	titleLabel.TextSize = 12
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Position = UDim2.fromOffset(15, 0)
	titleLabel.Size = UDim2.new(1, -15, 1, 0)
	titleLabel.ZIndex = Z.Content + 2
	titleLabel.Parent = header
 
	local iconsRow = Instance.new("Frame")
	iconsRow.Name = "Icons"
	iconsRow.BackgroundTransparency = 1
	iconsRow.Position = UDim2.fromOffset(0, HEADER_H + GAP1)
	iconsRow.Size = UDim2.new(1, 0, 0, ICON_SIZE)
	iconsRow.ZIndex = Z.Content + 1
	iconsRow.Parent = card
 
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.Padding = UDim.new(0, ROW_GAP)
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Parent = iconsRow
 
	for i, iconAsset in ipairs(icons) do
		local slot = Instance.new("Frame")
		slot.Name = "Slot" .. i
		slot.BackgroundColor3 = Color3.new(1, 1, 1)
		slot.BackgroundTransparency = 0.95
		slot.BorderSizePixel = 0
		slot.ClipsDescendants = true
		slot.Size = UDim2.new(1 / 3, -ROW_GAP * 2 / 3, 1, 0)
		slot.LayoutOrder = i
		slot.ZIndex = Z.Content + 2
		slot.Parent = iconsRow
		Corner(slot, NullUI.Theme.CornerRadiusSm)
		Stroke(slot, Color3.new(1, 1, 1), 1, 0.94)
 
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Image = ResolveIcon(iconAsset)
		img.ImageColor3 = color
		img.ScaleType = Enum.ScaleType.Fit
		img.Position = UDim2.fromOffset(8, 8)
		img.Size = UDim2.new(1, -16, 1, -16)
		img.ZIndex = Z.Content + 3
		img.Parent = slot
	end
 
	local btn = Instance.new("TextButton")
	btn.Name = "EquipButton"
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.BackgroundColor3 = Color3.new(1, 1, 1)
	btn.BackgroundTransparency = 0.92
	btn.BorderSizePixel = 0
	btn.Position = UDim2.fromOffset(0, HEADER_H + GAP1 + ICON_SIZE + GAP2)
	btn.Size = UDim2.new(1, 0, 0, BUTTON_H)
	btn.ZIndex = Z.Content + 1
	btn.Parent = card
	Corner(btn, 8)
 
	local btnLabel = Instance.new("TextLabel")
	btnLabel.BackgroundTransparency = 1
	btnLabel.FontFace = NullUI.Theme.Font
	btnLabel.Text = buttonText
	btnLabel.TextColor3 = NullUI.Theme.Text
	btnLabel.TextSize = 12
	btnLabel.Size = UDim2.fromScale(1, 1)
	btnLabel.ZIndex = Z.Content + 2
	btnLabel.Parent = btn
 
	btn.MouseEnter:Connect(function()
		Tween(btn, { BackgroundTransparency = 0.85 }, 0.12)
	end)
	btn.MouseLeave:Connect(function()
		Tween(btn, { BackgroundTransparency = 0.92 }, 0.12)
	end)
	btn.MouseButton1Click:Connect(function()
		Tween(btn, { BackgroundTransparency = 0.7 }, 0.08)
		task.delay(0.08, function()
			if btn.Parent then Tween(btn, { BackgroundTransparency = 0.85 }, 0.15) end
		end)
		if opts.Callback then task.spawn(opts.Callback) end
	end)
 
	return { Instance = card, Destroy = function() card:Destroy() end }
end
 
function Tab:AddInfoGrid(opts)
	opts = opts or {}
	local title = opts.Title or "Info"
	local hasDesc = opts.Description and opts.Description ~= ""
	local items = opts.Items or {}
	local color = opts.Color
	local columns = opts.Columns or 2
 
	local PAD = 12
	local HEADER_H = hasDesc and 32 or 16
	local CHIP_H = 38
	local GRID_GAP = 8
	local rows = math.ceil(#items / columns)
	local gridH = rows > 0 and (rows * CHIP_H + (rows - 1) * GRID_GAP) or 0
	local height = PAD * 2 + HEADER_H + (rows > 0 and (10 + gridH) or 0)
 
	local card = BaseCard(self._page, height)
	self._window:_RegisterSearchable(self, title, card)
 
	local leftInset = 0
	if color then
		local accent = Instance.new("Frame")
		accent.Name = "Accent"
		accent.BackgroundColor3 = color
		accent.BorderSizePixel = 0
		accent.Size = UDim2.new(0, 3, 1, -12)
		accent.Position = UDim2.fromOffset(0, 6)
		accent.ZIndex = Z.Content + 1
		accent.Parent = card
		Corner(accent, 1.5)
		leftInset = 6
	end
 
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, PAD)
	pad.PaddingBottom = UDim.new(0, PAD)
	pad.PaddingLeft = UDim.new(0, PAD + leftInset)
	pad.PaddingRight = UDim.new(0, PAD)
	pad.Parent = card
 
	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.FontFace = NullUI.Theme.Font
	titleLabel.Text = title
	titleLabel.TextColor3 = NullUI.Theme.Text
	titleLabel.TextSize = 14
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	titleLabel.Position = UDim2.fromOffset(0, 0)
	titleLabel.Size = UDim2.new(1, 0, 0, 16)
	titleLabel.ZIndex = Z.Content + 1
	titleLabel.Parent = card
 
	if hasDesc then
		local descLabel = Instance.new("TextLabel")
		descLabel.BackgroundTransparency = 1
		descLabel.FontFace = NullUI.Theme.FontRegular
		descLabel.Text = opts.Description
		descLabel.TextColor3 = NullUI.Theme.TextDim
		descLabel.TextSize = 12
		descLabel.TextWrapped = true
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.TextYAlignment = Enum.TextYAlignment.Top
		descLabel.Position = UDim2.fromOffset(0, 18)
		descLabel.Size = UDim2.new(1, 0, 0, 14)
		descLabel.ZIndex = Z.Content + 1
		descLabel.Parent = card
	end
 
	local chipValues = {}
 
	if rows > 0 then
		local grid = Instance.new("Frame")
		grid.Name = "Grid"
		grid.BackgroundTransparency = 1
		grid.Position = UDim2.fromOffset(0, HEADER_H + 10)
		grid.Size = UDim2.new(1, 0, 0, gridH)
		grid.ZIndex = Z.Content + 1
		grid.Parent = card
 
		local gridLayout = Instance.new("UIGridLayout")
		gridLayout.CellPadding = UDim2.fromOffset(GRID_GAP, GRID_GAP)
		gridLayout.FillDirectionMaxCells = columns
		gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
		gridLayout.Parent = grid
 
		local function relayout()
			local w = grid.AbsoluteSize.X / GetUIScale()
			if w <= 0 then return end
			local cellW = (w - GRID_GAP * (columns - 1)) / columns
			gridLayout.CellSize = UDim2.fromOffset(cellW, CHIP_H)
		end
		grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
		task.defer(relayout)
 
		for i, item in ipairs(items) do
			local chip = Instance.new("Frame")
			chip.Name = "Chip" .. i
			chip.BackgroundColor3 = Color3.new(1, 1, 1)
			chip.BackgroundTransparency = 0.95
			chip.BorderSizePixel = 0
			chip.LayoutOrder = i
			chip.ZIndex = Z.Content + 2
			chip.Parent = grid
			Corner(chip, 6)
 
			local chipPad = Instance.new("UIPadding")
			chipPad.PaddingTop = UDim.new(0, 6)
			chipPad.PaddingLeft = UDim.new(0, 8)
			chipPad.PaddingRight = UDim.new(0, 8)
			chipPad.Parent = chip
 
			local labelLabel = Instance.new("TextLabel")
			labelLabel.BackgroundTransparency = 1
			labelLabel.FontFace = NullUI.Theme.Font
			labelLabel.Text = tostring(item.Label or "")
			labelLabel.TextColor3 = NullUI.Theme.Text
			labelLabel.TextSize = 12
			labelLabel.TextXAlignment = Enum.TextXAlignment.Left
			labelLabel.TextTruncate = Enum.TextTruncate.AtEnd
			labelLabel.Size = UDim2.new(1, 0, 0, 15)
			labelLabel.ZIndex = Z.Content + 3
			labelLabel.Parent = chip
 
			local valueLabel = Instance.new("TextLabel")
			valueLabel.Name = "Value"
			valueLabel.BackgroundTransparency = 1
			valueLabel.FontFace = NullUI.Theme.FontRegular
			valueLabel.Text = tostring(item.Value or "")
			valueLabel.TextColor3 = NullUI.Theme.TextDim
			valueLabel.TextSize = 11
			valueLabel.TextXAlignment = Enum.TextXAlignment.Left
			valueLabel.TextTruncate = Enum.TextTruncate.AtEnd
			valueLabel.Position = UDim2.fromOffset(0, 15)
			valueLabel.Size = UDim2.new(1, 0, 0, 12)
			valueLabel.ZIndex = Z.Content + 3
			valueLabel.Parent = chip
 
			if item.Label then chipValues[item.Label] = valueLabel end
		end
	end
 
	return {
		Instance = card,
		SetValue = function(_, label, value)
			local lbl = chipValues[label]
			if lbl then lbl.Text = tostring(value) end
		end,
		Destroy = function() card:Destroy() end,
	}
end
 
function Tab:AddSystemInfoGrid(opts)
	opts = opts or {}
	local Stats = game:GetService("Stats")
	local LocalPlayer = Players.LocalPlayer
 
	local runCount = BumpRunCount()
 
	local grid = self:AddInfoGrid({
		Title       = opts.Title or "System Info",
		Description = opts.Description,
		Color       = opts.Color,
		Columns     = opts.Columns or 2,
		Items = {
			{ Label = "FPS",           Value = "--" },
			{ Label = "Ping",          Value = "-- ms" },
			{ Label = "Executor",      Value = GetExecutorName() },
			{ Label = "Executions",    Value = tostring(runCount) },
			{ Label = "Server Region", Value = "Unknown" },
			{ Label = "Time of Day",   Value = "--:--" },
		},
	})
 
	local frames = 0
	local lastFpsUpdate = os.clock()
	self._janitor:Add(RunService.Heartbeat:Connect(function()
		frames = frames + 1
		local now = os.clock()
		local elapsed = now - lastFpsUpdate
		if elapsed >= 1 then
			grid:SetValue("FPS", math.floor(frames / elapsed + 0.5))
			frames = 0
			lastFpsUpdate = now
		end
	end))
 
	local alive = true
	self._janitor:Add(function() alive = false end)
 
	task.spawn(function()
		while alive and grid.Instance.Parent do
			pcall(function()
				local ping = 0
				pcall(function()
					ping = math.clamp(Stats.Network.ServerStatsItem["Data Ping"]:GetValue(), 0, 9999)
				end)
				grid:SetValue("Ping", math.floor(ping) .. " ms")
 
				local h = tonumber(os.date("%H"))
				local m = tonumber(os.date("%M"))
				grid:SetValue("Time of Day", FormatClock(h * 60 + m))
			end)
			task.wait(1)
		end
	end)
 
	task.spawn(function()
		local ok, region = pcall(function()
			return game:GetService("LocalizationService"):GetCountryRegionForPlayerAsync(LocalPlayer)
		end)
		if ok and region and alive then grid:SetValue("Server Region", region) end
	end)
 
	return grid
end
 
function Tab:AddActiveUsersGrid(opts)
	opts = opts or {}
	local service = opts.Service
	local interval = opts.Interval or 30
 
	local grid = self:AddInfoGrid({
		Title       = opts.Title or "Active Users",
		Description = opts.Description,
		Color       = opts.Color,
		Columns     = 1,
		Items = { { Label = "Active Now", Value = "--" } },
	})
 
	if not service then
		grid:SetValue("Active Now", "No Service configured")
		return grid
	end
 
	local alive = true
	self._janitor:Add(function() alive = false end)
 
	task.spawn(function()
		while alive and grid.Instance.Parent do
			service:Heartbeat()
			local count, err = service:GetActiveCount()
			if alive and grid.Instance.Parent then
				grid:SetValue("Active Now", count and tostring(count) or ("Error: " .. tostring(err)))
			end
			task.wait(interval)
		end
	end)
 
	return grid
end
 
function Tab:AddLeaderboard(opts)
	opts = opts or {}
	local jan = self._janitor
	local service = opts.Service
	local interval = opts.Interval or 30
	local limit = math.clamp(opts.Limit or 5, 1, 50)
	local title = opts.Title or "Leaderboard"
	local hasDesc = opts.Description and opts.Description ~= ""
 
	local PAD = 12
	local HEADER_H = hasDesc and 32 or 16
	local ROW_H, ROW_GAP = 44, 6
	local listY = PAD + HEADER_H + 12
	local listH = limit * ROW_H + (limit - 1) * ROW_GAP
	local totalHeight = listY + listH + PAD
 
	local container = Instance.new("Frame")
	container.Name = "Leaderboard"
	container.BackgroundColor3 = NullUI.Theme.Surface
	container.BackgroundTransparency = 0.35
	container.BorderSizePixel = 0
	container.ClipsDescendants = true
	container.Size = UDim2.new(1, 0, 0, totalHeight)
	container.ZIndex = Z.Content
	container.Parent = self._page
	Corner(container, NullUI.Theme.CornerRadiusSm)
	Stroke(container, Color3.new(1, 1, 1), 1, 0.92)
	self._window:_RegisterSearchable(self, title, container)
 
	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.FontFace = NullUI.Theme.Font
	titleLabel.Text = title
	titleLabel.TextColor3 = NullUI.Theme.Text
	titleLabel.TextSize = 14
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	titleLabel.Position = UDim2.fromOffset(PAD, PAD)
	titleLabel.Size = UDim2.new(1, -PAD * 2 - 32, 0, 16)
	titleLabel.ZIndex = Z.Content + 1
	titleLabel.Parent = container
 
	if hasDesc then
		local descLabel = Instance.new("TextLabel")
		descLabel.BackgroundTransparency = 1
		descLabel.FontFace = NullUI.Theme.FontRegular
		descLabel.Text = opts.Description
		descLabel.TextColor3 = NullUI.Theme.TextDim
		descLabel.TextSize = 12
		descLabel.TextWrapped = true
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.TextYAlignment = Enum.TextYAlignment.Top
		descLabel.Position = UDim2.fromOffset(PAD, PAD + 18)
		descLabel.Size = UDim2.new(1, -PAD * 2 - 32, 0, 14)
		descLabel.ZIndex = Z.Content + 1
		descLabel.Parent = container
	end
 
	local revealMe = opts.RevealByDefault == true
 
	local revealBtn = Instance.new("TextButton")
	revealBtn.Name = "RevealToggle"
	revealBtn.Text = ""
	revealBtn.AutoButtonColor = false
	revealBtn.BackgroundColor3 = Color3.new(1, 1, 1)
	revealBtn.BackgroundTransparency = 1
	revealBtn.BorderSizePixel = 0
	revealBtn.AnchorPoint = Vector2.new(1, 0)
	revealBtn.Position = UDim2.new(1, -PAD, 0, PAD - 4)
	revealBtn.Size = UDim2.fromOffset(24, 24)
	revealBtn.ZIndex = Z.Content + 2
	revealBtn.Parent = container
	Corner(revealBtn, 7)
 
	local revealIcon = Instance.new("ImageLabel")
	revealIcon.BackgroundTransparency = 1
	revealIcon.Image = ResolveIcon(revealMe and "eye" or "eye-off")
	revealIcon.ImageColor3 = NullUI.Theme.TextDim
	revealIcon.Size = UDim2.fromOffset(14, 14)
	revealIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	revealIcon.Position = UDim2.fromScale(0.5, 0.5)
	revealIcon.ZIndex = Z.Content + 3
	revealIcon.Parent = revealBtn
 
	jan:Add(revealBtn.MouseEnter:Connect(function()
		Tween(revealBtn, { BackgroundTransparency = 0.9 }, 0.12)
		Tween(revealIcon, { ImageColor3 = NullUI.Theme.Text }, 0.12)
	end))
	jan:Add(revealBtn.MouseLeave:Connect(function()
		Tween(revealBtn, { BackgroundTransparency = 1 }, 0.12)
		Tween(revealIcon, { ImageColor3 = NullUI.Theme.TextDim }, 0.12)
	end))
 
	local divider = Instance.new("Frame")
	divider.BackgroundColor3 = Color3.new(1, 1, 1)
	divider.BackgroundTransparency = 0.92
	divider.BorderSizePixel = 0
	divider.Position = UDim2.fromOffset(0, PAD + HEADER_H + 8)
	divider.Size = UDim2.new(1, 0, 0, 1)
	divider.ZIndex = Z.Content + 1
	divider.Parent = container
 
	local list = Instance.new("Frame")
	list.Name = "Rows"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(PAD, listY)
	list.Size = UDim2.new(1, -PAD * 2, 0, listH)
	list.ZIndex = Z.Content + 1
	list.Parent = container
 
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, ROW_GAP)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = list
 
	local emptyLabel = Instance.new("TextLabel")
	emptyLabel.BackgroundTransparency = 1
	emptyLabel.FontFace = NullUI.Theme.FontRegular
	emptyLabel.Text = "No one's run this yet"
	emptyLabel.TextColor3 = NullUI.Theme.TextDim
	emptyLabel.TextSize = 12
	emptyLabel.Position = UDim2.fromOffset(PAD, listY + 10)
	emptyLabel.Size = UDim2.new(1, -PAD * 2, 0, 16)
	emptyLabel.Visible = false
	emptyLabel.ZIndex = Z.Content + 1
	emptyLabel.Parent = container
 
	local RANK_COLORS = {
		[1] = Color3.fromRGB(255, 196, 64),
		[2] = Color3.fromRGB(203, 209, 217),
		[3] = Color3.fromRGB(205, 141, 92),
	}
	local RANK_ICONS = { [1] = "crown", [2] = "medal", [3] = "medal" }
 
	local function formatSeconds(total)
		total = math.floor(total or 0)
		local h = math.floor(total / 3600)
		local m = math.floor((total % 3600) / 60)
		if h > 0 then return string.format("%dh %dm", h, m) end
		if m > 0 then return string.format("%dm", m) end
		return string.format("%ds", total)
	end
 
	local function fallbackLabel(identity)
		local tag = (identity or ""):gsub("-", ""):sub(1, 4):upper()
		return "Player-" .. (tag ~= "" and tag or "????")
	end
 
	local rowFrames = {}
	local function clearRows()
		for _, f in ipairs(rowFrames) do f:Destroy() end
		table.clear(rowFrames)
	end
 
	local function buildRow(index, item)
		local rankColor = RANK_COLORS[index]
 
		local row = Instance.new("Frame")
		row.Name = "Row" .. index
		row.Active = true
		row.BackgroundColor3 = Color3.new(1, 1, 1)
		row.BackgroundTransparency = item.IsYou and 0.9 or 0.96
		row.BorderSizePixel = 0
		row.LayoutOrder = index
		row.Size = UDim2.new(1, 0, 0, ROW_H)
		row.ZIndex = Z.Content + 2
		row.Parent = list
		Corner(row, NullUI.Theme.CornerRadiusSm)
		Stroke(row, Color3.new(1, 1, 1), 1, item.IsYou and 0.88 or 0.94)
 
		local baseTransparency = row.BackgroundTransparency
		row.MouseEnter:Connect(function() Tween(row, { BackgroundTransparency = baseTransparency - 0.05 }, 0.12) end)
		row.MouseLeave:Connect(function() Tween(row, { BackgroundTransparency = baseTransparency }, 0.12) end)
 
		local rowPad = Instance.new("UIPadding")
		rowPad.PaddingLeft = UDim.new(0, 10)
		rowPad.PaddingRight = UDim.new(0, 10)
		rowPad.Parent = row
 
		local badge = Instance.new("Frame")
		badge.AnchorPoint = Vector2.new(0, 0.5)
		badge.Position = UDim2.new(0, 0, 0.5, 0)
		badge.Size = UDim2.fromOffset(28, 28)
		badge.BackgroundColor3 = Color3.new(1, 1, 1)
		badge.BackgroundTransparency = 0.94
		badge.BorderSizePixel = 0
		badge.ZIndex = Z.Content + 3
		badge.Parent = row
		Corner(badge, 14)
		Stroke(badge, Color3.new(1, 1, 1), 1, 0.9)
 
		if rankColor then
			local badgeIcon = Instance.new("ImageLabel")
			badgeIcon.BackgroundTransparency = 1
			badgeIcon.Image = ResolveIcon(RANK_ICONS[index])
			badgeIcon.ImageColor3 = rankColor
			badgeIcon.Size = UDim2.fromOffset(15, 15)
			badgeIcon.AnchorPoint = Vector2.new(0.5, 0.5)
			badgeIcon.Position = UDim2.fromScale(0.5, 0.5)
			badgeIcon.ZIndex = Z.Content + 4
			badgeIcon.Parent = badge
		else
			local badgeLabel = Instance.new("TextLabel")
			badgeLabel.BackgroundTransparency = 1
			badgeLabel.FontFace = NullUI.Theme.Font
			badgeLabel.Text = "#" .. tostring(index)
			badgeLabel.TextColor3 = NullUI.Theme.TextDim
			badgeLabel.TextSize = 11
			badgeLabel.Size = UDim2.fromScale(1, 1)
			badgeLabel.ZIndex = Z.Content + 4
			badgeLabel.Parent = badge
		end
 
		local avatarHolder = Instance.new("Frame")
		avatarHolder.AnchorPoint = Vector2.new(0, 0.5)
		avatarHolder.Position = UDim2.new(0, 34, 0.5, 0)
		avatarHolder.Size = UDim2.fromOffset(28, 28)
		avatarHolder.BackgroundColor3 = Color3.new(1, 1, 1)
		avatarHolder.BackgroundTransparency = 0.94
		avatarHolder.BorderSizePixel = 0
		avatarHolder.ClipsDescendants = true
		avatarHolder.ZIndex = Z.Content + 3
		avatarHolder.Parent = row
		Corner(avatarHolder, 14)
		Stroke(avatarHolder, Color3.new(1, 1, 1), 1, 0.85)
 
		if item.UserId and item.UserId ~= 0 then
			local avatarImg = Instance.new("ImageLabel")
			avatarImg.BackgroundTransparency = 1
			avatarImg.ScaleType = Enum.ScaleType.Crop
			avatarImg.Size = UDim2.fromScale(1, 1)
			avatarImg.ZIndex = Z.Content + 4
			avatarImg.Parent = avatarHolder
			task.spawn(function()
				local ok, content = pcall(
					Players.GetUserThumbnailAsync,
					Players,
					item.UserId,
					Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size48x48
				)
				if ok and content and avatarImg.Parent then
					avatarImg.Image = content
				end
			end)
		else
			local placeholder = Instance.new("ImageLabel")
			placeholder.BackgroundTransparency = 1
			placeholder.Image = ResolveIcon("user")
			placeholder.ImageColor3 = NullUI.Theme.TextDim
			placeholder.Size = UDim2.fromOffset(14, 14)
			placeholder.AnchorPoint = Vector2.new(0.5, 0.5)
			placeholder.Position = UDim2.fromScale(0.5, 0.5)
			placeholder.ZIndex = Z.Content + 4
			placeholder.Parent = avatarHolder
		end
 
		local nameLabel = Instance.new("TextLabel")
		nameLabel.BackgroundTransparency = 1
		nameLabel.FontFace = NullUI.Theme.Font
		nameLabel.Text = (item.NamePreview and item.NamePreview ~= "" and item.NamePreview or fallbackLabel(item.Identity))
			.. (item.IsYou and "  (You)" or "")
		nameLabel.TextColor3 = NullUI.Theme.Text
		nameLabel.TextSize = 13
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.Position = UDim2.fromOffset(70, 0)
		nameLabel.Size = UDim2.new(1, -70 - 68, 1, 0)
		nameLabel.ZIndex = Z.Content + 3
		nameLabel.Parent = row
 
		local timeLabel = Instance.new("TextLabel")
		timeLabel.BackgroundTransparency = 1
		timeLabel.FontFace = NullUI.Theme.FontRegular
		timeLabel.Text = formatSeconds(item.Seconds)
		timeLabel.TextColor3 = NullUI.Theme.TextDim
		timeLabel.TextSize = 12
		timeLabel.TextXAlignment = Enum.TextXAlignment.Right
		timeLabel.AnchorPoint = Vector2.new(1, 0)
		timeLabel.Position = UDim2.new(1, 0, 0, 0)
		timeLabel.Size = UDim2.fromOffset(60, ROW_H)
		timeLabel.ZIndex = Z.Content + 3
		timeLabel.Parent = row
 
		return row
	end
 
	local function renderRows(items)
		clearRows()
		emptyLabel.Visible = #items == 0
 
		for i, item in ipairs(items) do
			if i > limit then break end
			table.insert(rowFrames, buildRow(i, item))
		end
	end
 
	renderRows({})
 
	if not service then
		return { Instance = container }
	end
 
	local function maskName(letters, stars)
		local name = LocalPlayer.Name or ""
		return name:sub(1, letters) .. stars
	end
 
	jan:Add(revealBtn.MouseButton1Click:Connect(function()
		revealMe = not revealMe
		revealIcon.Image = ResolveIcon(revealMe and "eye" or "eye-off")
		NullUI:Notify({
			Title = "Leaderboard",
			Text  = revealMe
				and "Your avatar and more of your name will show on the leaderboard."
				or "Back to anonymous -- only 2 letters of your name will show.",
			Type  = "info",
			Duration = 3,
		})
	end))
 
	local alive = true
	jan:Add(function() alive = false end)
 
	task.spawn(function()
		while alive and container.Parent do
			local payload = revealMe
				and { UserId = LocalPlayer.UserId, NamePreview = maskName(4, "*******") }
				or { UserId = 0, NamePreview = maskName(2, "********") }
			service:Heartbeat(payload)
 
			local items, err = service:GetLeaderboard(limit)
			if alive and container.Parent and items then
				for _, item in ipairs(items) do
					item.IsYou = item.Identity == service.Identity
				end
				renderRows(items)
			end
			task.wait(interval)
		end
	end)
 
	return { Instance = container }
end
 
function Tab:AddGradientCard(opts)
	opts = opts or {}
	local title = opts.Title or "Card"
	local hasDesc = opts.Description and opts.Description ~= ""
	local colorA = opts.ColorA or Color3.fromRGB(88, 101, 242)
	local colorB = opts.ColorB or Color3.fromRGB(52, 58, 138)
	local height = hasDesc and 56 or 44
 
	local card = Instance.new("Frame")
	card.Name = title .. "GradientCard"
	card.BackgroundColor3 = colorA
	card.BorderSizePixel = 0
	card.Size = UDim2.new(1, 0, 0, height)
	card.ZIndex = Z.Content
	card.Parent = self._page
	Corner(card, NullUI.Theme.CornerRadiusSm)
 
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(colorA, colorB)
	gradient.Rotation = 100
	gradient.Parent = card
 
	self._window:_RegisterSearchable(self, title, card)
 
	local PAD = 14
	local rightReserve = opts.Callback and 32 or PAD
 
	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.FontFace = NullUI.Theme.Font
	titleLabel.Text = title
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextSize = 14
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	titleLabel.Position = UDim2.fromOffset(PAD, hasDesc and 9 or 0)
	titleLabel.Size = UDim2.new(1, -(PAD + rightReserve), 0, 18)
	titleLabel.ZIndex = Z.Content + 1
	titleLabel.Parent = card
 
	if hasDesc then
		local descLabel = Instance.new("TextLabel")
		descLabel.BackgroundTransparency = 1
		descLabel.FontFace = NullUI.Theme.FontRegular
		descLabel.Text = opts.Description
		descLabel.TextColor3 = Color3.new(1, 1, 1)
		descLabel.TextTransparency = 0.3
		descLabel.TextSize = 12
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.TextTruncate = Enum.TextTruncate.AtEnd
		descLabel.Position = UDim2.fromOffset(PAD, 29)
		descLabel.Size = UDim2.new(1, -(PAD + rightReserve), 0, 14)
		descLabel.ZIndex = Z.Content + 1
		descLabel.Parent = card
	end
 
	if opts.Callback then
		local chev = Instance.new("ImageLabel")
		chev.BackgroundTransparency = 1
		chev.Image = ResolveIcon("chevron-right")
		chev.ImageColor3 = Color3.new(1, 1, 1)
		chev.ImageTransparency = 0.2
		chev.Size = UDim2.fromOffset(14, 14)
		chev.AnchorPoint = Vector2.new(1, 0.5)
		chev.Position = UDim2.new(1, -14, 0.5, 0)
		chev.ZIndex = Z.Content + 1
		chev.Parent = card
 
		local veil = Instance.new("Frame")
		veil.Name = "HoverVeil"
		veil.BackgroundColor3 = Color3.new(1, 1, 1)
		veil.BackgroundTransparency = 1
		veil.BorderSizePixel = 0
		veil.Size = UDim2.fromScale(1, 1)
		veil.ZIndex = Z.Content + 2
		veil.Parent = card
		Corner(veil, NullUI.Theme.CornerRadiusSm)
 
		local click = Instance.new("TextButton")
		click.Text = ""
		click.AutoButtonColor = false
		click.BackgroundTransparency = 1
		click.Size = UDim2.fromScale(1, 1)
		click.ZIndex = Z.Content + 3
		click.Parent = card
 
		click.MouseEnter:Connect(function()
			Tween(veil, { BackgroundTransparency = 0.9 }, 0.15)
			Tween(chev, { Position = UDim2.new(1, -10, 0.5, 0) }, 0.15)
		end)
		click.MouseLeave:Connect(function()
			Tween(veil, { BackgroundTransparency = 1 }, 0.15)
			Tween(chev, { Position = UDim2.new(1, -14, 0.5, 0) }, 0.15)
		end)
		click.MouseButton1Click:Connect(function()
			Tween(veil, { BackgroundTransparency = 0.8 }, 0.08)
			task.delay(0.08, function()
				if veil.Parent then Tween(veil, { BackgroundTransparency = 0.9 }, 0.15) end
			end)
			task.spawn(opts.Callback)
		end)
	end
 
	return { Instance = card, Destroy = function() card:Destroy() end }
end
 
function Tab:AddToggle(opts)
	opts = opts or {}
	local state = opts.Default == true
	local hasDesc = opts.Description and opts.Description ~= ""
	local height = hasDesc and 56 or 44
	local card = BaseCard(self._page, height)
 
	local textX = AddLeadingIcon(card, opts.Icon, height)
	AddTitleDesc(card, textX, 66, opts.Text or "Toggle", opts.Description, height)
	self._window:_RegisterSearchable(self, opts.Text or "Toggle", card)
 
	local switchBg = Instance.new("Frame")
	switchBg.AnchorPoint = Vector2.new(1, 0.5)
	switchBg.Position = UDim2.new(1, -14, 0.5, 0)
	switchBg.Size = UDim2.fromOffset(40, 22)
	switchBg.BackgroundColor3 = state and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(46, 50, 49)
	switchBg.BackgroundTransparency = state and 0 or 0.32
	switchBg.BorderSizePixel = 0
	switchBg.ZIndex = Z.Content + 1
	switchBg.Parent = card
	Corner(switchBg, 11)
 
	-- The disabled state stays translucent so the window background remains visible
	-- through the control instead of turning into a flat gray pill.
	local switchStroke = Stroke(
		switchBg,
		state and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(205, 212, 209),
		1,
		state and 0.88 or 0.72
	)
 
	local switchGradient = Instance.new("UIGradient")
	switchGradient.Rotation = 90
	switchGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 198, 194)),
	})
	switchGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, state and 0 or 0.76),
		NumberSequenceKeypoint.new(1, state and 0 or 0.94),
	})
	switchGradient.Parent = switchBg
 
	local switchScale = Instance.new("UIScale")
	switchScale.Scale = 1
	switchScale.Parent = switchBg
 
	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(16, 16)
	knob.Position = state and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
	knob.AnchorPoint = Vector2.new(0, 0.5)
	knob.BackgroundColor3 = state and Color3.fromRGB(18, 18, 18) or Color3.fromRGB(226, 230, 228)
	knob.BackgroundTransparency = state and 0 or 0.06
	knob.BorderSizePixel = 0
	knob.ZIndex = Z.Content + 2
	knob.Parent = switchBg
	Corner(knob, 8)
 
	local click = Instance.new("TextButton")
	click.Text = ""
	click.AutoButtonColor = false
	click.BackgroundTransparency = 1
	click.Size = UDim2.fromScale(1, 1)
	click.ZIndex = Z.Content + 3
	click.Parent = card
 
	local function render()
		local anim = 0.28
		local style, dir = Enum.EasingStyle.Quint, Enum.EasingDirection.InOut
		Tween(switchBg, {
			BackgroundColor3 = state and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(46, 50, 49),
			BackgroundTransparency = state and 0 or 0.32,
		}, anim, style, dir)
		Tween(switchStroke, {
			Color = state and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(205, 212, 209),
			Transparency = state and 0.88 or 0.72,
		}, anim, style, dir)
		switchGradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, state and 0 or 0.76),
			NumberSequenceKeypoint.new(1, state and 0 or 0.94),
		})
		Tween(knob, {
			BackgroundColor3 = state and Color3.fromRGB(18, 18, 18) or Color3.fromRGB(226, 230, 228),
			BackgroundTransparency = state and 0 or 0.06,
			Position = state and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
		}, anim, style, dir)
	end
 
	local signal = MakeSignal()
	local function fireChanged(newState)
		if opts.Callback then task.spawn(opts.Callback, newState) end
		signal.Fire(newState)
	end
 
	local locked = opts.Locked == true
	click.MouseButton1Click:Connect(function()
		if locked then return end
		Tween(switchScale, { Scale = 0.91 }, 0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		task.delay(0.08, function()
			if switchScale.Parent then
				Tween(switchScale, { Scale = 1 }, 0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			end
		end)
		state = not state
		render()
		fireChanged(state)
	end)
 
	card.MouseEnter:Connect(function()
		if not locked then
			Tween(card, { BackgroundTransparency = 0.93 }, 0.15)
			if not state then
				Tween(switchStroke, { Transparency = 0.55 }, 0.15)
				Tween(switchBg, { BackgroundTransparency = 0.24 }, 0.15)
			end
		end
	end)
	card.MouseLeave:Connect(function()
		Tween(card, { BackgroundTransparency = 0.96 }, 0.15)
		if not state then
			Tween(switchStroke, { Transparency = 0.72 }, 0.15)
			Tween(switchBg, { BackgroundTransparency = 0.32 }, 0.15)
		end
	end)
 
	return RegisterFlag(opts, {
		Instance = card,
		Set = function(_, value, silent)
			state = value == true
			render()
			if not silent then fireChanged(state) end
		end,
		Get = function() return state end,
		SetLocked = function(_, v)
			locked = v == true
			card.BackgroundTransparency = locked and 0.98 or 0.96
		end,
		OnChanged = function(_, fn) return signal.Connect(fn) end,
		Destroy = function() signal.Clear(); card:Destroy() end,
	}, "Toggle")
end
 
local ActiveSliderOwner = nil
 
function Tab:AddSlider(opts)
	opts = opts or {}
	local min = tonumber(opts.Min) or 0
	local max = tonumber(opts.Max) or 100
	if max < min then min, max = max, min end
	local increment = tonumber(opts.Increment) or 1
	local value = math.clamp(tonumber(opts.Default) or min, min, max)
 
	local hasDesc = opts.Description and opts.Description ~= ""
	local jan = self._janitor
 
	local card = BaseCard(self._page, hasDesc and 76 or 56)
	local textX = AddLeadingIcon(card, opts.Icon, 24)
	local leadingIcon = card:FindFirstChild("LeadingIcon")
	if leadingIcon then
		leadingIcon.AnchorPoint = Vector2.new(0, 0)
		leadingIcon.Position = UDim2.fromOffset(14, 9)
	end
 
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.FontFace = NullUI.Theme.Font
	label.Text = opts.Text or "Slider"
	label.TextColor3 = NullUI.Theme.Text
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Position = UDim2.fromOffset(textX, 8)
	label.Size = UDim2.new(1, -(textX + 76), 0, 18)
	label.ZIndex = Z.Content + 1
	label.Parent = card
	self._window:_RegisterSearchable(self, opts.Text or "Slider", card)
 
	local descLabel
	if hasDesc then
		descLabel = Instance.new("TextLabel")
		descLabel.BackgroundTransparency = 1
		descLabel.FontFace = NullUI.Theme.FontRegular
		descLabel.Text = opts.Description
		descLabel.TextColor3 = NullUI.Theme.TextDim
		descLabel.TextSize = 12
		descLabel.TextWrapped = true
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.TextYAlignment = Enum.TextYAlignment.Top
		descLabel.AutomaticSize = Enum.AutomaticSize.Y
		descLabel.Position = UDim2.fromOffset(textX, 26)
		descLabel.Size = UDim2.new(1, -(textX + 14), 0, 14)
		descLabel.ZIndex = Z.Content + 1
		descLabel.Parent = card
	end
 
	local valueLabel = Instance.new("TextLabel")
	valueLabel.BackgroundTransparency = 1
	valueLabel.FontFace = NullUI.Theme.FontRegular
	valueLabel.Text = FormatNumber(value) .. (opts.Suffix or "")
	valueLabel.TextColor3 = NullUI.Theme.TextDim
	valueLabel.TextSize = 13
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	valueLabel.AnchorPoint = Vector2.new(1, 0)
	valueLabel.Position = UDim2.new(1, -14, 0, 8)
	valueLabel.Size = UDim2.fromOffset(62, 18)
	valueLabel.ZIndex = Z.Content + 1
	valueLabel.Parent = card
 
	local track = Instance.new("Frame")
	track.Position = UDim2.new(0, 14, 1, -20)
	track.Size = UDim2.new(1, -28, 0, 6)
	-- Nearly transparent white overlay: no gray tint, so the window background
	-- remains visible through the unfilled portion of the slider.
	track.BackgroundColor3 = Color3.new(1, 1, 1)
	track.BackgroundTransparency = 0.91
	track.BorderSizePixel = 0
	track.ZIndex = Z.Content + 1
	track.Parent = card
	Corner(track, 3)
 
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BackgroundTransparency = 0
	fill.BorderSizePixel = 0
	fill.Size = UDim2.new(SafeAlpha(value, min, max), 0, 1, 0)
	fill.ZIndex = Z.Content + 2
	fill.Parent = track
	Corner(fill, 3)
 
	local knob = Instance.new("Frame")
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.new(SafeAlpha(value, min, max), 0, 0.5, 0)
	knob.Size = UDim2.fromOffset(12, 12)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.BackgroundTransparency = 0
	knob.BorderSizePixel = 0
	knob.ZIndex = Z.Content + 3
	knob.Parent = track
	Corner(knob, 6)
	Stroke(knob, Color3.fromRGB(16, 16, 16), 2, 0)
 
	if hasDesc then
		local lastW = -1
		local function relayout()
			local w = card.AbsoluteSize.X / GetUIScale()
			if w <= 0 or math.abs(w - lastW) < 1 then return end
			lastW = w
			local _, h = MeasureText(opts.Description, 12, math.max(w - textX - 14, 40))
			card.Size = UDim2.new(1, 0, 0, math.max(76, 26 + h + 8 + 20))
		end
		card:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
		task.defer(relayout)
	end
 
	local function setVisual(alpha, animated, duration)
		if animated then
			Tween(fill, { Size = UDim2.new(alpha, 0, 1, 0) }, duration or 0.16)
			Tween(knob, { Position = UDim2.new(alpha, 0, 0.5, 0) }, duration or 0.16)
		else
			fill.Size = UDim2.new(alpha, 0, 1, 0)
			knob.Position = UDim2.new(alpha, 0, 0.5, 0)
		end
	end
 
	local targetAlpha = SafeAlpha(value, min, max)
	local visualAlpha = targetAlpha
 
	local signal = MakeSignal()
	local function fireChanged(v)
		if opts.Callback then task.spawn(opts.Callback, v) end
		signal.Fire(v)
	end
 
	local function setValueLabel()
		valueLabel.Text = FormatNumber(value) .. (opts.Suffix or "")
	end
 
	local function moveTo(newValue, animated)
		value = math.clamp(newValue, min, max)
		local alpha = SafeAlpha(value, min, max)
		targetAlpha = alpha
		visualAlpha = alpha
		setValueLabel()
		setVisual(alpha, animated ~= false, 0.18)
	end
 
	local dragging = false
	local sliderInput = nil
	local sliderOwner = {}
	local followConn = nil
 
	local function updateFromX(xPos)
		if track.AbsoluteSize.X <= 0 then return end
		targetAlpha = math.clamp((xPos - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		local raw = min + targetAlpha * (max - min)
		local newValue = SnapToIncrement(raw, min, max, increment)
		if newValue ~= value then
			value = newValue
			setValueLabel()
			fireChanged(value)
		end
	end
 
	local SLIDER_SMOOTH = 22
 
	local function stopFollow()
		if followConn then
			followConn:Disconnect()
			followConn = nil
		end
	end
 
	local function releaseSlider()
		if ActiveSliderOwner == sliderOwner then ActiveSliderOwner = nil end
		dragging = false
		sliderInput = nil
		stopFollow()
	end
	jan:Add(releaseSlider)
	jan:Add(card.Destroying:Connect(releaseSlider))
	jan:Add(UserInputService.WindowFocusReleased:Connect(releaseSlider))
 
	local hitBox = Instance.new("TextButton")
	hitBox.Name = "SliderHitBox"
	hitBox.Text = ""
	hitBox.AutoButtonColor = false
	hitBox.BackgroundTransparency = 1
	hitBox.AnchorPoint = Vector2.new(0.5, 0.5)
	hitBox.Position = UDim2.fromScale(0.5, 0.5)
	hitBox.Size = UDim2.new(1, 8, 0, 26)
	hitBox.ZIndex = Z.Content + 4
	hitBox.Parent = track
 
	jan:Add(hitBox.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if dragging or ActiveSliderOwner ~= nil then return end
		ActiveSliderOwner = sliderOwner
		dragging = true
		sliderInput = input
		updateFromX(input.Position.X)
 
		stopFollow()
		followConn = RunService.RenderStepped:Connect(function(dt)
			if not track.Parent then stopFollow() return end
			local a = 1 - math.exp(-SLIDER_SMOOTH * dt)
			visualAlpha = visualAlpha + (targetAlpha - visualAlpha) * a
			if math.abs(targetAlpha - visualAlpha) < 0.001 then
				visualAlpha = targetAlpha
			end
			setVisual(visualAlpha, false)
		end)
		jan:Add(followConn)
	end))
 
	jan:Add(UserInputService.InputChanged:Connect(function(input)
		if not dragging or ActiveSliderOwner ~= sliderOwner then return end
		if input == sliderInput
			or (sliderInput and sliderInput.UserInputType == Enum.UserInputType.MouseButton1
				and input.UserInputType == Enum.UserInputType.MouseMovement) then
			updateFromX(input.Position.X)
		end
	end))
 
	jan:Add(UserInputService.InputEnded:Connect(function(input)
		if not dragging or ActiveSliderOwner ~= sliderOwner then return end
		if input ~= sliderInput
			and not (sliderInput and sliderInput.UserInputType == Enum.UserInputType.MouseButton1
				and input.UserInputType == Enum.UserInputType.MouseButton1) then
			return
		end
		releaseSlider()
		targetAlpha = SafeAlpha(value, min, max)
		visualAlpha = targetAlpha
		setVisual(targetAlpha, true, 0.12)
	end))
 
	return RegisterFlag(opts, {
		Instance = card,
		Set = function(_, v, silent)
			moveTo(SnapToIncrement(tonumber(v) or min, min, max, increment), true)
			if not silent then fireChanged(value) end
		end,
		Get = function() return value end,
		SetRange = function(_, newMin, newMax)
			min, max = newMin, newMax
			moveTo(math.clamp(value, min, max), true)
		end,
		OnChanged = function(_, fn) return signal.Connect(fn) end,
		Destroy = function() stopFollow(); signal.Clear(); card:Destroy() end,
	}, "Slider")
end
 
local function ComputePopupPosition(window, card, w, h)
	local s = GetUIScale()
	local realW, realH = w * s, h * s
 
	local view = ViewportSize()
	local winPos = window.AbsolutePosition
	local winSize = window.AbsoluteSize
	local cardPos = card.AbsolutePosition
 
	local px = winPos.X + winSize.X + 12
	if px + realW > view.X - 8 then
		px = winPos.X - realW - 12
	end
	px = SafeClamp(px, 8, view.X - realW - 8)
 
	local py = cardPos.Y - realH - 8
	py = SafeClamp(py, winPos.Y + 8, winPos.Y + winSize.Y - realH - 8)
	py = SafeClamp(py, 8, view.Y - realH - 8)
 
	return math.round(px / s), math.round(py / s)
end
 
function Tab:AddDropdown(opts)
	opts = opts or {}
	local options = opts.Options or {}
	local isMulti = opts.MultiSelect == true
	local hasDesc = opts.Description and opts.Description ~= ""
	local height = hasDesc and 56 or 44
	local jan = self._janitor
 
	local selected
	if isMulti then
		selected = {}
		if type(opts.Default) == "table" then
			for _, v in ipairs(opts.Default) do selected[v] = true end
		end
	else
		selected = opts.Default or options[1]
	end
 
	local signal = MakeSignal()
	local function fireChanged(newValue)
		if opts.Callback then task.spawn(opts.Callback, newValue) end
		signal.Fire(newValue)
	end
 
	local function getSelectedList()
		local list = {}
		for _, name in ipairs(options) do
			if isMulti and selected[name] then table.insert(list, name) end
		end
		return list
	end
 
	local function isOptionSelected(name)
		if isMulti then return selected[name] == true end
		return name == selected
	end
 
	local function formatValue()
		if isMulti then
			local list = getSelectedList()
			if #list == 0 then return "None" end
			if #list == 1 then return list[1] end
			return #list .. " selected"
		end
		return tostring(selected or "None")
	end
 
	local card = BaseCard(self._page, height)
	local textX = AddLeadingIcon(card, opts.Icon, height)
 
	AddTitleDesc(card, textX, 166, opts.Text or "Dropdown", opts.Description, height)
	self._window:_RegisterSearchable(self, opts.Text or "Dropdown", card)
 
	local valueLabel = Instance.new("TextLabel")
	valueLabel.BackgroundTransparency = 1
	valueLabel.FontFace = NullUI.Theme.FontRegular
	valueLabel.Text = formatValue()
	valueLabel.TextColor3 = NullUI.Theme.TextDim
	valueLabel.TextSize = 13
	valueLabel.TextTruncate = Enum.TextTruncate.AtEnd
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	valueLabel.AnchorPoint = Vector2.new(1, 0.5)
	valueLabel.Position = UDim2.new(1, -34, 0.5, 0)
	valueLabel.Size = UDim2.fromOffset(120, height)
	valueLabel.ZIndex = Z.Content + 1
	valueLabel.Parent = card
 
	local chevron = Instance.new("ImageLabel")
	chevron.BackgroundTransparency = 1
	chevron.Image = ResolveIcon("chevron-down")
	chevron.ImageColor3 = NullUI.Theme.TextDim
	chevron.Size = UDim2.fromOffset(14, 14)
	chevron.AnchorPoint = Vector2.new(1, 0.5)
	chevron.Position = UDim2.new(1, -14, 0.5, 0)
	chevron.ZIndex = Z.Content + 1
	chevron.Parent = card
 
	local click = Instance.new("TextButton")
	click.Text = ""
	click.AutoButtonColor = false
	click.BackgroundTransparency = 1
	click.Size = UDim2.fromScale(1, 1)
	click.ZIndex = Z.Content + 3
	click.Parent = card
 
	local popupOpen = false
	local popupFrame, popupBackdrop, followConn, scrollConn
	local optionButtons = {}
 
	local function closePopup()
		if not popupOpen then return end
		popupOpen = false
		RegisterPopupClose(closePopup)
		Tween(chevron, { Rotation = 0 }, 0.15)
 
		if followConn then followConn:Disconnect(); followConn = nil end
		if scrollConn then scrollConn:Disconnect(); scrollConn = nil end
		table.clear(optionButtons)
 
		if popupBackdrop then popupBackdrop:Destroy(); popupBackdrop = nil end
 
		if popupFrame then
			local pf = popupFrame
			popupFrame = nil
			Tween(pf, { Size = UDim2.new(0, pf.Size.X.Offset, 0, 0) }, 0.4,
				Enum.EasingStyle.Quint, Enum.EasingDirection.In)
			Tween(pf, { BackgroundTransparency = 1 }, 0.34, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
			task.delay(0.4, function() if pf then pf:Destroy() end end)
		end
	end
 
	local function refreshOptionVisual(name)
		local entry = optionButtons[name]
		if not entry then return end
		local sel = isOptionSelected(name)
		Tween(entry.button, { BackgroundTransparency = sel and 0.9 or 1 }, 0.1)
		Tween(entry.label, { TextColor3 = sel and NullUI.Theme.Text or NullUI.Theme.TextDim }, 0.1)
		if entry.check then
			Tween(entry.check, { BackgroundTransparency = sel and 0.05 or 0.9 }, 0.1)
		end
		if entry.checkIcon then
			Tween(entry.checkIcon, { ImageTransparency = sel and 0 or 1 }, 0.1)
		end
	end
 
	local function openPopup()
		if popupOpen then return end
		popupOpen = true
		RegisterPopupOpen(closePopup)
		Tween(chevron, { Rotation = 180 }, 0.15)
 
		local root = NullUI._Root
		local mainWindow = self._window and self._window._gui or root
 
		local rowH, padV = 30, 12
		local contentH = #options * rowH + math.max(#options - 1, 0) * 2 + padV
		local targetHeight = math.min(contentH, 220, math.max(1, (ViewportSize().Y - 16) / GetUIScale()))
 
		local popupW = 140
		for _, name in ipairs(options) do
			local w = MeasureText(tostring(name), 13, 1000)
			popupW = math.max(popupW, w + 66)
		end
		popupW = math.min(popupW, ViewportSize().X / GetUIScale() - 24)
 
		popupBackdrop = MakePopupBackdrop(closePopup)
 
		popupFrame = Instance.new("CanvasGroup")
		popupFrame.Name = "DropdownPopup"
		popupFrame.Active = true
		popupFrame.BackgroundColor3 = NullUI.Theme.Background
		popupFrame.BackgroundTransparency = 1
		popupFrame.BorderSizePixel = 0
		popupFrame.ZIndex = Z.Popup
		popupFrame.Size = UDim2.new(0, popupW, 0, 0)
		popupFrame.Parent = root
		Corner(popupFrame, 10)
		local popupStroke = Stroke(popupFrame, Color3.new(1, 1, 1), 1, 0.92)
		GlassLayer(popupFrame, 10, 0.985)
 
		local px, py = ComputePopupPosition(mainWindow, card, popupW, targetHeight)
		popupFrame.Position = UDim2.fromOffset(px, py)
 
		local optionsHolder = Instance.new("ScrollingFrame")
		optionsHolder.Name = "Options"
		optionsHolder.BackgroundTransparency = 1
		optionsHolder.BorderSizePixel = 0
		optionsHolder.Size = UDim2.fromScale(1, 1)
		optionsHolder.ScrollingDirection = Enum.ScrollingDirection.Y
		optionsHolder.ScrollBarThickness = 0
		optionsHolder.AutomaticCanvasSize = Enum.AutomaticSize.Y
		optionsHolder.CanvasSize = UDim2.new(0, 0, 0, 0)
		optionsHolder.ZIndex = Z.Popup + 1
		optionsHolder.Parent = popupFrame
 
		local optPad = Instance.new("UIPadding")
		optPad.PaddingTop = UDim.new(0, 6)
		optPad.PaddingBottom = UDim.new(0, 6)
		optPad.PaddingLeft = UDim.new(0, 6)
		optPad.PaddingRight = UDim.new(0, 16)
		optPad.Parent = optionsHolder
 
		local optLayout = Instance.new("UIListLayout")
		optLayout.Padding = UDim.new(0, 2)
		optLayout.SortOrder = Enum.SortOrder.LayoutOrder
		optLayout.Parent = optionsHolder
 
		AddScrollbar(optionsHolder)
		AddContentScrollThumb(optionsHolder, optLayout, popupFrame, {
			Add = function(_, conn) scrollConn = conn end,
		})
 
		for i, optionName in ipairs(options) do
			local optBtn = Instance.new("TextButton")
			optBtn.Text = ""
			optBtn.AutoButtonColor = false
			optBtn.BackgroundColor3 = Color3.new(1, 1, 1)
			optBtn.BackgroundTransparency = isOptionSelected(optionName) and 0.9 or 1
			optBtn.BorderSizePixel = 0
			optBtn.Size = UDim2.new(1, 0, 0, rowH)
			optBtn.LayoutOrder = i
			optBtn.ZIndex = Z.Popup + 2
			optBtn.Parent = optionsHolder
			Corner(optBtn, 8)
 
			local optLabel = Instance.new("TextLabel")
			optLabel.BackgroundTransparency = 1
			optLabel.FontFace = NullUI.Theme.FontRegular
			optLabel.Text = tostring(optionName)
			optLabel.TextColor3 = isOptionSelected(optionName) and NullUI.Theme.Text or NullUI.Theme.TextDim
			optLabel.TextSize = 13
			optLabel.TextXAlignment = Enum.TextXAlignment.Left
			optLabel.TextTruncate = Enum.TextTruncate.AtEnd
			optLabel.Position = UDim2.fromOffset(10, 0)
			optLabel.Size = UDim2.new(1, -34, 1, 0)
			optLabel.ZIndex = Z.Popup + 3
			optLabel.Parent = optBtn
 
			local entry = { button = optBtn, label = optLabel }
 
			if isMulti then
				local check = Instance.new("Frame")
				check.Name = "Check"
				check.AnchorPoint = Vector2.new(1, 0.5)
				check.Position = UDim2.new(1, -10, 0.5, 0)
				check.Size = UDim2.fromOffset(14, 14)
				check.BackgroundColor3 = Color3.new(1, 1, 1)
				check.BackgroundTransparency = isOptionSelected(optionName) and 0.05 or 0.9
				check.BorderSizePixel = 0
				check.ZIndex = Z.Popup + 3
				check.Parent = optBtn
				Corner(check, 4)
				Stroke(check, Color3.new(1, 1, 1), 1, 0.75)
 
				local checkIcon = Instance.new("ImageLabel")
				checkIcon.Name = "Icon"
				checkIcon.BackgroundTransparency = 1
				checkIcon.Image = ResolveIcon("check")
				checkIcon.ImageColor3 = NullUI.Theme.Background
				checkIcon.ImageTransparency = isOptionSelected(optionName) and 0 or 1
				checkIcon.Size = UDim2.fromOffset(10, 10)
				checkIcon.AnchorPoint = Vector2.new(0.5, 0.5)
				checkIcon.Position = UDim2.fromScale(0.5, 0.5)
				checkIcon.ZIndex = Z.Popup + 4
				checkIcon.Parent = check
 
				entry.check = check
				entry.checkIcon = checkIcon
			elseif isOptionSelected(optionName) then
				local check = Instance.new("ImageLabel")
				check.Name = "SingleCheck"
				check.BackgroundTransparency = 1
				check.Image = ResolveIcon("check")
				check.ImageColor3 = NullUI.Theme.Text
				check.Size = UDim2.fromOffset(14, 14)
				check.AnchorPoint = Vector2.new(1, 0.5)
				check.Position = UDim2.new(1, -10, 0.5, 0)
				check.ZIndex = Z.Popup + 3
				check.Parent = optBtn
			end
 
			optionButtons[optionName] = entry
 
			optBtn.MouseEnter:Connect(function()
				if not isOptionSelected(optionName) then
					Tween(optBtn, { BackgroundTransparency = 0.85 }, 0.1)
				end
			end)
			optBtn.MouseLeave:Connect(function()
				if not isOptionSelected(optionName) then
					Tween(optBtn, { BackgroundTransparency = 1 }, 0.1)
				end
			end)
 
			optBtn.MouseButton1Click:Connect(function()
				if isMulti then
					selected[optionName] = (not selected[optionName]) or nil
					refreshOptionVisual(optionName)
					valueLabel.Text = formatValue()
					fireChanged(getSelectedList())
				else
					selected = optionName
					valueLabel.Text = formatValue()
					fireChanged(optionName)
					closePopup()
				end
			end)
		end
 
		Tween(popupFrame, {
			Size = UDim2.new(0, popupW, 0, targetHeight),
			BackgroundTransparency = 0.15,
		}, 0.44, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		Tween(popupStroke, { Transparency = 0.85 }, 0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
 
		followConn = RunService.RenderStepped:Connect(function()
			if not popupFrame or not card.Parent then return end
			local nx, ny = ComputePopupPosition(mainWindow, card, popupW, targetHeight)
			popupFrame.Position = UDim2.fromOffset(nx, ny)
		end)
		jan:Add(followConn)
	end
 
	click.MouseButton1Click:Connect(function()
		if popupOpen then closePopup() else openPopup() end
	end)
 
	card.MouseEnter:Connect(function() Tween(card, { BackgroundTransparency = 0.93 }, 0.15) end)
	card.MouseLeave:Connect(function() Tween(card, { BackgroundTransparency = 0.96 }, 0.15) end)
 
	return RegisterFlag(opts, {
		Instance = card,
		Set = function(_, v, silent)
			if isMulti then
				selected = {}
				if type(v) == "table" then
					for _, name in ipairs(v) do selected[name] = true end
				end
			else
				selected = v
			end
			valueLabel.Text = formatValue()
			for name in pairs(optionButtons) do refreshOptionVisual(name) end
			if not silent then
				fireChanged(isMulti and getSelectedList() or selected)
			end
		end,
		Get = function()
			if isMulti then return getSelectedList() end
			return selected
		end,
		SetOptions = function(_, newOptions)
			options = newOptions or {}
			closePopup()
			valueLabel.Text = formatValue()
		end,
		Refresh = function(_, newOptions)
			options = newOptions or options
			closePopup()
			valueLabel.Text = formatValue()
		end,
		OnChanged = function(_, fn) return signal.Connect(fn) end,
		Destroy = function() closePopup(); signal.Clear(); card:Destroy() end,
	}, "Dropdown")
end
 
function Tab:AddTextbox(opts)
	opts = opts or {}
	local hasDesc = opts.Description and opts.Description ~= ""
	local height = hasDesc and 56 or 44
	local card = BaseCard(self._page, height)
 
	local textX = AddLeadingIcon(card, opts.Icon, height)
 
	local iconGap, rightPad, pillMinW = 29, 12, 90
	local titleReserve = pillMinW + 26
 
	local _, _, refreshTextLayout = AddTitleDesc(card, textX, function() return titleReserve end, opts.Text or "Textbox", opts.Description, height)
	self._window:_RegisterSearchable(self, opts.Text or "Textbox", card)
 
	local pill = Instance.new("Frame")
	pill.AnchorPoint = Vector2.new(1, 0.5)
	pill.Position = UDim2.new(1, -14, 0.5, 0)
	pill.Size = UDim2.fromOffset(pillMinW, 26)
	pill.BackgroundColor3 = Color3.new(1, 1, 1)
	pill.BackgroundTransparency = 0.9
	pill.BorderSizePixel = 0
	pill.ZIndex = Z.Content + 2
	pill.Parent = card
	Corner(pill, 8)
	local pillStroke = Stroke(pill, Color3.new(1, 1, 1), 1, 0.88)
 
	local penIcon = Instance.new("ImageLabel")
	penIcon.BackgroundTransparency = 1
	penIcon.Image = ResolveIcon("pencil")
	penIcon.ImageColor3 = NullUI.Theme.TextDim
	penIcon.Size = UDim2.fromOffset(13, 13)
	penIcon.AnchorPoint = Vector2.new(0, 0.5)
	penIcon.Position = UDim2.new(0, 10, 0.5, 0)
	penIcon.ZIndex = Z.Content + 3
	penIcon.Parent = pill
 
	local box = Instance.new("TextBox")
	box.ClearTextOnFocus = false
	box.FontFace = NullUI.Theme.FontRegular
	box.PlaceholderText = opts.Placeholder or ""
	box.PlaceholderColor3 = Color3.fromRGB(120, 120, 122)
	box.Text = opts.Default or ""
	box.TextColor3 = NullUI.Theme.Text
	box.TextSize = 13
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.TextYAlignment = Enum.TextYAlignment.Center
	box.TextTruncate = Enum.TextTruncate.AtEnd
	box.ClipsDescendants = true
	box.BackgroundTransparency = 1
	box.Position = UDim2.fromOffset(iconGap, 0)
	box.Size = UDim2.new(1, -(iconGap + 10), 1, 0)
	box.ZIndex = Z.Content + 3
	box.Parent = pill
 
	local currentPillW = pillMinW
 
	local function resizePill(animated)
		local sample = box.Text ~= "" and box.Text or box.PlaceholderText
		local textW = MeasureText(sample, 13, 2000)
		local desiredW = iconGap + textW + rightPad
 
		local realCardW = card.AbsoluteSize.X > 0 and card.AbsoluteSize.X or 400
		local cardW = realCardW / GetUIScale()
		local maxW = math.max(pillMinW, math.floor(cardW * 0.5))
		local targetW = math.clamp(desiredW, pillMinW, maxW)
 
		if math.abs(targetW - currentPillW) < 1 then return end
		currentPillW = targetW
		titleReserve = targetW + 26
		refreshTextLayout()
 
		if animated == false then
			pill.Size = UDim2.fromOffset(targetW, 26)
		else
			Tween(pill, { Size = UDim2.fromOffset(targetW, 26) }, 0.16,
				Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		end
	end
 
	box:GetPropertyChangedSignal("Text"):Connect(function() resizePill(true) end)
	card:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() resizePill(false) end)
	task.defer(function() resizePill(false) end)
 
	box.Focused:Connect(function()
		Tween(pillStroke, { Color = NullUI.Theme.Accent, Transparency = 0.3 }, 0.15)
		Tween(pill, { BackgroundTransparency = 0.82 }, 0.15)
	end)
 
	local signal = MakeSignal()
	local function fireChanged(text, enterPressed)
		if opts.Callback then task.spawn(opts.Callback, text, enterPressed) end
		signal.Fire(text, enterPressed)
	end
 
	box.FocusLost:Connect(function(enterPressed)
		Tween(pillStroke, { Color = Color3.new(1, 1, 1), Transparency = 0.88 }, 0.15)
		Tween(pill, { BackgroundTransparency = 0.9 }, 0.15)
		fireChanged(box.Text, enterPressed)
	end)
 
	return RegisterFlag(opts, {
		Instance = card,
		Set = function(_, v, silent)
			box.Text = tostring(v or "")
			resizePill()
			if not silent then fireChanged(box.Text, false) end
		end,
		Get = function() return box.Text end,
		OnChanged = function(_, fn) return signal.Connect(fn) end,
		Destroy = function() signal.Clear(); card:Destroy() end,
	}, "Textbox")
end
 
local function MiniField(parent, label, width, zBase)
	zBase = zBase or Z.Popup
 
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(width, 36)
	holder.ZIndex = zBase + 1
	holder.Parent = parent
 
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.FontFace = NullUI.Theme.FontRegular
	lbl.Text = label
	lbl.TextColor3 = NullUI.Theme.TextDim
	lbl.TextSize = 11
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Size = UDim2.new(1, 0, 0, 12)
	lbl.ZIndex = zBase + 2
	lbl.Parent = holder
 
	local field = Instance.new("Frame")
	field.Position = UDim2.fromOffset(0, 12)
	field.Size = UDim2.new(1, 0, 0, 24)
	field.BackgroundColor3 = Color3.new(1, 1, 1)
	field.BackgroundTransparency = 0.92
	field.BorderSizePixel = 0
	field.ZIndex = zBase + 2
	field.Parent = holder
	Corner(field, 7)
	local fieldStroke = Stroke(field, Color3.new(1, 1, 1), 1, 0.88)
 
	local box = Instance.new("TextBox")
	box.ClearTextOnFocus = false
	box.FontFace = NullUI.Theme.FontRegular
	box.Text = ""
	box.TextColor3 = NullUI.Theme.Text
	box.TextSize = 13
	box.TextXAlignment = Enum.TextXAlignment.Center
	box.TextYAlignment = Enum.TextYAlignment.Center
	box.BackgroundTransparency = 1
	box.Size = UDim2.fromScale(1, 1)
	box.ZIndex = zBase + 3
	box.Parent = field
 
	box.Focused:Connect(function()
		Tween(fieldStroke, { Color = NullUI.Theme.Accent, Transparency = 0.3 }, 0.15)
		Tween(field, { BackgroundTransparency = 0.84 }, 0.15)
	end)
	box.FocusLost:Connect(function()
		Tween(fieldStroke, { Color = Color3.new(1, 1, 1), Transparency = 0.88 }, 0.15)
		Tween(field, { BackgroundTransparency = 0.92 }, 0.15)
	end)
 
	return holder, box
end
 
function Tab:AddColorPicker(opts)
	opts = opts or {}
	local hasDesc = opts.Description and opts.Description ~= ""
	local height = hasDesc and 56 or 44
	local jan = self._janitor
 
	local card = BaseCard(self._page, height)
	local textX = AddLeadingIcon(card, opts.Icon, height)
	AddTitleDesc(card, textX, 52, opts.Text or "Color", opts.Description, height)
	self._window:_RegisterSearchable(self, opts.Text or "Color", card)
 
	local color = opts.Default or Color3.fromRGB(255, 255, 255)
	local hue, sat, val = Color3.toHSV(color)
 
	local swatchHolder = Instance.new("Frame")
	swatchHolder.AnchorPoint = Vector2.new(1, 0.5)
	swatchHolder.Position = UDim2.new(1, -14, 0.5, 0)
	swatchHolder.Size = UDim2.fromOffset(24, 24)
	swatchHolder.BackgroundColor3 = Color3.new(1, 1, 1)
	swatchHolder.BackgroundTransparency = 0.9
	swatchHolder.BorderSizePixel = 0
	swatchHolder.ZIndex = Z.Content + 1
	swatchHolder.Parent = card
	Corner(swatchHolder, 6)
	local swatchStroke = Stroke(swatchHolder, Color3.new(1, 1, 1), 1, 0.85)
 
	local swatch = Instance.new("Frame")
	swatch.AnchorPoint = Vector2.new(0.5, 0.5)
	swatch.Position = UDim2.fromScale(0.5, 0.5)
	swatch.Size = UDim2.fromOffset(16, 16)
	swatch.BackgroundColor3 = color
	swatch.BorderSizePixel = 0
	swatch.ZIndex = Z.Content + 2
	swatch.Parent = swatchHolder
	Corner(swatch, 4)
 
	local click = Instance.new("TextButton")
	click.Text = ""
	click.AutoButtonColor = false
	click.BackgroundTransparency = 1
	click.Size = UDim2.fromScale(1, 1)
	click.ZIndex = Z.Content + 3
	click.Parent = card
 
	local popupOpen = false
	local popupFrame, popupBackdrop, followConn
	local svCursor, hueCursor, svBox, hueBar, satGradient
	local hexBox, rBox, gBox, bBox
	local originalHue, originalSat, originalVal
	local draggingSV, draggingHue = false, false
	local colorInput = nil
	local dragEndedAt = 0
 
	local function currentColor()
		return Color3.fromHSV(hue, sat, val)
	end
 
	local function syncFields()
		if svCursor then svCursor.Position = UDim2.new(sat, 0, 1 - val, 0) end
		if hueCursor then hueCursor.Position = UDim2.new(hue, 0, 0.5, 0) end
		if svBox then svBox.BackgroundColor3 = Color3.new(1, 1, 1) end
		if satGradient then
			satGradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHSV(hue, 1, 1))
		end
 
		local c = currentColor()
		local r = math.floor(c.R * 255 + 0.5)
		local g = math.floor(c.G * 255 + 0.5)
		local b = math.floor(c.B * 255 + 0.5)
		if hexBox and not hexBox:IsFocused() then hexBox.Text = "#" .. c:ToHex():upper() end
		if rBox and not rBox:IsFocused() then rBox.Text = tostring(r) end
		if gBox and not gBox:IsFocused() then gBox.Text = tostring(g) end
		if bBox and not bBox:IsFocused() then bBox.Text = tostring(b) end
	end
 
	local signal = MakeSignal()
	local lastFired = nil
 
	local function ColorsClose(a, b)
		if a == nil or b == nil then return false end
		return math.abs(a.R - b.R) < 0.001
			and math.abs(a.G - b.G) < 0.001
			and math.abs(a.B - b.B) < 0.001
	end
 
	local function applyColor(fireCallback)
		local c = currentColor()
		swatch.BackgroundColor3 = c
		syncFields()
		if fireCallback then
			if not ColorsClose(c, lastFired) then
				lastFired = c
				if opts.Callback then task.spawn(opts.Callback, c) end
				signal.Fire(c)
			end
		end
	end
 
	local function closePopup()
		if not popupOpen then return end
		popupOpen = false
		draggingSV, draggingHue = false, false
		colorInput = nil
		RegisterPopupClose(closePopup)
		Tween(swatchStroke, { Color = Color3.new(1, 1, 1), Transparency = 0.85 }, 0.15)
 
		if followConn then followConn:Disconnect(); followConn = nil end
		if popupBackdrop then popupBackdrop:Destroy(); popupBackdrop = nil end
 
		if popupFrame then
			local pf = popupFrame
			popupFrame = nil
			svCursor, hueCursor, svBox, hueBar, satGradient = nil, nil, nil, nil, nil
			hexBox, rBox, gBox, bBox = nil, nil, nil, nil
			Tween(pf, { Size = UDim2.new(0, pf.Size.X.Offset, 0, 0) }, 0.4,
				Enum.EasingStyle.Quint, Enum.EasingDirection.In)
			Tween(pf, { BackgroundTransparency = 1 }, 0.34, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
			task.delay(0.4, function() if pf then pf:Destroy() end end)
		end
	end
 
	local function updateSV(inputPos)
		if not svBox or svBox.AbsoluteSize.X <= 0 then return end
		local rel, sz = svBox.AbsolutePosition, svBox.AbsoluteSize
		sat = math.clamp((inputPos.X - rel.X) / sz.X, 0, 1)
		val = 1 - math.clamp((inputPos.Y - rel.Y) / sz.Y, 0, 1)
		applyColor(true)
	end
 
	local function updateHue(inputPos)
		if not hueBar or hueBar.AbsoluteSize.X <= 0 then return end
		local rel, sz = hueBar.AbsolutePosition, hueBar.AbsoluteSize
		hue = math.clamp((inputPos.X - rel.X) / sz.X, 0, 1)
		applyColor(true)
	end
 
	jan:Add(UserInputService.InputChanged:Connect(function(input)
		if not popupFrame then return end
		if input ~= colorInput
			and not (colorInput and colorInput.UserInputType == Enum.UserInputType.MouseButton1
				and input.UserInputType == Enum.UserInputType.MouseMovement) then
			return
		end
		if draggingSV then updateSV(input.Position) end
		if draggingHue then updateHue(input.Position) end
	end))
 
	jan:Add(UserInputService.InputEnded:Connect(function(input)
		if input == colorInput
			or (colorInput and colorInput.UserInputType == Enum.UserInputType.MouseButton1
				and input.UserInputType == Enum.UserInputType.MouseButton1) then
			if draggingSV or draggingHue then
				dragEndedAt = os.clock()
			end
			draggingSV, draggingHue = false, false
			colorInput = nil
		end
	end))
 
	local function requestCloseFromBackdrop()
		if draggingSV or draggingHue then return end
		if os.clock() - dragEndedAt < 0.2 then return end
		closePopup()
	end
 
	local function openPopup()
		if popupOpen then return end
		popupOpen = true
		originalHue, originalSat, originalVal = hue, sat, val
		lastFired = currentColor()
		RegisterPopupOpen(closePopup)
		Tween(swatchStroke, { Color = NullUI.Theme.Accent, Transparency = 0.3 }, 0.15)
 
		local root = NullUI._Root
		local mainWindow = self._window and self._window._gui or root
		local popupW, popupH = 208, math.min(290, math.max(1, (ViewportSize().Y - 16) / GetUIScale()))
 
		popupBackdrop = MakePopupBackdrop(requestCloseFromBackdrop)
 
		popupFrame = Instance.new("ScrollingFrame")
		popupFrame.CanvasSize = UDim2.fromOffset(0, 290)
		popupFrame.ScrollingDirection = Enum.ScrollingDirection.Y
		popupFrame.ScrollBarThickness = 3
		popupFrame.ScrollBarImageColor3 = NullUI.Theme.TextDim
		popupFrame.ScrollBarImageTransparency = 0.35
		popupFrame.BorderSizePixel = 0
		popupFrame.Name = "ColorPickerPopup"
		popupFrame.Active = true
		popupFrame.BackgroundColor3 = NullUI.Theme.Background
		popupFrame.BackgroundTransparency = 1
		popupFrame.BorderSizePixel = 0
		popupFrame.ClipsDescendants = true
		popupFrame.ZIndex = Z.Popup
		popupFrame.Size = UDim2.new(0, popupW, 0, 0)
		popupFrame.Parent = root
		Corner(popupFrame, 10)
		local popupStroke = Stroke(popupFrame, Color3.new(1, 1, 1), 1, 0.92)
		GlassLayer(popupFrame, 10, 0.985)
 
		local px, py = ComputePopupPosition(mainWindow, card, popupW, popupH)
		popupFrame.Position = UDim2.fromOffset(px, py)
 
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 14)
		pad.PaddingBottom = UDim.new(0, 14)
		pad.PaddingLeft = UDim.new(0, 14)
		pad.PaddingRight = UDim.new(0, 14)
		pad.Parent = popupFrame
 
		local innerW = popupW - 28
 
		svBox = Instance.new("Frame")
		svBox.Active = true
		svBox.Position = UDim2.fromOffset(0, 0)
		svBox.Size = UDim2.fromOffset(innerW, 104)
		svBox.BackgroundColor3 = Color3.new(1, 1, 1)
		svBox.BorderSizePixel = 0
		svBox.ClipsDescendants = true
		svBox.ZIndex = Z.Popup + 1
		svBox.Parent = popupFrame
		Corner(svBox, 8)
 
		satGradient = Instance.new("UIGradient")
		satGradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHSV(hue, 1, 1))
		satGradient.Parent = svBox
 
		local valOverlay = Instance.new("Frame")
		valOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
		valOverlay.BorderSizePixel = 0
		valOverlay.Size = UDim2.fromScale(1, 1)
		valOverlay.ZIndex = Z.Popup + 1
		valOverlay.Parent = svBox
		local valGradient = Instance.new("UIGradient")
		valGradient.Rotation = 90
		valGradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 0),
		})
		valGradient.Parent = valOverlay
 
		local svCursorLayer = Instance.new("Frame")
		svCursorLayer.BackgroundTransparency = 1
		svCursorLayer.BorderSizePixel = 0
		svCursorLayer.ClipsDescendants = false
		svCursorLayer.Position = svBox.Position
		svCursorLayer.Size = svBox.Size
		svCursorLayer.ZIndex = Z.Popup + 2
		svCursorLayer.Parent = popupFrame
 
		svCursor = Instance.new("Frame")
		svCursor.AnchorPoint = Vector2.new(0.5, 0.5)
		svCursor.Position = UDim2.new(sat, 0, 1 - val, 0)
		svCursor.Size = UDim2.fromOffset(16, 16)
		svCursor.BackgroundTransparency = 1
		svCursor.ZIndex = Z.Popup + 3
		svCursor.Parent = svCursorLayer
		Corner(svCursor, 8)
		Stroke(svCursor, Color3.new(0, 0, 0), 2, 0.15)
 
		local svCursorInner = Instance.new("Frame")
		svCursorInner.AnchorPoint = Vector2.new(0.5, 0.5)
		svCursorInner.Position = UDim2.fromScale(0.5, 0.5)
		svCursorInner.Size = UDim2.fromOffset(11, 11)
		svCursorInner.BackgroundTransparency = 1
		svCursorInner.ZIndex = Z.Popup + 4
		svCursorInner.Parent = svCursor
		Corner(svCursorInner, 6)
		Stroke(svCursorInner, Color3.new(1, 1, 1), 2, 0)
 
		hueBar = Instance.new("Frame")
		hueBar.Active = true
		hueBar.Position = UDim2.fromOffset(0, 114)
		hueBar.Size = UDim2.fromOffset(innerW, 10)
		hueBar.BackgroundColor3 = Color3.new(1, 1, 1)
		hueBar.BorderSizePixel = 0
		hueBar.ClipsDescendants = true
		hueBar.ZIndex = Z.Popup + 1
		hueBar.Parent = popupFrame
		Corner(hueBar, 5)
 
		local hueGradient = Instance.new("UIGradient")
		hueGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.000, Color3.fromHSV(0.000, 1, 1)),
			ColorSequenceKeypoint.new(0.166, Color3.fromHSV(0.166, 1, 1)),
			ColorSequenceKeypoint.new(0.333, Color3.fromHSV(0.333, 1, 1)),
			ColorSequenceKeypoint.new(0.500, Color3.fromHSV(0.500, 1, 1)),
			ColorSequenceKeypoint.new(0.666, Color3.fromHSV(0.666, 1, 1)),
			ColorSequenceKeypoint.new(0.833, Color3.fromHSV(0.833, 1, 1)),
			ColorSequenceKeypoint.new(1.000, Color3.fromHSV(1.000, 1, 1)),
		})
		hueGradient.Parent = hueBar
 
		local hueCursorLayer = Instance.new("Frame")
		hueCursorLayer.BackgroundTransparency = 1
		hueCursorLayer.BorderSizePixel = 0
		hueCursorLayer.ClipsDescendants = false
		hueCursorLayer.Position = hueBar.Position
		hueCursorLayer.Size = hueBar.Size
		hueCursorLayer.ZIndex = Z.Popup + 2
		hueCursorLayer.Parent = popupFrame
 
		hueCursor = Instance.new("Frame")
		hueCursor.AnchorPoint = Vector2.new(0.5, 0.5)
		hueCursor.Position = UDim2.new(hue, 0, 0.5, 0)
		hueCursor.Size = UDim2.fromOffset(6, 10)
		hueCursor.BackgroundColor3 = Color3.new(1, 1, 1)
		hueCursor.BorderSizePixel = 0
		hueCursor.ZIndex = Z.Popup + 3
		hueCursor.Parent = hueCursorLayer
		Corner(hueCursor, 3)
		Stroke(hueCursor, Color3.new(0, 0, 0), 1, 0.4)
 
		local hexHolder, hexRef = MiniField(popupFrame, "HEX", innerW, Z.Popup)
		hexHolder.Position = UDim2.fromOffset(0, 136)
		hexBox = hexRef
 
		local rgbRow = Instance.new("Frame")
		rgbRow.BackgroundTransparency = 1
		rgbRow.Position = UDim2.fromOffset(0, 182)
		rgbRow.Size = UDim2.fromOffset(innerW, 36)
		rgbRow.ZIndex = Z.Popup + 1
		rgbRow.Parent = popupFrame
 
		local rHolder, rRef = MiniField(rgbRow, "R", 54, Z.Popup)
		rHolder.Position = UDim2.fromOffset(0, 0)
		rBox = rRef
 
		local gHolder, gRef = MiniField(rgbRow, "G", 54, Z.Popup)
		gHolder.Position = UDim2.fromOffset(62, 0)
		gBox = gRef
 
		local bHolder, bRef = MiniField(rgbRow, "B", 56, Z.Popup)
		bHolder.Position = UDim2.fromOffset(124, 0)
		bBox = bRef
 
		local btnRow = Instance.new("Frame")
		btnRow.BackgroundTransparency = 1
		btnRow.Position = UDim2.fromOffset(0, 232)
		btnRow.Size = UDim2.fromOffset(innerW, 30)
		btnRow.ZIndex = Z.Popup + 1
		btnRow.Parent = popupFrame
 
		local function MakeButton(text, x, w, filled)
			local btn = Instance.new("TextButton")
			btn.Position = UDim2.fromOffset(x, 0)
			btn.Size = UDim2.fromOffset(w, 30)
			btn.FontFace = NullUI.Theme.Font
			btn.Text = text
			btn.TextSize = 13
			btn.AutoButtonColor = false
			btn.BorderSizePixel = 0
			btn.ZIndex = Z.Popup + 2
			if filled then
				btn.BackgroundColor3 = NullUI.Theme.Accent
				btn.BackgroundTransparency = 0
				btn.TextColor3 = NullUI.Theme.Background
			else
				btn.BackgroundColor3 = Color3.new(1, 1, 1)
				btn.BackgroundTransparency = 0.92
				btn.TextColor3 = NullUI.Theme.Text
			end
			btn.Parent = btnRow
			Corner(btn, 8)
			if not filled then Stroke(btn, Color3.new(1, 1, 1), 1, 0.88) end
			return btn
		end
 
		local halfW = (innerW - 10) / 2
		local cancelBtn = MakeButton("Cancel", 0, halfW, false)
		local doneBtn   = MakeButton("Done", halfW + 10, halfW, true)
 
		cancelBtn.Activated:Connect(function()
			hue, sat, val = originalHue, originalSat, originalVal
			applyColor(true)
			closePopup()
		end)
		doneBtn.Activated:Connect(closePopup)
 
		svBox.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				if draggingSV or draggingHue then return end
				draggingSV = true
				colorInput = input
				updateSV(input.Position)
			end
		end)
 
		hueBar.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				if draggingSV or draggingHue then return end
				draggingHue = true
				colorInput = input
				updateHue(input.Position)
			end
		end)
 
		hexBox:GetPropertyChangedSignal("Text"):Connect(function()
			local filtered = hexBox.Text:gsub("[^%x]", "")
			filtered = filtered:sub(1, 6)
			if filtered ~= hexBox.Text then hexBox.Text = filtered end
		end)
 
		hexBox.FocusLost:Connect(function()
			local clean = hexBox.Text:gsub("#", "")
			if #clean == 3 then
				clean = clean:sub(1, 1):rep(2) .. clean:sub(2, 2):rep(2) .. clean:sub(3, 3):rep(2)
			end
			if #clean == 6 then
				local ok, c = pcall(Color3.fromHex, clean)
				if ok and c then
					hue, sat, val = Color3.toHSV(c)
					applyColor(true)
					return
				end
			end
			syncFields()
		end)
 
		local function filterDigits(b)
			b:GetPropertyChangedSignal("Text"):Connect(function()
				local filtered = b.Text:gsub("%D", ""):sub(1, 3)
				if filtered ~= b.Text then b.Text = filtered end
			end)
		end
		filterDigits(rBox); filterDigits(gBox); filterDigits(bBox)
 
		local function onRGBCommit()
			local r = math.clamp(tonumber(rBox.Text) or 0, 0, 255)
			local g = math.clamp(tonumber(gBox.Text) or 0, 0, 255)
			local b = math.clamp(tonumber(bBox.Text) or 0, 0, 255)
			hue, sat, val = Color3.toHSV(Color3.fromRGB(r, g, b))
			applyColor(true)
		end
		rBox.FocusLost:Connect(onRGBCommit)
		gBox.FocusLost:Connect(onRGBCommit)
		bBox.FocusLost:Connect(onRGBCommit)
 
		syncFields()
 
		Tween(popupFrame, {
			Size = UDim2.new(0, popupW, 0, popupH),
			BackgroundTransparency = 0.15,
		}, 0.44, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		Tween(popupStroke, { Transparency = 0.85 }, 0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
 
		followConn = RunService.RenderStepped:Connect(function()
			if not popupFrame or not card.Parent then return end
			local nx, ny = ComputePopupPosition(mainWindow, card, popupW, popupH)
			popupFrame.Position = UDim2.fromOffset(nx, ny)
		end)
		jan:Add(followConn)
	end
 
	click.MouseButton1Click:Connect(function()
		if popupOpen then closePopup() else openPopup() end
	end)
 
	card.MouseEnter:Connect(function() Tween(card, { BackgroundTransparency = 0.93 }, 0.15) end)
	card.MouseLeave:Connect(function() Tween(card, { BackgroundTransparency = 0.96 }, 0.15) end)
 
	return RegisterFlag(opts, {
		Instance = card,
		Set = function(_, c, silent)
			hue, sat, val = Color3.toHSV(c)
			applyColor(not silent)
			if silent then lastFired = currentColor() end
		end,
		Get = function() return currentColor() end,
		OnChanged = function(_, fn) return signal.Connect(fn) end,
		Destroy = function() closePopup(); signal.Clear(); card:Destroy() end,
	}, "ColorPicker")
end
 
function Tab:AddKeybind(opts)
	opts = opts or {}
	local hasDesc = opts.Description and opts.Description ~= ""
	local height = hasDesc and 56 or 44
	local jan = self._janitor
 
	local card = BaseCard(self._page, height)
	local textX = AddLeadingIcon(card, opts.Icon, height)
	AddTitleDesc(card, textX, 128, opts.Text or "Keybind", opts.Description, height)
	self._window:_RegisterSearchable(self, opts.Text or "Keybind", card)
 
	local currentKey = opts.Default
 
	local pill = Instance.new("Frame")
	pill.AnchorPoint = Vector2.new(1, 0.5)
	pill.Position = UDim2.new(1, -14, 0.5, 0)
	pill.Size = UDim2.fromOffset(104, 26)
	pill.BackgroundColor3 = Color3.new(1, 1, 1)
	pill.BackgroundTransparency = 0.9
	pill.BorderSizePixel = 0
	pill.ZIndex = Z.Content + 2
	pill.Parent = card
	Corner(pill, 8)
	local pillStroke = Stroke(pill, Color3.new(1, 1, 1), 1, 0.88)
 
	local keyIcon = Instance.new("ImageLabel")
	keyIcon.BackgroundTransparency = 1
	keyIcon.Image = ResolveIcon("keyboard")
	keyIcon.ImageColor3 = NullUI.Theme.TextDim
	keyIcon.Size = UDim2.fromOffset(13, 13)
	keyIcon.AnchorPoint = Vector2.new(0, 0.5)
	keyIcon.Position = UDim2.new(0, 10, 0.5, 0)
	keyIcon.ZIndex = Z.Content + 3
	keyIcon.Parent = pill
 
	local keyLabel = Instance.new("TextLabel")
	keyLabel.BackgroundTransparency = 1
	keyLabel.FontFace = NullUI.Theme.FontRegular
	keyLabel.Text = currentKey and currentKey.Name or "None"
	keyLabel.TextColor3 = NullUI.Theme.Text
	keyLabel.TextSize = 13
	keyLabel.TextTruncate = Enum.TextTruncate.AtEnd
	keyLabel.TextXAlignment = Enum.TextXAlignment.Left
	keyLabel.Position = UDim2.fromOffset(29, 0)
	keyLabel.Size = UDim2.new(1, -37, 1, 0)
	keyLabel.ZIndex = Z.Content + 3
	keyLabel.Parent = pill
 
	local click = Instance.new("TextButton")
	click.Text = ""
	click.AutoButtonColor = false
	click.BackgroundTransparency = 1
	click.Size = UDim2.fromScale(1, 1)
	click.ZIndex = Z.Content + 4
	click.Parent = pill
 
	local listening = false
	local listenConn = nil
	local signal = MakeSignal()
 
	local function fireChanged(key)
		signal.Fire(key)
	end
 
	local function stopListening()
		listening = false
		KeybindCapturing = false
		if listenConn then listenConn:Disconnect(); listenConn = nil end
		Tween(pillStroke, { Color = Color3.new(1, 1, 1), Transparency = 0.88 }, 0.15)
		Tween(pill, { BackgroundTransparency = 0.9 }, 0.15)
		keyLabel.Text = currentKey and currentKey.Name or "None"
	end
 
	local function startListening()
		if listening then return end
		listening = true
		KeybindCapturing = true
		keyLabel.Text = "..."
		Tween(pillStroke, { Color = NullUI.Theme.Accent, Transparency = 0.3 }, 0.15)
		Tween(pill, { BackgroundTransparency = 0.82 }, 0.15)
 
		listenConn = UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
 
			if input.KeyCode == Enum.KeyCode.Escape then
				stopListening()
				return
			end
			if input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Delete then
				currentKey = nil
				stopListening()
				fireChanged(nil)
				return
			end
 
			currentKey = input.KeyCode
			stopListening()
			if opts.Callback then task.spawn(opts.Callback, currentKey, "bind") end
			fireChanged(currentKey)
		end)
		jan:Add(listenConn)
	end
 
	click.MouseButton1Click:Connect(startListening)
 
	jan:Add(UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if listening or KeybindCapturing or gameProcessed then return end
		if UserInputService:GetFocusedTextBox() then return end
		if currentKey
			and input.UserInputType == Enum.UserInputType.Keyboard
			and input.KeyCode == currentKey then
			if opts.Callback then task.spawn(opts.Callback, currentKey, "press") end
		end
	end))
 
	card.MouseEnter:Connect(function() Tween(card, { BackgroundTransparency = 0.93 }, 0.15) end)
	card.MouseLeave:Connect(function() Tween(card, { BackgroundTransparency = 0.96 }, 0.15) end)
 
	return RegisterFlag(opts, {
		Instance = card,
		Set = function(_, key, silent)
			currentKey = key
			keyLabel.Text = key and key.Name or "None"
			if not silent then fireChanged(key) end
		end,
		Get = function() return currentKey end,
		OnChanged = function(_, fn) return signal.Connect(fn) end,
		Destroy = function() stopListening(); signal.Clear(); card:Destroy() end,
	}, "Keybind")
end
 
local ConsoleColors = {
	[Enum.MessageType.MessageInfo]    = Color3.fromRGB(120, 170, 255),
	[Enum.MessageType.MessageWarning] = Color3.fromRGB(255, 190, 90),
	[Enum.MessageType.MessageError]   = Color3.fromRGB(255, 105, 105),
	[Enum.MessageType.MessageOutput]  = nil,
}
 
function Tab:AddConsole(opts)
	opts = opts or {}
	local height = opts.Height or 200
	local maxLogs = opts.MaxLogs or 300
	local jan = self._janitor
 
	local container = Instance.new("Frame")
	container.Name = "Console"
	container.BackgroundColor3 = NullUI.Theme.Surface
	container.BackgroundTransparency = 0.35
	container.BorderSizePixel = 0
	container.ClipsDescendants = true
	container.Size = UDim2.new(1, 0, 0, height)
	container.ZIndex = Z.Content
	container.Parent = self._page
	Corner(container, NullUI.Theme.CornerRadiusSm)
	Stroke(container, Color3.new(1, 1, 1), 1, 0.92)
 
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 34)
	header.ZIndex = Z.Content + 1
	header.Parent = container
 
	local headerPad = Instance.new("UIPadding")
	headerPad.PaddingLeft = UDim.new(0, 12)
	headerPad.PaddingRight = UDim.new(0, 8)
	headerPad.Parent = header
 
	local titleRow = Instance.new("Frame")
	titleRow.BackgroundTransparency = 1
	titleRow.Size = UDim2.new(1, -70, 1, 0)
	titleRow.ZIndex = Z.Content + 2
	titleRow.Parent = header
 
	local titleLayout = Instance.new("UIListLayout")
	titleLayout.FillDirection = Enum.FillDirection.Horizontal
	titleLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	titleLayout.Padding = UDim.new(0, 7)
	titleLayout.Parent = titleRow
 
	local titleIcon = Instance.new("ImageLabel")
	titleIcon.BackgroundTransparency = 1
	titleIcon.Image = ResolveIcon("terminal")
	titleIcon.ImageColor3 = NullUI.Theme.TextDim
	titleIcon.Size = UDim2.fromOffset(14, 14)
	titleIcon.LayoutOrder = 1
	titleIcon.ZIndex = Z.Content + 3
	titleIcon.Parent = titleRow
 
	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.FontFace = NullUI.Theme.Font
	titleLabel.Text = opts.Title or "Debug Console"
	titleLabel.TextColor3 = NullUI.Theme.Text
	titleLabel.TextSize = 13
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	titleLabel.AutomaticSize = Enum.AutomaticSize.X
	titleLabel.Size = UDim2.fromOffset(0, 14)
	titleLabel.LayoutOrder = 2
	titleLabel.ZIndex = Z.Content + 3
	titleLabel.Parent = titleRow
 
	local controls = Instance.new("Frame")
	controls.BackgroundTransparency = 1
	controls.AnchorPoint = Vector2.new(1, 0.5)
	controls.Position = UDim2.new(1, 0, 0.5, 0)
	controls.Size = UDim2.fromOffset(58, 24)
	controls.ZIndex = Z.Content + 2
	controls.Parent = header
 
	local controlsLayout = Instance.new("UIListLayout")
	controlsLayout.FillDirection = Enum.FillDirection.Horizontal
	controlsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	controlsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	controlsLayout.Padding = UDim.new(0, 4)
	controlsLayout.Parent = controls
 
	local function iconButton(icon, order)
		local btn = Instance.new("TextButton")
		btn.Text = ""
		btn.AutoButtonColor = false
		btn.BackgroundColor3 = Color3.new(1, 1, 1)
		btn.BackgroundTransparency = 1
		btn.BorderSizePixel = 0
		btn.Size = UDim2.fromOffset(24, 24)
		btn.LayoutOrder = order
		btn.ZIndex = Z.Content + 3
		btn.Parent = controls
		Corner(btn, 7)
 
		local ic = Instance.new("ImageLabel")
		ic.BackgroundTransparency = 1
		ic.Image = ResolveIcon(icon)
		ic.ImageColor3 = NullUI.Theme.TextDim
		ic.Size = UDim2.fromOffset(13, 13)
		ic.AnchorPoint = Vector2.new(0.5, 0.5)
		ic.Position = UDim2.fromScale(0.5, 0.5)
		ic.ZIndex = Z.Content + 4
		ic.Parent = btn
 
		jan:Add(btn.MouseEnter:Connect(function()
			Tween(btn, { BackgroundTransparency = 0.9 }, 0.12)
			Tween(ic, { ImageColor3 = NullUI.Theme.Text }, 0.12)
		end))
		jan:Add(btn.MouseLeave:Connect(function()
			Tween(btn, { BackgroundTransparency = 1 }, 0.12)
			Tween(ic, { ImageColor3 = NullUI.Theme.TextDim }, 0.12)
		end))
 
		return btn, ic
	end
 
	local copyBtn, copyIcon = iconButton("copy", 1)
	local clearBtn = iconButton("trash-2", 2)
 
	local divider = Instance.new("Frame")
	divider.BackgroundColor3 = Color3.new(1, 1, 1)
	divider.BackgroundTransparency = 0.92
	divider.BorderSizePixel = 0
	divider.Size = UDim2.new(1, 0, 0, 1)
	divider.Position = UDim2.fromOffset(0, 34)
	divider.ZIndex = Z.Content + 1
	divider.Parent = container
 
	local logsScroll = Instance.new("ScrollingFrame")
	logsScroll.Name = "Logs"
	logsScroll.BackgroundTransparency = 1
	logsScroll.BorderSizePixel = 0
	logsScroll.Position = UDim2.fromOffset(0, 35)
	logsScroll.Size = UDim2.new(1, 0, 1, -35)
	logsScroll.ScrollingDirection = Enum.ScrollingDirection.Y
	logsScroll.ScrollBarThickness = 0
	logsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	logsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	logsScroll.ZIndex = Z.Content + 1
	logsScroll.Parent = container
 
	local logsPad = Instance.new("UIPadding")
	logsPad.PaddingTop = UDim.new(0, 8)
	logsPad.PaddingBottom = UDim.new(0, 8)
	logsPad.PaddingLeft = UDim.new(0, 10)
	logsPad.PaddingRight = UDim.new(0, 10)
	logsPad.Parent = logsScroll
 
	local logsLayout = Instance.new("UIListLayout")
	logsLayout.Padding = UDim.new(0, 4)
	logsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	logsLayout.Parent = logsScroll
 
	AddScrollbar(logsScroll)
	AddContentScrollThumb(logsScroll, logsLayout, container, jan)
 
	local emptyState = Instance.new("Frame")
	emptyState.Name = "EmptyState"
	emptyState.BackgroundTransparency = 1
	emptyState.Position = UDim2.fromOffset(0, 35)
	emptyState.Size = UDim2.new(1, 0, 1, -35)
	emptyState.ZIndex = Z.Content + 2
	emptyState.Parent = container
 
	local emptyLayout = Instance.new("UIListLayout")
	emptyLayout.FillDirection = Enum.FillDirection.Vertical
	emptyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	emptyLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	emptyLayout.Padding = UDim.new(0, 6)
	emptyLayout.Parent = emptyState
 
	local emptyIcon = Instance.new("ImageLabel")
	emptyIcon.BackgroundTransparency = 1
	emptyIcon.Image = ResolveIcon("frown")
	emptyIcon.ImageColor3 = NullUI.Theme.TextDim
	emptyIcon.Size = UDim2.fromOffset(22, 22)
	emptyIcon.LayoutOrder = 1
	emptyIcon.ZIndex = Z.Content + 3
	emptyIcon.Parent = emptyState
 
	local emptyLabel = Instance.new("TextLabel")
	emptyLabel.BackgroundTransparency = 1
	emptyLabel.FontFace = NullUI.Theme.FontRegular
	emptyLabel.Text = "No logs at the moment"
	emptyLabel.TextColor3 = NullUI.Theme.TextDim
	emptyLabel.TextSize = 12
	emptyLabel.AutomaticSize = Enum.AutomaticSize.XY
	emptyLabel.Size = UDim2.fromOffset(0, 14)
	emptyLabel.LayoutOrder = 2
	emptyLabel.ZIndex = Z.Content + 3
	emptyLabel.Parent = emptyState
 
	local logs = {}
	local logCount = 0
	local counter = 0
	local autoScroll = true
 
	local function trimLogs()
		while logCount > maxLogs do
			local oldest = table.remove(logs, 1)
			if oldest then
				oldest:Destroy()
				logCount = logCount - 1
			else
				break
			end
		end
	end
 
	local function escapeRich(text)
		return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
	end
 
	local function addLog(message, messageType)
		message = tostring(message or "")
		if message == "" then return end
		trimLogs()
 
		counter = counter + 1
		local color = ConsoleColors[messageType] or NullUI.Theme.Text
 
		local entry = Instance.new("TextLabel")
		entry.Name = "Entry"
		entry.BackgroundTransparency = 1
		entry.RichText = true
		entry.FontFace = NullUI.Theme.FontRegular
		entry.TextSize = 12
		entry.TextWrapped = true
		entry.TextXAlignment = Enum.TextXAlignment.Left
		entry.TextYAlignment = Enum.TextYAlignment.Top
		entry.LineHeight = 1.25
		entry.AutomaticSize = Enum.AutomaticSize.Y
		entry.Size = UDim2.new(1, 0, 0, 14)
		entry.LayoutOrder = counter
		entry.ZIndex = Z.Content + 2
		entry.Text = string.format(
			'<font color="#%s" transparency="0.45">[%s]</font> <font color="#%s">%s</font>',
			NullUI.Theme.TextDim:ToHex(), os.date("%H:%M:%S"),
			color:ToHex(), escapeRich(message)
		)
		entry.Parent = logsScroll
 
		table.insert(logs, entry)
		logCount = logCount + 1
		emptyState.Visible = false
 
		if autoScroll then
			task.defer(function()
				logsScroll.CanvasPosition = Vector2.new(0, logsScroll.AbsoluteCanvasSize.Y)
			end)
		end
	end
 
	jan:Add(logsScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		local atBottom = logsScroll.CanvasPosition.Y >= logsScroll.AbsoluteCanvasSize.Y - logsScroll.AbsoluteWindowSize.Y - 20
		autoScroll = atBottom
	end))
 
	copyBtn.MouseButton1Click:Connect(function()
		local setclipboard = hasFn("setclipboard")
		if not setclipboard then return end
 
		local lines = {}
		for _, entry in ipairs(logs) do
			local clean = entry.Text
				:gsub('<font[^>]*>', "")
				:gsub("</font>", "")
				:gsub("&lt;", "<")
				:gsub("&gt;", ">")
				:gsub("&amp;", "&")
			table.insert(lines, clean)
		end
		setclipboard(table.concat(lines, "\n"))
 
		Tween(copyIcon, { ImageColor3 = Color3.fromRGB(120, 220, 140) }, 0.1)
		task.delay(0.4, function()
			if copyIcon.Parent then
				Tween(copyIcon, { ImageColor3 = NullUI.Theme.TextDim }, 0.15)
			end
		end)
	end)
 
	local function clearLogs()
		for _, entry in ipairs(logs) do
			entry:Destroy()
		end
		table.clear(logs)
		logCount = 0
		emptyState.Visible = true
	end
 
	clearBtn.MouseButton1Click:Connect(clearLogs)
 
	if opts.AutoCapture ~= false then
		local LogService = game:GetService("LogService")
		jan:Add(LogService.MessageOut:Connect(addLog))
	end
 
	return {
		Instance = container,
		Log = function(_, message, messageType) addLog(message, messageType) end,
		Clear = function() clearLogs() end,
		Destroy = function() container:Destroy() end,
	}
end
 
function Tab:AddTable(opts)
	opts = opts or {}
	local jan = self._janitor
	local title = opts.Title or "Table"
	local hasDesc = opts.Description and opts.Description ~= ""
	local columns = opts.Columns or {}
	local rowHeight = opts.RowHeight or 30
	local bodyHeight = opts.Height or 200
	local sortable = opts.Sortable ~= false
	local striped = opts.Striped ~= false
 
	local totalWeight = 0
	for _, col in ipairs(columns) do
		col.Weight = col.Weight or 1
		totalWeight = totalWeight + col.Weight
	end
	if totalWeight <= 0 then totalWeight = 1 end
 
	local function colAlign(col)
		if col.Align == "Right" then return Enum.TextXAlignment.Right end
		if col.Align == "Center" then return Enum.TextXAlignment.Center end
		return Enum.TextXAlignment.Left
	end
 
	local function colX(index)
		local w = 0
		for i = 1, index - 1 do w = w + columns[i].Weight end
		return w / totalWeight
	end
 
	local PAD = 12
	local HEADER_H = hasDesc and 32 or 16
	local COLHEAD_H = 26
	local GAP1, GAP2 = 10, 6
	local colHeadY = PAD + HEADER_H + GAP1
	local scrollY = colHeadY + COLHEAD_H + GAP2
	local totalHeight = scrollY + bodyHeight + PAD
 
	local container = Instance.new("Frame")
	container.Name = "Table"
	container.BackgroundColor3 = NullUI.Theme.Surface
	container.BackgroundTransparency = 0.35
	container.BorderSizePixel = 0
	container.ClipsDescendants = true
	container.Size = UDim2.new(1, 0, 0, totalHeight)
	container.ZIndex = Z.Content
	container.Parent = self._page
	Corner(container, NullUI.Theme.CornerRadiusSm)
	Stroke(container, Color3.new(1, 1, 1), 1, 0.92)
	self._window:_RegisterSearchable(self, title, container)
 
	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.FontFace = NullUI.Theme.Font
	titleLabel.Text = title
	titleLabel.TextColor3 = NullUI.Theme.Text
	titleLabel.TextSize = 14
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	titleLabel.Position = UDim2.fromOffset(PAD, PAD)
	titleLabel.Size = UDim2.new(1, -PAD * 2, 0, 16)
	titleLabel.ZIndex = Z.Content + 1
	titleLabel.Parent = container
 
	if hasDesc then
		local descLabel = Instance.new("TextLabel")
		descLabel.BackgroundTransparency = 1
		descLabel.FontFace = NullUI.Theme.FontRegular
		descLabel.Text = opts.Description
		descLabel.TextColor3 = NullUI.Theme.TextDim
		descLabel.TextSize = 12
		descLabel.TextWrapped = true
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.TextYAlignment = Enum.TextYAlignment.Top
		descLabel.Position = UDim2.fromOffset(PAD, PAD + 18)
		descLabel.Size = UDim2.new(1, -PAD * 2, 0, 14)
		descLabel.ZIndex = Z.Content + 1
		descLabel.Parent = container
	end
 
	local colHead = Instance.new("Frame")
	colHead.Name = "ColumnHeader"
	colHead.BackgroundTransparency = 1
	colHead.Position = UDim2.fromOffset(PAD, colHeadY)
	colHead.Size = UDim2.new(1, -PAD * 2, 0, COLHEAD_H)
	colHead.ZIndex = Z.Content + 1
	colHead.Parent = container
 
	local sortState = { Key = nil, Asc = true }
	local headerLabels = {}
 
	for ci, col in ipairs(columns) do
		local x0 = colX(ci)
		local wFrac = col.Weight / totalWeight
 
		local cellBtn = Instance.new("TextButton")
		cellBtn.Name = "Col" .. ci
		cellBtn.Text = ""
		cellBtn.AutoButtonColor = false
		cellBtn.BackgroundTransparency = 1
		cellBtn.Position = UDim2.new(x0, ci > 1 and 4 or 0, 0, 0)
		cellBtn.Size = UDim2.new(wFrac, ci > 1 and -4 or 0, 1, 0)
		cellBtn.ZIndex = Z.Content + 2
		cellBtn.Parent = colHead
 
		local lbl = Instance.new("TextLabel")
		lbl.BackgroundTransparency = 1
		lbl.FontFace = NullUI.Theme.Font
		lbl.Text = tostring(col.Label or col.Key or "")
		lbl.TextColor3 = NullUI.Theme.TextDim
		lbl.TextSize = 12
		lbl.TextXAlignment = colAlign(col)
		lbl.TextTruncate = Enum.TextTruncate.AtEnd
		lbl.Size = UDim2.new(1, 0, 1, 0)
		lbl.ZIndex = Z.Content + 3
		lbl.Parent = cellBtn
 
		headerLabels[col.Key] = { Lbl = lbl, Text = tostring(col.Label or col.Key or "") }
 
		if sortable then
			cellBtn.MouseEnter:Connect(function()
				if sortState.Key ~= col.Key then Tween(lbl, { TextColor3 = NullUI.Theme.Text }, 0.12) end
			end)
			cellBtn.MouseLeave:Connect(function()
				if sortState.Key ~= col.Key then Tween(lbl, { TextColor3 = NullUI.Theme.TextDim }, 0.12) end
			end)
		end
	end
 
	local divider = Instance.new("Frame")
	divider.BackgroundColor3 = Color3.new(1, 1, 1)
	divider.BackgroundTransparency = 0.92
	divider.BorderSizePixel = 0
	divider.Position = UDim2.fromOffset(0, colHeadY + COLHEAD_H)
	divider.Size = UDim2.new(1, 0, 0, 1)
	divider.ZIndex = Z.Content + 1
	divider.Parent = container
 
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Rows"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(0, scrollY)
	scroll.Size = UDim2.new(1, 0, 0, bodyHeight)
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.ScrollBarThickness = 0
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.ZIndex = Z.Content + 1
	scroll.Parent = container
 
	local scrollPad = Instance.new("UIPadding")
	scrollPad.PaddingLeft = UDim.new(0, PAD)
	scrollPad.PaddingRight = UDim.new(0, PAD)
	scrollPad.Parent = scroll
 
	local rowsLayout = Instance.new("UIListLayout")
	rowsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowsLayout.Parent = scroll
 
	AddScrollbar(scroll)
	AddContentScrollThumb(scroll, rowsLayout, container, jan)
 
	local emptyLabel = Instance.new("TextLabel")
	emptyLabel.BackgroundTransparency = 1
	emptyLabel.FontFace = NullUI.Theme.FontRegular
	emptyLabel.Text = "No rows"
	emptyLabel.TextColor3 = NullUI.Theme.TextDim
	emptyLabel.TextSize = 12
	emptyLabel.Position = UDim2.fromOffset(PAD, scrollY + 10)
	emptyLabel.Size = UDim2.new(1, -PAD * 2, 0, 16)
	emptyLabel.Visible = false
	emptyLabel.ZIndex = Z.Content + 1
	emptyLabel.Parent = container
 
	local currentRows = {}
	local rowFrames = {}
 
	local function clearRowFrames()
		for _, f in ipairs(rowFrames) do f:Destroy() end
		table.clear(rowFrames)
	end
 
	local function renderRows()
		clearRowFrames()
		emptyLabel.Visible = #currentRows == 0
		for ri, row in ipairs(currentRows) do
			local rowFrame = Instance.new("Frame")
			rowFrame.Name = "Row" .. ri
			rowFrame.BackgroundColor3 = Color3.new(1, 1, 1)
			rowFrame.BackgroundTransparency = (striped and ri % 2 == 0) and 0.97 or 1
			rowFrame.BorderSizePixel = 0
			rowFrame.LayoutOrder = ri
			rowFrame.Size = UDim2.new(1, 0, 0, rowHeight)
			rowFrame.ZIndex = Z.Content + 2
			rowFrame.Parent = scroll
 
			for ci, col in ipairs(columns) do
				local x0 = colX(ci)
				local wFrac = col.Weight / totalWeight
 
				local cell = Instance.new("TextLabel")
				cell.Name = "Cell" .. ci
				cell.BackgroundTransparency = 1
				cell.FontFace = NullUI.Theme.FontRegular
				cell.Text = tostring(row[col.Key] == nil and "" or row[col.Key])
				cell.TextColor3 = NullUI.Theme.Text
				cell.TextSize = 12
				cell.TextXAlignment = colAlign(col)
				cell.TextTruncate = Enum.TextTruncate.AtEnd
				cell.Position = UDim2.new(x0, ci > 1 and 4 or 0, 0, 0)
				cell.Size = UDim2.new(wFrac, ci > 1 and -4 or 0, 1, 0)
				cell.ZIndex = Z.Content + 3
				cell.Parent = rowFrame
			end
 
			table.insert(rowFrames, rowFrame)
		end
	end
 
	local function compareValues(av, bv)
		local an, bn = tonumber(av), tonumber(bv)
		if an and bn then
			if an == bn then return 0 end
			return an < bn and -1 or 1
		end
		local as, bs = tostring(av or ""), tostring(bv or "")
		if as == bs then return 0 end
		return as < bs and -1 or 1
	end
 
	local function applySort()
		if not sortState.Key then return end
		table.sort(currentRows, function(a, b)
			local c = compareValues(a[sortState.Key], b[sortState.Key])
			if sortState.Asc then return c < 0 else return c > 0 end
		end)
		renderRows()
	end
 
	if sortable then
		for ci, col in ipairs(columns) do
			local cellBtn = colHead:FindFirstChild("Col" .. ci)
			if cellBtn then
				cellBtn.MouseButton1Click:Connect(function()
					if sortState.Key == col.Key then
						sortState.Asc = not sortState.Asc
					else
						sortState.Key = col.Key
						sortState.Asc = true
					end
					for key, info in pairs(headerLabels) do
						local arrow = ""
						if key == sortState.Key then arrow = sortState.Asc and "  \226\150\178" or "  \226\150\188" end
						info.Lbl.Text = info.Text .. arrow
						info.Lbl.TextColor3 = (key == sortState.Key) and NullUI.Theme.Text or NullUI.Theme.TextDim
					end
					applySort()
				end)
			end
		end
	end
 
	local api = {
		Instance = container,
		SetRows = function(_, rows)
			currentRows = rows or {}
			if sortState.Key then applySort() else renderRows() end
		end,
		GetRows = function() return currentRows end,
		Destroy = function() container:Destroy() end,
	}
 
	api:SetRows(opts.Rows or {})
 
	return api
end
 
local function Serialize(value)
	local t = typeof(value)
	if t == "Color3" then
		return { __t = "Color3", r = value.R, g = value.G, b = value.B }
	elseif t == "EnumItem" then
		return { __t = "Enum", v = tostring(value) }
	elseif t == "table" then
		local out = {}
		for i, v in ipairs(value) do out[i] = Serialize(v) end
		return out
	end
	return value
end
 
local function Deserialize(value)
	if type(value) ~= "table" then return value end
	if value.__t == "Color3" then
		return Color3.new(value.r, value.g, value.b)
	elseif value.__t == "Enum" then
		local parts = string.split(value.v, ".")
		local ok, result = pcall(function()
			return Enum[parts[2]][parts[3]]
		end)
		return ok and result or nil
	end
	local out = {}
	for i, v in ipairs(value) do out[i] = Deserialize(v) end
	return out
end
 
function Tab:AddCardGrid(opts)
	opts = opts or {}
	local height = opts.Height or 380
	local sorts = opts.Sorts or {}
	local pageSize = opts.PageSize or 20
	local showSearch = opts.Search ~= false
	local descriptionHeight = opts.DescriptionHeight or 28
	local showNativeScrollbar = opts.ShowScrollbar == true
	local cardPadding = opts.CardPadding or 10
 
	local outer = Instance.new("Frame")
	outer.Name = "CardGrid"
	outer.BackgroundColor3 = Color3.new(1, 1, 1)
	outer.BackgroundTransparency = 0.97
	outer.BorderSizePixel = 0
	outer.Size = UDim2.new(1, 0, 0, height)
	outer.ZIndex = Z.Content
	outer.Parent = self._page
	Corner(outer, NullUI.Theme.CornerRadiusSm)
	Stroke(outer, Color3.new(1, 1, 1), 1, 0.95)
	self._window:_RegisterSearchable(self, opts.Title or "Cards", outer)
 
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Size = UDim2.fromScale(1, 1)
	content.ZIndex = Z.Content + 1
	content.Parent = outer
 
	local OUTER_V_PAD = opts.OuterPadding or 18
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, OUTER_V_PAD)
	pad.PaddingBottom = UDim.new(0, OUTER_V_PAD)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = content
 
	local TOP_H, TABS_H = 32, 28
	local headerH = 0
	if showSearch then headerH = headerH + TOP_H end
	if #sorts > 1 then
		if headerH > 0 then headerH = headerH + 8 end
		headerH = headerH + TABS_H
	end
	if headerH > 0 then headerH = headerH + 10 end
 
	local searchBox
	if showSearch then
		local searchPill = Instance.new("Frame")
		searchPill.BackgroundColor3 = Color3.new(1, 1, 1)
		searchPill.BackgroundTransparency = 0.92
		searchPill.BorderSizePixel = 0
		searchPill.Size = UDim2.new(1, 0, 0, TOP_H)
		searchPill.ZIndex = Z.Content + 1
		searchPill.Parent = content
		Corner(searchPill, 9)
		local searchStroke = Stroke(searchPill, Color3.new(1, 1, 1), 1, 0.88)
 
		local searchIcon = Instance.new("ImageLabel")
		searchIcon.BackgroundTransparency = 1
		searchIcon.Image = ResolveIcon("search")
		searchIcon.ImageColor3 = NullUI.Theme.TextDim
		searchIcon.Size = UDim2.fromOffset(13, 13)
		searchIcon.AnchorPoint = Vector2.new(0, 0.5)
		searchIcon.Position = UDim2.new(0, 10, 0.5, 0)
		searchIcon.ZIndex = Z.Content + 2
		searchIcon.Parent = searchPill
 
		searchBox = Instance.new("TextBox")
		searchBox.ClearTextOnFocus = false
		searchBox.FontFace = NullUI.Theme.FontRegular
		searchBox.PlaceholderText = opts.SearchPlaceholder or "Search by name / tags..."
		searchBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 122)
		searchBox.Text = ""
		searchBox.TextColor3 = NullUI.Theme.Text
		searchBox.TextSize = 13
		searchBox.TextXAlignment = Enum.TextXAlignment.Left
		searchBox.TextYAlignment = Enum.TextYAlignment.Center
		searchBox.BackgroundTransparency = 1
		searchBox.ClipsDescendants = true
		searchBox.Position = UDim2.fromOffset(30, 0)
		searchBox.Size = UDim2.new(1, -40, 1, 0)
		searchBox.ZIndex = Z.Content + 2
		searchBox.Parent = searchPill
 
		searchBox.Focused:Connect(function()
			Tween(searchStroke, { Color = NullUI.Theme.Accent, Transparency = 0.3 }, 0.15)
		end)
		searchBox.FocusLost:Connect(function()
			Tween(searchStroke, { Color = Color3.new(1, 1, 1), Transparency = 0.88 }, 0.15)
		end)
	end
 
	local currentSort = opts.DefaultSort or sorts[1]
	local sortButtons = {}
	if #sorts > 1 then
		local tabsRow = Instance.new("Frame")
		tabsRow.BackgroundTransparency = 1
		tabsRow.Position = UDim2.fromOffset(0, showSearch and (TOP_H + 8) or 0)
		tabsRow.Size = UDim2.new(1, 0, 0, TABS_H)
		tabsRow.ZIndex = Z.Content + 1
		tabsRow.Parent = content
 
		local tabsLayout = Instance.new("UIListLayout")
		tabsLayout.FillDirection = Enum.FillDirection.Horizontal
		tabsLayout.Padding = UDim.new(0, 6)
		tabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
		tabsLayout.Parent = tabsRow
 
		for i, sortName in ipairs(sorts) do
			local btn = Instance.new("TextButton")
			btn.AutoButtonColor = false
			btn.Text = ""
			btn.BackgroundColor3 = Color3.new(1, 1, 1)
			btn.BackgroundTransparency = (sortName == currentSort) and 0.85 or 1
			btn.BorderSizePixel = 0
			btn.AutomaticSize = Enum.AutomaticSize.X
			btn.Size = UDim2.fromOffset(0, TABS_H)
			btn.LayoutOrder = i
			btn.ZIndex = Z.Content + 1
			btn.Parent = tabsRow
			Corner(btn, 7)
 
			local btnPad = Instance.new("UIPadding")
			btnPad.PaddingLeft = UDim.new(0, 10)
			btnPad.PaddingRight = UDim.new(0, 10)
			btnPad.Parent = btn
 
			local lbl = Instance.new("TextLabel")
			lbl.BackgroundTransparency = 1
			lbl.FontFace = NullUI.Theme.Font
			lbl.Text = string.upper(sortName)
			lbl.TextColor3 = (sortName == currentSort) and NullUI.Theme.Text or NullUI.Theme.TextDim
			lbl.TextSize = 11
			lbl.AutomaticSize = Enum.AutomaticSize.X
			lbl.Size = UDim2.fromOffset(0, TABS_H)
			lbl.ZIndex = Z.Content + 2
			lbl.Parent = btn
 
			sortButtons[sortName] = { Button = btn, Label = lbl }
		end
	end
 
	local gridScroll = Instance.new("ScrollingFrame")
	gridScroll.BackgroundTransparency = 1
	gridScroll.BorderSizePixel = 0
	gridScroll.Position = UDim2.fromOffset(0, headerH)
	gridScroll.Size = UDim2.new(1, 0, 1, -headerH)
	gridScroll.ScrollingDirection = Enum.ScrollingDirection.Y
	gridScroll.ScrollingEnabled = true
	gridScroll.Active = true
	gridScroll.ElasticBehavior = Enum.ElasticBehavior.Never
	gridScroll.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	gridScroll.ScrollBarThickness = showNativeScrollbar and (opts.ScrollBarThickness or 4) or 0
	gridScroll.ScrollBarImageColor3 = NullUI.Theme.TextDim
	gridScroll.ScrollBarImageTransparency = 0.35
	gridScroll.AutomaticCanvasSize = Enum.AutomaticSize.None
	gridScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	gridScroll.ZIndex = Z.Content + 1
	gridScroll.Parent = content
 
	-- Reserve room for the visible scrollbar so cards never sit underneath it.
	local GRID_RIGHT_PAD = gridScroll.ScrollBarThickness > 0 and (gridScroll.ScrollBarThickness + 6) or 16
	local GRID_TOP_PAD = 8
	local GRID_BOTTOM_PAD = 8
	local gridPad = Instance.new("UIPadding")
	gridPad.PaddingTop = UDim.new(0, GRID_TOP_PAD)
	gridPad.PaddingRight = UDim.new(0, GRID_RIGHT_PAD)
	gridPad.Parent = gridScroll
 
	local MIN_CELL_W = opts.CardMinWidth or opts.CardWidth or 190
	local FIXED_COLUMNS = opts.Columns
	local MAX_COLUMNS = opts.MaxColumns
	local CELL_H = opts.CardHeight or 88
	local CELL_GAP = 8
 
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellPadding = UDim2.fromOffset(CELL_GAP, CELL_GAP)
	gridLayout.CellSize = UDim2.fromOffset(MIN_CELL_W, CELL_H)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = gridScroll
 
	local function updateGridCanvas()
		gridScroll.CanvasSize = UDim2.new(
			0, 0, 0,
			math.max(0, (gridLayout.AbsoluteContentSize.Y / GetUIScale()) + GRID_TOP_PAD + GRID_BOTTOM_PAD)
		)
	end
	gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateGridCanvas)
	task.defer(updateGridCanvas)
 
	local SAFETY_MARGIN = 4
	local currentColumns = 1
	local function relayoutGridColumns()
		local availableW = (gridScroll.AbsoluteSize.X / GetUIScale()) - GRID_RIGHT_PAD - SAFETY_MARGIN
		if availableW <= 0 then return end
		local columns = FIXED_COLUMNS and math.max(1, FIXED_COLUMNS)
			or math.max(1, math.floor((availableW + CELL_GAP) / (MIN_CELL_W + CELL_GAP)))
		if not FIXED_COLUMNS and MAX_COLUMNS then columns = math.min(columns, math.max(1, MAX_COLUMNS)) end
		local cellW = math.floor((availableW - (columns - 1) * CELL_GAP) / columns)
		currentColumns = columns
		gridLayout.CellSize = UDim2.fromOffset(math.max(1, cellW), CELL_H)
	end
	gridScroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayoutGridColumns)
	task.defer(relayoutGridColumns)
 
	if not showNativeScrollbar then
		AddScrollbar(gridScroll)
		AddContentScrollThumb(gridScroll, gridLayout, outer, self._janitor)
	end
 
	local MAX_OUTER_H = opts.Height or 300
	local showingCards = false
 
	local function applyOuterHeight(target)
		Tween(outer, { Size = UDim2.new(1, 0, 0, target) }, 0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	end
 
	local EMPTY_STATE_H = 220
	local function resizeOuterEmpty()
		showingCards = false
		if opts.FixedHeight then
			applyOuterHeight(MAX_OUTER_H)
			return
		end
		applyOuterHeight(math.min(headerH + OUTER_V_PAD + EMPTY_STATE_H + OUTER_V_PAD, MAX_OUTER_H))
	end
 
	local function resizeOuterToGridContent()
		if not showingCards then return end
		if opts.FixedHeight then
			applyOuterHeight(MAX_OUTER_H)
			return
		end
		local contentH = gridLayout.AbsoluteContentSize.Y
		if contentH <= 0 then return end
		local target = math.min(headerH + OUTER_V_PAD + contentH + OUTER_V_PAD, MAX_OUTER_H)
		applyOuterHeight(target)
	end
	gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resizeOuterToGridContent)
 
	local statusHolder = Instance.new("Frame")
	statusHolder.BackgroundTransparency = 1
	statusHolder.Position = UDim2.fromOffset(0, headerH)
	statusHolder.Size = UDim2.new(1, 0, 1, -headerH)
	statusHolder.Visible = false
	statusHolder.ZIndex = Z.Content + 2
	statusHolder.Parent = content
 
	local statusLayout = Instance.new("UIListLayout")
	statusLayout.FillDirection = Enum.FillDirection.Vertical
	statusLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	statusLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	statusLayout.Padding = UDim.new(0, 6)
	statusLayout.Parent = statusHolder
 
	local statusIcon = Instance.new("ImageLabel")
	statusIcon.BackgroundTransparency = 1
	statusIcon.ImageColor3 = NullUI.Theme.TextDim
	statusIcon.Size = UDim2.fromOffset(24, 24)
	statusIcon.LayoutOrder = 1
	statusIcon.Visible = false
	statusIcon.ZIndex = Z.Content + 3
	statusIcon.Parent = statusHolder
 
	local statusLabel = Instance.new("TextLabel")
	statusLabel.BackgroundTransparency = 1
	statusLabel.FontFace = NullUI.Theme.FontRegular
	statusLabel.TextColor3 = NullUI.Theme.TextDim
	statusLabel.TextSize = 12
	statusLabel.TextWrapped = true
	statusLabel.TextXAlignment = Enum.TextXAlignment.Center
	statusLabel.AutomaticSize = Enum.AutomaticSize.Y
	statusLabel.Size = UDim2.new(1, -20, 0, 16)
	statusLabel.LayoutOrder = 2
	statusLabel.ZIndex = Z.Content + 3
	statusLabel.Parent = statusHolder
 
	local STATUS_ICONS = { loading = "loader-circle", empty = "frown", error = "triangle-alert" }
 
	local function openCardMenu(anchor, actions)
		if type(actions) ~= "table" or #actions == 0 then return end
 
		local popup, backdrop
		local function closeMenu()
			RegisterPopupClose(closeMenu)
			if backdrop then backdrop:Destroy(); backdrop = nil end
			if popup then popup:Destroy(); popup = nil end
		end
 
		RegisterPopupOpen(closeMenu)
		backdrop = MakePopupBackdrop(closeMenu)
 
		local rowH, gap, pad = 32, 2, 8
		local popupW = 190
		local popupH = pad * 2 + #actions * rowH + math.max(0, #actions - 1) * gap
		local scale = GetUIScale()
		local view = ViewportSize()
		local anchorPos, anchorSize = anchor.AbsolutePosition, anchor.AbsoluteSize
		local px = (anchorPos.X + anchorSize.X) / scale - popupW
		local py = (anchorPos.Y + anchorSize.Y) / scale + 5
		px = SafeClamp(px, 8, view.X / scale - popupW - 8)
		py = SafeClamp(py, 8, view.Y / scale - popupH - 8)
 
		popup = Instance.new("CanvasGroup")
		popup.Name = "CardActionsPopup"
		popup.Active = true
		popup.BackgroundColor3 = NullUI.Theme.Background
		popup.BackgroundTransparency = 0.04
		popup.BorderSizePixel = 0
		popup.Position = UDim2.fromOffset(math.round(px), math.round(py))
		popup.Size = UDim2.fromOffset(popupW, popupH)
		popup.ZIndex = Z.Popup
		popup.Parent = NullUI._Root
		Corner(popup, 10)
		Stroke(popup, Color3.new(1, 1, 1), 1, 0.9)
		GlassLayer(popup, 10, 0.985)
 
		local actionsHolder = Instance.new("Frame")
		actionsHolder.Name = "Actions"
		actionsHolder.BackgroundTransparency = 1
		actionsHolder.Size = UDim2.fromScale(1, 1)
		actionsHolder.ZIndex = Z.Popup + 1
		actionsHolder.Parent = popup
 
		local popupPad = Instance.new("UIPadding")
		popupPad.PaddingTop = UDim.new(0, pad)
		popupPad.PaddingBottom = UDim.new(0, pad)
		popupPad.PaddingLeft = UDim.new(0, pad)
		popupPad.PaddingRight = UDim.new(0, pad)
		popupPad.Parent = actionsHolder
 
		local popupLayout = Instance.new("UIListLayout")
		popupLayout.Padding = UDim.new(0, gap)
		popupLayout.SortOrder = Enum.SortOrder.LayoutOrder
		popupLayout.Parent = actionsHolder
 
		for i, action in ipairs(actions) do
			local button = Instance.new("TextButton")
			button.Name = "Action" .. i
			button.Text = ""
			button.AutoButtonColor = false
			button.BackgroundColor3 = Color3.new(1, 1, 1)
			button.BackgroundTransparency = 1
			button.BorderSizePixel = 0
			button.Size = UDim2.new(1, 0, 0, rowH)
			button.LayoutOrder = i
			button.ZIndex = Z.Popup + 1
			button.Parent = actionsHolder
			Corner(button, 7)
 
			local icon = Instance.new("ImageLabel")
			icon.BackgroundTransparency = 1
			icon.Image = ResolveIcon(action.Icon or "circle")
			icon.ImageColor3 = action.Danger and NullUI.Theme.Danger or NullUI.Theme.TextDim
			icon.Size = UDim2.fromOffset(14, 14)
			icon.AnchorPoint = Vector2.new(0, 0.5)
			icon.Position = UDim2.new(0, 9, 0.5, 0)
			icon.ZIndex = Z.Popup + 2
			icon.Parent = button
 
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.FontFace = NullUI.Theme.FontRegular
			label.Text = tostring(action.Text or "Action")
			label.TextColor3 = action.Danger and NullUI.Theme.Danger or NullUI.Theme.Text
			label.TextSize = 12
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Position = UDim2.fromOffset(31, 0)
			label.Size = UDim2.new(1, -39, 1, 0)
			label.ZIndex = Z.Popup + 2
			label.Parent = button
 
			button.MouseEnter:Connect(function()
				Tween(button, { BackgroundTransparency = 0.9 }, 0.1)
			end)
			button.MouseLeave:Connect(function()
				Tween(button, { BackgroundTransparency = 1 }, 0.1)
			end)
			button.MouseButton1Click:Connect(function()
				closeMenu()
				if action.Callback then task.spawn(action.Callback) end
			end)
		end
	end
 
	local function buildCard(item, animDelay)
		local cell = Instance.new("Frame")
		cell.Name = "GridCard"
		cell.BackgroundColor3 = Color3.new(1, 1, 1)
		cell.BackgroundTransparency = 1
		cell.BorderSizePixel = 0
		cell.ClipsDescendants = true
		cell.ZIndex = Z.Content + 2
		cell.Parent = gridScroll
		Corner(cell, NullUI.Theme.CornerRadiusSm)
		local cellStroke = Stroke(cell, Color3.new(1, 1, 1), 1, 1)
 
		local cellScale = Instance.new("UIScale")
		cellScale.Scale = 0.9
		cellScale.Parent = cell
 
		task.delay(animDelay or 0, function()
			if not cell.Parent then return end
			Tween(cell, { BackgroundTransparency = 0.94 }, 0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
			Tween(cellStroke, { Transparency = 0.9 }, 0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
			Tween(cellScale, { Scale = 1 }, 0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		end)
 
		local cellPad = Instance.new("UIPadding")
		cellPad.PaddingTop = UDim.new(0, cardPadding)
		cellPad.PaddingBottom = UDim.new(0, cardPadding)
		cellPad.PaddingLeft = UDim.new(0, cardPadding)
		cellPad.PaddingRight = UDim.new(0, cardPadding)
		cellPad.Parent = cell
 
		local textX = 0
		if item.Icon then
			local ICON_BOX = 24
			local iconHolder = Instance.new("Frame")
			iconHolder.BackgroundColor3 = Color3.new(1, 1, 1)
			iconHolder.BackgroundTransparency = 0.9
			iconHolder.BorderSizePixel = 0
			iconHolder.Size = UDim2.fromOffset(ICON_BOX, ICON_BOX)
			iconHolder.ZIndex = Z.Content + 3
			iconHolder.Parent = cell
			Corner(iconHolder, 7)
 
			local iconImg = Instance.new("ImageLabel")
			iconImg.BackgroundTransparency = 1
			iconImg.Image = ResolveIcon(item.Icon)
			iconImg.ImageColor3 = NullUI.Theme.Accent
			iconImg.Size = UDim2.fromOffset(13, 13)
			iconImg.AnchorPoint = Vector2.new(0.5, 0.5)
			iconImg.Position = UDim2.fromScale(0.5, 0.5)
			iconImg.ZIndex = Z.Content + 4
			iconImg.Parent = iconHolder
 
			textX = ICON_BOX + 8
		end
 
		local hasPrimaryAction = item.Callback ~= nil
		local hasSecondaryAction = item.SecondaryCallback ~= nil
		local hasMenuAction = item.Menu and #item.Menu > 0
		local trailingReserve = (hasPrimaryAction and 26 or 0)
			+ (hasSecondaryAction and 30 or 0)
			+ (hasMenuAction and 30 or 0)
		if hasPrimaryAction then
 
			local actionBadge = Instance.new("Frame")
			actionBadge.Name = "LoadBadge"
			actionBadge.BackgroundColor3 = NullUI.Theme.Accent
			actionBadge.BackgroundTransparency = 0.8
			actionBadge.BorderSizePixel = 0
			actionBadge.AnchorPoint = Vector2.new(1, 0)
			actionBadge.Position = UDim2.new(1, 0, 0, 0)
			actionBadge.Size = UDim2.fromOffset(22, 22)
			actionBadge.ZIndex = Z.Content + 6
			actionBadge.Parent = cell
			Corner(actionBadge, 7)
 
			local actionIcon = Instance.new("ImageLabel")
			actionIcon.BackgroundTransparency = 1
			actionIcon.Image = ResolveIcon(item.ActionIcon or "download")
			actionIcon.ImageColor3 = NullUI.Theme.Accent
			actionIcon.Size = UDim2.fromOffset(12, 12)
			actionIcon.AnchorPoint = Vector2.new(0.5, 0.5)
			actionIcon.Position = UDim2.fromScale(0.5, 0.5)
			actionIcon.ZIndex = Z.Content + 7
			actionIcon.Parent = actionBadge
 
			local actionClick = Instance.new("TextButton")
			actionClick.Text = ""
			actionClick.AutoButtonColor = false
			actionClick.BackgroundTransparency = 1
			actionClick.Size = UDim2.fromScale(1, 1)
			actionClick.ZIndex = Z.Content + 8
			actionClick.Parent = actionBadge
			actionClick.MouseButton1Click:Connect(function()
				item.Callback()
			end)
		end
 
		if hasSecondaryAction then
			local secondaryBadge = Instance.new("Frame")
			secondaryBadge.Name = "SecondaryActionBadge"
			secondaryBadge.BackgroundColor3 = item.SecondaryDanger
				and Color3.fromRGB(225, 76, 88)
				or NullUI.Theme.Accent
			secondaryBadge.BackgroundTransparency = item.SecondaryDanger and 0.82 or 0.8
			secondaryBadge.BorderSizePixel = 0
			secondaryBadge.AnchorPoint = Vector2.new(1, 0)
			secondaryBadge.Position = UDim2.new(1, hasPrimaryAction and -30 or 0, 0, 0)
			secondaryBadge.Size = UDim2.fromOffset(22, 22)
			secondaryBadge.ZIndex = Z.Content + 6
			secondaryBadge.Parent = cell
			Corner(secondaryBadge, 7)
 
			local secondaryIcon = Instance.new("ImageLabel")
			secondaryIcon.BackgroundTransparency = 1
			secondaryIcon.Image = ResolveIcon(item.SecondaryIcon or "trash-2")
			secondaryIcon.ImageColor3 = item.SecondaryDanger
				and Color3.fromRGB(255, 125, 135)
				or NullUI.Theme.Accent
			secondaryIcon.Size = UDim2.fromOffset(12, 12)
			secondaryIcon.AnchorPoint = Vector2.new(0.5, 0.5)
			secondaryIcon.Position = UDim2.fromScale(0.5, 0.5)
			secondaryIcon.ZIndex = Z.Content + 7
			secondaryIcon.Parent = secondaryBadge
 
			local secondaryClick = Instance.new("TextButton")
			secondaryClick.Text = ""
			secondaryClick.AutoButtonColor = false
			secondaryClick.BackgroundTransparency = 1
			secondaryClick.Size = UDim2.fromScale(1, 1)
			secondaryClick.ZIndex = Z.Content + 8
			secondaryClick.Parent = secondaryBadge
			secondaryClick.MouseButton1Click:Connect(function()
				item.SecondaryCallback()
			end)
		end
 
		if hasMenuAction then
			local menuBadge = Instance.new("Frame")
			menuBadge.Name = "MenuBadge"
			menuBadge.BackgroundColor3 = NullUI.Theme.Accent
			menuBadge.BackgroundTransparency = 0.8
			menuBadge.BorderSizePixel = 0
			menuBadge.AnchorPoint = Vector2.new(1, 0)
			menuBadge.Position = UDim2.new(
				1,
				-((hasPrimaryAction and 30 or 0) + (hasSecondaryAction and 30 or 0)),
				0,
				0
			)
			menuBadge.Size = UDim2.fromOffset(22, 22)
			menuBadge.ZIndex = Z.Content + 6
			menuBadge.Parent = cell
			Corner(menuBadge, 7)
 
			local menuIcon = Instance.new("ImageLabel")
			menuIcon.BackgroundTransparency = 1
			menuIcon.Image = ResolveIcon("Lucide:settings")
			menuIcon.ImageColor3 = NullUI.Theme.Accent
			menuIcon.Size = UDim2.fromOffset(12, 12)
			menuIcon.AnchorPoint = Vector2.new(0.5, 0.5)
			menuIcon.Position = UDim2.fromScale(0.5, 0.5)
			menuIcon.ZIndex = Z.Content + 7
			menuIcon.Parent = menuBadge
 
			local menuClick = Instance.new("TextButton")
			menuClick.Text = ""
			menuClick.AutoButtonColor = false
			menuClick.BackgroundTransparency = 1
			menuClick.Size = UDim2.fromScale(1, 1)
			menuClick.ZIndex = Z.Content + 8
			menuClick.Parent = menuBadge
			menuClick.MouseButton1Click:Connect(function()
				openCardMenu(menuBadge, item.Menu)
			end)
		end
 
		local cursorY = 0
 
		local titleLbl = Instance.new("TextLabel")
		titleLbl.BackgroundTransparency = 1
		titleLbl.FontFace = NullUI.Theme.Font
		titleLbl.Text = item.Title or "Untitled"
		titleLbl.TextColor3 = NullUI.Theme.Text
		titleLbl.TextSize = 13
		titleLbl.TextXAlignment = Enum.TextXAlignment.Left
		titleLbl.TextYAlignment = Enum.TextYAlignment.Center
		titleLbl.TextTruncate = Enum.TextTruncate.AtEnd
		titleLbl.Position = UDim2.fromOffset(textX, item.Icon and 4 or cursorY)
		titleLbl.Size = UDim2.new(1, -(textX + trailingReserve), 0, item.Icon and 24 or 16)
		titleLbl.ZIndex = Z.Content + 3
		titleLbl.Parent = cell
		cursorY = math.max(item.Icon and (24 + 6) or 0, cursorY + 16 + 3)
 
		if item.Description and item.Description ~= "" then
 
			local descLbl = Instance.new("TextLabel")
			descLbl.BackgroundTransparency = 1
			descLbl.FontFace = NullUI.Theme.FontRegular
			descLbl.Text = item.Description
			descLbl.TextColor3 = NullUI.Theme.TextDim
			descLbl.TextSize = 11
			descLbl.TextWrapped = true
			descLbl.TextTruncate = Enum.TextTruncate.None
			descLbl.TextXAlignment = Enum.TextXAlignment.Left
			descLbl.TextYAlignment = Enum.TextYAlignment.Top
			descLbl.Position = UDim2.fromOffset(0, cursorY)
			descLbl.Size = UDim2.new(1, -trailingReserve, 0, descriptionHeight)
			descLbl.ZIndex = Z.Content + 3
			descLbl.Parent = cell
			cursorY = cursorY + descriptionHeight + 3
		end
 
		if item.Byline and item.Byline ~= "" then
			local bylineLbl = Instance.new("TextLabel")
			bylineLbl.BackgroundTransparency = 1
			bylineLbl.FontFace = NullUI.Theme.FontRegular
			bylineLbl.Text = item.Byline
			bylineLbl.TextColor3 = NullUI.Theme.TextDim
			bylineLbl.TextTransparency = 0.25
			bylineLbl.TextSize = 10
			bylineLbl.TextXAlignment = Enum.TextXAlignment.Left
			bylineLbl.TextTruncate = Enum.TextTruncate.AtEnd
			bylineLbl.Position = UDim2.fromOffset(0, cursorY)
			bylineLbl.Size = UDim2.new(1, -trailingReserve, 0, 12)
			bylineLbl.ZIndex = Z.Content + 3
			bylineLbl.Parent = cell
		end
 
		if item.Stats and #item.Stats > 0 then
			local statsRow = Instance.new("Frame")
			statsRow.BackgroundTransparency = 1
			statsRow.AnchorPoint = Vector2.new(0, 1)
			statsRow.Position = UDim2.new(0, 0, 1, 0)
			statsRow.Size = UDim2.new(1, 0, 0, 16)
			statsRow.ZIndex = Z.Content + 3
			statsRow.Parent = cell
 
			local statsLayout = Instance.new("UIListLayout")
			statsLayout.FillDirection = Enum.FillDirection.Horizontal
			statsLayout.Padding = UDim.new(0, 10)
			statsLayout.SortOrder = Enum.SortOrder.LayoutOrder
			statsLayout.Parent = statsRow
 
			for i, stat in ipairs(item.Stats) do
 
				local statFrame = Instance.new(stat.Callback and "TextButton" or "Frame")
				statFrame.BackgroundTransparency = 1
				statFrame.AutomaticSize = Enum.AutomaticSize.X
				statFrame.Size = UDim2.fromOffset(0, 14)
				statFrame.LayoutOrder = i
				statFrame.ZIndex = Z.Content + 3
				statFrame.Parent = statsRow
				if stat.Callback then
					statFrame.Text = ""
					statFrame.AutoButtonColor = false
				end
 
				local statLayout = Instance.new("UIListLayout")
				statLayout.FillDirection = Enum.FillDirection.Horizontal
				statLayout.VerticalAlignment = Enum.VerticalAlignment.Center
				statLayout.Padding = UDim.new(0, 3)
				statLayout.Parent = statFrame
 
				local statIcon = Instance.new("ImageLabel")
				statIcon.BackgroundTransparency = 1
				statIcon.Image = ResolveIcon(stat.Icon or "circle")
				statIcon.ImageColor3 = NullUI.Theme.TextDim
				statIcon.Size = UDim2.fromOffset(11, 11)
				statIcon.LayoutOrder = 1
				statIcon.ZIndex = Z.Content + 4
				statIcon.Parent = statFrame
 
				local statLbl = Instance.new("TextLabel")
				statLbl.BackgroundTransparency = 1
				statLbl.FontFace = NullUI.Theme.FontRegular
				statLbl.Text = tostring(stat.Text or "")
				statLbl.TextColor3 = NullUI.Theme.TextDim
				statLbl.TextSize = 10
				statLbl.AutomaticSize = Enum.AutomaticSize.X
				statLbl.Size = UDim2.fromOffset(0, 12)
				statLbl.LayoutOrder = 2
				statLbl.ZIndex = Z.Content + 4
				statLbl.Parent = statFrame
 
				if stat.Callback then
					statFrame.MouseEnter:Connect(function()
						Tween(statIcon, { ImageColor3 = NullUI.Theme.Accent }, 0.1)
						Tween(statLbl, { TextColor3 = NullUI.Theme.Accent }, 0.1)
					end)
					statFrame.MouseLeave:Connect(function()
						Tween(statIcon, { ImageColor3 = NullUI.Theme.TextDim }, 0.1)
						Tween(statLbl, { TextColor3 = NullUI.Theme.TextDim }, 0.1)
					end)
					statFrame.MouseButton1Click:Connect(function()
						task.spawn(stat.Callback)
					end)
				end
			end
		end
 
		if item.Callback then
 
			local hasInteractiveStat = false
			if item.Stats then
				for _, stat in ipairs(item.Stats) do
					if stat.Callback then hasInteractiveStat = true end
				end
			end
 
			local click = Instance.new("TextButton")
			click.Text = ""
			click.AutoButtonColor = false
			click.BackgroundTransparency = 1
			click.Size = hasInteractiveStat and UDim2.new(1, 0, 1, -20) or UDim2.fromScale(1, 1)
			click.ZIndex = Z.Content + 5
			click.Parent = cell
 
			click.MouseEnter:Connect(function()
				Tween(cell, { BackgroundTransparency = 0.88 }, 0.12)
				Tween(cellStroke, { Transparency = 0.8 }, 0.12)
			end)
			click.MouseLeave:Connect(function()
				Tween(cell, { BackgroundTransparency = 0.94 }, 0.12)
				Tween(cellStroke, { Transparency = 0.9 }, 0.12)
			end)
			click.MouseButton1Click:Connect(function()
				task.spawn(item.Callback)
			end)
		end
 
		return cell
	end
 
	local currentQuery = ""
	local loadToken = 0
 
	local function clearGrid()
		for _, child in ipairs(gridScroll:GetChildren()) do
			if child.Name == "GridCard" then child:Destroy() end
		end
	end
 
	local function setStatus(msg, kind)
		local visible = msg ~= nil and msg ~= ""
		statusLabel.Text = msg or ""
		statusHolder.Visible = visible
		local iconName = visible and STATUS_ICONS[kind]
		statusIcon.Visible = iconName ~= nil
		if iconName then
			statusIcon.Image = ResolveIcon(iconName)
		end
	end
 
	local function computeCellHeight(items)
		local hasIcon, hasDesc, hasByline, hasStats = false, false, false, false
		for _, item in ipairs(items) do
			if item.Icon then hasIcon = true end
			if item.Description and item.Description ~= "" then hasDesc = true end
			if item.Byline and item.Byline ~= "" then hasByline = true end
			if item.Stats and #item.Stats > 0 then hasStats = true end
		end
		local h = 20
		h = h + (hasIcon and 24 or 16) + 3
		if hasDesc then h = h + descriptionHeight + 3 end
		if hasByline then h = h + 12 end
		if hasStats then h = h + 16 + 4 end
		return h
	end
 
	local function refresh()
		if not opts.Fetch then return end
		loadToken = loadToken + 1
		local myToken = loadToken
		clearGrid()
		setStatus(opts.LoadingText or "Loading...", "loading")
		resizeOuterEmpty()
		task.spawn(function()
			local ok, items, fetchErr = pcall(opts.Fetch, {
				Query = currentQuery,
				Sort = currentSort,
				PageSize = pageSize,
			})
			if myToken ~= loadToken then return end
			if not ok then
				setStatus(opts.ErrorText or tostring(items), "error")
				resizeOuterEmpty()
				return
			end
			if fetchErr then
				setStatus(opts.ErrorText or tostring(fetchErr), "error")
				resizeOuterEmpty()
				return
			end
			items = items or {}
			if #items == 0 then
				setStatus(opts.EmptyText or "Nothing here yet.", "empty")
				resizeOuterEmpty()
				return
			end
			setStatus(nil)
			if opts.AutoCardHeight ~= false then
				CELL_H = math.max(computeCellHeight(items), opts.MinCardHeight or 0)
				gridLayout.CellSize = UDim2.new(
					gridLayout.CellSize.X.Scale, gridLayout.CellSize.X.Offset,
					0, CELL_H
				)
			end
			showingCards = true
			for i, item in ipairs(items) do
 
				buildCard(item, math.min(i - 1, 8) * 0.035)
			end
 
			task.spawn(function()
				RunService.Heartbeat:Wait()
				RunService.Heartbeat:Wait()
				if myToken == loadToken then resizeOuterToGridContent() end
			end)
		end)
	end
 
	if searchBox then
		local debounceToken = 0
		searchBox:GetPropertyChangedSignal("Text"):Connect(function()
			currentQuery = searchBox.Text
			debounceToken = debounceToken + 1
			local myDebounce = debounceToken
			task.delay(0.35, function()
				if myDebounce == debounceToken then refresh() end
			end)
		end)
	end
 
	for sortName, entry in pairs(sortButtons) do
		entry.Button.MouseButton1Click:Connect(function()
			if currentSort == sortName then return end
			currentSort = sortName
			for otherName, otherEntry in pairs(sortButtons) do
				local active = otherName == currentSort
				Tween(otherEntry.Button, { BackgroundTransparency = active and 0.85 or 1 }, 0.12)
				Tween(otherEntry.Label, { TextColor3 = active and NullUI.Theme.Text or NullUI.Theme.TextDim }, 0.12)
			end
			refresh()
		end)
	end
 
	if opts.AutoLoad ~= false and opts.Fetch then
		task.defer(refresh)
	end
 
	return {
		Instance = outer,
		Refresh = refresh,
		SetQuery = function(_, q)
			currentQuery = q or ""
			if searchBox then searchBox.Text = currentQuery end
			refresh()
		end,
		SetSort = function(_, s)
			currentSort = s
			refresh()
		end,
		Destroy = function() outer:Destroy() end,
	}
end
 
function NullUI:GetConfig()
	local data = {}
	for flag, api in pairs(NullUI.Flags) do
		if api.Get then
			local ok, value = pcall(api.Get)
			if ok then data[flag] = Serialize(value) end
		end
	end
	return data
end
 
function NullUI:SetConfig(data, silent)
	if type(data) ~= "table" then return false end
	for flag, raw in pairs(data) do
		local api = NullUI.Flags[flag]
		if api and api.Set then
			pcall(api.Set, api, Deserialize(raw), silent ~= false)
		end
	end
	return true
end
 
function NullUI:ListUIElements()
	local out = {}
	for flag, api in pairs(NullUI.Flags) do
		local ok, value = pcall(api.Get)
		table.insert(out, {
			Flag  = flag,
			Kind  = api.Kind,
			Label = api.Label,
			Value = ok and value or nil,
		})
	end
	table.sort(out, function(a, b) return a.Flag < b.Flag end)
	return out
end
 
function NullUI:SetUIElementValue(flag, value, silent)
	local api = NullUI.Flags[flag]
	if not api or not api.Set then
		return false, "Unknown UI element: " .. tostring(flag)
	end
	local ok, err = pcall(api.Set, api, value, silent ~= false)
	if not ok then return false, tostring(err) end
	return true
end
 
local CONFIGS_FOLDER = "NullUI/Configs"
 
local function EnsureConfigsFolder()
	if not (fn_isfolder and fn_makefolder) then return false end
	local ok = pcall(function()
		if not fn_isfolder("NullUI") then fn_makefolder("NullUI") end
		if not fn_isfolder(CONFIGS_FOLDER) then fn_makefolder(CONFIGS_FOLDER) end
	end)
	return ok
end
 
local function SafeConfigName(name)
	name = tostring(name or "config"):gsub("[^%w_%- ]", "_"):gsub("^%s+", ""):gsub("%s+$", "")
	if name == "" then name = "config" end
	return name
end
 
local function ConfigPath(name)
	return CONFIGS_FOLDER .. "/" .. SafeConfigName(name) .. ".json"
end
 
local function LegacyConfigPath(name)
	return "NullUI/" .. SafeConfigName(name) .. ".json"
end
 
local function BuildConfigEnvelope(name, data, meta)
	meta = meta or {}
	return {
		Schema      = 1,
		Name        = name,
		Description = meta.Description or "",
		Tags        = meta.Tags or {},
		CreatedAt   = meta.CreatedAt or os.time(),
		Data        = data,
	}
end
 
local function ReadConfigFile(path)
	if not (fn_isfile and fn_readfile) then return nil, "readfile unavailable" end
	local existsOk, exists = pcall(fn_isfile, path)
	if not existsOk or not exists then return nil, "config does not exist" end
	local ok, raw = pcall(fn_readfile, path)
	if not ok then return nil, raw end
	local decodeOk, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
	if not decodeOk then return nil, "failed to decode config" end
	if type(decoded) ~= "table" then return nil, "malformed config" end
 
	if decoded.Data == nil then
		return BuildConfigEnvelope(nil, decoded, {}), nil
	end
	return decoded, nil
end
 
function NullUI:SaveConfig(name, opts)
	if not fn_writefile then return false, "writefile unavailable" end
	opts = opts or {}
	EnsureConfigsFolder()
	name = name or "config"
	local envelope = BuildConfigEnvelope(name, NullUI:GetConfig(), opts)
	local ok, err = pcall(function()
		fn_writefile(ConfigPath(name), HttpService:JSONEncode(envelope))
	end)
	return ok, err
end
 
function NullUI:LoadConfig(name, silent)
	name = name or "config"
	local envelope, err = ReadConfigFile(ConfigPath(name))
	if not envelope then
		envelope, err = ReadConfigFile(LegacyConfigPath(name))
	end
	if not envelope then return false, err end
	return NullUI:SetConfig(envelope.Data, silent)
end
 
function NullUI:GetConfigMeta(name)
	local envelope, err = ReadConfigFile(ConfigPath(name))
	if not envelope then return nil, err end
	return {
		Name        = envelope.Name or name,
		Description = envelope.Description or "",
		Tags        = envelope.Tags or {},
		CreatedAt   = envelope.CreatedAt,
	}
end
 
function NullUI:GetSavedConfig(name)
	local envelope, err = ReadConfigFile(ConfigPath(name))
	if not envelope then return nil, err end
	return envelope, nil
end
 
function NullUI:ListConfigs()
	if not fn_listfiles then return {}, "listfiles unavailable" end
	EnsureConfigsFolder()
	local ok, files = pcall(fn_listfiles, CONFIGS_FOLDER)
	if not ok or type(files) ~= "table" then return {}, "failed to list configs" end
 
	local out = {}
	for _, path in ipairs(files) do
		if tostring(path):match("%.json$") then
			local envelope = ReadConfigFile(path)
			if envelope then
				local fileName = tostring(path):match("([^/\\]+)%.json$") or envelope.Name
				table.insert(out, {
					Name        = envelope.Name or fileName,
					FileName    = fileName,
					Description = envelope.Description or "",
					Tags        = envelope.Tags or {},
					CreatedAt   = envelope.CreatedAt or 0,
				})
			end
		end
	end
 
	table.sort(out, function(a, b) return (a.CreatedAt or 0) > (b.CreatedAt or 0) end)
	return out, nil
end
 
function NullUI:DeleteConfig(name)
	if not (fn_isfile and fn_delfile) then return false, "delfile unavailable" end
	local path = ConfigPath(name)
	local ok, exists = pcall(fn_isfile, path)
	if not ok or not exists then return false, "config does not exist" end
	local delOk, err = pcall(fn_delfile, path)
	return delOk, err
end
 
function NullUI:RenameConfig(oldName, newName)
	local envelope, err = ReadConfigFile(ConfigPath(oldName))
	if not envelope then return false, err end
	envelope.Name = newName
	local ok, writeErr = pcall(function()
		EnsureConfigsFolder()
		fn_writefile(ConfigPath(newName), HttpService:JSONEncode(envelope))
	end)
	if not ok then return false, writeErr end
	if ConfigPath(oldName) ~= ConfigPath(newName) then
		pcall(fn_delfile, ConfigPath(oldName))
	end
	return true
end
 
function NullUI:CreateSnapshot()
	return { Data = NullUI:GetConfig(), CreatedAt = os.time() }
end
 
function NullUI:RestoreSnapshot(snapshot, silent)
	if type(snapshot) ~= "table" or type(snapshot.Data) ~= "table" then
		return false, "invalid snapshot"
	end
	return NullUI:SetConfig(snapshot.Data, silent)
end
 
local CLOUD_IDENTITY_PATH = "NullUI/cloud_identity.json"
 
local function LoadCloudIdentity()
	if fn_isfile and fn_readfile then
		local existsOk, exists = pcall(fn_isfile, CLOUD_IDENTITY_PATH)
		if existsOk and exists then
			local ok, raw = pcall(fn_readfile, CLOUD_IDENTITY_PATH)
			if ok then
				local decodeOk, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
				if decodeOk and type(decoded) == "table" and decoded.Id then
					decoded.Tokens = decoded.Tokens or {}
					return decoded
				end
			end
		end
	end
	return nil
end
 
local function SaveCloudIdentity(identity)
	if not fn_writefile then return end
	EnsureAssetsFolder()
	pcall(fn_writefile, CLOUD_IDENTITY_PATH, HttpService:JSONEncode(identity))
end
 
local function GetOrCreateCloudIdentity()
	local identity = LoadCloudIdentity()
	if identity then return identity end
	identity = { Id = HttpService:GenerateGUID(false), Tokens = {} }
	SaveCloudIdentity(identity)
	return identity
end
 
local CLOUD_PUBLISH_COOLDOWN = 15
local LastCloudPublishAt = 0
 
function NullUI:CloudService(opts)
	opts = opts or {}
	local baseUrl = opts.BaseUrl
	local scriptId = opts.Script or "default"
	local identity = GetOrCreateCloudIdentity()
	local httpRequest = (syn and syn.request) or http_request or request
 
	local function apiRequest(method, path, body, extraHeaders)
		if not httpRequest then
			return nil, "Your executor doesn't support HTTP requests."
		end
		if not baseUrl or baseUrl == "" then
			return nil, "No cloud BaseUrl configured -- point CloudService's BaseUrl at your own backend."
		end
 
		local headers = {
			["Content-Type"] = "application/json",
			["X-NullUI-Identity"] = identity.Id,
			["X-NullUI-Script"] = scriptId,
		}
		if extraHeaders then
			for k, v in pairs(extraHeaders) do headers[k] = v end
		end
 
		local ok, res = pcall(httpRequest, {
			Url = baseUrl .. path,
			Method = method,
			Headers = headers,
			Body = body and HttpService:JSONEncode(body) or nil,
		})
		if not ok then return nil, tostring(res) end
 
		if res.StatusCode and (res.StatusCode < 200 or res.StatusCode >= 300) then
			local message = res.Body
			local decodeOk, decoded = pcall(function() return HttpService:JSONDecode(res.Body) end)
			if decodeOk and type(decoded) == "table" and decoded.error then
				message = tostring(decoded.error)
			end
			return nil, "HTTP " .. tostring(res.StatusCode) .. ": " .. tostring(message)
		end
 
		if res.Body == nil or res.Body == "" then return {}, nil end
		local decodeOk, decoded = pcall(function() return HttpService:JSONDecode(res.Body) end)
		if not decodeOk then return nil, "Failed to decode response." end
		return decoded, nil
	end
 
	local api = { Identity = identity.Id }
 
	function api:List(state)
		state = state or {}
		local query = "?sort=" .. HttpService:UrlEncode(state.Sort or "top")
		if state.Query and state.Query ~= "" then
			query = query .. "&q=" .. HttpService:UrlEncode(state.Query)
		end
		if state.Cursor then
			query = query .. "&cursor=" .. HttpService:UrlEncode(tostring(state.Cursor))
		end
		query = query .. "&limit=" .. tostring(state.PageSize or 20)
 
		local decoded, err = apiRequest("GET", "/configs" .. query)
		if not decoded then return nil, err end
		return decoded.Items or {}, decoded.NextCursor
	end
 
	function api:ListMine()
		local decoded, err = apiRequest("GET", "/configs/mine")
		if not decoded then return nil, err end
		return decoded.Items or {}
	end
 
	function api:GetByShareCode(shareCode)
		return apiRequest("GET", "/configs/code/" .. HttpService:UrlEncode(tostring(shareCode)))
	end
 
	function api:Publish(meta, data)
		meta = meta or {}
		local now = os.clock()
		if now - LastCloudPublishAt < CLOUD_PUBLISH_COOLDOWN then
			return nil, string.format(
				"Please wait %ds before publishing again.",
				math.ceil(CLOUD_PUBLISH_COOLDOWN - (now - LastCloudPublishAt))
			)
		end
 
		local cleanName, nameBlocked = NullUI:SanitizeText(meta.Name, { MaxLength = 60 })
		if nameBlocked or cleanName == "" then
			return nil, "Name was empty or blocked by the content filter."
		end
		local cleanDesc, descBlocked = NullUI:SanitizeText(meta.Description or "", { MaxLength = 280 })
		if descBlocked then
			return nil, "Description was blocked by the content filter."
		end
 
		local cleanTags = {}
		for _, tag in ipairs(meta.Tags or {}) do
			local cleanTag = NullUI:SanitizeText(tag, { MaxLength = 24 })
			if cleanTag ~= "" then table.insert(cleanTags, cleanTag) end
			if #cleanTags >= 8 then break end
		end
 
		LastCloudPublishAt = now
 
		local decoded, err = apiRequest("POST", "/configs", {
			Name = cleanName,
			Description = cleanDesc,
			Tags = cleanTags,
			Data = data or NullUI:GetConfig(),
		})
		if not decoded then return nil, err end
 
		if decoded.Id and decoded.OwnerToken then
			identity.Tokens[decoded.Id] = decoded.OwnerToken
			SaveCloudIdentity(identity)
		end
		return decoded
	end
 
	function api:Delete(id)
		local token = identity.Tokens[id]
		if not token then
			return false, "You don't have publish rights for this config on this device."
		end
		local decoded, err = apiRequest("DELETE", "/configs/" .. id, nil, {
			["X-NullUI-Owner-Token"] = token,
		})
		if not decoded then return false, err end
		identity.Tokens[id] = nil
		SaveCloudIdentity(identity)
		return true
	end
 
	function api:Like(id)
		local decoded, err = apiRequest("POST", "/configs/" .. id .. "/like")
		if not decoded then return false, err end
		return true
	end
 
	function api:Download(id)
		return apiRequest("POST", "/configs/" .. id .. "/download")
	end
 
	function api:SendChatMessage(userId, text)
		return apiRequest("POST", "/chat/send", { UserId = userId, Text = text })
	end
 
	function api:PollChatMessages(sinceId)
		local decoded, err = apiRequest("GET", "/chat?since=" .. tostring(sinceId or 0))
		if not decoded then return nil, err end
		return decoded.Messages or {}
	end
 
	function api:ReportChatMessage(messageId)
		local decoded, err = apiRequest("POST", "/chat/" .. tostring(messageId) .. "/report")
		if not decoded then return false, err end
		return true
	end
 
	function api:Heartbeat(payload)
		local decoded, err = apiRequest("POST", "/presence/heartbeat", payload)
		if not decoded then return false, err end
		return true
	end
 
	function api:GetActiveCount()
		local decoded, err = apiRequest("GET", "/presence/count")
		if not decoded then return nil, err end
		return decoded.Count or 0
	end
 
	function api:GetLeaderboard(limit)
		local decoded, err = apiRequest("GET", "/presence/leaderboard?limit=" .. tostring(limit or 10))
		if not decoded then return nil, err end
		return decoded.Items or {}
	end
 
	return api
end
 
function NullUI:CreateAIAssistant(opts)
	opts = opts or {}
	local providers = opts.Providers or {}
	local tools = opts.Tools or (opts.Window and opts.Window:_BuildDefaultChatTools()) or {}
	local systemPrompt = opts.SystemPrompt
		or (opts.Window and opts.Window:_BuildDefaultSystemPrompt())
		or "You are a helpful assistant."
	local maxRounds = opts.MaxRounds or 6
	local maxTokens = opts.MaxTokens or 2048
	local httpRequest = (syn and syn.request) or http_request or request
 
	local function toOpenAITools()
		local out = {}
		for _, tool in ipairs(tools) do
			table.insert(out, {
				type = "function",
				["function"] = {
					name        = tool.Name,
					description = tool.Description,
					parameters  = tool.Parameters,
				},
			})
		end
		return out
	end
 
	local persistPath = nil
	if opts.Persist then
		persistPath = ASSETS_FOLDER .. "/" .. SafeConfigName(tostring(opts.Persist)) .. ".chat.json"
	end
 
	local function loadHistory()
		if not (persistPath and fn_isfile and fn_readfile) then return nil end
		local existsOk, exists = pcall(fn_isfile, persistPath)
		if not existsOk or not exists then return nil end
		local ok, raw = pcall(fn_readfile, persistPath)
		if not ok then return nil end
		local decodeOk, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
		if decodeOk and type(decoded) == "table" then return decoded end
		return nil
	end
 
	local conversation = loadHistory() or { { role = "system", content = systemPrompt } }
 
	local function saveHistory()
		if not (persistPath and fn_writefile) then return end
		EnsureAssetsFolder()
		pcall(fn_writefile, persistPath, HttpService:JSONEncode(conversation))
	end
 
	local function callProvider(provider, messages)
		local body = HttpService:JSONEncode({
			model      = provider.Model,
			messages   = messages,
			tools      = toOpenAITools(),
			max_tokens = maxTokens,
		})
 
		local ok, res = pcall(httpRequest, {
			Url = provider.Endpoint,
			Method = "POST",
			Headers = {
				["Authorization"] = "Bearer " .. tostring(provider.ApiKey),
				["Content-Type"]  = "application/json",
			},
			Body = body,
		})
		if not ok then return nil, tostring(res), false end
 
		if res.StatusCode and res.StatusCode ~= 200 then
			local message = res.Body
			local parseOk, parsed = pcall(function() return HttpService:JSONDecode(res.Body) end)
			if parseOk and type(parsed) == "table" then
				local errField = parsed.error
				if type(errField) == "table" and errField.message then
					message = tostring(errField.message)
				elseif type(errField) == "string" then
					message = errField
				end
			end
			local rateLimited = res.StatusCode == 429
			if rateLimited then message = message .. " (daily free-tier limit)" end
			return nil, provider.Name .. " API error " .. tostring(res.StatusCode) .. ": " .. message, rateLimited
		end
 
		local decodeOk, decoded = pcall(function() return HttpService:JSONDecode(res.Body) end)
		if not decodeOk then return nil, provider.Name .. ": failed to decode API response.", false end
		return decoded, nil, false
	end
 
	local function callAI(messages)
		if not httpRequest then
			return nil, "Your executor doesn't support HTTP requests."
		end
		local lastErr = "No AI provider configured -- add at least one entry with an ApiKey to Providers."
		for _, provider in ipairs(providers) do
			if provider.ApiKey and provider.ApiKey ~= "" then
				local decoded, err, rateLimited = callProvider(provider, messages)
				if decoded then return decoded end
				lastErr = err
				if not rateLimited then return nil, lastErr end
			end
		end
		return nil, lastErr
	end
 
	local assistant = {}
	local stopRequested = false
	local busy = false
 
	function assistant:Stop()
		stopRequested = true
	end
 
	function assistant:IsBusy()
		return busy
	end
 
	function assistant:GetHistory()
		return conversation
	end
 
	function assistant:Reset()
		table.clear(conversation)
		table.insert(conversation, { role = "system", content = systemPrompt })
		saveHistory()
	end
 
	function assistant:Ask(panel, userText)
		table.insert(conversation, { role = "user", content = userText })
		panel:ShowTyping()
		stopRequested = false
		busy = true
 
		for _ = 1, maxRounds do
			if stopRequested then
				busy = false
				panel:HideTyping()
				panel:AddMessage("assistant", "(stopped)")
				saveHistory()
				return
			end
 
			local response, err = callAI(conversation)
			if not response then
				busy = false
				panel:HideTyping()
				panel:AddMessage("assistant", "Error: " .. tostring(err))
				saveHistory()
				return
			end
 
			local choice  = response.choices and response.choices[1]
			local message = choice and choice.message
			if not message then
				busy = false
				panel:HideTyping()
				panel:AddMessage("assistant", "Error: empty response from API.")
				saveHistory()
				return
			end
 
			table.insert(conversation, message)
 
			local calls = message.tool_calls
			local hasCalls = calls and #calls > 0
			local content = message.content or ""
 
			local _, fenceCount = content:gsub("```", "")
			local truncated = choice.finish_reason == "length" or fenceCount % 2 == 1
 
			if message.content and message.content ~= "" then
				if not hasCalls and not truncated then panel:HideTyping() end
				panel:AddMessage("assistant", message.content)
			end
 
			if hasCalls then
				for _, call in ipairs(calls) do
					local argsOk, args = pcall(function()
						return HttpService:JSONDecode(call["function"].arguments)
					end)
					local result = panel:HandleToolCall(call["function"].name, argsOk and args or {})
					table.insert(conversation, {
						role = "tool",
						tool_call_id = call.id,
						content = HttpService:JSONEncode(result == nil and {} or result),
					})
				end
			elseif truncated then
				table.insert(conversation, {
					role = "user",
					content = "You got cut off. Continue exactly where you left off -- don't repeat "
						.. "anything, don't restart the explanation.",
				})
			else
				busy = false
				panel:HideTyping()
				saveHistory()
				return
			end
		end
 
		busy = false
		panel:HideTyping()
		panel:AddMessage("assistant",
			"(stopped after several rounds of tool calls/continuations -- ask me to continue if you need to)")
		saveHistory()
	end
 
	return assistant
end
 
local function DestroyAllWindowJanitors()
	for _, win in ipairs(NullUI._Windows) do
		win._destroyed = true
		if win._janitor then win._janitor:Destroy() end
	end
	table.clear(NullUI._Windows)
end
 
NullUI._Root.Destroying:Connect(function()
	AcrylicShuttingDown = true
	DestroyAllWindowJanitors()
	DestroyAllAcrylicControllers()
	LibJanitor:Destroy()
end)
 
function NullUI:Unload()
	CloseAnyOpenPopup()
	AcrylicShuttingDown = true
	DestroyAllWindowJanitors()
	DestroyAllAcrylicControllers()
	LibJanitor:Destroy()
	if NullUI._Root then NullUI._Root:Destroy() end
end
 
do
	local globalTable = GetGlobalTable()
	globalTable.__NullUI_Unload = function()
		pcall(function() NullUI:Unload() end)
	end
end
 
return NullUI

end

local function startSwingMain(session,controller)
if not session.Alive or session:GetRemaining()<=0 then return end
-- NEXZAN HUB | Swing For Eggs! | 2.0 | Themes & Automation
-- Map: 4be9rdkaLw | Income API scan: Henfl1wjLl | PlaceId: 109203247742910
-- Client script; server acceptance and live-game behavior are not guaranteed.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local Player = Players.LocalPlayer

if game.PlaceId ~= 109203247742910 then
    warn("Nexzan Hub: buka Swing For Eggs! terlebih dahulu.")
    return
end

local ENV = (getgenv and getgenv()) or _G
if ENV.NexzanRollerPurple and ENV.NexzanRollerPurple.Stop then
    pcall(ENV.NexzanRollerPurple.Stop)
end
local app = {Alive = true, Connections = {}, Tweens = {}}
ENV.NexzanRollerPurple = app
local State = {Farm = false, Hatch = false, Delay = 1.5, HatchDelay = 2, Animated = true}
State.AutoClaim, State.AutoPlaceBest = false, false
State.ClaimDelay, State.PlaceBestDelay = 1, 1.5
State.ColorPeriod = 2.7
local Window
local StopPlayerFeatures
function app.Stop()
    if not app.Alive then return end
    app.Alive = false
    State.Farm, State.Hatch = false, false
    State.AutoClaim, State.AutoPlaceBest = false, false
    if StopPlayerFeatures then pcall(StopPlayerFeatures) end
    for _, connection in ipairs(app.Connections) do connection:Disconnect() end
    for _, tween in ipairs(app.Tweens) do tween:Cancel() end
    if Window and not Window._destroyed then Window:Destroy() end
end

local ok, UI = pcall(function()
    return loadBundledLibrary()
end)
if not ok or type(UI) ~= "table" then
    app.Stop()
    warn("Nexzan Hub: UI gagal dimuat. Coba jalankan kembali.")
    return
end

-- Preserve the library's original palette and layout definitions.
local DefaultTheme = {}
for key,value in pairs(UI.Theme) do DefaultTheme[key] = value end
local Purple = Color3.fromRGB(178, 109, 255)
local Lavender = Color3.fromRGB(223, 200, 255)
UI.Theme.Background = Color3.fromRGB(18, 11, 30)
UI.Theme.Surface = Color3.fromRGB(32, 20, 49)
UI.Theme.Accent = Purple
UI.Theme.Glow = Lavender
UI.Theme.Text = Color3.fromRGB(249, 242, 255)
UI.Theme.TextDim = Color3.fromRGB(187, 164, 210)
UI.Theme.Danger = Color3.fromRGB(255, 124, 160)

UI:PreloadIcons({ "Lucide", "Material", "Phosphor", "SF" })
UI:SetScaleRange(0.75, 1.35)

Window = UI:CreateWindow({
    Title = "Nexzan Hub",
    Subtitle = "Swing For Eggs!",
    Icon = "Lucide:egg",
    Size = UDim2.fromOffset(680, 510),
    MinSize = Vector2.new(540, 400),
    Draggable = true,
    Resizable = true,
    UseBlur = true,
    DefaultTab = "Home",
})

local function notify(text)
    UI:Notify({Title = "Nexzan Hub", Text = text, Type = "info", Duration = 4})
end

local main = Window._gui
local background = Instance.new("ImageLabel")
background.Name = "PurpleBackground"
background.Size = UDim2.fromScale(1, 1)
background.BackgroundTransparency = 1
background.Image = "rbxassetid://114231177950533"
background.ScaleType = Enum.ScaleType.Crop
background.ImageTransparency = 0.2
background.ImageColor3 = Color3.fromRGB(218, 194, 255)
background.ZIndex = 1
background.Active = false
background.Parent = main
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 16)
corner.Parent = background
local shade = Instance.new("Frame")
shade.Name = "PurpleShade"
shade.Size = UDim2.fromScale(1, 1)
shade.BackgroundColor3 = Color3.fromRGB(15, 6, 29)
shade.BackgroundTransparency = 0.40
shade.BorderSizePixel = 0
shade.ZIndex = 1
shade.Active = false
shade.Parent = background
corner:Clone().Parent = shade
local shadeGradient = Instance.new("UIGradient")
shadeGradient.Rotation = 90
shadeGradient.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.18),
    NumberSequenceKeypoint.new(0.5, 0.42),
    NumberSequenceKeypoint.new(1, 0.05),
})
shadeGradient.Parent = shade
local border = main:FindFirstChildOfClass("UIStroke")
if border then border.Color = Purple; border.Transparency = 0.45; border.Thickness = 1.2 end

task.spawn(function()
    pcall(function() ContentProvider:PreloadAsync({background}) end)
end)

-- Theme layer: colors only; no control positions, sizes or layout changes.
local gradientEntries = setmetatable({}, {__mode = "k"})
local purpleSequence = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Purple),
    ColorSequenceKeypoint.new(0.30, Lavender),
    ColorSequenceKeypoint.new(0.50, Color3.new(1, 1, 1)),
    ColorSequenceKeypoint.new(0.70, Lavender),
    ColorSequenceKeypoint.new(1, Purple),
})
local function paint(instance, property, existing, enabled)
    if not instance or gradientEntries[instance] then return end
    local gradient = existing or Instance.new("UIGradient")
    gradient.Name = "PurpleWhiteMotion"
    gradient.Color = purpleSequence
    gradient.Rotation = 0
    gradient.Offset = Vector2.new(-0.65, 0)
    gradient.Parent = instance
    gradientEntries[instance] = {Gradient = gradient, Property = property, Enabled = enabled}
    if not enabled or enabled() then instance[property] = Color3.new(1, 1, 1) end
end
local themeBindings = setmetatable({}, {__mode = "k"})
local function bindColor(instance, property, role)
    themeBindings[instance] = themeBindings[instance] or {}
    themeBindings[instance][property] = role
    instance[property] = UI.Theme[role]
end
local function protectedColorArea(instance)
    local current = instance
    while current and current ~= UI._Root do
        if current:GetAttribute("NexzanColorWell") then return true end
        current = current.Parent
    end
    return false
end
local function style(instance)
    if not app.Alive or not instance.Parent or protectedColorArea(instance) then return end
    local pickerPopup = instance:FindFirstAncestor("ColorPickerPopup")
    if instance:IsA("TextBox") then
        paint(instance, "TextColor3")
        bindColor(instance, "PlaceholderColor3", "Glow")
    elseif instance:IsA("TextLabel") or instance:IsA("TextButton") then
        local heading = instance.Name == "Title"
            or instance.Parent.Name == "Section"
            or (instance.FontFace == UI.Theme.Font and instance.Name ~= "Description")
        local dropdownOption = instance:FindFirstAncestor("DropdownPopup") ~= nil
        if (heading or dropdownOption) and instance.Text ~= "" then paint(instance, "TextColor3")
        elseif instance.TextColor3 == UI.Theme.TextDim then bindColor(instance,"TextColor3","TextDim")
        elseif instance.TextColor3 == UI.Theme.Text then bindColor(instance,"TextColor3","Text") end
    elseif instance:IsA("ScrollingFrame") then
        bindColor(instance,"ScrollBarImageColor3","Accent")
    elseif instance:IsA("ImageLabel") and instance.Name == "LeadingIcon" then
        bindColor(instance,"ImageColor3","Glow")
    end
    -- Keep color-picker hue/saturation fields and custom color swatches untouched.
    if not pickerPopup and not gradientEntries[instance] then
        local property
        if instance:IsA("UIStroke") then property="Color"
        elseif instance:IsA("Frame") or instance:IsA("CanvasGroup") or instance:IsA("ScrollingFrame") then property="BackgroundColor3" end
        if property then
            local color=instance[property]
            for _,role in ipairs({"Background","Surface","Accent","TextDim"}) do
                if color == UI.Theme[role] then bindColor(instance,property,role); break end
            end
        end
    end
end
local function decorateControl(control, kind)
    if not control or not control.Instance then return control end
    local card = control.Instance
    if kind == "ColorPicker" then
        for _, child in ipairs(card:GetChildren()) do
            if child:IsA("Frame") then child:SetAttribute("NexzanColorWell",true) end
        end
    end
    if kind == "Dropdown" or kind == "Slider" then
        for _, child in ipairs(card:GetChildren()) do
            if child:IsA("TextLabel") and child.Name ~= "Description"
                and (kind == "Dropdown" or child.TextXAlignment == Enum.TextXAlignment.Right) then
                paint(child, "TextColor3")
            end
        end
    end
    if kind == "Toggle" then
        for _, child in ipairs(card:GetChildren()) do
            if child:IsA("Frame") then
                local gradient = child:FindFirstChildOfClass("UIGradient")
                if gradient then
                    paint(child, "BackgroundColor3", gradient, function() return control:Get() == true end)
                end
            end
        end
    elseif kind == "Slider" then
        for _, child in ipairs(card:GetChildren()) do
            if child:IsA("Frame") and child.Size.Y.Offset == 6 then
                bindColor(child,"BackgroundColor3","Accent")
                for _, part in ipairs(child:GetChildren()) do
                    if part:IsA("Frame") then paint(part, "BackgroundColor3") end
                end
            end
        end
    elseif kind == "Textbox" then
        for _, child in ipairs(card:GetDescendants()) do
            if child:IsA("TextBox") then style(child) end
        end
    end
    return control
end
local decorated = setmetatable({}, {__mode = "k"})
local function decorateTab(tab)
    if decorated[tab] then return tab end
    decorated[tab] = true
    local icon = tab._icon or tab.Icon
    if icon then
        paint(icon, "ImageColor3", nil, function()
            if tab._parentTab then return tab.Selected == true end
            return Window._currentTab == tab
        end)
    end
    for _, kind in ipairs({"Toggle", "Slider", "Dropdown", "Textbox", "ColorPicker"}) do
        local controlKind = kind
        local method = "Add" .. controlKind
        local original = tab[method]
        tab[method] = function(self, options)
            return decorateControl(original(self, options), controlKind)
        end
    end
    local originalSubTab = tab.AddSubTab
    tab.AddSubTab = function(self, options) return decorateTab(originalSubTab(self, options)) end
    return tab
end
local originalAddTab = Window.AddTab
Window.AddTab = function(self, options) return decorateTab(originalAddTab(self, options)) end
local originalPrivateTab = Window.AddPrivateTab
Window.AddPrivateTab = function(self, options) return decorateTab(originalPrivateTab(self, options)) end
local colorClock, elapsed = 0, 0
local RunTheme = game:GetService("RunService")
table.insert(app.Connections, RunTheme.Heartbeat:Connect(function(dt)
    if not app.Alive then return end
    if State.Animated then colorClock = colorClock + dt end
    elapsed = elapsed + dt
    if elapsed < 1 / 30 then return end
    elapsed = 0
    local offset = Vector2.new(-0.65 * math.cos(colorClock * math.pi / State.ColorPeriod), 0)
    for instance, entry in pairs(gradientEntries) do
        if instance.Parent and entry.Gradient.Parent then
            local enabled = not entry.Enabled or entry.Enabled()
            entry.Gradient.Enabled = enabled
            entry.Gradient.Offset = offset
            if enabled then instance[entry.Property] = Color3.new(1, 1, 1) end
        else gradientEntries[instance] = nil end
    end
end))
-- Dropdown menus are rendered under the UI root, not under the window.
table.insert(app.Connections, UI._Root.DescendantAdded:Connect(function(instance)
    task.defer(function()
        if instance.Parent and (instance:IsDescendantOf(main)
            or instance:FindFirstAncestor("DropdownPopup") or instance:FindFirstAncestor("ColorPickerPopup")) then style(instance) end
    end)
end))

local Themes = (function()
    local api = {Presets = {}, Custom = {}, Selected = "Purple", Dropdown = nil, Status = nil}
    local order = {"Purple", "Blue", "Red", "Green", "Default", "Yellow", "Orange", "Pink", "Cyan", "Teal", "Rose", "Silver"}
    local fields = {"Accent", "Glow", "Background", "Surface", "Text", "TextDim", "Danger"}
    local fileName = "nexzan_roller_themes.json"
    local function copy(palette)
        local result = {}
        for _, field in ipairs(fields) do result[field] = palette[field] end
        return result
    end
    local function make(accent)
        return {Accent=accent, Glow=accent:Lerp(Color3.new(1,1,1),0.62),
            Background=Color3.fromRGB(10,10,14):Lerp(accent,0.055),
            Surface=Color3.fromRGB(21,21,26):Lerp(accent,0.085),
            Text=Color3.fromRGB(247,245,252), TextDim=accent:Lerp(Color3.fromRGB(195,195,205),0.8),
            Danger=Color3.fromRGB(255,124,160)}
    end
    api.Presets.Purple = {Accent=Color3.fromRGB(178,109,255), Glow=Color3.fromRGB(223,200,255),
        Background=Color3.fromRGB(18,11,30), Surface=Color3.fromRGB(32,20,49),
        Text=Color3.fromRGB(249,242,255), TextDim=Color3.fromRGB(187,164,210), Danger=Color3.fromRGB(255,124,160)}
    for name, color in pairs({Blue=Color3.fromRGB(85,160,255), Red=Color3.fromRGB(255,93,116),
        Green=Color3.fromRGB(83,225,153), Yellow=Color3.fromRGB(255,221,88), Orange=Color3.fromRGB(255,161,80),
        Pink=Color3.fromRGB(245,135,210), Cyan=Color3.fromRGB(83,222,245), Teal=Color3.fromRGB(64,204,190),
        Rose=Color3.fromRGB(240,140,159), Silver=Color3.fromRGB(201,210,228)}) do api.Presets[name] = make(color) end
    api.Presets.Default = {Accent=DefaultTheme.Accent, Glow=DefaultTheme.Text,
        Background=DefaultTheme.Background, Surface=DefaultTheme.Surface,
        Text=DefaultTheme.Text, TextDim=DefaultTheme.TextDim, Danger=DefaultTheme.Danger}
    local function decodePalette(value)
        if type(value) ~= "table" then return nil end
        local result = {}
        for _, field in ipairs(fields) do
            local hex = value[field]
            if type(hex) ~= "string" or not hex:match("^%x%x%x%x%x%x$") then return nil end
            result[field] = Color3.fromHex(hex)
        end
        return result
    end
    local function saveFile()
        if type(writefile) ~= "function" then return false end
        local data = {Version=1, Selected=api.Selected, Custom={}}
        for name, palette in pairs(api.Custom) do
            local row = {}
            for _, field in ipairs(fields) do row[field] = palette[field]:ToHex() end
            data.Custom[name] = row
        end
        return pcall(function() writefile(fileName, game:GetService("HttpService"):JSONEncode(data)) end)
    end
    if type(readfile) == "function" then
        pcall(function()
            local value = game:GetService("HttpService"):JSONDecode(readfile(fileName))
            if type(value) ~= "table" or value.Version ~= 1 or type(value.Custom) ~= "table" then return end
            local count = 0
            for name, row in pairs(value.Custom) do
                if type(name) == "string" and #name > 0 and #name <= 32 and count < 30 then
                    local palette = decodePalette(row)
                    if palette then api.Custom[name] = palette; count = count + 1 end
                end
            end
            if type(value.Selected) == "string" then api.Selected = value.Selected end
        end)
    end
    function api.Options()
        local list, custom = {}, {}
        for _, name in ipairs(order) do table.insert(list, name) end
        for name in pairs(api.Custom) do table.insert(custom, name) end
        table.sort(custom)
        for _, name in ipairs(custom) do table.insert(list, "Custom: " .. name) end
        return list
    end
    function api.Get(name)
        if api.Presets[name] then return api.Presets[name] end
        local customName = type(name) == "string" and name:match("^Custom: (.+)$")
        return customName and api.Custom[customName] or nil
    end
    if not api.Get(api.Selected) then api.Selected = "Purple" end
    function api.Apply(palette, name)
        if not app.Alive then return end
        for _, field in ipairs(fields) do UI.Theme[field] = palette[field] end
        Purple, Lavender = palette.Accent, palette.Glow
        purpleSequence = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Purple), ColorSequenceKeypoint.new(0.3, Lavender),
            ColorSequenceKeypoint.new(0.5, Color3.new(1,1,1)), ColorSequenceKeypoint.new(0.7, Lavender),
            ColorSequenceKeypoint.new(1, Purple),
        })
        for instance, entry in pairs(gradientEntries) do
            if instance.Parent and entry.Gradient.Parent then entry.Gradient.Color = purpleSequence end
        end
        for instance, bindings in pairs(themeBindings) do
            if instance.Parent then
                for property, role in pairs(bindings) do instance[property] = UI.Theme[role] end
            else themeBindings[instance] = nil end
        end
        main.BackgroundColor3 = palette.Background
        shade.BackgroundColor3 = palette.Background
        background.ImageColor3 = palette.Glow
        if border then border.Color = palette.Accent end
        api.Selected = name or "Preview Custom"
        if api.Status then api.Status:Set("Theme aktif: " .. api.Selected) end
    end
    function api.Select(name)
        local palette = api.Get(name)
        if not palette then return false end
        api.Apply(palette, name)
        saveFile()
        return true
    end
    api.Draft = copy(api.Get(api.Selected))
    api.DraftName = "Theme Saya"
    function api.SaveCustom()
        local name = api.DraftName:gsub("^%s+", ""):gsub("%s+$", "")
        if #name == 0 or #name > 32 or name:find("[%c]") then notify("Nama theme harus 1–32 karakter."); return end
        local count = 0
        for _ in pairs(api.Custom) do count = count + 1 end
        if count >= 30 and not api.Custom[name] then notify("Batas 30 theme custom tercapai."); return end
        api.Custom[name] = copy(api.Draft)
        local selected = "Custom: " .. name
        api.Apply(api.Custom[name], selected)
        if api.Dropdown then api.Dropdown:SetOptions(api.Options()); api.Dropdown:Set(selected, true) end
        local saved = saveFile()
        notify(saved and "Theme custom disimpan dan diterapkan." or "Theme disimpan untuk sesi ini. Penyimpanan file belum tersedia.")
    end
    function api.DeleteSelected()
        local name = api.Selected:match("^Custom: (.+)$")
        if not name or not api.Custom[name] then notify("Pilih theme custom yang ingin dihapus."); return end
        api.Custom[name] = nil
        api.Select("Purple")
        if api.Dropdown then api.Dropdown:SetOptions(api.Options()); api.Dropdown:Set("Purple", true) end
        notify("Theme custom dihapus.")
    end
    api.Copy = copy
    return api
end)()

local Automation = (function()
    local RS = game:GetService("ReplicatedStorage")
    local api = {Status = {}, Busy = {}, SelectedTrail = nil}
    local provider, providerLoading, retryAt = nil, false, 0
    local inventoryBusy = false
    local function status(name, text)
        local row = api.Status[name]
        if row and app.Alive then row:Set(text) end
    end
    local function findAction(name)
        local shared = RS:FindFirstChild("SharedModules")
        local net = shared and shared:FindFirstChild("Net")
        local action = net and net:FindFirstChild(name)
        return action and action:IsA("RemoteFunction") and action or nil
    end
    local function invoke(name, ...)
        if not app.Alive or api.Busy[name] then return false, "Masih diproses." end
        local action = findAction(name)
        if not action then return false, "Fitur belum tersedia. Menunggu game..." end
        api.Busy[name] = true
        local ok, result = pcall(function(...) return action:InvokeServer(...) end, ...)
        api.Busy[name] = nil
        if not ok then return false, "Permintaan gagal. Akan dicoba kembali." end
        if result == false then return false, "Permintaan belum diterima game." end
        if type(result) == "table" then
            if result.Success == false or result.success == false or result.ok == false then
                return false, tostring(result.Message or result.message or result.error or "Syarat belum terpenuhi."):sub(1, 160)
            end
        end
        return true, "Permintaan diproses."
    end
    local function uuid(value)
        return type(value) == "string" and value:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil
    end
    local function ownTable(data)
        if type(data) ~= "table" then return false end
        for _, field in ipairs({"OwnerUserId", "ownerUserId", "UserId", "userId"}) do
            local id = rawget(data, field)
            if tonumber(id) and tonumber(id) ~= 0 and tonumber(id) ~= Player.UserId then return false end
        end
        return true
    end
    local function protected(record)
        for _, key in ipairs({"Locked", "locked", "IsLocked", "Favorite", "favorite", "Favourite", "IsFavorite"}) do
            local value = record[key]
            if value == true or value == 1 or value == "true" then return true end
        end
        return false
    end
    local function collectInventory(data, ids, blocked)
        local recognized, seen = false, {}
        local containers = {Inventory=true, inventory=true, Animals=true, animals=true, Pets=true, pets=true,
            Items=true, items=true, AnimalInventory=true, OwnedAnimals=true, entries=true, Entries=true}
        local wrappers = {Data=true, data=true, Profile=true, profile=true, Replica=true, replica=true}
        local function record(value, key)
            if type(value) == "string" and uuid(value) then ids[value] = true; return end
            if value == true and uuid(key) then ids[key] = true; return end
            if type(value) ~= "table" or not ownTable(value) then return end
            local id
            for _, field in ipairs({"EntryId", "entryId", "Id", "id", "UID", "uid", "AnimalId", "ItemId"}) do
                if uuid(value[field]) then id = value[field]; break end
            end
            id = id or (uuid(key) and key or nil)
            if id then
                if protected(value) then blocked[id] = true else ids[id] = true end
            end
        end
        local function visit(node, depth, collection)
            if type(node) ~= "table" or seen[node] or depth > 7 or not ownTable(node) then return end
            seen[node] = true
            if collection then
                recognized = true
                for key, value in pairs(node) do record(value, key) end
            end
            for key, value in pairs(node) do
                if type(value) == "table" and (containers[key] or wrappers[key]) then
                    visit(value, depth + 1, containers[key] == true)
                end
            end
        end
        visit(data, 0, false)
        return recognized
    end
    local function ensureProvider()
        if provider or providerLoading or os.clock() < retryAt then return end
        retryAt, providerLoading = os.clock() + 15, true
        task.spawn(function()
            local clients = RS:FindFirstChild("ClientModules")
            local module = clients and clients:FindFirstChild("PlayerData")
            if module and module:IsA("ModuleScript") then
                local done, ok, value = false, false, nil
                local thread = task.spawn(function() ok, value = pcall(require, module); done = true end)
                local deadline = os.clock() + 8
                while app.Alive and not done and os.clock() < deadline do task.wait(0.1) end
                if not done then pcall(task.cancel, thread) end
                if done and ok and type(value) == "table" then provider = value end
            end
            providerLoading = false
        end)
    end
    function api.InventoryIds()
        ensureProvider()
        local ids, blocked, recognized = {}, {}, false
        if provider then
            for _, method in ipairs({"GetLocalData", "GetData", "GetSnapshot", "GetReplica", "Get"}) do
                local getter = provider[method]
                if type(getter) == "function" then
                    local ok, snapshot = pcall(getter)
                    if not ok or type(snapshot) ~= "table" then ok, snapshot = pcall(getter, provider) end
                    if ok and type(snapshot) == "table" then
                        local currentIds, currentBlocked = {}, {}
                        if collectInventory(snapshot, currentIds, currentBlocked) then
                            ids, blocked, recognized = currentIds, currentBlocked, true
                            break
                        end
                    end
                end
            end
            if not recognized then recognized = collectInventory(provider, ids, blocked) end
        end
        local function instanceRecords(container)
            if not container then return end
            for _, object in ipairs(container:GetDescendants()) do
                local id = object:GetAttribute("EntryId") or object:GetAttribute("ItemId") or object:GetAttribute("AnimalId")
                if uuid(id) then
                    local owner = object:GetAttribute("OwnerUserId")
                    if not owner or tonumber(owner) == Player.UserId then
                        recognized = true
                        if protected(object:GetAttributes()) then blocked[id] = true else ids[id] = true end
                    end
                end
            end
        end
        -- A recognized profile snapshot is authoritative, even when it is empty.
        if not recognized then
        instanceRecords(Player:FindFirstChild("Backpack"))
        instanceRecords(Player:FindFirstChild("Inventory"))
        -- Only held Tools belonging to this character, never arbitrary workspace models.
        if Player.Character then
            for _, object in ipairs(Player.Character:GetChildren()) do
                if object:IsA("Tool") then
                    local id = object:GetAttribute("EntryId") or object:GetAttribute("ItemId") or object:GetAttribute("AnimalId")
                    if uuid(id) then
                        recognized = true
                        if protected(object:GetAttributes()) then blocked[id] = true else ids[id] = true end
                    end
                    instanceRecords(object)
                end
            end
        end
        end
        local list = {}
        for id in pairs(ids) do if not blocked[id] then table.insert(list, id) end end
        table.sort(list)
        return list, recognized
    end
    function api.Trails()
        local assets = RS:FindFirstChild("Assets")
        local instances = assets and assets:FindFirstChild("Instances")
        local folder = instances and instances:FindFirstChild("Trails")
        local names = {}
        if folder then for _, item in ipairs(folder:GetChildren()) do table.insert(names, item.Name) end end
        table.sort(names)
        return names
    end
    function api.BuyTrail()
        local selected = api.SelectedTrail
        local valid = false
        for _, name in ipairs(api.Trails()) do if name == selected then valid = true; break end end
        if not valid then status("Trail", "Pilih Trail yang tersedia terlebih dahulu."); return end
        if api.Busy["RF/Trail_Buy"] then status("Trail", "Pembelian masih diproses."); return end
        status("Trail", "Memproses pembelian " .. selected .. "...")
        local ok, text = invoke("RF/Trail_Buy", selected)
        if app.Alive then status("Trail", selected .. " • " .. text) end
        return ok
    end
    local definitions = {
        {Flag="AutoClaim", Delay="ClaimDelay", Action="RF/Index_ClaimAll", Label="Claim"},
        {Flag="AutoPlaceBest", Delay="PlaceBestDelay", Action="RF/Pen_PlaceBest", Label="Place"},
    }
    for _, definition in ipairs(definitions) do
        local job = definition
        task.spawn(function()
            while app.Alive do
                if State[job.Flag] then
                    local usesInventory = job.Label == "Place"
                    if not usesInventory or not inventoryBusy then
                        if usesInventory then inventoryBusy = true end
                        local ran, err = pcall(function()
                            local _, message = invoke(job.Action)
                            if State[job.Flag] then status(job.Label, message) end
                        end)
                        if usesInventory then inventoryBusy = false end
                        if not ran then
                            status(job.Label, "Menunggu data game siap...")
                            warn("Nexzan automation: " .. tostring(err))
                        end
                    end
                    task.wait(math.max(0.2, State[job.Delay] or 1))
                else task.wait(0.2) end
            end
        end)
    end
    -- Expose pure validation helpers for local tests; no hardcoded player item IDs.
    api.CollectInventory = collectInventory
    return api
end)()

local FarmStatus, HatchStatus
local lastFarm, lastHatch
local function farmStatus(text)
    if text ~= lastFarm then
        lastFarm = text
        if FarmStatus and app.Alive then FarmStatus:Set(text) end
    end
end
local function hatchStatus(text)
    if text ~= lastHatch then
        lastHatch = text
        if HatchStatus and app.Alive then HatchStatus:Set(text) end
    end
end

local function root()
    local character = Player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return nil end
    return character:FindFirstChild("HumanoidRootPart")
end
local function plotsFolder()
    local map = Workspace:FindFirstChild("Map")
    return map and map:FindFirstChild("Plots")
end
local function myPlot()
    local plots = plotsFolder()
    if not plots then return nil end
    for _, plot in ipairs(plots:GetChildren()) do
        if tonumber(plot:GetAttribute("OwnerUserId")) == Player.UserId then return plot end
    end
    for _, plot in ipairs(plots:GetChildren()) do
        local id = plot:GetAttribute("OwnerUserId")
        if (not id or tonumber(id) == 0)
            and plot:GetAttribute("OwnerName") == Player.Name then return plot end
    end
    -- Do not use DisplayName alone: it is not unique.
    return nil
end
local function plotCenter(plot)
    return plot and (plot:FindFirstChild("CenterPoint") or plot:FindFirstChild("CenterPoint", true))
end
local function teleport(cf)
    if not app.Alive then return false end
    local part = root()
    if not part then return false end
    part.AssemblyLinearVelocity = Vector3.zero
    part.AssemblyAngularVelocity = Vector3.zero
    part.CFrame = cf
    return true
end
local function home()
    local center = plotCenter(myPlot())
    return center and center:IsA("BasePart") and teleport(center.CFrame + Vector3.new(0, State.PlotOffsetY or 3.5, 0))
end
local function positionOf(prompt)
    local parent = prompt.Parent
    if not parent then return nil end
    if parent:IsA("Attachment") then return parent.WorldPosition end
    if parent:IsA("BasePart") then return parent.Position end
    if parent:IsA("Model") then return parent:GetPivot().Position end
    return nil
end
local function interact(prompt, allowed)
    if not app.Alive or not allowed() or not prompt.Parent or not prompt.Enabled then return false end
    local position = positionOf(prompt)
    if not position then return false end
    if not teleport(CFrame.new(position + Vector3.new(0, 2, 3), position)) then return false end
    task.wait(0.25)
    if not app.Alive or not allowed() or not prompt.Parent or not prompt.Enabled then return false end
    local succeeded = pcall(function()
        if type(fireproximityprompt) == "function" then
            fireproximityprompt(prompt, prompt.HoldDuration + 0.1)
        else
            prompt:InputHoldBegin()
            task.wait(prompt.HoldDuration + 0.15)
            prompt:InputHoldEnd()
        end
    end)
    task.wait(0.35)
    return succeeded
end

-- Income ordering uses live game getters, never rarity or template Generation.
local IncomeModules = {}
local incomeLoading = false
local incomeRetryAt = 0
local baseCache, sizeAdapters = {}, {}
local suffixes = {
    {"Dc", 1e33}, {"No", 1e30}, {"Oc", 1e27}, {"Sp", 1e24},
    {"Sx", 1e21}, {"Qi", 1e18}, {"Qa", 1e15}, {"T", 1e12},
    {"B", 1e9}, {"M", 1e6}, {"K", 1e3},
}
local function validNumber(value)
    return type(value) == "number" and value == value and value >= 0 and value < math.huge
end
local function parseIncome(value)
    if validNumber(value) then return value end
    if type(value) ~= "string" then return nil end
    local text = value:gsub("<[^>]*>", ""):lower():gsub("%s", "")
    text = text:gsub("/sec$", ""):gsub("/s$", ""):gsub("%$", ""):gsub("^%+", "")
    local multiplier, hasSuffix = 1, false
    for _, item in ipairs(suffixes) do
        local suffix = item[1]:lower()
        if text:sub(-#suffix) == suffix then
            text, multiplier, hasSuffix = text:sub(1, -#suffix - 1), item[2], true
            break
        end
    end
    local comma, dot = text:match(".*(),"), text:match(".*()%.")
    if comma and dot then
        if comma > dot then text = text:gsub("%.", ""):gsub(",", ".")
        else text = text:gsub(",", "") end
    elseif comma then
        local grouped = text:match("^%d%d?%d?,%d%d%d$") or text:match(",%d%d%d,")
        if grouped and not hasSuffix then text = text:gsub(",", "")
        else text = text:gsub(",", ".") end
    end
    local number = tonumber(text)
    number = number and number * multiplier
    return validNumber(number) and number or nil
end
local function formatIncome(value)
    for _, item in ipairs(suffixes) do
        if value >= item[2] then return string.format("$%.2f%s/s", value / item[2], item[1]) end
    end
    return string.format("$%.2f/s", value)
end
local function readNumber(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    return ok and parseIncome(value) or nil
end
local function loadIncomeModules()
    if incomeLoading or os.clock() < incomeRetryAt then return end
    if IncomeModules.AnimalsData and IncomeModules.SizeData and IncomeModules.MutationData then return end
    incomeLoading = true
    incomeRetryAt = os.clock() + 15
    task.spawn(function()
        local shared = game:GetService("ReplicatedStorage"):FindFirstChild("SharedModules")
        local folder = shared and shared:FindFirstChild("GameData")
        for _, name in ipairs({"AnimalsData", "SizeData", "MutationData"}) do
            if not app.Alive then break end
            local module = folder and folder:FindFirstChild(name)
            if module and not IncomeModules[name] then
                local done, success, result = false, false, nil
                local thread = task.spawn(function()
                    success, result = pcall(require, module)
                    done = true
                end)
                local deadline = os.clock() + 8
                while app.Alive and not done and os.clock() < deadline do task.wait(0.1) end
                if not done then pcall(task.cancel, thread) end
                if done and success and type(result) == "table" then IncomeModules[name] = result end
            end
        end
        incomeLoading = false
    end)
end
local function animalBase(animal)
    if type(animal) ~= "string" or animal == "" then return nil end
    if baseCache[animal] ~= nil then return baseCache[animal] end
    local data = IncomeModules.AnimalsData
    if not data then return nil end
    if type(data.Exists) == "function" then
        local ok, exists = pcall(data.Exists, animal)
        if not ok or not exists then return nil end
    end
    -- Exclusive animals may be relative to a player's best pet: do not invent a fixed rate.
    if type(data.IsExclusive) == "function" then
        local ok, exclusive = pcall(data.IsExclusive, animal)
        if not ok or exclusive then return nil end
    end
    local value = readNumber(data.GetCashPerSecond, animal)
    if value and value > 0 then baseCache[animal] = value; return value end
    return nil
end
local function mutationMultiplier(mutation)
    if mutation == nil or mutation == "" or mutation == "Normal" or mutation == "None" then return 1 end
    local data = IncomeModules.MutationData
    if not data then return nil end
    -- Getter handles combined mutations; do not multiply labels together manually.
    local value = readNumber(data.GetMultiplier, mutation)
    return value and value >= 1 and value or nil
end
local function near(a, b)
    return a and b and math.abs(a - b) <= math.max(0.000001, math.abs(b) * 0.00001)
end
local function sizeMultiplier(size, rarity)
    local data = IncomeModules.SizeData
    if not data or type(data.GetCPSMultiplier) ~= "function" then return nil end
    if not validNumber(size) or size <= 0 or type(rarity) ~= "string" then return nil end
    if size == 1 then return 1 end
    local cached = sizeAdapters[rarity]
    if cached then return readNumber(cached, size) end
    -- The scan exposes the getter but not parameter names. Accept an argument order
    -- only if its neutral and increasing-size probes behave like an income multiplier.
    local candidates = {
        function(value) return data.GetCPSMultiplier(value, rarity) end,
        function(value) return data.GetCPSMultiplier(rarity, value) end,
    }
    local approved = {}
    for _, candidate in ipairs(candidates) do
        local one, two, five = readNumber(candidate, 1), readNumber(candidate, 2), readNumber(candidate, 5)
        if near(one, 1) and two and five and two > one and five > two then
            table.insert(approved, candidate)
        end
    end
    if #approved == 0 then return nil end
    local value = readNumber(approved[1], size)
    if not value then return nil end
    for index = 2, #approved do
        if not near(value, readNumber(approved[index], size)) then return nil end
    end
    -- Do not cache ambiguous orders even if they happen to agree for this egg.
    if #approved == 1 then sizeAdapters[rarity] = approved[1] end
    return value
end
local function visibleIncome(egg)
    for _, key in ipairs({"IncomePerSecond", "CashPerSecond", "EarningsPerSecond"}) do
        local value = parseIncome(egg:GetAttribute(key))
        if value then return value end
    end
    for _, object in ipairs(egg:GetDescendants()) do
        if object:IsA("TextLabel") and object.Text:lower():find("/s", 1, true) then
            local value = parseIncome(object.Text)
            if value then return value end
        end
    end
    return nil
end
local function eggIncome(egg)
    local explicit = visibleIncome(egg)
    if explicit then return explicit, "visible" end
    local animal = egg:GetAttribute("Animal")
    local base = animalBase(animal)
    if not base then return nil end
    local mutation = mutationMultiplier(egg:GetAttribute("Mutation"))
    if not mutation then return nil end
    local scale = parseIncome(egg:GetAttribute("CPSMultiplier"))
    if not scale then
        local size = tonumber(egg:GetAttribute("Size")) or 1
        scale = sizeMultiplier(size, egg:GetAttribute("Rarity"))
    end
    if not scale or scale <= 0 then return nil end
    local estimate = base * mutation * scale
    -- This comparison excludes player-wide boosts, which apply equally to candidates.
    return validNumber(estimate) and estimate or nil, "estimate"
end
local cooldown = setmetatable({}, {__mode = "k"})
local function targetEgg()
    loadIncomeModules()
    local eggs, part = Workspace:FindFirstChild("WorldEggs"), root()
    if not eggs or not part then return nil, nil, nil, "Menunggu telur tersedia..." end
    local candidates, unknown = {}, 0
    for _, egg in ipairs(eggs:GetChildren()) do
        if (cooldown[egg] or 0) <= os.clock() then
            local prompt = egg:FindFirstChild("TakeEgg", true)
            if prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled then
                local position = positionOf(prompt)
                if position then
                    local income, source = eggIncome(egg)
                    if income then
                        table.insert(candidates, {Egg = egg, Prompt = prompt, Income = income,
                            Source = source, Distance = (part.Position - position).Magnitude})
                    else unknown = unknown + 1 end
                end
            end
        end
    end
    -- Never silently fall back to rarity when an eligible egg cannot be valued.
    if unknown > 0 then
        return nil, nil, nil, "Menunggu data penghasilan " .. tostring(unknown) .. " telur..."
    end
    if #candidates == 0 then return nil, nil, nil, "Menunggu telur tersedia..." end
    -- Do not compare boosted visible totals against unboosted estimates.
    local source = candidates[1].Source
    for _, candidate in ipairs(candidates) do
        if candidate.Source ~= source then
            return nil, nil, nil, "Menunggu data penghasilan yang sebanding..."
        end
    end
    table.sort(candidates, function(a, b)
        if a.Income ~= b.Income then return a.Income > b.Income end
        return a.Distance < b.Distance
    end)
    local best = candidates[1]
    return best.Egg, best.Prompt, best.Income, nil, best.Source
end

local function carryingEgg()
    for _, holder in ipairs({Player, Player.Character or Player}) do
        local carried = holder:GetAttribute("CarryingEggs")
        if carried == true or (tonumber(carried) and tonumber(carried) > 0) then return true end
    end
    local carried = Workspace:FindFirstChild("CarriedEggs")
    if carried then
        for _, egg in ipairs(carried:GetChildren()) do
            if tonumber(egg:GetAttribute("OwnerUserId")) == Player.UserId
                or tonumber(egg:GetAttribute("CarrierUserId")) == Player.UserId
                or egg.Name == tostring(Player.UserId) or egg.Name == Player.Name then return true end
            local eggRoot = egg:FindFirstChild("EggRoot", true)
            if eggRoot and eggRoot:IsA("BasePart") and Player.Character then
                for _, part in ipairs(eggRoot:GetConnectedParts(true)) do
                    if part:IsDescendantOf(Player.Character) then return true end
                end
            end
        end
    end
    local character = Player.Character
    if character then
        for _, object in ipairs(character:GetChildren()) do
            if (object:IsA("Model") or object:IsA("Tool")) and object:FindFirstChild("EggRoot", true) then return true end
        end
    end
    return false
end

local function eggInMyPlot(egg, plot)
    local owner = egg:GetAttribute("OwnerUserId")
    if owner and tonumber(owner) ~= 0 then return tonumber(owner) == Player.UserId end
    if egg:IsDescendantOf(plot) then return true end
    local eggRoot = egg:FindFirstChild("EggRoot", true)
    local area = plot:FindFirstChild("PetArea", true)
    if not eggRoot or not eggRoot:IsA("BasePart") or not area or not area:IsA("BasePart") then return false end
    local point = area.CFrame:PointToObjectSpace(eggRoot.Position)
    return math.abs(point.X) <= area.Size.X / 2
        and math.abs(point.Z) <= area.Size.Z / 2
        and math.abs(point.Y) <= 25
end
local function hatchOne()
    local plot = myPlot()
    if not plot then hatchStatus("Plot kamu belum ditemukan."); return end
    local eggs = Workspace:FindFirstChild("PenEggs")
    if not eggs then hatchStatus("Belum ada telur di plot."); return end
    for _, egg in ipairs(eggs:GetChildren()) do
        if eggInMyPlot(egg, plot) then
            local prompt = egg:FindFirstChild("EggPrompt", true)
            if prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled then
                local action = string.lower(prompt.ActionText):gsub("<[^>]+>", "")
                if action == "open" or action == "hatch" then
                    hatchStatus("Menetaskan telur di plot kamu...")
                    local success = interact(prompt, function() return State.Hatch end)
                    if success then
                        task.wait(0.6)
                        if not egg.Parent or not prompt.Parent or not prompt.Enabled then
                            hatchStatus("Penetasan diproses.")
                        else
                            hatchStatus("Menunggu penetasan...")
                        end
                    end
                    if app.Alive and root() then home() end
                    return
                end
            end
        end
    end
    hatchStatus("Menunggu telur siap menetas di plot kamu.")
end
local pendingReturn = false
local function farmOne()
    if not myPlot() then farmStatus("Plot kamu belum ditemukan."); return end
    if carryingEgg() then
        home()
        farmStatus("Telur masih dibawa. Letakkan telur untuk melanjutkan.")
        return
    end
    local egg, prompt, income, reason, source = targetEgg()
    if not egg then farmStatus(reason or "Menunggu telur terbaik..."); return end
    farmStatus("Target: " .. tostring(egg:GetAttribute("Animal") or egg.Name)
        .. " • " .. (source == "estimate" and "Est. " or "") .. formatIncome(income))
    cooldown[egg] = os.clock() + 8
    pendingReturn = true
    local attempted = interact(prompt, function() return State.Farm end)
    local confirmed = false
    local deadline = os.clock() + 2
    while attempted and app.Alive and State.Farm and os.clock() < deadline do
        if carryingEgg() then confirmed = true; break end
        if not egg.Parent or not egg:IsDescendantOf(Workspace:FindFirstChild("WorldEggs") or Workspace) then break end
        task.wait(0.1)
    end
    if app.Alive then
        pendingReturn = not home()
        farmStatus(confirmed and "Telur dibawa kembali ke plot." or "Kembali ke plot. Menunggu pembaruan telur...")
        task.wait(0.75)
    end
end

local VindUI = UI
local LocalPlayer = Player
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local Humanoid, Character, RootPart
State.WalkSpeed, State.JumpPower = 16, 50
State.Fly, State.NoClip, State.InfiniteJump, State.AntiAFK = false, false, false, true
State.FlySpeed = 50
State.AIApiKey, State.AIProvider, State.AIModel = "", "Google Gemini", "gemini-2.5-flash"
State.PlotOffsetY = 3.5
local function UpdatePlotStatusText()
    local plot = myPlot()
    return plot and ("Plot " .. plot.Name .. " • @" .. Player.Name) or "Plot belum ditemukan."
end
local CONFIG = {
    SourceUrl = "bundled local library",
    FeedbackWebhook = "",
    CommunityUrl = "https://discord.gg/yyWdWas8mx",
    YoutubeUrl   = "https://www.youtube.com/@Nexzan_hub",
}

local function GetCleanChatTools()
    return {
        {
            Name = "list_ui_elements",
            Description = "Lists every UI element that has a Flag, with its kind and current value.",
            Parameters = {
                type = "object",
                properties = {
                    query = { type = "string", description = "Optional query or leave empty" },
                },
                required = { "query" },
            },
            Handler = function()
                return VindUI:ListUIElements()
            end,
        },
        {
            Name = "set_ui_element_value",
            Description = "Sets a UI element's value by its flag name.",
            Parameters = {
                type = "object",
                properties = {
                    flag  = { type = "string", description = "The Flag of the UI element to change." },
                    value = { type = "string", description = "The new value for the element." },
                },
                required = { "flag", "value" },
            },
            Handler = function(args)
                local ok, err = VindUI:SetUIElementValue(args.flag, args.value)
                if not ok then error(err, 0) end
                return true
            end,
        },
        {
            Name = "select_tab",
            Description = "Switches the panel to one of its top-level sidebar tabs.",
            Parameters = {
                type = "object",
                properties = {
                    tab = { type = "string", description = "The tab's name." },
                },
                required = { "tab" },
            },
            Handler = function(args)
                local tabObj = Window:SelectTab(args.tab)
                if not tabObj then error("No tab named '" .. tostring(args.tab) .. "'", 0) end
                return "Switched to " .. tabObj.Name
            end,
        },
        {
            Name = "select_subtab",
            Description = "Switches to a sub-tab nested under one of the top-level tabs.",
            Parameters = {
                type = "object",
                properties = {
                    tab    = { type = "string", description = "The top-level tab that contains the sub-tab." },
                    subtab = { type = "string", description = "The sub-tab's name." },
                },
                required = { "tab", "subtab" },
            },
            Handler = function(args)
                local tabObj = Window:SelectTab(args.tab)
                if not tabObj then error("No tab named '" .. tostring(args.tab) .. "'", 0) end
                local sub = tabObj:SelectSubTabByName(args.subtab)
                if not sub then
                    error("No sub-tab named '" .. tostring(args.subtab) .. "' under " .. tabObj.Name, 0)
                end
                return "Switched to " .. tabObj.Name .. " > " .. sub.Name
            end,
        },
        {
            Name = "find_and_highlight_element",
            Description = "Finds a UI element by its visible label and highlights it.",
            Parameters = {
                type = "object",
                properties = {
                    query = { type = "string", description = "The element's visible text." },
                },
                required = { "query" },
            },
            Handler = function(args)
                local ok, titleOrErr = Window:JumpToElement(args.query)
                if not ok then error(titleOrErr, 0) end
                return "Highlighted: " .. titleOrErr
            end,
        },
    }
end

Window._BuildDefaultChatTools = function(self)
    return GetCleanChatTools()
end

-- ====================================================================
local function GetDeviceType()
    if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
        return "Mobile / Touchscreen"
    elseif UserInputService.KeyboardEnabled then
        return "PC (Keyboard / Mouse)"
    elseif UserInputService.GamepadEnabled then
        return "Console / Gamepad"
    else
        return "Unknown Device"
    end
end

local function GetExecutorName()
    if identifyexecutor then return tostring(identifyexecutor()) end
    if getexecutorname then return tostring(getexecutorname()) end
    return "Delta / Universal"
end

local function GetAccountCreatedDate()
    local createdTimestamp = os.time() - (LocalPlayer.AccountAge * 86400)
    return os.date("%Y-%m-%d", createdTimestamp)
end

-- ====================================================================

local flightVelocity, flightGyro
local collisionBackup = setmetatable({}, {__mode = "k"})
local originalHumanoids = setmetatable({}, {__mode = "k"})
local function restoreCollision()
    for part, value in pairs(collisionBackup) do
        if part.Parent then part.CanCollide = value end
        collisionBackup[part] = nil
    end
end
local function StopFly()
    if flightVelocity then flightVelocity:Destroy(); flightVelocity = nil end
    if flightGyro then flightGyro:Destroy(); flightGyro = nil end
    if Humanoid then Humanoid.PlatformStand = false end
end
local function StartFly()
    StopFly()
    if not RootPart or not Humanoid or Humanoid.Health <= 0 then return end
    flightVelocity = Instance.new("BodyVelocity")
    flightVelocity.Name = "NexzanFlyVel"
    flightVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    flightVelocity.Velocity = Vector3.zero
    flightVelocity.Parent = RootPart
    flightGyro = Instance.new("BodyGyro")
    flightGyro.Name = "NexzanFlyGyro"
    flightGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
    flightGyro.P = 10000
    flightGyro.CFrame = RootPart.CFrame
    flightGyro.Parent = RootPart
    Humanoid.PlatformStand = true
end
local function bindCharacter(character)
    StopFly()
    restoreCollision()
    Character = character
    Humanoid, RootPart = nil, nil
    local h = character:WaitForChild("Humanoid", 10)
    local r = character:WaitForChild("HumanoidRootPart", 10)
    if not app.Alive or Player.Character ~= character then return end
    Humanoid, RootPart = h, r
    if h then originalHumanoids[h] = {Speed = h.WalkSpeed, Jump = h.JumpPower, Stand = h.PlatformStand} end
    if State.Fly then StartFly() end
end
StopPlayerFeatures = function()
    State.Fly, State.NoClip, State.InfiniteJump, State.AntiAFK = false, false, false, false
    StopFly()
    restoreCollision()
    for humanoid, values in pairs(originalHumanoids) do
        if humanoid.Parent then
            humanoid.WalkSpeed, humanoid.JumpPower, humanoid.PlatformStand = values.Speed, values.Jump, values.Stand
        end
    end
end
table.insert(app.Connections, Player.CharacterAdded:Connect(bindCharacter))
if Player.Character then bindCharacter(Player.Character) end
table.insert(app.Connections, RunService.Stepped:Connect(function()
    if not app.Alive then return end
    if State.NoClip and Character then
        for _, part in ipairs(Character:GetDescendants()) do
            if part:IsA("BasePart") then
                if collisionBackup[part] == nil then collisionBackup[part] = part.CanCollide end
                part.CanCollide = false
            end
        end
    else restoreCollision() end
end))
table.insert(app.Connections, UserInputService.JumpRequest:Connect(function()
    if State.InfiniteJump and Humanoid then Humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
end))
table.insert(app.Connections, RunService.RenderStepped:Connect(function()
    if State.Fly and flightVelocity and flightGyro and Humanoid and Workspace.CurrentCamera then
        local camera = Workspace.CurrentCamera
        flightGyro.CFrame = camera.CFrame
        local move = Humanoid.MoveDirection
        local localMove = camera.CFrame:VectorToObjectSpace(move)
        local direction = camera.CFrame.RightVector * localMove.X + camera.CFrame.LookVector * -localMove.Z
        flightVelocity.Velocity = direction.Magnitude > 0.01 and direction.Unit * State.FlySpeed or Vector3.zero
    end
end))
table.insert(app.Connections, Player.Idled:Connect(function()
    if State.AntiAFK and app.Alive then
        pcall(function()
            local virtualUser = game:GetService("VirtualUser")
            virtualUser:CaptureController()
            virtualUser:ClickButton2(Vector2.new())
        end)
    end
end))
local TabHome = Window:AddTab({ Name = "Home", Icon = "Lucide:layout-dashboard" })

local SubInfoPlayer = TabHome:AddSubTab({ Name = "Informasi Player", Icon = "Material:person" })
local SubInfoServer = TabHome:AddSubTab({ Name = "Informasi Server", Icon = "Lucide:server" })
local SubFiturList  = TabHome:AddSubTab({ Name = "Fitur List",        Icon = "Lucide:list-ordered" })
local SubUICommunity= TabHome:AddSubTab({ Name = "UI & Komunitas",    Icon = "Phosphor:chats-circle" })

-- SubTab: Informasi Player
SubInfoPlayer:AddCard({
    UserId      = LocalPlayer.UserId,
    Title       = LocalPlayer.DisplayName .. " (@" .. LocalPlayer.Name .. ")",
    Description = "Selamat datang di Nexzan Hub - Swing For Eggs!! Kirim ulasan atau masukan melalui form bintang di bawah.",
    Rating = {
        Title       = "Beri Nilai & Feedback Script",
        Placeholder = "Ketik saran atau masukan Anda di sini...",
        WebhookUrl  = CONFIG.FeedbackWebhook,
    },
})

SubInfoPlayer:AddSection("Profil & Device Lengkap", "Lucide:user-check")

SubInfoPlayer:AddInfoGrid({
    Title       = "Data Akun & Device",
    Description = "Spesifikasi akun pemain dan executor aktif",
    Color       = Purple,
    Columns     = 2,
    Items       = {
        { Label = "Username Asli",    Value = LocalPlayer.Name },
        { Label = "Display Name",     Value = LocalPlayer.DisplayName },
        { Label = "User ID",          Value = tostring(LocalPlayer.UserId) },
        { Label = "Umur Akun",        Value = tostring(LocalPlayer.AccountAge) .. " Hari" },
        { Label = "Akun Dibuat",      Value = GetAccountCreatedDate() },
        { Label = "Perangkat",        Value = GetDeviceType() },
        { Label = "Executor",         Value = GetExecutorName() },
        { Label = "Place ID",         Value = tostring(game.PlaceId) },
    },
})

SubInfoPlayer:AddDivider()
SubInfoPlayer:AddSection("Diagnostik Real-Time", "SF:waveform.path.ecg")

SubInfoPlayer:AddSystemInfoGrid({
    Title       = "Diagnostik & Real-Time Performance",
    Description = "Monitor langsung FPS, Ping, Region, dan waktu server",
    Color       = Purple,
})

-- SubTab: Informasi Server
SubInfoServer:AddSection("Detail Server Roblox", "Lucide:network")

local function GetServerUptime()
    local up = math.floor(Workspace.DistributedGameTime)
    local h = math.floor(up / 3600)
    local m = math.floor((up % 3600) / 60)
    local s = up % 60
    return string.format("%02d jam %02d mnt %02d dtk", h, m, s)
end

SubInfoServer:AddInfoGrid({
    Title       = "Server Status & Job Info",
    Description = "Informasi lengkap tentang server tempat Anda bermain",
    Color       = Purple,
    Columns     = 2,
    Items       = {
        { Label = "Job ID",          Value = (game.JobId ~= "" and string.sub(game.JobId, 1, 14) .. "..." or "Singleplayer") },
        { Label = "Place ID",        Value = tostring(game.PlaceId) },
        { Label = "Total Pemain",    Value = tostring(#Players:GetPlayers()) .. " / " .. tostring(Players.MaxPlayers) },
        { Label = "Server Uptime",   Value = GetServerUptime() },
        { Label = "Game Name",       Value = "Swing For Eggs!" },
        { Label = "Status Plot",     Value = UpdatePlotStatusText() },
    },
})

SubInfoServer:AddDivider()
SubInfoServer:AddSection("Aksi Server", "Lucide:refresh-cw")

SubInfoServer:AddButton({
    Text        = "Salin Job ID Server",
    Description = "Menyalin JobId server ke clipboard",
    Icon        = "Lucide:copy",
    Callback    = function()
        if setclipboard and game.JobId ~= "" then
            setclipboard(game.JobId)
            VindUI:Notify({ Title = "Disalin!", Text = "Job ID berhasil disalin ke clipboard", Type = "success", Duration = 3 })
        end
    end,
})

SubInfoServer:AddButton({
    Text        = "Rejoin Server Ini",
    Description = "Keluar lalu masuk kembali ke server yang sama",
    Icon        = "Lucide:rotate-cw",
    Callback    = function()
        if #Players:GetPlayers() <= 1 then
            LocalPlayer:Kick("\n[Nexzan Hub] Mereconnect ke server...")
            task.wait(0.5)
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        else
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end
    end,
})

-- SubTab: Fitur List
SubFiturList:AddSection("Daftar Fitur Nexzan Hub", "Lucide:sparkles")

SubFiturList:AddParagraph({
    Title = "Auto Farm Best Eggs", Icon = "Lucide:egg",
    Text = "Prioritaskan telur dengan penghasilan animal tertinggi yang dapat dibandingkan.",
})
SubFiturList:AddParagraph({
    Title = "Auto Hatch Egg", Icon = "Lucide:egg-fried",
    Text = "Tetaskan telur yang sudah siap di plot kamu.",
})
SubFiturList:AddParagraph({
    Title = "Theme Collection", Icon = "Lucide:palette",
    Text = "Purple, Blue, Red, Green, Default, Yellow, Orange, dan theme custom.",
})

SubFiturList:AddParagraph({Title="Otomatisasi & Trail",Icon="Lucide:sparkles",
    Text="Auto Claim Index, Auto Place Best, dan pembelian Trail pilihanmu."})

-- SubTab: UI & Komunitas
SubUICommunity:AddSection("Media Sosial & Komunitas Nexzan Hub", "Phosphor:chats-circle")

SubUICommunity:AddCard({
    Title       = "Discord Community Nexzan Hub",
    Description = "Gabung server Discord resmi untuk update script terbaru & info komunitas! Link: " .. CONFIG.CommunityUrl,
    Image       = "rbxassetid://139853376447596",
    ButtonText  = "Salin Link Discord Community",
    ButtonCallback = function()
        if setclipboard then
            setclipboard(CONFIG.CommunityUrl)
            VindUI:Notify({ Title = "Link Disalin!", Text = CONFIG.CommunityUrl, Type = "success", Duration = 4 })
        end
    end,
    Callback = function()
        if setclipboard then
            setclipboard(CONFIG.CommunityUrl)
            VindUI:Notify({ Title = "Link Disalin!", Text = CONFIG.CommunityUrl, Type = "success", Duration = 4 })
        end
    end,
})

SubUICommunity:AddCard({
    Title       = "YouTube Channel @Nexzan_hub",
    Description = "Subscribe channel YouTube resmi kami untuk tutorial dan showcase script! Link: " .. CONFIG.YoutubeUrl,
    Image       = "rbxassetid://90006502564793",
    ButtonText  = "Salin Link YouTube Channel",
    ButtonCallback = function()
        if setclipboard then
            setclipboard(CONFIG.YoutubeUrl)
            VindUI:Notify({ Title = "Link Disalin!", Text = CONFIG.YoutubeUrl, Type = "success", Duration = 4 })
        end
    end,
    Callback = function()
        if setclipboard then
            setclipboard(CONFIG.YoutubeUrl)
            VindUI:Notify({ Title = "Link Disalin!", Text = CONFIG.YoutubeUrl, Type = "success", Duration = 4 })
        end
    end,
})

SubUICommunity:AddDivider()
SubUICommunity:AddSection("Pengaturan Antarmuka", "SF:paintbrush")

SubUICommunity:AddToggle({
    Text        = "Background Blur",
    Description = "Aktifkan efek blur latar belakang saat UI terbuka",
    Icon        = "SF:camera.filters",
    Default     = true,
    Callback    = function(val)
        pcall(function() VindUI:SetBlurEnabled(val) end)
    end,
})

SubUICommunity:AddButton({
    Text        = "Reset Posisi Window",
    Description = "Mengembalikan posisi jendela UI ke tengah layar",
    Icon        = "Lucide:layout",
    Callback    = function()
        pcall(function()
            local mainFrame = Window._gui
            if mainFrame then mainFrame.Position = UDim2.fromScale(0.5, 0.5) end
        end)
    end,
})

SubUICommunity:AddButton({
    Text = "Unload Nexzan Hub", Description = "Hentikan fitur dan tutup UI.", Icon = "Lucide:power",
    Callback = function()
        UI:Confirm({Title = "Unload Nexzan Hub?", Text = "Semua fitur akan dihentikan.",
            Callback = function(confirmed) if confirmed then app.Stop() end end})
    end,
})

SubUICommunity:AddButton({Text="Buka Setting Theme", Icon="Lucide:palette",
    Callback=function() Window:SelectTab("Setting Theme") end})
SubUICommunity:AddParagraph({Title="Kontrol Window",Text="Right Shift untuk sembunyikan/tampilkan. Tombol minimize juga tersedia."})

Window:AddTabLine()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EggState = {AutoFarm = false, AutoHatch = false, AutoClaim = false, AutoEquip = false, AutoSell = false, Zone = "All", Delay = 0.35, ClaimDelay = 0.6, EquipDelay = 0.6, SellDelay = 0.6, Working = false}
local EggFarmStatus, EggHatchStatus, EggInfoStatus
local EggZones = {"All", "Zone1", "Zone2", "Zone3", "Zone4", "Zone5", "Zone6", "Zone7", "Zone8", "Zone9", "Zone10"}
local function eggSet(paragraph, text)
    if paragraph and paragraph.Set and app.Alive then pcall(function() paragraph:Set(text) end) end
end
local function eggAttr(object, name)
    if not object then return nil end
    local ok, value = pcall(function() return object:GetAttribute(name) end)
    return ok and value or nil
end
local function eggRoot()
    local character = Player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end
local function eggOwnPlot()
    return Workspace:FindFirstChild("Plot_" .. Player.Name)
end
local function eggPlotTarget(plot)
    if not plot then return nil end
    local area = plot:FindFirstChild("Spawn", true) or plot:FindFirstChild("HomeIconAnchor", true) or plot:FindFirstChild("EggHatch", true) or plot.PrimaryPart
    if area then
        local ok, position = pcall(function() return area.Position end)
        if ok and position then return Vector3.new(position.X, 0, position.Z) end
    end
    local ok, pivot = pcall(function() return plot:GetPivot() end)
    return ok and Vector3.new(pivot.Position.X, 0, pivot.Position.Z) or nil
end
local function eggTeleport(position)
    local root = eggRoot()
    if not root or typeof(position) ~= "Vector3" then return false end
    local ok = pcall(function() root.CFrame = CFrame.new(position + Vector3.new(0, 3, 0)) end)
    if ok then task.wait(0.30) end
    return ok
end
local function eggTweenTo(position, duration)
    local root = eggRoot()
    if not root or typeof(position) ~= "Vector3" or not app.Alive then return false end
    local tween = TweenService:Create(root, TweenInfo.new(duration or .5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {CFrame = CFrame.new(position)})
    table.insert(app.Tweens, tween)
    tween:Play()
    local ok = pcall(function() tween.Completed:Wait() end)
    return ok and app.Alive
end
local function eggApproach(position)
    if typeof(position) ~= "Vector3" then return false end
    local below = Vector3.new(position.X, position.Y - 7, position.Z)
    if not eggTweenTo(below, .55) then return false end
    task.wait(.08)
    -- Rise from below and stop over the egg's center before clicking.
    return eggTweenTo(position + Vector3.new(0, 1.5, 0), .20)
end
local function eggPrompt(model)
    if not model then return nil end
    for _, object in ipairs(model:GetDescendants()) do
        if object:IsA("ProximityPrompt") and tostring(object.ActionText):lower():find("collect", 1, true) then return object end
    end
end
local function eggZone(model)
    return model:GetFullName():match("Workspace%.Eggs%.(Zone%d+)") or eggAttr(model, "Zone") or "Unknown"
end
local function eggList()
    local list = {}
    local eggs = Workspace:FindFirstChild("Eggs")
    if not eggs then return list end
    for _, object in ipairs(eggs:GetDescendants()) do
        if object:IsA("Model") and eggAttr(object, "EggName") then
            local prompt = eggPrompt(object)
            if prompt then
                pcall(function() prompt.HoldDuration = 0; prompt.RequiresLineOfSight = false; prompt.MaxActivationDistance = math.max(prompt.MaxActivationDistance, 12) end)
                list[#list + 1] = {Model = object, Prompt = prompt, Zone = eggZone(object)}
            end
        end
    end
    return list
end
local function carriedEgg()
    local character = Player.Character
    local worldCharacter = Workspace:FindFirstChild(Player.Name)
    for _, object in ipairs({character, worldCharacter, Player}) do
        local value = eggAttr(object, "CarriedEgg_SpawnId") or eggAttr(object, "CarriedEggSpawnId") or eggAttr(object, "CarryingEgg")
        if value then return value end
    end
end
local function eggStillSpawned(model)
    local eggs = Workspace:FindFirstChild("Eggs")
    local still = false
    pcall(function() still = model:IsDescendantOf(eggs or Workspace) end)
    return still
end
local function collectEgg(item)
    local prompt = item and item.Prompt
    if not prompt then return false end
    local previousCarried = carriedEgg()
    for attempt = 1, 4 do
        if not app.Alive then return false end
        if eggStillSpawned(item.Model) == false then return true end
        local fired = false
        pcall(function() prompt.HoldDuration = 0; prompt.RequiresLineOfSight = false; prompt.Enabled = true end)
        local clicked = pcall(function()
            prompt:InputHoldBegin()
            task.wait(.05)
            prompt:InputHoldEnd()
        end)
        fired = clicked
        task.wait(.08)
        local currentCarried = carriedEgg()
        if eggStillSpawned(item.Model) == false or (currentCarried ~= nil and currentCarried ~= previousCarried) then return true end
        if type(fireproximityprompt) == "function" then
            local ok = pcall(function() fireproximityprompt(prompt) end)
            if not ok then ok = pcall(function() fireproximityprompt(prompt, 1, false) end) end
            fired = ok or fired
        end
        if not fired then return false end
        -- Confirm as soon as the selected model leaves the spawn; do not add a long post-click wait.
        for _ = 1, 24 do
            if eggStillSpawned(item.Model) == false then return true end
            local nowCarried = carriedEgg()
            if nowCarried ~= nil and nowCarried ~= previousCarried then return true end
            task.wait(.05)
        end
        if attempt < 4 then
            local ok, position = pcall(function() return prompt.Parent.Position end)
            if ok and position then eggApproach(position) end
            task.wait(.12)
        end
    end
    return false
end
local function chooseEgg()
    local selected = EggState.Zone:lower()
    local list = eggList()
    table.sort(list, function(a, b) return tostring(a.Zone) < tostring(b.Zone) end)
    for _, item in ipairs(list) do
        if selected == "all" or tostring(item.Zone):lower() == selected then return item end
    end
    eggSet(EggFarmStatus, "Belum ada egg di " .. EggState.Zone .. ".")
end
local function eggFarmCycle()
    local plot = eggOwnPlot()
    if not plot then eggSet(EggFarmStatus, "Plot_" .. Player.Name .. " belum ditemukan."); return end
    local item = chooseEgg()
    if not item then return end
    eggSet(EggFarmStatus, "Menuju " .. tostring(eggAttr(item.Model, "EggName")) .. " [" .. tostring(item.Zone) .. "]...")
    local ok, position = pcall(function() return item.Prompt.Parent.Position end)
    if not ok or not position or not eggApproach(position) then return end
    if not collectEgg(item) then eggSet(EggFarmStatus, "Egg gagal diambil; prompt atau server belum menerima collect."); return end
    if not eggTeleport(eggPlotTarget(plot)) then return end
    eggSet(EggFarmStatus, "Egg berhasil dibawa ke plot sendiri.")
    task.wait(.80)
end
local function eggHatchCycle()
    local plot = eggOwnPlot()
    if not plot then eggSet(EggHatchStatus, "Plot sendiri belum ditemukan."); return end
    local ready, activated = 0, 0
    for _, object in ipairs(plot:GetDescendants()) do
        local text = object:IsA("TextLabel") or object:IsA("TextButton")
        if text and tostring(object.Text):lower():find("ready", 1, true) then
            ready += 1
            local button = object:IsA("TextButton") and object or object:FindFirstAncestorWhichIsA("TextButton")
            if button then
                local ok = pcall(function() button:Activate() end)
                if ok then activated += 1 end
            end
        elseif object:IsA("ProximityPrompt") then
            local action = tostring(object.ActionText):lower()
            if action:find("hatch", 1, true) and not action:find("skip", 1, true) then
                if type(fireproximityprompt) == "function" then pcall(function() fireproximityprompt(object) end); activated += 1 end
            end
        end
    end
    eggSet(EggHatchStatus, "Aktif. Ready: " .. tostring(ready) .. " • Diproses: " .. tostring(activated))
end
local function callSwingRemote(name, method, ...)
    local events = ReplicatedStorage:FindFirstChild("Events")
    local remote = events and events:FindFirstChild(name)
    if not remote then return false end
    local args = table.pack(...)
    return pcall(function()
        if method == "InvokeServer" then return remote:InvokeServer(table.unpack(args, 1, args.n)) end
        remote:FireServer(table.unpack(args, 1, args.n))
    end)
end
local function suitOptions()
    local folder = ReplicatedStorage:FindFirstChild("SuitModels")
    local names = {}
    if folder then for _, object in ipairs(folder:GetChildren()) do names[#names + 1] = object.Name end end
    table.sort(names)
    if #names == 0 then names[1] = "Tidak tersedia" end
    return names
end

local TabMain = Window:AddTab({Name = "Main", Icon = "Lucide:zap"})
local FarmTab = TabMain:AddSubTab({Name = "Farm Eggs", Icon = "Lucide:egg"})
local HatchTab = TabMain:AddSubTab({Name = "Auto Hatch", Icon = "Lucide:egg-fried"})
local PlotTab = TabMain:AddSubTab({Name = "Plot Settings", Icon = "Lucide:home"})
local QuickTab = TabMain:AddSubTab({Name = "Quick Action", Icon = "Lucide:navigation"})
local ClaimTab = TabMain:AddSubTab({Name = "Auto Claim Index", Icon = "Lucide:gift"})
local SuitTab = TabMain:AddSubTab({Name = "Buy Suit", Icon = "Lucide:shirt"})
local PetTab = TabMain:AddSubTab({Name = "Auto Equip Best", Icon = "Lucide:paw-print"})
local SellTab = TabMain:AddSubTab({Name = "Auto Sell", Icon = "Lucide:shopping-bag"})

FarmTab:AddSection("Auto Farm Egg", "Lucide:sparkles")
FarmTab:AddParagraph({Title = "Alur Farm", Icon = "Lucide:route", Text = "Pilih zona → teleport ke egg → Collect Egg → kembali ke plot sendiri."})
FarmTab:AddDropdown({Text = "Pilih Zona Egg", Options = EggZones, Default = EggState.Zone, Callback = function(value)
    EggState.Zone = tostring(value or "All"); eggSet(EggInfoStatus, "Zona aktif: " .. EggState.Zone)
end})
FarmTab:AddSlider({Text = "Jeda Farm", Description = "Jeda aman antar collect.", Min = .2, Max = 3, Default = EggState.Delay, Increment = .1, Suffix = "s", Callback = function(value) EggState.Delay = value end})
FarmTab:AddToggle({Text = "Auto Farm Egg", Description = "Ambil salah satu egg dari zona yang dipilih.", Default = false, Icon = "Lucide:egg", Callback = function(value)
    EggState.AutoFarm = value; eggSet(EggFarmStatus, value and "Aktif. Menunggu egg di " .. EggState.Zone .. "." or "Nonaktif.")
end})
EggFarmStatus = FarmTab:AddParagraph({Title = "Status Farm", Text = "Nonaktif.", Icon = "Lucide:activity"})
EggInfoStatus = FarmTab:AddParagraph({Title = "Status Zona", Text = "Zona aktif: All", Icon = "Lucide:map"})

HatchTab:AddSection("Auto Hatch", "Lucide:egg-fried")
HatchTab:AddParagraph({Title = "Hatch Otomatis Map", Icon = "Lucide:info", Text = "Map melakukan hatch otomatis setelah egg ditempatkan. Toggle ini memantau proses di plot sendiri tanpa tombol Skip."})
HatchTab:AddToggle({Text = "Auto Hatch", Description = "Pantau egg yang sedang menunggu hatch otomatis.", Default = false, Icon = "Lucide:egg-fried", Callback = function(value)
    EggState.AutoHatch = value; eggSet(EggHatchStatus, value and "Aktif." or "Nonaktif.")
end})
EggHatchStatus = HatchTab:AddParagraph({Title = "Status Hatch", Text = "Nonaktif.", Icon = "Lucide:activity"})

ClaimTab:AddSection("Auto Claim Index", "Lucide:gift")
ClaimTab:AddToggle({Text = "Auto Claim Index", Description = "Aktifkan klaim otomatis.", Default = false, Icon = "Lucide:gift", Callback = function(value)
    EggState.AutoClaim = value
end})
ClaimTab:AddSlider({Text = "Jeda Claim", Min = .2, Max = 3, Default = EggState.ClaimDelay, Increment = .1, Suffix = "s", Callback = function(value) EggState.ClaimDelay = value end})

local availableSuits = suitOptions()
local selectedSuit = availableSuits[1]
SuitTab:AddSection("Buy Suit", "Lucide:shirt")
SuitTab:AddDropdown({Text = "Pilih Suit", Options = availableSuits, Default = selectedSuit, Callback = function(value) selectedSuit = tostring(value or availableSuits[1]) end})
SuitTab:AddButton({Text = "Buy Suit", Icon = "Lucide:shopping-cart", Callback = function()
    if selectedSuit == "Tidak tersedia" then notify("Suit belum tersedia."); return end
    local ok = callSwingRemote("SuitShopAction", "InvokeServer", "Buy", selectedSuit)
    notify(ok and "Permintaan buy suit dikirim." or "Buy suit gagal.")
end})

PetTab:AddSection("Auto Equip Best", "Lucide:paw-print")
PetTab:AddToggle({Text = "Auto Equip Best", Description = "Aktifkan equip best otomatis.", Default = false, Icon = "Lucide:paw-print", Callback = function(value) EggState.AutoEquip = value end})
PetTab:AddSlider({Text = "Jeda Equip", Min = .2, Max = 3, Default = EggState.EquipDelay, Increment = .1, Suffix = "s", Callback = function(value) EggState.EquipDelay = value end})

SellTab:AddSection("Auto Sell Inventory", "Lucide:shopping-bag")
SellTab:AddToggle({Text = "Auto Sell Inventory", Description = "Aktifkan penjualan inventory otomatis.", Default = false, Icon = "Lucide:shopping-bag", Callback = function(value) EggState.AutoSell = value end})
SellTab:AddSlider({Text = "Jeda Sell", Min = .2, Max = 3, Default = EggState.SellDelay, Increment = .1, Suffix = "s", Callback = function(value) EggState.SellDelay = value end})

PlotTab:AddSection("Plot Sendiri", "Lucide:home")
local plotStatus = PlotTab:AddParagraph({Title = "Status Plot", Text = "Plot_" .. Player.Name})
PlotTab:AddButton({Text = "Deteksi Ulang Plot", Icon = "Lucide:refresh-cw", Callback = function()
    eggSet(plotStatus, eggOwnPlot() and "Plot_" .. Player.Name .. " terdeteksi." or "Plot belum ditemukan.")
end})
QuickTab:AddSection("Aksi Cepat", "Lucide:navigation")
QuickTab:AddButton({Text = "Teleport ke Plot Sendiri", Icon = "Lucide:home", Callback = function()
    local plot = eggOwnPlot(); if plot then eggTeleport(eggPlotTarget(plot)) else notify("Plot sendiri belum ditemukan.") end
end})
QuickTab:AddButton({Text = "Hentikan Farm", Icon = "Lucide:power", Callback = function()
    EggState.AutoFarm = false; eggSet(EggFarmStatus, "Nonaktif.")
end})

task.spawn(function()
    while app.Alive do
        if EggState.AutoClaim then callSwingRemote("IndexRewardAction", "InvokeServer", "ClaimAll"); task.wait(EggState.ClaimDelay)
        else task.wait(.25) end
    end
end)
task.spawn(function()
    while app.Alive do
        if EggState.AutoEquip then callSwingRemote("EquipBestPets", "FireServer"); task.wait(EggState.EquipDelay)
        else task.wait(.25) end
    end
end)
task.spawn(function()
    while app.Alive do
        if EggState.AutoSell then callSwingRemote("RequestSell", "FireServer", "Inventory"); task.wait(EggState.SellDelay)
        else task.wait(.25) end
    end
end)

task.spawn(function()
    while app.Alive do
        if EggState.AutoFarm and not EggState.Working then
            EggState.Working = true; pcall(eggFarmCycle); EggState.Working = false; task.wait(EggState.Delay)
        else task.wait(.25) end
    end
end)
task.spawn(function()
    while app.Alive do
        if EggState.AutoHatch then pcall(eggHatchCycle) end
        task.wait(1.5)
    end
end)

local TabPlayer = Window:AddTab({ Name = "Player Setting", Icon = "Lucide:user-cog" })

local SubPlayerSet = TabPlayer:AddSubTab({ Name = "Player Setting", Icon = "Lucide:sliders" })

SubPlayerSet:AddSection("Kecepatan & Lompatan Karakter", "Lucide:user-check")

SubPlayerSet:AddSlider({
    Text        = "WalkSpeed (Slider)",
    Description = "Atur kecepatan jalan karakter",
    Icon        = "Lucide:fast-forward",
    Min         = 16,
    Max         = 250,
    Default     = 16,
    Increment   = 2,
    Callback    = function(val)
        State.WalkSpeed = val
        if Humanoid then Humanoid.WalkSpeed = val end
    end,
})

SubPlayerSet:AddTextbox({
    Text        = "WalkSpeed (Input Textbox)",
    Description = "Ketik angka kecepatan jalan custom",
    Icon        = "Lucide:gauge",
    Placeholder = "16",
    Default     = "16",
    Callback    = function(text)
        local val = tonumber(text)
        if val and val > 0 then
            State.WalkSpeed = val
            if Humanoid then Humanoid.WalkSpeed = val end
            VindUI:Notify({ Title = "Speed", Text = "WalkSpeed diatur ke: " .. val, Type = "info", Duration = 2 })
        end
    end,
})

SubPlayerSet:AddSlider({
    Text        = "JumpPower (Slider)",
    Description = "Atur tinggi lompatan karakter",
    Icon        = "Lucide:arrow-up",
    Min         = 50,
    Max         = 350,
    Default     = 50,
    Increment   = 5,
    Callback    = function(val)
        State.JumpPower = val
        if Humanoid then Humanoid.JumpPower = val end
    end,
})

SubPlayerSet:AddTextbox({
    Text        = "JumpPower (Input Textbox)",
    Description = "Ketik angka tinggi lompatan custom",
    Icon        = "Lucide:arrow-up-circle",
    Placeholder = "50",
    Default     = "50",
    Callback    = function(text)
        local val = tonumber(text)
        if val and val > 0 then
            State.JumpPower = val
            if Humanoid then Humanoid.JumpPower = val end
            VindUI:Notify({ Title = "Jump", Text = "JumpPower diatur ke: " .. val, Type = "info", Duration = 2 })
        end
    end,
})

SubPlayerSet:AddDivider()
SubPlayerSet:AddSection("Fly (Analog / Mobile & PC)", "Lucide:plane")

SubPlayerSet:AddToggle({
    Text        = "Fly (Analog / Free Flight)",
    Description = "Terbang bebas mengikuti arah analog / joystick HP atau kamera PC",
    Icon        = "Lucide:plane",
    Default     = false,
    Callback    = function(val)
        State.Fly = val
        if val then
            StartFly()
            VindUI:Notify({ Title = "Fly Aktif", Text = "Gunakan analog atau WASD untuk terbang!", Type = "success", Duration = 3 })
        else
            StopFly()
            VindUI:Notify({ Title = "Fly Nonaktif", Text = "Mode terbang dimatikan.", Type = "info", Duration = 2 })
        end
    end,
})

SubPlayerSet:AddSlider({
    Text        = "Kecepatan Fly (Slider)",
    Description = "Atur kecepatan terbang karakter",
    Icon        = "Lucide:gauge",
    Min         = 10,
    Max         = 250,
    Default     = 50,
    Increment   = 5,
    Callback    = function(val)
        State.FlySpeed = val
    end,
})

SubPlayerSet:AddTextbox({
    Text        = "Kecepatan Fly (Input Textbox)",
    Description = "Ketik angka kecepatan terbang custom",
    Icon        = "Lucide:timer",
    Placeholder = "50",
    Default     = "50",
    Callback    = function(text)
        local val = tonumber(text)
        if val and val > 0 then
            State.FlySpeed = val
            VindUI:Notify({ Title = "Fly Speed", Text = "Kecepatan terbang: " .. val, Type = "info", Duration = 2 })
        end
    end,
})

SubPlayerSet:AddDivider()
SubPlayerSet:AddSection("Fitur Cheats Fisik", "Lucide:shield-check")

SubPlayerSet:AddToggle({
    Text        = "NoClip (Tembus Tembok)",
    Description = "Menonaktifkan tabrakan rintangan & pagar",
    Icon        = "Lucide:shield-off",
    Default     = false,
    Callback    = function(val)
        State.NoClip = val
    end,
})

SubPlayerSet:AddToggle({
    Text        = "Infinite Jump",
    Description = "Lompat berkali-kali di udara tanpa batas",
    Icon        = "Lucide:chevrons-up",
    Default     = false,
    Callback    = function(val)
        State.InfiniteJump = val
    end,
})

SubPlayerSet:AddToggle({
    Text        = "Anti-AFK",
    Description = "Mencegah kick idle 20 menit dari server Roblox",
    Icon        = "Lucide:shield-alert",
    Default     = true,
    Callback    = function(val)
        State.AntiAFK = val
    end,
})

SubPlayerSet:AddButton({
    Text        = "Reset Karakter",
    Description = "Reset avatar secara manual jika stuck",
    Icon        = "Lucide:rotate-ccw",
    Callback    = function()
        if Humanoid then Humanoid.Health = 0 end
    end,
})

-- --------------------------------------------------------------------
-- 4. TAB SETTING AI (DENGAN SUBTABS & CUSTOM API KEY)
-- --------------------------------------------------------------------
do
    local TabTheme = Window:AddTab({Name="Setting Theme", Icon="Lucide:palette"})
    local SubThemePresets = TabTheme:AddSubTab({Name="Pilihan Theme", Icon="Lucide:swatch-book"})
    local SubThemeCustom = TabTheme:AddSubTab({Name="Buat Theme", Icon="Lucide:paintbrush"})
    SubThemePresets:AddSection("Theme Collection", "Lucide:palette")
    Themes.Dropdown = SubThemePresets:AddDropdown({Text="Pilih Theme", Options=Themes.Options(), Default=Themes.Selected,
        Callback=function(value) Themes.Select(value) end})
    Themes.Status = SubThemePresets:AddParagraph({Title="Theme Aktif", Text="Theme aktif: " .. Themes.Selected})
    SubThemePresets:AddToggle({Text="Animasi Warna", Default=State.Animated,
        Callback=function(value) State.Animated=value end})
    SubThemePresets:AddSlider({Text="Durasi Animasi", Min=0.5, Max=6, Default=State.ColorPeriod, Increment=0.1, Suffix="s",
        Callback=function(value) State.ColorPeriod=value end})
    SubThemePresets:AddToggle({Text="Tampilkan Background", Default=true,
        Callback=function(value) background.Visible=value end})
    SubThemePresets:AddSlider({Text="Kecerahan Background", Min=10, Max=100, Default=60, Increment=1, Suffix="%",
        Callback=function(value) shade.BackgroundTransparency=0.10+value/100*0.50 end})
    SubThemePresets:AddButton({Text="Kembali ke Default", Icon="Lucide:rotate-ccw", Callback=function()
        Themes.Select("Default"); Themes.Dropdown:Set("Default",true)
    end})
    SubThemePresets:AddButton({Text="Hapus Theme Custom Terpilih", Icon="Lucide:trash-2", Callback=function()
        if not Themes.Selected:match("^Custom: ") then notify("Pilih theme custom terlebih dahulu."); return end
        local selected=Themes.Selected
        UI:Confirm({Title="Hapus Theme Custom?", Text=selected, Danger=true,
            Callback=function(yes) if yes and app.Alive and Themes.Selected==selected then Themes.DeleteSelected() end end})
    end})

    SubThemeCustom:AddSection("Buat Theme Sendiri", "Lucide:paintbrush")
    SubThemeCustom:AddTextbox({Text="Nama Theme", Default=Themes.DraftName, Placeholder="Theme Saya",
        Callback=function(value) Themes.DraftName=value end})
    local pickers={}
    for _, definition in ipairs({{"Accent","Warna Utama"},{"Glow","Warna Highlight"},
        {"Background","Warna Latar"},{"Surface","Warna Panel"},{"Text","Warna Teks"},
        {"TextDim","Warna Deskripsi"},{"Danger","Warna Peringatan"}}) do
        local key,label=definition[1],definition[2]
        pickers[key]=SubThemeCustom:AddColorPicker({Text=label, Default=Themes.Draft[key],
            Callback=function(color) Themes.Draft[key]=color end})
    end
    SubThemeCustom:AddButton({Text="Salin Warna Theme Aktif", Icon="Lucide:copy", Callback=function()
        local palette=Themes.Get(Themes.Selected)
        if not palette then notify("Simpan preview terlebih dahulu, atau pilih theme dari daftar."); return end
        Themes.Draft=Themes.Copy(palette)
        for key,picker in pairs(pickers) do picker:Set(Themes.Draft[key],true) end
        notify("Warna theme aktif disalin ke editor.")
    end})
    SubThemeCustom:AddButton({Text="Pratinjau Theme", Icon="Lucide:eye", Callback=function()
        Themes.Apply(Themes.Draft,"Preview Custom")
    end})
    SubThemeCustom:AddButton({Text="Simpan & Gunakan Theme", Icon="Lucide:save", Callback=function() Themes.SaveCustom() end})
    SubThemeCustom:AddParagraph({Title="Theme Kamu", Text="Theme custom masuk ke dropdown Pilih Theme. Penyimpanan antar-sesi tersedia jika executor mendukung baca/tulis file. Tata letak window tidak berubah."})
end

local TabAI = Window:AddTab({ Name = "Setting AI", Icon = "bot" })

local SubAISettings    = TabAI:AddSubTab({ Name = "Konfigurasi AI",            Icon = "Lucide:key" })
local SubAIGeminiGuide = TabAI:AddSubTab({ Name = "Dapatkan Gemini API Gratis", Icon = "Lucide:sparkles" })
local SubAIChat        = TabAI:AddSubTab({ Name = "Panduan & Status",          Icon = "Lucide:help-circle" })

local ActiveAssistant = nil
local AIChatPanel = nil

local function InitAssistant(apiKey, endpoint, model)
    if not apiKey or apiKey == "" then return false end
    pcall(function()
        ActiveAssistant = VindUI:CreateAIAssistant({
            Providers = {{
                Name     = State.AIProvider,
                Endpoint = endpoint,
                ApiKey   = apiKey,
                Model    = model,
            }},
            Window = Window,
            Tools  = GetCleanChatTools(),
            SystemPrompt = "You are Nexzan AI Assistant, an expert gaming AI for 'Swing For Eggs!' on Roblox. Help the player understand egg rarities, game features and navigating this UI. Do not explain script internals or invent game data. Always respond helpfully in Indonesian.",
            Persist = "nexzan-roller-ai",
        })
    end)
    return ActiveAssistant ~= nil
end

SubAISettings:AddSection("Input API Key AI Anda", "Lucide:key")

SubAISettings:AddParagraph({
    Title = "Gunakan API Key Milik Anda Sendiri",
    Icon  = "Lucide:shield",
    Text  = "Masukkan API Key dari Google Gemini Anda di bawah ini untuk menggunakan AI sesuai kuota provider Anda.",
})

SubAISettings:AddTextbox({
    Text        = "API Key AI Anda",
    Description = "Tempel (paste) API Key Anda di sini",
    Icon        = "Lucide:lock",
    Placeholder = "Tempel API Key di sini...",
    Default     = "",
    Callback    = function(text)
        State.AIApiKey = text:gsub(" ", "")
    end,
})

SubAISettings:AddDropdown({
    Text        = "Pilih Provider AI",
    Description = "Pilih provider yang cocok dengan API Key Anda",
    Icon        = "Lucide:cpu",
    Options     = { "Google Gemini", "OpenRouter" },
    Default     = "Google Gemini",
    Callback    = function(val)
        if val == "OpenRouter" then
            State.AIProvider = "OpenRouter"
            State.AIModel = "openrouter/free"
        else
            State.AIProvider = "Google Gemini"
            State.AIModel = "gemini-2.5-flash"
        end
    end,
})

SubAISettings:AddDropdown({
    Text        = "Pilih Model Gemini",
    Description = "Pilih versi model Gemini yang aktif pada akun Google AI Studio Anda",
    Icon        = "Lucide:sparkles",
    Options     = { "gemini-2.5-flash", "gemini-2.0-flash", "gemini-1.5-flash", "gemini-1.5-pro" },
    Default     = "gemini-2.5-flash",
    Callback    = function(val)
        State.AIModel = val
    end,
})

SubAISettings:AddTextbox({
    Text        = "Model AI (Custom Model ID)",
    Description = "Ketik model kustom manual jika ingin menggunakan model lain",
    Icon        = "Lucide:bot",
    Placeholder = "gemini-2.5-flash",
    Default     = "gemini-2.5-flash",
    Callback    = function(text)
        if text and text ~= "" then State.AIModel = text:gsub(" ", "") end
    end,
})

SubAISettings:AddButton({
    Text        = "Simpan & Hubungkan AI Sekarang",
    Description = "Mengaktifkan panel chat AI dengan API Key yang Anda masukkan",
    Icon        = "Lucide:check-check",
    Callback    = function()
        if not State.AIApiKey or State.AIApiKey == "" then
            VindUI:Notify({
                Title = "API Key Kosong",
                Text  = "Silakan masukkan API Key Anda pada kotak di atas terlebih dahulu!",
                Type  = "warning",
                Duration = 4,
            })
            return
        end
        
        local endpoint = "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
        if State.AIProvider == "OpenRouter" then
            endpoint = "https://openrouter.ai/api/v1/chat/completions"
        end
        
        local ok = InitAssistant(State.AIApiKey, endpoint, State.AIModel)
        if ok then
            VindUI:Notify({
                Title = "AI Terhubung!",
                Text  = "AI Assistant berhasil diinisialisasi dengan API Key Anda. Buka panel chat melalui tombol bot di dock!",
                Type  = "success",
                Duration = 5,
            })
        else
            VindUI:Notify({
                Title = "Gagal Menghubungkan",
                Text  = "Pastikan API Key Anda valid dan koneksi internet stabil.",
                Type  = "error",
                Duration = 4,
            })
        end
    end,
})

-- SubTab: Cara Mendapatkan API Key Gemini Gratis
SubAIGeminiGuide:AddSection("Panduan Resmi Dapatkan API Key Gemini Gratis", "Lucide:sparkles")

SubAIGeminiGuide:AddParagraph({
    Title = "API Key Google AI Studio",
    Icon  = "Lucide:shield-check",
    Text  = "Ketersediaan, kuota gratis, dan biaya mengikuti ketentuan Google AI Studio.",
})

SubAIGeminiGuide:AddParagraph({
    Title = "Langkah 1: Kunjungi Google AI Studio",
    Icon  = "Lucide:globe",
    Text  = "Buka Google Chrome atau browser di HP / PC Anda, lalu buka tautan https://aistudio.google.com",
})

SubAIGeminiGuide:AddButton({
    Text        = "Salin Link Google AI Studio",
    Description = "Salin alamat https://aistudio.google.com ke clipboard",
    Icon        = "Lucide:copy",
    Callback    = function()
        if setclipboard then
            setclipboard("https://aistudio.google.com")
            VindUI:Notify({ Title = "Link Disalin!", Text = "https://aistudio.google.com", Type = "success", Duration = 3 })
        end
    end,
})

SubAIGeminiGuide:AddParagraph({
    Title = "Langkah 2: Login Akun Google Anda",
    Icon  = "Lucide:user",
    Text  = "Masuk menggunakan akun Gmail Anda seperti biasa dan setujui Terms of Service.",
})

SubAIGeminiGuide:AddParagraph({
    Title = "Langkah 3: Klik 'Get API key' & Buat Kunci",
    Icon  = "Lucide:key-round",
    Text  = "1. Pada menu navigasi sebelah kiri / atas, klik tombol 'Get API key' atau 'Create API key'.\n"
         .. "2. Pilih 'Create API key in new project' (atau gunakan project yang sudah ada).\n"
         .. "3. Kunci API Anda akan muncul (kode panjang berawalan 'AIzaSy...'). Klik tombol Copy.",
})

SubAIGeminiGuide:AddParagraph({
    Title = "Langkah 4: Tempelkan ke Nexzan Hub",
    Icon  = "Lucide:check-circle-2",
    Text  = "Kembali ke script Nexzan Hub ini, buka SubTab 'Konfigurasi AI', tempelkan API Key tersebut di kotak 'API Key AI Anda', lalu klik tombol 'Simpan & Hubungkan AI Sekarang'.",
})

SubAIGeminiGuide:AddButton({
    Text        = "Pergi ke SubTab Konfigurasi AI",
    Description = "Langsung buka SubTab Konfigurasi AI untuk menempelkan kunci",
    Icon        = "Lucide:arrow-right",
    Callback    = function()
        pcall(function()
            TabAI:SelectSubTabByName("Konfigurasi AI")
        end)
    end,
})

SubAIGeminiGuide:AddDivider()

SubAIChat:AddSection("Status AI Assistant", "Lucide:info")

SubAIChat:AddParagraph({
    Title = "Tips Berinteraksi dengan AI",
    Icon  = "Lucide:sparkles",
    Text  = "• Tanyakan lokasi sarang telur langka (Prehistoric, Celestial, Secret).\n"
         .. "• Minta saran hewan mana yang menghasilkan income tertinggi di pen Anda.\n"
         .. "• AI Assistant dapat membantu navigasi UI panel dengan perintah teks langsung.",
})

-- Chat Panel Setup
local ChatDockButton
AIChatPanel = Window:AddChatPanel({
    Title = "Nexzan AI Assistant",
    Icon = "bot",
    Tools = GetCleanChatTools(),
    Placeholder = "Tanya AI seputar tips game Swing For Eggs!...",
    OnToggle = function(open)
        if ChatDockButton then ChatDockButton:SetActive(open) end
    end,
    OnClear = function()
        if ActiveAssistant then ActiveAssistant:Reset() end
    end,
    OnSend = function(panel, text)
        if not ActiveAssistant or State.AIApiKey == "" then
            panel:AddMessage("assistant", "⚠️ API Key belum dimasukkan! Silakan buka tab 'Setting AI' lalu masukkan API Key Anda dan klik 'Simpan & Hubungkan AI Sekarang'.")
            return
        end
        ActiveAssistant:Ask(panel, text)
    end,
    OnStop = function()
        if ActiveAssistant then ActiveAssistant:Stop() end
    end,
    OnRegenerate = function(panel, text)
        if ActiveAssistant and State.AIApiKey ~= "" then
            ActiveAssistant:Ask(panel, text)
        end
    end,
})

ChatDockButton = Window:AddDockButton({
    Title = "AI Chat",
    Icon = "bot",
    Callback = function() AIChatPanel:Toggle() end,
})

-- --------------------------------------------------------------------

local TabAdmin = Window:AddPrivateTab({Name = "Admin", Icon = "Lucide:shield-alert", Password = "938172"})
local SubAdminBroadcast = TabAdmin:AddSubTab({Name = "Broadcast Notifikasi", Icon = "Lucide:megaphone"})
local SubAdminTools = TabAdmin:AddSubTab({Name = "Admin & Server Tools", Icon = "Lucide:wrench"})
SubAdminBroadcast:AddSection("Preview Notifikasi", "Lucide:megaphone")
SubAdminBroadcast:AddParagraph({Title = "Notifikasi Lokal", Text = "Preview ini hanya tampil di layar kamu."})
local previewTitle, previewText = "NEXZAN HUB", "Selamat datang di Purple Edition."
SubAdminBroadcast:AddTextbox({Text = "Judul Notifikasi", Default = previewTitle,
    Callback = function(value) previewTitle = value end})
SubAdminBroadcast:AddTextbox({Text = "Isi Pesan Notifikasi", Default = previewText,
    Callback = function(value) previewText = value end})
SubAdminBroadcast:AddButton({Text = "Preview Notifikasi", Icon = "Lucide:eye", Callback = function()
    UI:Notify({Title = previewTitle, Text = previewText, Type = "info", Duration = 5})
end})
SubAdminTools:AddSection("UI & Server Tools", "Lucide:shield-check")
SubAdminTools:AddButton({Text = "Salin Job ID Server", Icon = "Lucide:copy", Callback = function()
    if setclipboard then setclipboard(game.JobId); notify("Job ID disalin.") end
end})
SubAdminTools:AddButton({Text = "Hentikan Semua Fitur", Icon = "Lucide:power", Callback = function() app.Stop() end})

for _, instance in ipairs(main:GetDescendants()) do style(instance) end
table.insert(app.Connections, main.DescendantAdded:Connect(function(instance)
    task.defer(function() style(instance) end)
end))
table.insert(app.Connections, main.Destroying:Connect(function() app.Stop() end))

-- A single scheduler serializes movement between farming and hatching.
task.spawn(function()
    local nextFarm, nextHatch = 0, 0
    while app.Alive do
        if root() then
            local success, message = pcall(function()
                if pendingReturn then
                    if home() then pendingReturn = false end
                    return
                end
                if State.Hatch and os.clock() >= nextHatch then
                    hatchOne()
                    nextHatch = os.clock() + State.HatchDelay
                end
                if State.Farm and app.Alive and os.clock() >= nextFarm then
                    farmOne()
                    nextFarm = os.clock() + State.Delay
                end
            end)
            if not success then
                warn("Nexzan Roller: " .. tostring(message))
                if State.Farm then farmStatus("Menunggu map siap...") end
                if State.Hatch then hatchStatus("Menunggu plot siap...") end
                task.wait(1)
            end
        else
            if State.Farm then farmStatus("Menunggu karakter...") end
            if State.Hatch then hatchStatus("Menunggu karakter...") end
        end
        task.wait(0.2)
    end
end)
Themes.Apply(Themes.Get(Themes.Selected), Themes.Selected)
Window:SelectTab("Home")
Window:Open()
notify("Nexzan Hub siap. Fitur berada di Main; pilihan warna tersedia di Setting Theme.")

end

local Players=game:GetService('Players')
local UIS=game:GetService('UserInputService')
local Http=game:GetService('HttpService')
local Player=Players.LocalPlayer
if not Player then warn('Nexzan: pemain belum siap.');return end
local ENV=(getgenv and getgenv()) or _G
if ENV.NexzanKeyUI and ENV.NexzanKeyUI.Destroy then pcall(ENV.NexzanKeyUI.Destroy) end
if ENV.NexzanRollerPurple and ENV.NexzanRollerPurple.Stop then pcall(ENV.NexzanRollerPurple.Stop) end
if ENV.NexzanLocalExample and ENV.NexzanLocalExample.Stop then pcall(ENV.NexzanLocalExample.Stop) end
ENV.NexzanLocalExample=nil
ENV.NexzanRollerPurple=nil
ENV.NexzanLocalKeyLocks=ENV.NexzanLocalKeyLocks or {}
local clipboardFn=setclipboard or toclipboard
local alive,busy,launched=true,false,false
local connections={}
local currentSession,shownRecord
local DISCORD='https://discord.gg/yyWdWas8mx'
local function clean(value,limit)
    return tostring(value or ''):gsub('[%c]',' '):sub(1,limit or 160)
end
local hwid
for _,getter in pairs({gethwid,get_hwid,syn and syn.gethwid,ENV.gethwid}) do
    if type(getter)=='function' then
        local ok,value=pcall(getter)
        if ok and type(value)=='string' then
            value=value:match('^%s*(.-)%s*$')
            local lower=value:lower()
            if #value>=8 and #value<=512 and not value:find('[%c]') and lower~='unsupported' and lower~='undefined' and lower~='not supported' and lower~='00000000' and lower~='00000000-0000-0000-0000-000000000000' then hwid=value;break end
        end
    end
end
local executorName='Tidak tersedia'
for _,getter in pairs({identifyexecutor,getexecutorname,ENV.identifyexecutor,ENV.getexecutorname}) do
    if type(getter)=='function' then
        local ok,name,version=pcall(getter)
        if ok and type(name)=='string' and name~='' then
            executorName=clean(name,90)
            if (type(version)=='string' or type(version)=='number') and tostring(version)~='' then executorName=executorName..' '..clean(version,30) end
            break
        end
    end
end
local function deviceName()
    local ok,platform=pcall(function() return UIS:GetPlatform() end)
    if ok and platform then
        local name=tostring(platform):gsub('^Enum.Platform%.','')
        local names={Windows='Windows',OSX='macOS',IOS='iOS',Android='Android',UWP='Windows UWP',XBoxOne='Xbox',PS4='PlayStation',PS5='PlayStation',MetaOS='Meta Quest',Linux='Linux'}
        if names[name] then return names[name] end
    end
    if UIS.TouchEnabled and UIS.KeyboardEnabled then return 'Touch + keyboard' end
    if UIS.TouchEnabled then return 'Layar sentuh' end
    if UIS.KeyboardEnabled and UIS.MouseEnabled then return 'Keyboard + mouse' end
    if UIS.GamepadEnabled then return 'Gamepad' end
    return 'Tidak tersedia'
end
local deviceHash=hwid and sha256(hwid:lower()) or nil
local store=createLocalStore({hash=deviceHash,read=readfile,write=writefile,exists=isfile,locks=ENV.NexzanLocalKeyLocks,
    now=os.time,guid=function() return Http:GenerateGUID(false) end,
    encode=function(row) return Http:JSONEncode(row) end,decode=function(raw) return Http:JSONDecode(raw) end})
local gui=Instance.new('ScreenGui');gui.Name='NexzanKeySystem';gui.ResetOnSpawn=false;gui.IgnoreGuiInset=true;gui.DisplayOrder=10000;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
local parented=false
if gethui then parented=pcall(function() gui.Parent=gethui() end) and gui.Parent~=nil end
if not parented then parented=pcall(function() gui.Parent=game:GetService('CoreGui') end) and gui.Parent~=nil end
if not parented then gui.Parent=Player:WaitForChild('PlayerGui') end
local function connect(signal,fn) local c=signal:Connect(fn);table.insert(connections,c);return c end
local controller={}
function controller.Destroy()
    if not alive then return end
    alive=false
    if currentSession then currentSession.Alive=false end
    if ENV.NexzanDeviceSession==currentSession then ENV.NexzanDeviceSession=nil end
    if ENV.NexzanRollerPurple and ENV.NexzanRollerPurple.Stop then pcall(ENV.NexzanRollerPurple.Stop) end
    for _,c in ipairs(connections) do c:Disconnect() end
    table.clear(connections);gui:Destroy()
    if ENV.NexzanKeyUI==controller then ENV.NexzanKeyUI=nil end
end
ENV.NexzanKeyUI=controller
local C={text=Color3.fromRGB(246,240,255),dim=Color3.fromRGB(163,145,184),accent=Color3.fromRGB(168,111,245),border=Color3.fromRGB(105,72,148),green=Color3.fromRGB(137,225,184),red=Color3.fromRGB(244,151,174)}
local function create(class,parent,props)
    local obj=Instance.new(class);for k,v in pairs(props or {}) do obj[k]=v end;obj.Parent=parent;return obj
end
local function round(obj,n) create('UICorner',obj,{CornerRadius=UDim.new(0,n)}) end
local function border(obj,alpha) return create('UIStroke',obj,{Color=C.border,Thickness=1,Transparency=alpha or .3,ApplyStrokeMode=Enum.ApplyStrokeMode.Border}) end
local function text(parent,name,value,x,y,w,h,size,color,bold)
    return create('TextLabel',parent,{Name=name,Text=value,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundTransparency=1,Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,TextSize=size or 12,TextColor3=color or C.text,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center})
end
local function image(parent,name,id,x,y,w,h,color)
    return create('ImageLabel',parent,{Name=name,Image=id,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundTransparency=1,ImageColor3=color or C.text,ScaleType=Enum.ScaleType.Fit})
end
local function button(parent,name,value,x,y,w,h,primary)
    local b=create('TextButton',parent,{Name=name,Text=value,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundColor3=primary and C.accent or Color3.fromRGB(43,29,60),BorderSizePixel=0,Font=Enum.Font.GothamMedium,TextSize=12,TextColor3=C.text,AutoButtonColor=true})
    round(b,9)
    if primary then create('UIGradient',b,{Rotation=20,Color=ColorSequence.new(Color3.fromRGB(185,140,255),Color3.fromRGB(135,77,219))}) else border(b,.45) end
    return b
end
local host=create('ScrollingFrame',gui,{Name='PanelViewport',BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromOffset(420,448),Position=UDim2.fromOffset(0,0),CanvasSize=UDim2.fromOffset(420,448),ScrollBarThickness=3,ScrollBarImageColor3=C.accent,ScrollingDirection=Enum.ScrollingDirection.X,ScrollingEnabled=false,ClipsDescendants=true,Active=true})
local content=create('Frame',host,{Name='Panels',BackgroundTransparency=1,Size=UDim2.fromOffset(420,448),Position=UDim2.fromOffset(0,0)})
local scale=create('UIScale',content,{Scale=1})
local function card(name,w,h)
    local frame=create('Frame',content,{Name=name,Size=UDim2.fromOffset(w,h),BackgroundColor3=Color3.fromRGB(25,16,37),BorderSizePixel=0,Active=true})
    round(frame,15);border(frame,.2);create('UIGradient',frame,{Rotation=125,Color=ColorSequence.new(Color3.fromRGB(31,21,45),Color3.fromRGB(17,12,27))});return frame
end
local main=card('KeyCard',420,334)
local profile=card('ProfilePanel',294,448);profile.Visible=false
local generator=card('GeneratorPanel',294,448);generator.Visible=false
local function closeButton(parent,name,width)
    local b=button(parent,name,'',width-44,13,30,30,false)
    image(b,'CloseIcon','rbxassetid://73070135088117',7,7,16,16,C.dim);return b
end
local mainClose=closeButton(main,'Close',420)
local profileClose=closeButton(profile,'CloseProfile',294)
local generatorClose=closeButton(generator,'CloseGenerator',294)
local header=create('Frame',main,{Name='Header',Size=UDim2.fromOffset(362,76),BackgroundTransparency=1,Active=true})
local badge=create('Frame',header,{Position=UDim2.fromOffset(22,22),Size=UDim2.fromOffset(36,36),BackgroundColor3=Color3.fromRGB(55,34,81),BorderSizePixel=0});round(badge,11);border(badge,.55)
local lockIcon=image(badge,'LockIcon','rbxassetid://82932539629673',8,8,20,20,Color3.fromRGB(211,180,255))
text(header,'Title','Nexzan Key System',68,20,285,25,20,C.text,true)
text(header,'Subtitle','Klik Get Key For Key',68,47,285,16,12,C.dim)
text(main,'KeyLabel','ACCESS KEY',22,89,370,15,10,C.dim,true)
local inputFrame=create('Frame',main,{Name='InputFrame',Position=UDim2.fromOffset(22,111),Size=UDim2.fromOffset(376,46),BackgroundColor3=Color3.fromRGB(14,10,22),BorderSizePixel=0});round(inputFrame,10);local inputBorder=border(inputFrame,.45)
local keyBox=create('TextBox',inputFrame,{Name='Key',Position=UDim2.fromOffset(12,0),Size=UDim2.fromOffset(352,46),BackgroundTransparency=1,Text='',PlaceholderText='Masukkan key NEXZAN-...',PlaceholderColor3=Color3.fromRGB(119,102,140),TextColor3=C.text,Font=Enum.Font.Gotham,TextSize=13,TextXAlignment=Enum.TextXAlignment.Left,ClearTextOnFocus=false,MultiLine=false,ClipsDescendants=true})
text(main,'AccountHint','@'..Player.Name..' • Key perangkat 24 jam',23,164,374,16,11,C.dim)
local openProfileButton=button(main,'GetKey','Get Key',22,190,376,36,false)
local discord=button(main,'Discord','',22,237,183,43,false)
image(discord,'DiscordLogo','rbxassetid://139853376447596',45,12,19,19)
text(discord,'DiscordText','Discord',73,0,78,43,13,C.text,true)
local checkButton=button(main,'CheckKey','Check Key',215,237,183,43,true)
local message=text(main,'Status','',22,290,376,31,11,C.dim);message.TextWrapped=true;message.TextYAlignment=Enum.TextYAlignment.Top
local function status(value,color) if alive then message.Text=value;message.TextColor3=color or C.dim end end
-- Right-hand identity panel. Values come from Roblox/executor APIs, never a guessed brand.
text(profile,'ProfileTitle','Perangkat Saya',18,17,220,24,16,C.text,true)
local avatarFrame=create('Frame',profile,{Position=UDim2.fromOffset(18,58),Size=UDim2.fromOffset(62,62),BackgroundColor3=Color3.fromRGB(47,31,66),BorderSizePixel=0});round(avatarFrame,15);border(avatarFrame,.4)
local avatar=image(avatarFrame,'ProfilePhoto','rbxthumb://type=AvatarHeadShot&id='..tostring(Player.UserId)..'&w=150&h=150',2,2,58,58);round(avatar,14)
text(profile,'ProfileCaption','PROFIL ROBLOX',94,62,182,14,9,C.dim,true)
local displayHead=text(profile,'ProfileDisplay',clean(Player.DisplayName,80),94,82,182,20,14,C.text,true);displayHead.TextTruncate=Enum.TextTruncate.AtEnd
text(profile,'UserId','UserId '..tostring(Player.UserId),94,106,182,14,9,C.dim)
local function row(name,value,y)
    text(profile,name..'Label',name,18,y,74,22,10,C.dim)
    local valueLabel=text(profile,name,value,98,y,178,22,11,C.text)
    valueLabel.TextScaled=true;create('UITextSizeConstraint',valueLabel,{MinTextSize=8,MaxTextSize=11})
    return valueLabel
end
row('Nama','@'..Player.Name,137)
row('Display',clean(Player.DisplayName,100),163)
row('Perangkat',deviceName(),189)
row('Executor',executorName,215)
local regionLabel=row('Region','Memuat...',241)
text(profile,'HwidLabel','HWID PERANGKAT',18,277,258,16,9,C.dim,true)
local hwidBox=create('TextBox',profile,{Name='HWID',Position=UDim2.fromOffset(18,299),Size=UDim2.fromOffset(258,43),BackgroundColor3=Color3.fromRGB(13,9,21),BorderSizePixel=0,Text=hwid or 'Tidak tersedia',TextColor3=Color3.fromRGB(211,181,248),Font=Enum.Font.Code,TextSize=10,TextWrapped=true,TextEditable=false,ClearTextOnFocus=false,MultiLine=true,TextXAlignment=Enum.TextXAlignment.Center,ClipsDescendants=true});round(hwidBox,8);border(hwidBox,.55)
local copyHwid=button(profile,'CopyHWID','Salin HWID',18,351,258,29,false)
local profileGetKey=button(profile,'ProfileGetKey','Get Key',18,393,258,37,true)
-- Left-hand generator panel.
text(generator,'GeneratorTitle','Generate Key',18,17,220,24,16,C.text,true)
text(generator,'GeneratorCaption','Tempel HWID dari panel perangkat.',18,53,258,19,11,C.dim)
text(generator,'HwidInputLabel','HWID PERANGKAT',18,87,258,16,9,C.dim,true)
local hwidInput=create('TextBox',generator,{Name='HwidInput',Position=UDim2.fromOffset(18,109),Size=UDim2.fromOffset(258,42),BackgroundColor3=Color3.fromRGB(13,9,21),BorderSizePixel=0,Text='',PlaceholderText='Tempel HWID yang sudah disalin',PlaceholderColor3=C.dim,TextColor3=C.text,Font=Enum.Font.Code,TextSize=10,TextWrapped=false,ClearTextOnFocus=false,MultiLine=false,TextXAlignment=Enum.TextXAlignment.Center,ClipsDescendants=true});round(hwidInput,8);border(hwidInput,.5)
text(generator,'PasteHint','HWID wajib cocok dengan perangkat ini.',18,159,258,17,9,C.dim)
text(generator,'DurationLabel','SISA MASA AKTIF',18,188,258,14,9,C.dim,true)
local genTimer=text(generator,'KeyTimer','--:--:--',18,208,258,33,27,Color3.fromRGB(213,182,255),true)
local generatedBox=create('TextBox',generator,{Name='GeneratedKey',Position=UDim2.fromOffset(18,250),Size=UDim2.fromOffset(258,48),BackgroundColor3=Color3.fromRGB(13,9,21),BorderSizePixel=0,Text='Belum ada key',TextColor3=Color3.fromRGB(211,181,248),Font=Enum.Font.Code,TextSize=11,TextWrapped=true,TextEditable=false,ClearTextOnFocus=false,MultiLine=true,TextXAlignment=Enum.TextXAlignment.Center,ClipsDescendants=true});round(generatedBox,8);border(generatedBox,.5)
local generateButton=button(generator,'GenerateKey','Generate Key',18,310,258,36,true)
local copyKey=button(generator,'CopyKey','Salin Key',18,358,124,32,false)
local useKey=button(generator,'UseKey','Gunakan Key',152,358,124,32,false)
local genMessage=text(generator,'GeneratorStatus','Masa aktif key: 24 jam.',18,402,258,28,10,C.dim);genMessage.TextWrapped=true;genMessage.TextYAlignment=Enum.TextYAlignment.Top
local function genStatus(value,color) if alive then genMessage.Text=value;genMessage.TextColor3=color or C.dim end end
local desiredCenter,overflow,lastFocus=nil,false,'main'
local function layout(focus)
    if not alive then return end
    local camera=workspace.CurrentCamera;if not camera then return end
    local vp=camera.ViewportSize
    desiredCenter=desiredCenter or Vector2.new(vp.X/2,vp.Y/2)
    local left=generator.Visible and 306 or 0
    local total=left+420+(profile.Visible and 306 or 0)
    local factor=math.min(1,math.max(1,vp.Y-24)/448)
    if vp.X>=760 then factor=math.min(factor,math.max(1,vp.X-24)/total) else factor=math.min(factor,math.max(1,vp.X-24)/420) end
    factor=math.max(.1,factor)
    scale.Scale=factor;content.Size=UDim2.fromOffset(total,448)
    main.Position=UDim2.fromOffset(left,57);generator.Position=UDim2.fromOffset(0,0);profile.Position=UDim2.fromOffset(left+432,0)
    local width=math.min(total*factor,math.max(1,vp.X-24));local height=448*factor
    overflow=total*factor>width+.5
    host.Size=UDim2.fromOffset(width,height);host.CanvasSize=UDim2.fromOffset(total*factor,height)
    host.ScrollingEnabled=overflow;host.ScrollBarThickness=overflow and 3 or 0
    local x=math.clamp(desiredCenter.X-(left+210)*factor,12,math.max(12,vp.X-width-12))
    local y=math.clamp(desiredCenter.Y-height/2,12,math.max(12,vp.Y-height-12))
    host.Position=UDim2.fromOffset(x,y)
    if focus then lastFocus=focus end
    if lastFocus=='profile' and not profile.Visible then lastFocus='main' end
    if lastFocus=='generator' and not generator.Visible then lastFocus='main' end
    local center=lastFocus=='profile' and (left+432+147) or lastFocus=='generator' and 147 or left+210
    host.CanvasPosition=Vector2.new(overflow and math.clamp(center*factor-width/2,0,math.max(0,total*factor-width)) or 0,0)
end
local viewportConnection
local function bindCamera()
    if viewportConnection then viewportConnection:Disconnect() end
    if workspace.CurrentCamera then viewportConnection=connect(workspace.CurrentCamera:GetPropertyChangedSignal('ViewportSize'),function() desiredCenter=nil;layout() end) end
    task.defer(function() layout() end)
end
connect(workspace:GetPropertyChangedSignal('CurrentCamera'),bindCamera);bindCamera()
local dragging,dragInput,dragStart,centerStart
connect(header.InputBegan,function(input)
    if not overflow and (input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch) then dragging=true;dragInput=input;dragStart=input.Position;centerStart=desiredCenter end
end)
connect(UIS.InputChanged,function(input)
    if not alive or not dragging then return end
    local valid=(dragInput.UserInputType==Enum.UserInputType.Touch and input==dragInput) or (dragInput.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseMovement)
    if valid then local delta=input.Position-dragStart;desiredCenter=Vector2.new(centerStart.X+delta.X,centerStart.Y+delta.Y);layout() end
end)
connect(UIS.InputEnded,function(input) if input==dragInput or input.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end)
connect(UIS.WindowFocusReleased,function() dragging=false end)
local function copy(value,box)
    if clipboardFn and pcall(clipboardFn,value) then return true end
    if box then pcall(function() box:CaptureFocus();box.SelectionStart=1;box.CursorPosition=#box.Text+1 end) end
    return false
end
local function showProfile()
    if not alive then return end
    profile.Visible=true;gui.Enabled=true;layout('profile')
end
local function showRecord(row)
    shownRecord=row
    generatedBox.Text=row and row.key or 'Belum ada key'
    generateButton.Text=row and row.expiresAt>os.time() and 'Lihat Key Aktif' or 'Generate Key'
    genTimer.Text=row and string.format('%02d:%02d:%02d',math.floor(math.max(0,row.expiresAt-os.time())/3600),math.floor(math.max(0,row.expiresAt-os.time())/60)%60,math.max(0,row.expiresAt-os.time())%60) or '--:--:--'
end
local function showGenerator()
    if not alive then return end
    generator.Visible=true;gui.Enabled=true;layout('generator')
    hwidInput.Text='';showRecord(nil)
    genStatus('Tempel HWID yang sudah disalin, lalu Generate Key.')
end
connect(hwidInput:GetPropertyChangedSignal('Text'),function()
    if not alive then return end
    showRecord(nil)
    genStatus('Tempel HWID yang sudah disalin, lalu Generate Key.')
end)
connect(mainClose.Activated,controller.Destroy)
connect(profileClose.Activated,function() if alive then profile.Visible=false;layout('main') end end)
connect(generatorClose.Activated,function() if alive then generator.Visible=false;layout('main') end end)
connect(openProfileButton.Activated,function() if alive and gui.Enabled then showProfile() end end)
connect(profileGetKey.Activated,function() if alive and gui.Enabled and profile.Visible then showGenerator() end end)
connect(copyHwid.Activated,function()
    if not alive or not gui.Enabled or not profile.Visible then return end
    if not hwid then status('HWID tidak tersedia.',C.red);return end
    local copied=copy(hwid,hwidBox)
    copyHwid.Text=copied and 'HWID Disalin' or 'Pilih Teks HWID'
    task.delay(2,function() if alive then copyHwid.Text='Salin HWID' end end)
    status(copied and 'HWID disalin.' or 'Pilih teks HWID, lalu salin secara manual.',C.green)
end)
connect(discord.Activated,function() if alive and gui.Enabled then status(copy(DISCORD) and 'Link Discord disalin.' or DISCORD,C.green) end end)
connect(generateButton.Activated,function()
    if not alive or not gui.Enabled or not generator.Visible or busy then return end
    local submitted=hwidInput.Text
    busy=true;generateButton.Text='Memproses...';hwidInput.TextEditable=false
    local row,why,_,created=store:GetOrCreate(submitted)
    if not alive then return end
    busy=false;hwidInput.TextEditable=true
    if hwidInput.Text~=submitted then showRecord(nil);genStatus('HWID berubah. Tekan Generate Key lagi.',C.red);return end
    if not row then generateButton.Text='Generate Key';genStatus(why or 'Key gagal dibuat.',C.red);return end
    showRecord(row);genStatus(created and 'Key siap. Salin atau pilih Gunakan Key.' or 'Key masih aktif. Waktu tidak direset.',C.green)
end)
connect(copyKey.Activated,function()
    if not alive or not gui.Enabled or not generator.Visible then return end
    if not shownRecord or shownRecord.expiresAt<=os.time() then genStatus('Buat key aktif terlebih dahulu.',C.red);return end
    genStatus(copy(shownRecord.key,generatedBox) and 'Key disalin.' or 'Pilih teks key untuk menyalin.',C.green)
end)
connect(useKey.Activated,function()
    if not alive or not gui.Enabled or not generator.Visible then return end
    if not shownRecord or shownRecord.expiresAt<=os.time() then genStatus('Buat key aktif terlebih dahulu.',C.red);return end
    keyBox.Text=shownRecord.key;layout('main');status('Key dimasukkan. Klik Check Key.',C.green)
end)
connect(keyBox.Focused,function() inputBorder.Color=C.accent end)
local function lockSession(reason)
    if not alive then return end
    if currentSession then currentSession.Alive=false end
    if ENV.NexzanDeviceSession==currentSession then ENV.NexzanDeviceSession=nil end
    currentSession=nil
    if ENV.NexzanRollerPurple and ENV.NexzanRollerPurple.Stop then pcall(ENV.NexzanRollerPurple.Stop) end
    launched=false;busy=false;keyBox.Text='';checkButton.Text='Check Key';lockIcon.Image='rbxassetid://82932539629673';lockIcon.ImageColor3=C.text
    gui.Enabled=true;layout('main');status(reason,C.red)
end
local function makeSession(row)
    local session={Alive=true,Key=row.key,ExpiresAt=row.expiresAt,DeviceTag=deviceHash:sub(1,8):upper(),Deadline=os.clock()+math.max(0,row.expiresAt-os.time()),Callbacks={}}
    function session:GetRemaining() return math.max(0,math.ceil(math.min(self.ExpiresAt-os.time(),self.Deadline-os.clock()))) end
    function session:Format(seconds)
        seconds=math.max(0,math.floor(seconds or self:GetRemaining()))
        return string.format('%02d:%02d:%02d',math.floor(seconds/3600),math.floor(seconds/60)%60,seconds%60)
    end
    function session:BindTimer(callback) table.insert(self.Callbacks,callback);pcall(callback,self:GetRemaining(),self:Format()) end
    function session:OpenGetKey() if self.Alive then checkButton.Text='Kembali ke UI';showProfile() end end
    function session:ClosePanels() if self.Alive and alive then gui.Enabled=false end end
    return session
end
local function checkKey()
    if not alive or not gui.Enabled or busy then return end
    if launched then gui.Enabled=false;return end
    if game.PlaceId~=109203247742910 then status('Buka Swing For Eggs terlebih dahulu.',C.red);return end
    if #keyBox.Text>100 then status('Masukkan key yang lengkap.',C.red);return end
    busy=true;checkButton.Text='Memeriksa...'
    local row,why=store:Validate(keyBox.Text)
    if not alive then return end
    if not row then busy=false;checkButton.Text='Check Key';status(why,C.red);return end
    local session=makeSession(row);currentSession=session;ENV.NexzanDeviceSession=session;launched=true
    status('Key valid • Sisa '..session:Format(),C.green);lockIcon.Image='rbxassetid://126670774179963';lockIcon.ImageColor3=C.green
    task.wait(.15)
    if not alive or not session.Alive then return end
    if session:GetRemaining()<=0 then lockSession('Key kedaluwarsa. Klik Get Key lagi.');return end
    gui.Enabled=false;busy=false;checkButton.Text='Check Key'
    local ok=pcall(startSwingMain,session,controller)
    if not alive or not session.Alive then
        if ENV.NexzanRollerPurple and ENV.NexzanRollerPurple.Stop then pcall(ENV.NexzanRollerPurple.Stop) end
        return
    end
    if not ok then lockSession('UI belum dapat dimuat. Coba Check Key lagi.');return end
end
connect(checkButton.Activated,checkKey)
connect(keyBox.FocusLost,function(enter) if alive then inputBorder.Color=C.border;if enter then checkKey() end end end)
connect(gui.Destroying,function() if alive then controller.Destroy() end end)
local ready,why=store:Ready();if not ready then status(why,C.red) end
task.defer(function()
    if not alive or launched then return end
    local saved=store:Read()
    if saved and saved.expiresAt>os.time() then
        keyBox.Text=saved.key
        status('Key tersimpan aktif. Memuat UI...',C.green)
        task.wait(.15)
        if alive and not launched then checkKey() end
    end
end)

-- Avatar and region are Roblox-reported, not inferred from the executor name/IP.
task.spawn(function()
    local ok,url=pcall(function() return Players:GetUserThumbnailAsync(Player.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size150x150) end)
    if alive and ok and type(url)=='string' and url~='' then avatar.Image=url end
end)
task.spawn(function()
    local ok,region=pcall(function() return game:GetService('LocalizationService'):GetCountryRegionForPlayerAsync(Player) end)
    if not alive then return end
    local countries={ID='Indonesia',US='United States',GB='United Kingdom',MY='Malaysia',SG='Singapore',PH='Philippines',TH='Thailand',VN='Vietnam',JP='Japan',KR='South Korea',IN='India',AU='Australia',BR='Brazil',DE='Germany',FR='France',CA='Canada'}
    regionLabel.Text=ok and type(region)=='string' and region:match('^%u%u$') and ((countries[region] and countries[region]..' ('..region..')') or region) or 'Tidak tersedia'
end)
task.spawn(function()
    local nextTouch=os.clock()+60
    while alive do
        if shownRecord then
            local left=math.max(0,shownRecord.expiresAt-os.time())
            genTimer.Text=string.format('%02d:%02d:%02d',math.floor(left/3600),math.floor(left/60)%60,left%60)
            if left<=0 then generateButton.Text='Generate Key';if generator.Visible then genStatus('Key kedaluwarsa. Generate key baru.',C.red) end end
        end
        local session=currentSession
        if session and session.Alive then
            local left=session:GetRemaining()
            for _,callback in ipairs(session.Callbacks) do pcall(callback,left,session:Format(left)) end
            if left<=0 then lockSession('Key kedaluwarsa. Klik Get Key untuk key 24 jam yang baru.')
            elseif ENV.NexzanRollerPurple and ENV.NexzanRollerPurple.Alive==false then controller.Destroy()
            elseif os.clock()>=nextTouch then
                nextTouch=os.clock()+60
                local record,reason=store:Touch({key=session.Key,expiresAt=session.ExpiresAt})
                if alive and currentSession==session and not record then lockSession(reason or 'Key tidak dapat diperiksa.') end
            end
        else nextTouch=os.clock()+60 end
        task.wait(1)
    end
end)
