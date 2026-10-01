local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
--=====================================================================
--  NEXZAN UI SHIM  ·  Arcane UI (by Da7mu) menggantikan "xsx ui lib"
--  Semua FITUR script tetap sama — hanya lapisan UI yang diganti.
--  Logo: 133830716253881  ·  Watermark: NEXZAN HUB
--=====================================================================
local _NX = {
    Name = "NEXZAN HUB",
    Logo = "133830716253881",
    ToggleKey = Enum.KeyCode.RightControl,
    fps = 0,
    DisableNotifications = false,
    title = "NEXZAN HUB",
    Arcane = nil,
}
_NX.Libs = {
    "https://raw.githubusercontent.com/Da7mu/Ui-Collection/refs/heads/main/Arcane%20Ui/Library.lua",
    "https://cdn.jsdelivr.net/gh/Da7mu/Ui-Collection@main/Arcane%20Ui/Library.lua",
    "https://api.pastes.dev/L8OPAWbOcG",
    "https://dpaste.com/2KZAQX4YM.txt",
}

--=====================================================================
-- Helper: HTTP multi-metode
--=====================================================================
local function _nxFetch(url)
    local fns = {
        function() return game:HttpGet(url) end,
        function() return game:HttpGetAsync(url) end,
        function() return game.HttpGet(game, url) end,
        function()
            local req = (syn and syn.request) or (http and http.request) or http_request
                or (fluxus and fluxus.request) or request
            if not req then error("request() tidak tersedia") end
            local res = req({ Url = url, Method = "GET" })
            if type(res) == "table" then return res.Body or res.body end
            return res
        end,
    }
    for _, fn in ipairs(fns) do
        local ok, res = pcall(fn)
        if ok and type(res) == "string" and #res > 0 then return res end
    end
    return nil
end

--=====================================================================
-- Helper: coba beberapa varian pembuatan elemen
--=====================================================================
local function _nxTry(variants)
    for _, fn in ipairs(variants) do
        local ok, res = pcall(fn)
        if ok and res ~= nil then return res end
    end
    return nil
end

_NX.stats = { tabs = {}, order = {}, arcOK = 0, arcFail = 0 }

local function _nxMarkArc(ok)
    if ok then
        _NX.stats.arcOK = _NX.stats.arcOK + 1
    else
        _NX.stats.arcFail = _NX.stats.arcFail + 1
    end
end

local function _nxTabStat(tabTitle)
    local key = tostring(tabTitle)
    if not _NX.stats.tabs[key] then
        _NX.stats.tabs[key] = { elements = 0, subtabs = {}, empty = true }
        table.insert(_NX.stats.order, key)
    end
    return _NX.stats.tabs[key]
end

local _nxFlagId = 0
local function _nxFlag(prefix)
    _nxFlagId = _nxFlagId + 1
    return string.format("NX%s%d", tostring(prefix), _nxFlagId)
end

local function _nxNotify(title, text, kind)
    local icon = "list"
    local color = Color3.fromRGB(190, 200, 255)
    if kind == "success" then
        icon, color = "check", Color3.fromRGB(90, 220, 140)
    elseif kind == "error" then
        icon, color = "zap", Color3.fromRGB(255, 110, 110)
    end
    if _NX.Arcane and _NX.Arcane.Notification and not _NX.DisableNotifications then
        pcall(function()
            _NX.Arcane:Notification({
                Name = tostring(title or _NX.Name),
                Description = tostring(text or ""),
                Duration = 4,
                Icon = icon,
                Color = color,
            })
        end)
    end
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = tostring(title or _NX.Name),
            Text = tostring(text or ""),
            Duration = 4,
        })
    end)
end
_NX.notify = _nxNotify

--=====================================================================
-- Blokir tombol mobile besar dari library lama ("Kill All" dll)
-- Fungsi lama dari getgenv() bisa tertinggal dari script sebelumnya.
--=====================================================================
pcall(function()
    local genv = (typeof(getgenv) == "function" and getgenv()) or _G
    if genv then
        genv.CreateMobileButton = function() end
        genv.RemoveMobileButton = function() end
    end
end)
_NX.blockedMobileButtons = {}

--=====================================================================
-- 1) Muat library Arcane (4 mirror)
--=====================================================================
for index, url in ipairs(_NX.Libs) do
    local body = _nxFetch(url)
    if body and #body > 5000 then
        local chunk = loadstring(body, "ArcaneLibrary")
        if chunk then
            local ok, res = pcall(chunk)
            if ok and type(res) == "table" then
                _NX.Arcane = res
                print(string.format("[%s] Library Arcane OK (mirror #%d, %d bytes)", _NX.Name, index, #body))
                break
            else
                warn(string.format("[%s] Mirror #%d gagal jalan: %s", _NX.Name, index, tostring(res)))
            end
        else
            warn(string.format("[%s] Mirror #%d gagal compile", _NX.Name, index))
        end
    else
        warn(string.format("[%s] Mirror #%d gagal diunduh", _NX.Name, index))
    end
end

--=====================================================================
-- 2) Panel cadangan sederhana (kalau Arcane gagal dimuat)
--=====================================================================
local FB = nil
local function fbInit()
    if FB then return FB end
    local parent
    pcall(function()
        if typeof(gethui) == "function" then parent = gethui() end
    end)
    parent = parent or game:GetService("CoreGui")
    if not parent then return nil end

    local gui = Instance.new("ScreenGui")
    gui.Name = "NexzanSimpleUI"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Parent = parent

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 340, 0, 500)
    frame.Position = UDim2.new(0, 20, 0.5, -250)
    frame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame

    local head = Instance.new("TextLabel")
    head.Size = UDim2.new(1, -16, 0, 26)
    head.Position = UDim2.new(0, 8, 0, 6)
    head.BackgroundTransparency = 1
    head.Font = Enum.Font.GothamBold
    head.TextSize = 14
    head.TextXAlignment = Enum.TextXAlignment.Left
    head.TextColor3 = Color3.fromRGB(140, 150, 255)
    head.Text = "NEXZAN HUB (panel sederhana)"
    head.Parent = frame

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -16, 1, -44)
    scroll.Position = UDim2.new(0, 8, 0, 34)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 3
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.Parent = frame

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 4)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = scroll

    local order = 0
    local FBx = {}

    local function addRow(text, height)
        order = order + 1
        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, -6, 0, height or 26)
        row.BackgroundColor3 = Color3.fromRGB(32, 32, 42)
        row.BorderSizePixel = 0
        row.AutoButtonColor = true
        row.Font = Enum.Font.Gotham
        row.TextSize = 11
        row.TextColor3 = Color3.fromRGB(232, 232, 244)
        row.TextXAlignment = Enum.TextXAlignment.Left
        row.Text = "  " .. tostring(text)
        row.LayoutOrder = order
        row.Parent = scroll
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = row
        scroll.CanvasSize = UDim2.new(0, 0, 0, order * 30 + 10)
        return row
    end

    function FBx.header(text)
        local row = addRow("— " .. tostring(text) .. " —", 22)
        row.BackgroundTransparency = 1
        row.TextColor3 = Color3.fromRGB(140, 150, 255)
        row.AutoButtonColor = false
    end

    function FBx.toggle(name, state, changed)
        local row = addRow(name .. "   [OFF]")
        row.MouseButton1Click:Connect(function()
            state = not state
            row.Text = "  " .. name .. "   [" .. (state and "ON" or "OFF") .. "]"
            pcall(changed, state)
        end)
        row.Text = "  " .. name .. "   [" .. (state and "ON" or "OFF") .. "]"
        return {
            Set = function(_, v)
                state = v and true or false
                row.Text = "  " .. name .. "   [" .. (state and "ON" or "OFF") .. "]"
            end,
        }
    end

    function FBx.slider(name, min, max, default, changed)
        local value = tonumber(default) or tonumber(min) or 0
        min, max = tonumber(min) or 0, tonumber(max) or 100
        local step = (max - min) / 20
        if step <= 0 then step = 1 end
        local row = addRow(name .. ": " .. tostring(value) .. "   (- / +)")
        local function apply(delta)
            value = math.clamp(value + delta, min, max)
            row.Text = "  " .. name .. ": " .. tostring(math.floor(value * 100) / 100) .. "   (- / +)"
            pcall(changed, value)
        end
        row.MouseButton1Click:Connect(function() apply(step) end)
        row.MouseButton2Click:Connect(function() apply(-step) end)
        return {
            Set = function(_, v)
                value = tonumber(v) or value
                row.Text = "  " .. name .. ": " .. tostring(value) .. "   (- / +)"
            end,
        }
    end

    function FBx.selector(name, options, value, changed)
        local idx = 1
        for i, v in ipairs(options or {}) do
            if v == value then idx = i end
        end
        local function label()
            return "  " .. name .. ": " .. tostring((options or {})[idx] or "-") .. "  (tap = ganti)"
        end
        local row = addRow(label())
        row.MouseButton1Click:Connect(function()
            if #(options or {}) == 0 then return end
            idx = idx % #options + 1
            row.Text = label()
            pcall(changed, options[idx])
        end)
        return {
            Set = function(_, v)
                for i, option in ipairs(options or {}) do
                    if option == v then idx = i end
                end
                row.Text = label()
            end,
            UpdateOptions = function(_, list)
                options = list or options
                idx = math.clamp(idx, 1, math.max(#options, 1))
                row.Text = label()
            end,
        }
    end

    function FBx.button(name, callback)
        local row = addRow(name)
        row.MouseButton1Click:Connect(function() pcall(callback) end)
        return row
    end

    function FBx.keybind(name, callback)
        local row = addRow(name .. "   [tap = jalankan]")
        row.MouseButton1Click:Connect(function() pcall(callback) end)
        return {
            Set = function() end,
        }
    end

    function FBx.label(text)
        local row = addRow(text, 22)
        row.AutoButtonColor = false
    end

    function FBx.textbox(name, default, placeholder, changed)
        local row = addRow(name .. ":", 28)
        local box = Instance.new("TextBox")
        box.Size = UDim2.new(0.45, 0, 1, -4)
        box.Position = UDim2.new(0.55, 0, 0, 2)
        box.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
        box.BorderSizePixel = 0
        box.Font = Enum.Font.Gotham
        box.TextSize = 11
        box.TextColor3 = Color3.fromRGB(235, 235, 245)
        box.PlaceholderText = tostring(placeholder or "")
        box.Text = tostring(default or "")
        box.ClearTextOnFocus = false
        box.Parent = row
        box.FocusLost:Connect(function() pcall(changed, box.Text) end)
        return {
            Set = function(_, v) box.Text = tostring(v or "") end,
            Get = function() return box.Text end,
        }
    end

    FB = FBx
    return FBx
end

--=====================================================================
-- 3) Watermark NEXZAN HUB
--=====================================================================
local wmGui, wmStack, wmTitle
local function ensureWatermark(title)
    if wmGui and wmGui.Parent then
        wmTitle.Text = tostring(title)
        return
    end
    local parent
    pcall(function()
        if typeof(gethui) == "function" then parent = gethui() end
    end)
    parent = parent or game:GetService("CoreGui")
    if not parent then return end

    wmGui = Instance.new("ScreenGui")
    wmGui.Name = "NexzanWatermark"
    wmGui.ResetOnSpawn = false
    wmGui.IgnoreGuiInset = true
    wmGui.Parent = parent

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 240, 0, 46)
    frame.Position = UDim2.new(0.5, -120, 0, 12)
    frame.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
    frame.BackgroundTransparency = 0.12
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = wmGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(120, 130, 255)
    stroke.Transparency = 0.45
    stroke.Parent = frame

    wmTitle = Instance.new("TextLabel")
    wmTitle.Size = UDim2.new(1, -12, 0, 18)
    wmTitle.Position = UDim2.new(0, 6, 0, 3)
    wmTitle.BackgroundTransparency = 1
    wmTitle.Font = Enum.Font.GothamBold
    wmTitle.TextSize = 12
    wmTitle.TextXAlignment = Enum.TextXAlignment.Left
    wmTitle.TextColor3 = Color3.fromRGB(150, 160, 255)
    wmTitle.Text = tostring(title)
    wmTitle.Parent = frame

    wmStack = Instance.new("Frame")
    wmStack.Size = UDim2.new(1, -12, 0, 20)
    wmStack.Position = UDim2.new(0, 6, 0, 21)
    wmStack.BackgroundTransparency = 1
    wmStack.Parent = frame

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.Padding = UDim.new(0, 10)
    layout.Parent = wmStack
end

local function Watermark(text)
    ensureWatermark(text or _NX.Name)
    local api = {}
    function api:AddWatermark(sub)
        ensureWatermark(wmTitle and wmTitle.Text or _NX.Name)
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0, 100, 1, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.Gotham
        label.TextSize = 10
        label.TextColor3 = Color3.fromRGB(215, 215, 235)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Text = tostring(sub)
        label.Parent = wmStack
        local subApi = {}
        function subApi:Text(value)
            pcall(function() label.Text = tostring(value) end)
            return subApi
        end
        subApi.Set = subApi.Text
        local ok = pcall(function() label.Size = UDim2.new(0, label.TextBounds.X + 12, 1, 0) end)
        if not ok then end
        return subApi
    end
    function api:Text(value)
        ensureWatermark(tostring(value))
        return api
    end
    api.Set = api.Text
    return api
end

--=====================================================================
-- 4) Objek "library" pengganti
--=====================================================================
local library = _NX
local Init = {}

-- FPS counter ---------------------------------------------------------
task.spawn(function()
    local RunService = game:GetService("RunService")
    local frames, last = 0, tick()
    RunService.RenderStepped:Connect(function()
        frames = frames + 1
    end)
    while task.wait(1) do
        local now = tick()
        _NX.fps = math.floor(frames / math.max(now - last, 0.001))
        frames, last = 0, now
    end
end)

function library:GetUsername()
    local lp = game:GetService("Players").LocalPlayer
    return lp and (lp.DisplayName or lp.Name) or "player"
end

function library:SetKeybindsWidgetVisible(value)
    self._keybindsVisible = value and true or false
end

function library:InitNotifications()
    local api = {}
    function api:Notify(text, duration, notifType)
        _nxNotify(_NX.Name, text, notifType)
        local dummy = {}
        function dummy:Text() return dummy end
        function dummy:Hide() return dummy end
        function dummy:Show() return dummy end
        function dummy:Remove() return dummy end
        return dummy
    end
    return api
end

library.Watermark = function(self, text)
    return Watermark(text)
end

function library:Init(toggleKey)
    if toggleKey ~= nil then
        self.ToggleKey = toggleKey
    end
    return Init
end

--=====================================================================
-- 5) Window Arcane
--=====================================================================
local Window
local function _nxCoreGuiSnapshot()
    local set = {}
    pcall(function()
        for _, child in ipairs(game:GetService("CoreGui"):GetChildren()) do
            set[child] = true
        end
    end)
    return set
end

_NX.hideables = {}

if _NX.Arcane then
    local before = _nxCoreGuiSnapshot()
    local Players = game:GetService("Players")
    local lp = Players.LocalPlayer
    Window = _nxTry({
        function()
            return _NX.Arcane:Window({
                Name = "NEXZAN",
                User = lp and (lp.DisplayName or lp.Name) or "player",
                Logo = _NX.Logo,
            })
        end,
        function()
            return _NX.Arcane:Window({ Name = "NEXZAN", Logo = _NX.Logo })
        end,
        function()
            return _NX.Arcane:Window({ Name = "NEXZAN" })
        end,
    })
    if not Window then
        warn("[" .. _NX.Name .. "] Window Arcane gagal dibuat -> panel sederhana dipakai.")
    end

    -- catat GUI Arcane supaya tombol LeftAlt bisa show/hide
    pcall(function()
        for _, child in ipairs(game:GetService("CoreGui"):GetChildren()) do
            if not before[child] and child:IsA("ScreenGui") then
                table.insert(_NX.hideables, child)
            end
        end
        if #_NX.hideables == 0 then
            for _, child in ipairs(game:GetService("CoreGui"):GetChildren()) do
                if child:IsA("ScreenGui") and (string.lower(child.Name):find("arcane")
                    or child:FindFirstChild("Main")) then
                    table.insert(_NX.hideables, child)
                end
            end
        end
    end)
    print(string.format("[%s] GUI terdaftar untuk toggle LeftAlt: %d", _NX.Name, #_NX.hideables))
end

local function _sectionIcon(name)
    local low = string.lower(tostring(name or ""))
    if string.find(low, "esp") or string.find(low, "chams") or string.find(low, "visual")
        or string.find(low, "name") then
        return "crosshair"
    end
    if string.find(low, "key") or string.find(low, "resolver") or string.find(low, "prediction")
        or string.find(low, "shader") then
        return "settings"
    end
    if string.find(low, "config") then return "save" end
    if string.find(low, "combat") or string.find(low, "kill") or string.find(low, "gun")
        or string.find(low, "fling") then
        return "swords"
    end
    if string.find(low, "farm") or string.find(low, "coin") then return "home" end
    return "list"
end

local TAB_ICONS = {
    ["Main"] = "home",
    ["Local Player"] = "user",
    ["Visuals"] = "crosshair",
    ["Combat"] = "swords",
    ["Farming"] = "home",
    ["Fling"] = "zap",
    ["Misc"] = "settings",
    ["Configs"] = "save",
}

local function makePage(name)
    if not Window then return nil end
    local icon = TAB_ICONS[name] or "list"
    return _nxTry({
        function() return Window:Page({ Name = tostring(name), Icon = icon }) end,
        function() return Window:Page({ Name = tostring(name) }) end,
    })
end

local function makeSubPage(page, name)
    if not page then return nil end
    local icon = _sectionIcon(name)
    local sub = _nxTry({
        function() return page:SubPage({ Name = tostring(name), Icon = icon, OneColumn = true }) end,
        function() return page:SubPage({ Name = tostring(name), OneColumn = true }) end,
        function() return page:SubPage({ Name = tostring(name), Icon = icon }) end,
        function() return page:SubPage({ Name = tostring(name) }) end,
    })
    if not sub then return nil end
    return _nxTry({
        function() return sub:Section({ Name = tostring(name), Side = 1 }) end,
        function() return sub:Section({ Name = tostring(name), Side = 2 }) end,
        function() return sub:Section({ Name = tostring(name) }) end,
        function() return sub:Section({}) end,
    })
end

--=====================================================================
-- 6) Konstruktor elemen (dipakai oleh script fitur)
--=====================================================================
local function makeElementAPI(getSection, tabTitle)
    local api = {}

    local function fallback() return fbInit() end

    function api:NewSection(name)
        local tab = self
        if tab then
            -- subtab baru dibuat NANTI, hanya kalau section ini benar-benar
            -- punya elemen. Section kosong tidak akan muncul sama sekali.
            tab._pendingSection = tostring(name)
            tab._sec = nil
            tab._secName = nil
        end
        if not (Window and tab and tab._page) then
            local fb = fallback()
            if fb then fb.header(name) end
        end
        return api
    end

    function api:NewLabel(text)
        text = tostring(text)
        local sec = getSection()
        if sec then
            local made = _nxTry({
                function()
                    return sec:Button({
                        Name = text,
                        Callback = function()
                            if typeof(setclipboard) == "function" then
                                pcall(setclipboard, text)
                            end
                            _nxNotify(_NX.Name, "Disalin: " .. text)
                        end,
                    })
                end,
                function() return sec:Button({ Name = text, Callback = function() end }) end,
            })
            _nxMarkArc(made ~= nil)
            if not made then
                local fb = fallback()
                if fb then fb.label(text) end
            end
        else
            local fb = fallback()
            if fb then fb.label(text) end
        end
    end

    function api:NewButton(name, callback)
        local sec = getSection()
        local arcButton
        if sec then
            arcButton = _nxTry({
                function() return sec:Button({ Name = tostring(name), Callback = function() pcall(callback) end }) end,
                function() return sec:Button({ Name = tostring(name) }) end,
            })
            _nxMarkArc(arcButton ~= nil)
        end
        local usedFallback = false
        if not arcButton then
            _nxMarkArc(false)
            local fb = fallback()
            if fb then fb.button(name, callback) end
            usedFallback = true
        end

        -- Objek kembalian: tetap mendukung :AddButton (tombol anak, gaya UI lama),
        -- :Set / :SetValue supaya kode lama yang memakainya tidak error.
        local wrapper = {}
        wrapper._arc = arcButton
        wrapper._sec = sec

        function wrapper:AddButton(subName, subCallback)
            local label = "   \u{2514} " .. tostring(subName)
            local subArc
            if self._sec then
                subArc = _nxTry({
                    function()
                        return self._sec:Button({
                            Name = label,
                            Callback = function() pcall(subCallback) end,
                        })
                    end,
                    function() return self._sec:Button({ Name = label }) end,
                })
            end
            _nxMarkArc(subArc ~= nil)
            if not subArc then
                local fb = fallback()
                if fb then fb.button(subName, subCallback) end
            end
            local child = {}
            function child:AddButton() return nil end
            function child:Set() end
            child.SetValue = function() end
            return child
        end

        function wrapper:Set(value)
            pcall(function()
                if arcButton then
                    if type(arcButton.Set) == "function" then
                        arcButton:Set(value)
                    elseif type(arcButton.SetValue) == "function" then
                        arcButton:SetValue(value)
                    end
                end
            end)
        end
        wrapper.SetValue = function() end
        wrapper.Callback = callback
        return wrapper
    end

    function api:NewToggle(name, default, callback)
        -- fitur tombol mobile dibuang (UI besar yang isinya cuma 1 tombol)
        if type(name) == "string" and string.find(name, "^%s*Mobile Button") then
            table.insert(_NX.blockedMobileButtons, name)
            return {
                _blocked = true,
                Get = function() return false end,
                Set = function() end,
            }
        end
        local state = default and true or false
        local suppress = false
        local arc
        local function userChanged(value)
            if suppress then return end
            state = value and true or false
            if callback then pcall(callback, state) end
        end
        local sec = getSection()
        if sec then
            arc = _nxTry({
                function()
                    return sec:Toggle({
                        Name = tostring(name),
                        Default = state,
                        Flag = _nxFlag("T"),
                        Callback = userChanged,
                    })
                end,
                function()
                    return sec:Toggle({ Name = tostring(name), Default = state, Callback = userChanged })
                end,
                function() return sec:Toggle({ Name = tostring(name), Default = state }) end,
            })
            if arc and not (type(arc.Set) == "function" or type(arc.SetValue) == "function") and arc.Callback == nil then
                -- tetap dipakai, visual saja
            end
        end
        _nxMarkArc(arc ~= nil)
        if not arc then
            local fb = fallback()
            if fb then arc = fb.toggle(tostring(name), state, userChanged) end
        end
        return {
            _arc = arc,
            Get = function() return state end,
            Set = function(_, value)
                value = value and true or false
                suppress = true
                pcall(function()
                    if arc then
                        if type(arc.Set) == "function" then
                            arc:Set(value)
                        elseif type(arc.SetValue) == "function" then
                            arc:SetValue(value)
                        end
                    end
                end)
                suppress = false
                userChanged(value)
            end,
        }
    end

    function api:NewSlider(name, suffix, _b, _c, options, callback)
        options = type(options) == "table" and options or {}
        local min = tonumber(options.min) or tonumber(options.Min) or 0
        local max = tonumber(options.max) or tonumber(options.Max) or 100
        local value = tonumber(options.default) or tonumber(options.Default) or min
        local suppress = false
        local arc
        local function userChanged(newValue)
            if suppress then return end
            value = tonumber(newValue) or value
            if callback then pcall(callback, value) end
        end
        local sec = getSection()
        if sec then
            arc = _nxTry({
                function()
                    return sec:Slider({
                        Name = tostring(name),
                        Min = min,
                        Max = max,
                        Default = value,
                        Suffix = tostring(suffix or ""),
                        Flag = _nxFlag("S"),
                        Callback = userChanged,
                    })
                end,
                function()
                    return sec:Slider({
                        Name = tostring(name),
                        Min = min,
                        Max = max,
                        Default = value,
                        Callback = userChanged,
                    })
                end,
                function() return sec:Slider({ Name = tostring(name), Min = min, Max = max, Default = value }) end,
            })
        end
        _nxMarkArc(arc ~= nil)
        if not arc then
            local fb = fallback()
            if fb then arc = fb.slider(tostring(name), min, max, value, userChanged) end
        end
        return {
            _arc = arc,
            Get = function() return value end,
            Set = function(_, newValue)
                newValue = tonumber(newValue) or value
                suppress = true
                pcall(function()
                    if arc then
                        if type(arc.Set) == "function" then
                            arc:Set(newValue)
                        elseif type(arc.SetValue) == "function" then
                            arc:SetValue(newValue)
                        end
                    end
                end)
                suppress = false
                userChanged(newValue)
            end,
        }
    end

    function api:NewSelector(name, default, items, callback)
        local options = {}
        for index, item in ipairs(items or {}) do
            options[index] = tostring(item)
        end
        local value = default or options[1]
        local suppress = false
        local arc
        local function userChanged(newValue)
            if suppress then return end
            value = newValue
            if callback then pcall(callback, value) end
        end
        local sec = getSection()
        if sec then
            arc = _nxTry({
                function()
                    return sec:Selector({
                        Name = tostring(name),
                        Items = options,
                        Default = value,
                        Flag = _nxFlag("D"),
                        Callback = userChanged,
                    })
                end,
                function()
                    return sec:Selector({ Name = tostring(name), Items = options, Default = value, Callback = userChanged })
                end,
                function() return sec:Selector({ Name = tostring(name), Items = options, Default = value }) end,
                function()
                    return sec:Dropdown({
                        Name = tostring(name),
                        Items = options,
                        Default = value,
                        Flag = _nxFlag("D"),
                        Callback = userChanged,
                    })
                end,
            })
        end
        _nxMarkArc(arc ~= nil)
        if not arc then
            local fb = fallback()
            if fb then arc = fb.selector(tostring(name), options, value, userChanged) end
        end
        return {
            _arc = arc,
            Get = function() return value end,
            Set = function(_, newValue)
                suppress = true
                pcall(function()
                    if arc then
                        if type(arc.SetValue) == "function" then
                            arc:SetValue(newValue)
                        elseif type(arc.Set) == "function" then
                            arc:Set(newValue)
                        end
                    end
                end)
                suppress = false
                userChanged(newValue)
            end,
            UpdateOptions = function(_, list)
                local newOptions = {}
                for index, item in ipairs(list or {}) do
                    newOptions[index] = tostring(item)
                end
                options = newOptions
                pcall(function()
                    if arc then
                        if type(arc.UpdateOptions) == "function" then
                            arc:UpdateOptions(newOptions)
                        elseif type(arc.SetItems) == "function" then
                            arc:SetItems(newOptions)
                        elseif type(arc.Update) == "function" then
                            arc:Update(newOptions)
                        end
                    end
                end)
            end,
        }
    end

    function api:NewKeybind(name, default, callback)
        local function fire()
            if callback then pcall(callback) end
        end
        local arc
        local sec = getSection()
        if sec then
            arc = _nxTry({
                function()
                    return sec:Toggle({
                        Name = tostring(name),
                        Default = false,
                        Flag = _nxFlag("K"),
                        Callback = function(value)
                            if value then fire() end
                        end,
                    })
                end,
                function() return sec:Toggle({ Name = tostring(name), Default = false }) end,
            })
            if arc then
                pcall(function()
                    arc:Keybind({
                        Default = default or Enum.KeyCode.None,
                        Mode = "Toggle",
                        Flag = _nxFlag("KB"),
                        Callback = function(value)
                            if value then fire() end
                        end,
                    })
                end)
            end
        end
        _nxMarkArc(arc ~= nil)
        if not arc then
            local fb = fallback()
            if fb then arc = fb.keybind(tostring(name), fire) end
        end
        return {
            _arc = arc,
            Get = function() return nil end,
            Set = function(_, value)
                pcall(function()
                    if arc and type(arc.SetValue) == "function" then
                        arc:SetValue(value)
                    end
                end)
            end,
        }
    end

    function api:NewTextbox(name, ...)
        local args = { ... }
        local callback = type(args[#args]) == "function" and args[#args] or nil
        local default = type(args[1]) == "string" and args[1] or ""
        local placeholder = type(args[2]) == "string" and args[2] or ""
        local text = default
        local arc
        local function userChanged(value)
            text = tostring(value or "")
            if callback then pcall(callback, text) end
        end
        local sec = getSection()
        if sec then
            arc = _nxTry({
                function()
                    return sec:Textbox({
                        Name = tostring(name),
                        Default = default,
                        Placeholder = placeholder,
                        Flag = _nxFlag("X"),
                        Callback = userChanged,
                    })
                end,
                function()
                    return sec:Textbox({ Name = tostring(name), Placeholder = placeholder, Callback = userChanged })
                end,
                function() return sec:Textbox({ Name = tostring(name) }) end,
            })
        end
        _nxMarkArc(arc ~= nil)
        if not arc then
            local fb = fallback()
            if fb then arc = fb.textbox(tostring(name), default, placeholder, userChanged) end
        end
        return {
            _arc = arc,
            Get = function() return text end,
            Set = function(_, value)
                text = tostring(value or "")
                pcall(function()
                    if arc then
                        if type(arc.Set) == "function" then
                            arc:Set(text)
                        elseif type(arc.SetValue) == "function" then
                            arc:SetValue(text)
                        end
                    end
                end)
            end,
        }
    end

    return api
end

local function registerTab(tabTitle)
    local page = makePage(tabTitle)
    local tab = {
        _page = page,
        _sec = nil,
        _title = tabTitle,
    }
    local api = makeElementAPI(function()
        -- hitung elemen apa pun modenya (Arcane atau panel sederhana)
        local stat = _nxTabStat(tabTitle)
        stat.elements = stat.elements + 1
        stat.empty = false

        if not tab._page then return nil end

        local want = tab._pendingSection
        if want == nil and tab._sec == nil then
            want = "Umum"
        end

        if tab._sec and (want == nil or tab._secName == want) then
            return tab._sec
        end

        local sub = makeSubPage(tab._page, want or "Umum")
        if sub then
            tab._sec = sub
            tab._secName = want or "Umum"
            table.insert(stat.subtabs, tostring(tab._secName))
        end
        return tab._sec
    end, tabTitle)

    -- salin semua konstruktor ke objek tab
    for key, value in pairs(api) do
        tab[key] = value
    end
    tab._api = api

    return tab
end


-- daftar GUI NEXZAN (dipakai tombol LeftAlt untuk show/hide)
NEXZAN_HIDEABLES = _NX.hideables or {}

function Init:NewTab(name)
    local tab = registerTab(tostring(name))
    _nxTabStat(name)
    if not tab._page then
        local fb = fbInit()
        if fb then fb.header(name) end
    end
    return tab
end

if not _NX.Arcane or not Window then
    local fb = fbInit()
    if fb then fb.header("NEXZAN HUB (mode sederhana)") end
    warn("[" .. _NX.Name .. "] Arcane tidak tersedia - memakai panel sederhana (fitur tetap jalan).")
end

--=====================================================================
-- 7) Ekspor (untuk dipakai bagian lain / debugging)
--=====================================================================
-- ringkasan UI ke console (biar kelihatan tab/subtab yang dibuat)
task.spawn(function()
    task.wait(3)
    local parts = {}
    for _, key in ipairs(_NX.stats.order) do
        local st = _NX.stats.tabs[key]
        if st.elements > 0 then
            table.insert(parts, string.format("%s(%d): %s", key, st.elements, table.concat(st.subtabs, ", ")))
        else
            table.insert(parts, string.format("%s: KOSONG", key))
        end
    end
    print("[" .. _NX.Name .. "] Struktur UI -> " .. table.concat(parts, " | "))
    print(string.format("[%s] Elemen UI: %d di Arcane, %d di panel cadangan",
        _NX.Name, _NX.stats.arcOK, _NX.stats.arcFail))
    if #_NX.blockedMobileButtons > 0 then
        print(string.format("[%s] Tombol mobile besar dibuang: %d buah", _NX.Name, #_NX.blockedMobileButtons))
    end
end)

_G.NEXZAN_UI_EXPORT = {
    library = library,
    Init = Init,
    Window = Window,
    Arcane = _NX.Arcane,
    stats = _NX.stats,
    WatermarkTitle = function()
        return wmTitle and wmTitle.Text or nil
    end,
}


local replicatedStorage = game:GetService("ReplicatedStorage")
local eventsFolder = replicatedStorage:FindFirstChild("Events")
local localRoleFromEvent = nil
if eventsFolder then
    local remoteEvents = eventsFolder:FindFirstChild("RemoteEvents")
    if remoteEvents then
        local showRole = remoteEvents:FindFirstChild("showRole")
        if showRole and showRole:IsA("RemoteEvent") then
            showRole.OnClientEvent:Connect(function(role, time)
                local rStr = tostring(role):lower()
                local displayRole = tostring(role)
                if rStr:find("murder") or rStr:find("bad") then
                    displayRole = "Bad Guy"
                    localRoleFromEvent = "Murderer"
                elseif rStr:find("sherif") or rStr:find("protect") then
                    displayRole = "Protector"
                    localRoleFromEvent = "Sheriff"
                elseif rStr:find("inocent") or rStr:find("innocent") or rStr:find("good") then
                    displayRole = "Good Guy"
                    localRoleFromEvent = "Innocent"
                end
                local dur = (type(time) == "number" and time > 0) and time or 6
                Notif:Notify("Role: " .. displayRole, dur, "information")
            end)
        end
    end
end
LocalPlayer.CharacterAdded:Connect(function()
    localRoleFromEvent = nil
end)
if not UserInputService.TouchEnabled then
    local Wm = library:Watermark("NEXZAN HUB | " .. (LocalPlayer.DisplayName or LocalPlayer.Name or library:GetUsername()))
    local FpsWm = Wm:AddWatermark("fps: " .. library.fps)
    local PingWm = Wm:AddWatermark("ping: 0 ms")
    task.spawn(function()
        local StatsService = game:GetService("Stats")
        while task.wait(1) do
            FpsWm:Text("fps: " .. library.fps)
            local ping = 0
            pcall(function()
                ping = math.floor(StatsService.Network.ServerStatsItem["Data Ping"]:GetValue())
            end)
            if ping == 0 then
                pcall(function()
                    ping = math.floor(LocalPlayer:GetNetworkPing() * 1000)
                end)
            end
            PingWm:Text("ping: " .. tostring(ping) .. " ms")
        end
    end)
end
local State = {
    DisableNotifications = false,
    Chams = false,
    Nametags = false,
    ChamsObjects = {},
    NametagObjects = {},
    SelectedTargets = {},
    TargetMode = "Selected",
    FlingActive = false,
    FlingTargetName = nil,
    TouchFling = false,
    Noclip = false,
    InfJump = false,
    InfJumpConn = nil,
    WalkSpeedEnabled = false,
    WalkSpeed = 16,
    OriginalWalkSpeed = 16,
    TPWalk = false,
    TPWalkSpeed = 3,
    Bhop = false,
    BhopSpeed = 50,
    Shaders = false,
    SilentAim = false,
    AutoCoins = false,
    AutoKillAll = false,
    AutoGrabGun = false,
    AutoShootBadGuy = false,
    ShootPrediction = true,
    PredictionAmount = 100,
    PingCompensation = true,
    MoveDirPrediction = true,
    PredictYAxis = true,
    WallCheck = true,
    HitboxTarget = "HumanoidRootPart",
    AntiAimResolver = true,
    ResolverMode = "Delta Calculation",
    ResolverMaxVel = 65,
    AntiAfk = false,
    AutoSafeTeleport = false,
    SafeTeleportPos = Vector3.new(0, 505, 0),
    AntiSit = false,
    AntiFling = false,
    AutoRemoveCars = false,
    AntiGameplayPaused = false,
    SafePlatform = nil,
    CtrlClickTp = false,
    CtrlTpConn = nil,
    CurrentConfigName = "default",
    SelectedConfigName = "default",
    ConfigDropdown = nil,
    Toggles = {},
    Sliders = {},
    Keybinds = {},
    Selectors = {},
    Autoload = false,
    AutoloadToggle = nil
}
getgenv().OldPos = nil
getgenv().FPDH = workspace.FallenPartsDestroyHeight
local Mouse = LocalPlayer:GetMouse()
State.CtrlTpConn = Mouse.Button1Down:Connect(function()
    if State.CtrlClickTp and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
        if Mouse.Target and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(Mouse.Hit.Position + Vector3.new(0, 3, 0))
        end
    end
end)
local function clearTable(t)
    for k in pairs(t) do
        t[k] = nil
    end
end
local function GetRoleColor(player)
    local char = player.Character
    local function checkAttr(name)
        if player:GetAttribute(name) == true then return true end
        if char and char:GetAttribute(name) == true then return true end
        return false
    end
    if checkAttr("murderer") or checkAttr("Murderer") or checkAttr("murder") then
        return Color3.fromRGB(255, 0, 0) 
    elseif checkAttr("innocent") or checkAttr("Innocent") or checkAttr("inocent") then
        return Color3.fromRGB(0, 255, 0) 
    elseif checkAttr("sheriff") or checkAttr("Sheriff") or checkAttr("sherif") then
        return Color3.fromRGB(0, 150, 255) 
    end
    return Color3.fromRGB(128, 128, 128) 
end
local function RemovePlayerNametag(player)
    if State.NametagObjects[player] then
        pcall(function() State.NametagObjects[player]:Destroy() end)
        State.NametagObjects[player] = nil
    end
end
local function GetPlayerNametag(player, head)
    if not State.NametagObjects[player] or not State.NametagObjects[player].Parent then
        local bg = Instance.new("BillboardGui")
        bg.Name = "MM2KidsNametag"
        bg.Adornee = head
        bg.Size = UDim2.new(0, 160, 0, 24)
        bg.StudsOffset = Vector3.new(0, 1.8, 0)
        bg.AlwaysOnTop = true
        bg.ResetOnSpawn = false
        bg.Parent = CoreGui
        local label = Instance.new("TextLabel")
        label.Name = "TagLabel"
        label.Parent = bg
        label.BackgroundTransparency = 1
        label.Size = UDim2.new(1, 0, 1, 0)
        label.Font = Enum.Font.Code
        label.TextSize = 13
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextStrokeTransparency = 0
        label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        label.Text = player.DisplayName or player.Name
        State.NametagObjects[player] = bg
    end
    return State.NametagObjects[player]
end
local function UpdateVisuals()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
            local isAlive = char and hum and hum.Health > 0 and head
            if State.Chams and isAlive then
                if not State.ChamsObjects[player] or not State.ChamsObjects[player].Parent then
                    local highlight = Instance.new("Highlight")
                    highlight.Name = "MM2KidsChams"
                    highlight.OutlineTransparency = 1
                    highlight.FillTransparency = 0.5
                    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    highlight.Parent = CoreGui
                    State.ChamsObjects[player] = highlight
                end
                if State.ChamsObjects[player] then
                    State.ChamsObjects[player].Adornee = char
                    local newColor = GetRoleColor(player)
                    if State.ChamsObjects[player].FillColor ~= newColor then
                        State.ChamsObjects[player].FillColor = newColor
                        State.ChamsObjects[player].Enabled = false
                        State.ChamsObjects[player].Enabled = true
                    end
                end
            else
                if State.ChamsObjects[player] then
                    pcall(function() State.ChamsObjects[player]:Destroy() end)
                    State.ChamsObjects[player] = nil
                end
            end
            if State.Nametags and isAlive then
                local bg = GetPlayerNametag(player, head)
                bg.Adornee = head
                bg.Enabled = true
                local label = bg:FindFirstChild("TagLabel")
                if label then
                    label.Text = player.DisplayName or player.Name
                    label.TextColor3 = GetRoleColor(player)
                end
            else
                RemovePlayerNametag(player)
            end
        end
    end
end
UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.LeftAlt then
        for _, gui in ipairs(NEXZAN_HIDEABLES or {}) do
            pcall(function()
                if gui and gui.Parent then
                    gui.Enabled = not gui.Enabled
                end
            end)
        end
        for _, gui in pairs(CoreGui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Name == "NexzanWatermark" then
                gui.Enabled = not gui.Enabled
            end
        end
    end
end)
LocalPlayer.Idled:Connect(function()
    if State.AntiAfk then
        VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    end
end)
local Lighting = game:GetService("Lighting")
local shaderInstances = {}
local originalLightingProps = {}
local ShaderPresets = {
    night = {
        Ambient = Color3.fromRGB(33, 33, 33),
        Atmosphere_Color = Color3.fromRGB(175, 221, 255),
        Atmosphere_Decay = Color3.fromRGB(13, 105, 172),
        Atmosphere_Density = 0.264,
        Atmosphere_Glare = 0.36,
        Atmosphere_Haze = 1.72,
        Atmosphere_Offset = 0.156,
        Bloom_Intensity = 0.34,
        Bloom_Size = 10.0,
        Bloom_Threshold = 0.813,
        Blur_Size = 5.0,
        Brightness = 3.25,
        ClockTime = 20.0,
        Clouds_Color = Color3.fromRGB(255, 255, 255),
        Clouds_Cover = 0.65,
        Clouds_Density = 0.33,
        ColorCorrection_Brightness = -0.06,
        ColorCorrection_Contrast = -0.02,
        ColorCorrection_Saturation = -0.2,
        ColorCorrection_TintColor = Color3.fromRGB(242, 243, 243),
        ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
        ColorShift_Top = Color3.fromRGB(255, 247, 237),
        DepthOfField_FarIntensity = 0.217,
        DepthOfField_FocusDistance = 11.54,
        DepthOfField_InFocusRadius = 16.77,
        DepthOfField_NearIntensity = 0.277,
        EnvironmentDiffuseScale = 0.203,
        EnvironmentSpecularScale = 0.255,
        ExposureCompensation = 0.85,
        GeographicLatitude = -15.0,
        GlobalShadows = true,
        OutdoorAmbient = Color3.fromRGB(51, 54, 67)
    }
}
local function UpdateShaders(enabled)
    State.Shaders = enabled
    for _, inst in ipairs(shaderInstances) do
        pcall(function() inst:Destroy() end)
    end
    shaderInstances = {}
    if enabled then
        originalLightingProps = {
            Ambient = Lighting.Ambient,
            Brightness = Lighting.Brightness,
            ClockTime = Lighting.ClockTime,
            ColorShift_Bottom = Lighting.ColorShift_Bottom,
            ColorShift_Top = Lighting.ColorShift_Top,
            EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
            EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
            ExposureCompensation = Lighting.ExposureCompensation,
            GeographicLatitude = Lighting.GeographicLatitude,
            GlobalShadows = Lighting.GlobalShadows,
            OutdoorAmbient = Lighting.OutdoorAmbient
        }
        local p = ShaderPresets.night
        pcall(function()
            Lighting.Ambient = p.Ambient
            Lighting.Brightness = p.Brightness
            Lighting.ClockTime = p.ClockTime
            Lighting.ColorShift_Bottom = p.ColorShift_Bottom
            Lighting.ColorShift_Top = p.ColorShift_Top
            Lighting.EnvironmentDiffuseScale = p.EnvironmentDiffuseScale
            Lighting.EnvironmentSpecularScale = p.EnvironmentSpecularScale
            Lighting.ExposureCompensation = p.ExposureCompensation
            Lighting.GeographicLatitude = p.GeographicLatitude
            Lighting.GlobalShadows = p.GlobalShadows
            Lighting.OutdoorAmbient = p.OutdoorAmbient
        end)
        local atmosphere = Instance.new("Atmosphere")
        atmosphere.Name = "MM2KidsAtmosphere"
        atmosphere.Color = p.Atmosphere_Color
        atmosphere.Decay = p.Atmosphere_Decay
        atmosphere.Density = p.Atmosphere_Density
        atmosphere.Glare = p.Atmosphere_Glare
        atmosphere.Haze = p.Atmosphere_Haze
        atmosphere.Offset = p.Atmosphere_Offset
        atmosphere.Parent = Lighting
        table.insert(shaderInstances, atmosphere)
        local bloom = Instance.new("BloomEffect")
        bloom.Name = "MM2KidsBloom"
        bloom.Intensity = p.Bloom_Intensity
        bloom.Size = p.Bloom_Size
        bloom.Threshold = p.Bloom_Threshold
        bloom.Parent = Lighting
        table.insert(shaderInstances, bloom)
        local blur = Instance.new("BlurEffect")
        blur.Name = "MM2KidsBlur"
        blur.Size = p.Blur_Size
        blur.Parent = Lighting
        table.insert(shaderInstances, blur)
        local cc = Instance.new("ColorCorrectionEffect")
        cc.Name = "MM2KidsColorCorrection"
        cc.Brightness = p.ColorCorrection_Brightness
        cc.Contrast = p.ColorCorrection_Contrast
        cc.Saturation = p.ColorCorrection_Saturation
        cc.TintColor = p.ColorCorrection_TintColor
        cc.Parent = Lighting
        table.insert(shaderInstances, cc)
        local dof = Instance.new("DepthOfFieldEffect")
        dof.Name = "MM2KidsDepthOfField"
        dof.FarIntensity = p.DepthOfField_FarIntensity
        dof.FocusDistance = p.DepthOfField_FocusDistance
        dof.InFocusRadius = p.DepthOfField_InFocusRadius
        dof.NearIntensity = p.DepthOfField_NearIntensity
        dof.Parent = Lighting
        table.insert(shaderInstances, dof)
        local terrain = workspace:FindFirstChildOfClass("Terrain")
        if terrain then
            local clouds = Instance.new("Clouds")
            clouds.Name = "MM2KidsClouds"
            clouds.Color = p.Clouds_Color
            clouds.Cover = p.Clouds_Cover
            clouds.Density = p.Clouds_Density
            clouds.Parent = terrain
            table.insert(shaderInstances, clouds)
        end
    else
        pcall(function()
            if originalLightingProps.Ambient then
                Lighting.Ambient = originalLightingProps.Ambient
                Lighting.Brightness = originalLightingProps.Brightness
                Lighting.ClockTime = originalLightingProps.ClockTime
                Lighting.ColorShift_Bottom = originalLightingProps.ColorShift_Bottom
                Lighting.ColorShift_Top = originalLightingProps.ColorShift_Top
                Lighting.EnvironmentDiffuseScale = originalLightingProps.EnvironmentDiffuseScale
                Lighting.EnvironmentSpecularScale = originalLightingProps.EnvironmentSpecularScale
                Lighting.ExposureCompensation = originalLightingProps.ExposureCompensation
                Lighting.GeographicLatitude = originalLightingProps.GeographicLatitude
                Lighting.GlobalShadows = originalLightingProps.GlobalShadows
                Lighting.OutdoorAmbient = originalLightingProps.OutdoorAmbient
            end
        end)
    end
end
local tpWalkHeartbeatConn = nil
local function UpdateTPWalk(enabled)
    State.TPWalk = enabled
    if tpWalkHeartbeatConn then
        tpWalkHeartbeatConn:Disconnect()
        tpWalkHeartbeatConn = nil
    end
    if enabled then
        tpWalkHeartbeatConn = RunService.Heartbeat:Connect(function(dt)
            if not State.TPWalk then return end
            local char = LocalPlayer.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hrp and hum and hum.Health > 0 and hum.MoveDirection.Magnitude > 0 then
                    local speed = (State.TPWalkSpeed or 3) * 10
                    hrp.CFrame = hrp.CFrame + (hum.MoveDirection * (speed * dt))
                end
            end
        end)
    end
end
local bhopHeartbeatConn = nil
local spaceHeld = false
local mobileJumpHeld = false
local function HookMobileJump()
    pcall(function()
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        local touchGui = playerGui and playerGui:FindFirstChild("TouchGui")
        local tcf = touchGui and touchGui:FindFirstChild("TouchControlFrame")
        local jumpBtn = tcf and tcf:FindFirstChild("JumpButton")
        if jumpBtn then
            jumpBtn.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then
                    mobileJumpHeld = true
                end
            end)
            jumpBtn.InputEnded:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then
                    mobileJumpHeld = false
                end
            end)
        end
    end)
end
HookMobileJump()
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    HookMobileJump()
end)
UserInputService.InputBegan:Connect(function(inp, gpe)
    if inp.KeyCode == Enum.KeyCode.Space then
        spaceHeld = true
    elseif inp.UserInputType == Enum.UserInputType.Touch then
        local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800, 600)
        if inp.Position.X > vp.X * 0.70 and inp.Position.Y > vp.Y * 0.55 then
            mobileJumpHeld = true
        end
    end
end)
UserInputService.InputEnded:Connect(function(inp, gpe)
    if inp.KeyCode == Enum.KeyCode.Space then
        spaceHeld = false
    elseif inp.UserInputType == Enum.UserInputType.Touch then
        mobileJumpHeld = false
    end
end)
local function IsJumpHolding()
    if spaceHeld then return true end
    local isDown = false
    pcall(function()
        isDown = UserInputService:IsKeyDown(Enum.KeyCode.Space)
    end)
    if isDown then return true end
    if mobileJumpHeld then return true end
    return false
end
local function UpdateBhop(enabled)
    State.Bhop = enabled
    if bhopHeartbeatConn then
        bhopHeartbeatConn:Disconnect()
        bhopHeartbeatConn = nil
    end
    if enabled then
        bhopHeartbeatConn = RunService.Heartbeat:Connect(function()
            if not State.Bhop then return end
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then return end
            if IsJumpHolding() and hum.MoveDirection.Magnitude > 0 then
                local targetSpeed = State.BhopSpeed or 50
                if hum.WalkSpeed ~= targetSpeed then
                    hum.WalkSpeed = targetSpeed
                end
                if hum.FloorMaterial ~= Enum.Material.Air then
                    hum.Jump = true
                end
            else
                local defaultSpeed = State.WalkSpeedEnabled and State.WalkSpeed or (State.OriginalWalkSpeed or 16)
                if not State.WalkSpeedEnabled and hum.WalkSpeed ~= defaultSpeed then
                    hum.WalkSpeed = defaultSpeed
                end
            end
        end)
    else
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 and not State.WalkSpeedEnabled then
            hum.WalkSpeed = State.OriginalWalkSpeed or 16
        end
    end
end
local tfHeartbeatConn = nil
local function UpdateTouchFling(enabled)
    State.TouchFling = enabled
    if tfHeartbeatConn then
        tfHeartbeatConn:Disconnect()
        tfHeartbeatConn = nil
    end
    if enabled then
        tfHeartbeatConn = RunService.Heartbeat:Connect(function()
            if not State.TouchFling then return end
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then
                local oldVel = root.Velocity
                root.Velocity = Vector3.new(oldVel.X * 1000, 30000, oldVel.Z * 1000)
                root.RotVelocity = Vector3.new(10000, 10000, 10000)
                RunService.RenderStepped:Wait()
                if root and root.Parent then
                    root.Velocity = oldVel
                    root.RotVelocity = Vector3.zero
                end
            end
        end)
    end
end
RunService.Stepped:Connect(function()
    if State.Noclip and LocalPlayer.Character then
        for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
    if State.TouchFling and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        end
    end
    if State.AntiFling and not State.TouchFling and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                local otherRoot = p.Character.HumanoidRootPart
                local myRoot = LocalPlayer.Character.HumanoidRootPart
                if (otherRoot.Position - myRoot.Position).Magnitude < 3 then
                    for _, part in pairs(p.Character:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                        end
                    end
                end
            end
        end
    end
    if State.AntiSit and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
        if hum.Sit then hum.Sit = false end
    end
end)
local function SetInfJump(enabled)
    State.InfJump = enabled
    if State.InfJumpConn then
        State.InfJumpConn:Disconnect()
        State.InfJumpConn = nil
    end
    if enabled then
        State.InfJumpConn = UserInputService.JumpRequest:Connect(function()
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
                LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
    end
end
RunService.RenderStepped:Connect(function()
    UpdateVisuals()
    if State.AutoSafeTeleport and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local root = LocalPlayer.Character.HumanoidRootPart
        if (root.Position - State.SafeTeleportPos).Magnitude > 20 then
            root.Velocity = Vector3.zero
            root.CFrame = CFrame.new(State.SafeTeleportPos)
        end
    end
end)
task.spawn(function()
    while task.wait(0.1) do
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
            local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if State.WalkSpeedEnabled then
                if humanoid.WalkSpeed ~= State.WalkSpeed then
                    humanoid.WalkSpeed = State.WalkSpeed
                end
            else
                if not State.Bhop or not IsJumpHolding() then
                    if humanoid.WalkSpeed == State.WalkSpeed and State.WalkSpeed ~= 16 then
                        humanoid.WalkSpeed = State.OriginalWalkSpeed or 16
                    end
                end
            end
        end
    end
end)
task.spawn(function()
    while task.wait(0.1) do
        if State.AntiGameplayPaused then
            pcall(function()
                game:GetService("GuiService"):SetGameplayPausedNotificationEnabled(false)
            end)
            if LocalPlayer.GameplayPaused and LocalPlayer.Character then
                for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
                    if part:IsA("BasePart") and part.Anchored then
                        pcall(function() part.Anchored = false end)
                    end
                end
            end
        end
    end
end)
local function GetLocalPlayerRole()
    local char = LocalPlayer.Character
    if not char then return "Unknown" end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return "Dead" end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") and (tool:FindFirstChild("KnifeServer") or tool.Name:lower():find("knife")) then
            return "Murderer"
        end
    end
    if LocalPlayer:FindFirstChild("Backpack") then
        for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
            if tool:IsA("Tool") and (tool:FindFirstChild("KnifeServer") or tool.Name:lower():find("knife")) then
                return "Murderer"
            end
        end
    end
    if LocalPlayer:GetAttribute("Murderer") == true or LocalPlayer:GetAttribute("murderer") == true or LocalPlayer:GetAttribute("murder") == true or
       char:GetAttribute("Murderer") == true or char:GetAttribute("murderer") == true then
        return "Murderer"
    end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") and (tool:FindFirstChild("GunServer") or tool:FindFirstChild("ShootGun") or tool.Name:lower():find("gun") or tool.Name:lower():find("revolver")) then
            return "Sheriff"
        end
    end
    if LocalPlayer:FindFirstChild("Backpack") then
        for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
            if tool:IsA("Tool") and (tool:FindFirstChild("GunServer") or tool:FindFirstChild("ShootGun") or tool.Name:lower():find("gun") or tool.Name:lower():find("revolver")) then
                return "Sheriff"
            end
        end
    end
    if LocalPlayer:GetAttribute("Sheriff") == true or LocalPlayer:GetAttribute("sheriff") == true or LocalPlayer:GetAttribute("sherif") == true or
       char:GetAttribute("Sheriff") == true or char:GetAttribute("sheriff") == true then
        return "Sheriff"
    end
    if LocalPlayer:GetAttribute("Innocent") == true or LocalPlayer:GetAttribute("innocent") == true or LocalPlayer:GetAttribute("inocent") == true or
       char:GetAttribute("Innocent") == true or char:GetAttribute("innocent") == true or localRoleFromEvent == "Innocent" then
        return "Innocent"
    end
    if localRoleFromEvent == "Murderer" then return "Murderer" end
    if localRoleFromEvent == "Sheriff" then return "Sheriff" end
    return "Unknown"
end
local function SimulateKnifeAttack(knife)
    if knife then
        pcall(function() knife:Activate() end)
    end
    if mouse1click then
        pcall(mouse1click)
    end
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        vim:SendMouseButtonEvent(0, 0, 0, false, game, 0)
    end)
    pcall(function()
        local vu = game:GetService("VirtualUser")
        vu:Button1Down(Vector2.new(500, 500), workspace.CurrentCamera.CFrame)
        vu:Button1Up(Vector2.new(500, 500), workspace.CurrentCamera.CFrame)
    end)
    if UserInputService.TouchEnabled then
        pcall(function()
            local vim = game:GetService("VirtualInputManager")
            local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800, 600)
            vim:SendTouchEvent(99, 0, vp.X * 0.75, vp.Y * 0.5)
            vim:SendTouchEvent(99, 2, vp.X * 0.75, vp.Y * 0.5)
        end)
        pcall(function()
            local touchGui = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("TouchGui")
            if touchGui then
                touchGui.Enabled = true
                local frame = touchGui:FindFirstChild("TouchControlFrame")
                if frame then frame.Visible = true end
            end
        end)
    end
end
task.spawn(function()
    while task.wait(0.2) do
        if State.AutoCoins and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            local role = GetLocalPlayerRole()
            if hum and hum.Health > 0 and (role == "Innocent" or role == "Sheriff" or role == "Murderer") then
                local rootPart = LocalPlayer.Character.HumanoidRootPart
                for _, obj in pairs(workspace:GetDescendants()) do
                    if (obj.Name == "Coin" or obj.Name == "coin") and obj:IsA("BasePart") then
                        obj.CFrame = rootPart.CFrame
                    end
                end
            end
        end
        if State.AutoKillAll and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local someoneAlive = false
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                    local pHum = p.Character:FindFirstChildOfClass("Humanoid")
                    if pHum and pHum.Health > 0 then
                        local function checkAttr(name)
                            if p:GetAttribute(name) == true then return true end
                            if p.Character and p.Character:GetAttribute(name) == true then return true end
                            return false
                        end
                        if checkAttr("murderer") or checkAttr("Murderer") or checkAttr("murder") or
                           checkAttr("innocent") or checkAttr("Innocent") or checkAttr("inocent") or
                           checkAttr("sheriff") or checkAttr("Sheriff") or checkAttr("sherif") then
                            someoneAlive = true
                            break
                        end
                    end
                end
            end
            if someoneAlive then
                local knife = nil
                for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
                    if tool:IsA("Tool") and (tool:FindFirstChild("KnifeServer") or tool.Name:lower():find("knife")) then knife = tool break end
                end
                if not knife then
                    for _, tool in ipairs(LocalPlayer.Character:GetChildren()) do
                        if tool:IsA("Tool") and (tool:FindFirstChild("KnifeServer") or tool.Name:lower():find("knife")) then knife = tool break end
                    end
                end
                if knife then
                    local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                    if knife.Parent == LocalPlayer.Backpack and hum then
                        hum:EquipTool(knife)
                    end
                    local myRoot = LocalPlayer.Character.HumanoidRootPart
                    local killPos = myRoot.CFrame * CFrame.new(0, 0, -3)
                    local handle = knife:FindFirstChild("Handle") or knife:FindFirstChildWhichIsA("BasePart")
                    for _, p in pairs(Players:GetPlayers()) do
                        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                            local enemyHum = p.Character:FindFirstChildOfClass("Humanoid")
                            if enemyHum and enemyHum.Health > 0 then
                                local enemyRoot = p.Character.HumanoidRootPart
                                enemyRoot.Velocity = Vector3.zero
                                enemyRoot.RotVelocity = Vector3.zero
                                enemyRoot.CFrame = killPos
                                if handle and firetouchinterest then
                                    pcall(function()
                                        firetouchinterest(handle, enemyRoot, 0)
                                        firetouchinterest(handle, enemyRoot, 1)
                                    end)
                                end
                            end
                        end
                    end
                    SimulateKnifeAttack(knife)
                end
            end
        end
        if State.AutoGrabGun and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local role = GetLocalPlayerRole()
            if role == "Innocent" then
                local droppedGun = workspace:FindFirstChild("GunDrop") or workspace:FindFirstChild("Gun")
                if droppedGun then
                    local myRoot = LocalPlayer.Character.HumanoidRootPart
                    if droppedGun:IsA("Model") and droppedGun.PrimaryPart then
                        droppedGun:SetPrimaryPartCFrame(myRoot.CFrame)
                    elseif droppedGun:IsA("BasePart") then
                        droppedGun.CFrame = myRoot.CFrame
                    end
                end
            end
        end
    end
end)
Players.PlayerRemoving:Connect(function(player)
    RemovePlayerNametag(player)
        if State.ChamsObjects[player] then
            pcall(function() State.ChamsObjects[player]:Destroy() end)
            State.ChamsObjects[player] = nil
        end
    State.SelectedTargets[player.Name] = nil
end)
local function Fling(TargetPlayer)
    local Character = LocalPlayer.Character
    local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
    local RootPart = Humanoid and Humanoid.RootPart
    local TCharacter = TargetPlayer.Character
    if not TCharacter then return end
    local THumanoid = TCharacter:FindFirstChildOfClass("Humanoid")
    local TRootPart = THumanoid and THumanoid.RootPart
    local THead = TCharacter:FindFirstChild("Head")
    local Accessory = TCharacter:FindFirstChildOfClass("Accessory")
    local Handle = Accessory and Accessory:FindFirstChild("Handle")
    if Character and Humanoid and RootPart then
        if RootPart.Velocity.Magnitude < 50 then
            getgenv().OldPos = RootPart.CFrame
        end
        if THumanoid and THumanoid.Sit then
            return
        end
        if THead then
            workspace.CurrentCamera.CameraSubject = THead
        elseif Handle then
            workspace.CurrentCamera.CameraSubject = Handle
        elseif THumanoid and TRootPart then
            workspace.CurrentCamera.CameraSubject = THumanoid
        end
        if not TCharacter:FindFirstChildWhichIsA("BasePart") then
            return
        end
        local FPos = function(BasePart, Pos, Ang)
            RootPart.CFrame = CFrame.new(BasePart.Position) * Pos * Ang
            pcall(function() Character:SetPrimaryPartCFrame(CFrame.new(BasePart.Position) * Pos * Ang) end)
            RootPart.Velocity = Vector3.new(9e7, 9e7 * 10, 9e7)
            RootPart.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
        end
        local SFBasePart = function(BasePart)
            local TimeToWait = 2
            local Time = tick()
            local Angle = 0
            repeat
                if RootPart and THumanoid then
                    if BasePart.Velocity.Magnitude < 50 then
                        Angle = Angle + 100
                        FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle),0 ,0))
                        task.wait()
                        FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                        task.wait()
                        FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle),0 ,0))
                        task.wait()
                        FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                        task.wait()
                        FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection, CFrame.Angles(math.rad(Angle),0 ,0))
                        task.wait()
                        FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection, CFrame.Angles(math.rad(Angle), 0, 0))
                        task.wait()
                    else
                        FPos(BasePart, CFrame.new(0, 1.5, THumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
                        task.wait()
                        FPos(BasePart, CFrame.new(0, -1.5, -THumanoid.WalkSpeed), CFrame.Angles(0, 0, 0))
                        task.wait()
                        FPos(BasePart, CFrame.new(0, 1.5, THumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
                        task.wait()
                        FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(90), 0, 0))
                        task.wait()
                        FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0))
                        task.wait()
                        FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(90), 0, 0))
                        task.wait()
                        FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0))
                        task.wait()
                    end
                end
            until Time + TimeToWait < tick() or not State.FlingActive
        end
        workspace.FallenPartsDestroyHeight = 0/0
        local BV = Instance.new("BodyVelocity")
        BV.Parent = RootPart
        BV.Velocity = Vector3.new(0, 0, 0)
        BV.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
        if TRootPart then
            SFBasePart(TRootPart)
        elseif THead then
            SFBasePart(THead)
        elseif Handle then
            SFBasePart(Handle)
        end
        BV:Destroy()
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
        workspace.CurrentCamera.CameraSubject = Humanoid
        if getgenv().OldPos then
            repeat
                RootPart.CFrame = getgenv().OldPos * CFrame.new(0, .5, 0)
                pcall(function() Character:SetPrimaryPartCFrame(getgenv().OldPos * CFrame.new(0, .5, 0)) end)
                Humanoid:ChangeState("GettingUp")
                for _, part in pairs(Character:GetChildren()) do
                    if part:IsA("BasePart") then
                        part.Velocity, part.RotVelocity = Vector3.new(), Vector3.new()
                    end
                end
                task.wait()
            until (RootPart.Position - getgenv().OldPos.p).Magnitude < 25
            workspace.FallenPartsDestroyHeight = getgenv().FPDH
        end
    end
end
local function ExecuteFling()
    if not State.FlingTargetName or State.FlingTargetName == "" then
        Notif:Notify("Please select a target to fling!", 3, "error")
        return
    end
    local targetPlayer = Players:FindFirstChild(State.FlingTargetName)
    if not targetPlayer then
        Notif:Notify("Player not found!", 3, "error")
        return
    end
    Notif:Notify("Flinging " .. targetPlayer.Name .. "...", 3, "information")
    task.spawn(function()
        State.FlingActive = true
        Fling(targetPlayer)
        State.FlingActive = false
        Notif:Notify("Fling Complete!", 3, "success")
    end)
end
local function PerformKillAll()
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    local knife = nil
    for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
        if tool:IsA("Tool") and (tool:FindFirstChild("KnifeServer") or tool.Name:lower():find("knife")) then knife = tool break end
    end
    if not knife then
        for _, tool in ipairs(LocalPlayer.Character:GetChildren()) do
            if tool:IsA("Tool") and (tool:FindFirstChild("KnifeServer") or tool.Name:lower():find("knife")) then knife = tool break end
        end
    end
    if not knife then
        Notif:Notify("Knife not found!", 3, "error")
        return
    end
    local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if knife.Parent == LocalPlayer.Backpack and hum then
        hum:EquipTool(knife)
    end
    task.spawn(function()
        local startTime = tick()
        local maxDuration = 10
        local killedCount = 0
        while tick() - startTime < maxDuration do
            if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then break end
            local myRoot = LocalPlayer.Character.HumanoidRootPart
            local myHum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if not myHum or myHum.Health <= 0 then break end
            local killPos = myRoot.CFrame * CFrame.new(0, 0, -3)
            local handle = knife:FindFirstChild("Handle") or knife:FindFirstChildWhichIsA("BasePart")
            local anyAlive = false
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                    local enemyHum = p.Character:FindFirstChildOfClass("Humanoid")
                    if enemyHum and enemyHum.Health > 0 then
                        anyAlive = true
                        local enemyRoot = p.Character.HumanoidRootPart
                        enemyRoot.Velocity = Vector3.zero
                        enemyRoot.RotVelocity = Vector3.zero
                        enemyRoot.CFrame = killPos
                        if handle and firetouchinterest then
                            pcall(function()
                                firetouchinterest(handle, enemyRoot, 0)
                                firetouchinterest(handle, enemyRoot, 1)
                            end)
                        end
                    end
                end
            end
            if not anyAlive then
                break
            end
            SimulateKnifeAttack(knife)
            task.wait(0.04)
        end
        Notif:Notify("Kill All Complete!", 3, "success")
    end)
end
local function PerformKillProtector()
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    local knife = nil
    for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
        if tool:IsA("Tool") and (tool:FindFirstChild("KnifeServer") or tool.Name:lower():find("knife")) then knife = tool break end
    end
    if not knife then
        for _, tool in ipairs(LocalPlayer.Character:GetChildren()) do
            if tool:IsA("Tool") and (tool:FindFirstChild("KnifeServer") or tool.Name:lower():find("knife")) then knife = tool break end
        end
    end
    if not knife then
        Notif:Notify("Knife not found!", 3, "error")
        return
    end
    local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if knife.Parent == LocalPlayer.Backpack and hum then
        hum:EquipTool(knife)
    end
    task.spawn(function()
        local startTime = tick()
        local maxDuration = 10
        local killed = false
        while tick() - startTime < maxDuration do
            if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then break end
            local myRoot = LocalPlayer.Character.HumanoidRootPart
            local myHum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if not myHum or myHum.Health <= 0 then break end
            local killPos = myRoot.CFrame * CFrame.new(0, 0, -3)
            local handle = knife:FindFirstChild("Handle") or knife:FindFirstChildWhichIsA("BasePart")
            local protectorAlive = false
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                    local char = p.Character
                    local hasGun = false
                    for _, obj in pairs(char:GetChildren()) do
                        if obj:IsA("Tool") and (obj:FindFirstChild("GunServer") or obj.Name:lower():find("gun")) then hasGun = true break end
                    end
                    if not hasGun and p:FindFirstChild("Backpack") then
                        for _, obj in pairs(p.Backpack:GetChildren()) do
                            if obj:IsA("Tool") and (obj:FindFirstChild("GunServer") or obj.Name:lower():find("gun")) then hasGun = true break end
                        end
                    end
                    local isSheriff = p:GetAttribute("Sheriff") == true or p:GetAttribute("sheriff") == true or p:GetAttribute("sherif") == true or
                        (char and (char:GetAttribute("Sheriff") == true or char:GetAttribute("sheriff") == true)) or hasGun
                    if isSheriff then
                        local enemyHum = p.Character:FindFirstChildOfClass("Humanoid")
                        if enemyHum and enemyHum.Health > 0 then
                            protectorAlive = true
                            local enemyRoot = p.Character.HumanoidRootPart
                            enemyRoot.Velocity = Vector3.zero
                            enemyRoot.RotVelocity = Vector3.zero
                            enemyRoot.CFrame = killPos
                            if handle and firetouchinterest then
                                pcall(function()
                                    firetouchinterest(handle, enemyRoot, 0)
                                    firetouchinterest(handle, enemyRoot, 1)
                                end)
                            end
                        else
                            killed = true
                        end
                    end
                end
            end
            if not protectorAlive then
                break
            end
            SimulateKnifeAttack(knife)
            task.wait(0.04)
        end
        if killed then
            Notif:Notify("Killed Protector!", 2, "success")
        else
            Notif:Notify("Protector not found!", 2, "error")
        end
    end)
end
local function PerformFlingBadGuy()
    for _, p in pairs(Players:GetPlayers()) do
        local char = p.Character
        if p:GetAttribute("Murderer") == true or p:GetAttribute("murderer") == true or p:GetAttribute("murder") == true or
            (char and (char:GetAttribute("Murderer") == true or char:GetAttribute("murderer") == true)) then
            State.FlingTargetName = p.Name
            ExecuteFling()
            Notif:Notify("Flinging Bad Guy: " .. p.Name, 2, "success")
            return
        end
    end
    Notif:Notify("Bad Guy not found!", 2, "error")
end
local function PerformFlingProtector()
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local char = p.Character
            if char then
                local hasGun = false
                for _, obj in pairs(char:GetChildren()) do
                    if obj:IsA("Tool") and obj:FindFirstChild("GunServer") then hasGun = true break end
                end
                if not hasGun and p:FindFirstChild("Backpack") then
                    for _, obj in pairs(p.Backpack:GetChildren()) do
                        if obj:IsA("Tool") and obj:FindFirstChild("GunServer") then hasGun = true break end
                    end
                end
                if p:GetAttribute("Sheriff") == true or p:GetAttribute("sheriff") == true or hasGun then
                    State.FlingTargetName = p.Name
                    ExecuteFling()
                    Notif:Notify("Flinging Protector: " .. p.Name, 2, "success")
                    return
                end
            end
        end
    end
    Notif:Notify("Protector not found!", 2, "error")
end
local function SendChatMessage(msg)
    local sent = false
    pcall(function()
        local TextChatService = game:GetService("TextChatService")
        if TextChatService and TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            local textChannels = TextChatService:FindFirstChild("TextChannels")
            local rbxGeneral = textChannels and (textChannels:FindFirstChild("RBXGeneral") or textChannels:FindFirstChild("RBXSystem"))
            if rbxGeneral then
                rbxGeneral:SendAsync(msg)
                sent = true
            end
        end
    end)
    if not sent then
        pcall(function()
            local ReplicatedStorage = game:GetService("ReplicatedStorage")
            local defaultEvents = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
            local sayMessage = defaultEvents and defaultEvents:FindFirstChild("SayMessageRequest")
            if sayMessage then
                sayMessage:FireServer(msg, "All")
                sent = true
            end
        end)
    end
    if not sent then
        pcall(function()
            game:GetService("Players"):Chat(msg)
        end)
    end
end
local function GetProtectorPlayer()
    for _, p in ipairs(Players:GetPlayers()) do
        local char = p.Character
        if char then
            local hasGun = false
            for _, obj in ipairs(char:GetDescendants()) do
                if obj:IsA("Tool") and (obj:FindFirstChild("GunServer") or obj:FindFirstChild("ShootGun") or obj.Name:lower():find("gun") or obj.Name:lower():find("revolver")) then
                    hasGun = true
                    break
                end
            end
            if not hasGun and p:FindFirstChild("Backpack") then
                for _, obj in ipairs(p.Backpack:GetDescendants()) do
                    if obj:IsA("Tool") and (obj:FindFirstChild("GunServer") or obj:FindFirstChild("ShootGun") or obj.Name:lower():find("gun") or obj.Name:lower():find("revolver")) then
                        hasGun = true
                        break
                    end
                end
            end
            if p:GetAttribute("Sheriff") == true or p:GetAttribute("sheriff") == true or (char:GetAttribute("Sheriff") == true or char:GetAttribute("sheriff") == true) or hasGun then
                return p
            end
        end
    end
    return nil
end
local function GetBadGuyPlayer()
    for _, p in ipairs(Players:GetPlayers()) do
        local char = p.Character
        if char then
            local hasKnife = false
            for _, obj in ipairs(char:GetDescendants()) do
                if obj:IsA("Tool") and (obj.Name:lower():find("knife") or obj:FindFirstChild("KnifeServer")) then
                    hasKnife = true
                    break
                end
            end
            if not hasKnife and p:FindFirstChild("Backpack") then
                for _, obj in ipairs(p.Backpack:GetDescendants()) do
                    if obj:IsA("Tool") and (obj.Name:lower():find("knife") or obj:FindFirstChild("KnifeServer")) then
                        hasKnife = true
                        break
                    end
                end
            end
            if p:GetAttribute("Murderer") == true or p:GetAttribute("murderer") == true or p:GetAttribute("murder") == true or
               (char:GetAttribute("Murderer") == true or char:GetAttribute("murderer") == true) or hasKnife then
                return p
            end
        end
    end
    return nil
end
local function SendProtectorToChat()
    local p = GetProtectorPlayer()
    if p == LocalPlayer then
        Notif:Notify("Protector is you!", 3, "information")
    elseif p then
        SendChatMessage("Protector: " .. p.Name)
        Notif:Notify("Sent Protector (" .. p.Name .. ") to chat", 2, "success")
    else
        Notif:Notify("Protector not found!", 2, "error")
    end
end
local function SendBadGuyToChat()
    local p = GetBadGuyPlayer()
    if p == LocalPlayer then
        Notif:Notify("Bad Guy is you!", 3, "information")
    elseif p then
        SendChatMessage("Bad Guy: " .. p.Name)
        Notif:Notify("Sent Bad Guy (" .. p.Name .. ") to chat", 2, "success")
    else
        Notif:Notify("Bad Guy not found!", 2, "error")
    end
end
local function PerformGrabGun()
    local droppedGun = workspace:FindFirstChild("GunDrop") or workspace:FindFirstChild("Gun")
    if droppedGun and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local myRoot = LocalPlayer.Character.HumanoidRootPart
        if droppedGun:IsA("Model") and droppedGun.PrimaryPart then
            droppedGun:SetPrimaryPartCFrame(myRoot.CFrame)
        elseif droppedGun:IsA("BasePart") then
            droppedGun.CFrame = myRoot.CFrame
        end
        Notif:Notify("Grabbed Gun!", 2, "success")
    else
        Notif:Notify("Gun not dropped!", 2, "error")
    end
end
local resolverTracker = {}
RunService.Heartbeat:Connect(function()
    local now = tick()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local data = resolverTracker[p]
                if not data then
                    resolverTracker[p] = { lastPos = hrp.Position, lastTime = now, realVel = Vector3.zero }
                else
                    local dt = now - data.lastTime
                    if dt > 0.001 then
                        local diff = hrp.Position - data.lastPos
                        local calculatedVel = diff / dt
                        if calculatedVel.Magnitude < 300 then
                            data.realVel = calculatedVel
                        end
                        data.lastPos = hrp.Position
                        data.lastTime = now
                    end
                end
            else
                resolverTracker[p] = nil
            end
        end
    end
end)
Players.PlayerRemoving:Connect(function(p)
    resolverTracker[p] = nil
end)
local function GetResolvedVelocity(targetPlayer, targetChar, targetRoot, humanoid)
    local rawVel = targetRoot.AssemblyLinearVelocity or targetRoot.Velocity or Vector3.zero
    if not State.AntiAimResolver then
        return rawVel
    end
    if rawVel.X ~= rawVel.X or rawVel.Y ~= rawVel.Y or rawVel.Z ~= rawVel.Z or
       math.abs(rawVel.X) == math.huge or math.abs(rawVel.Y) == math.huge or math.abs(rawVel.Z) == math.huge then
        rawVel = Vector3.zero
    end
    local isSpoofed = false
    local maxVel = State.ResolverMaxVel or 70
    if rawVel.Magnitude > maxVel or math.abs(rawVel.Y) > 120 then
        isSpoofed = true
    end
    local trackerData = resolverTracker[targetPlayer]
    local realDeltaVel = trackerData and trackerData.realVel or Vector3.zero
    if (rawVel - realDeltaVel).Magnitude > 35 then
        isSpoofed = true
    end
    if isSpoofed then
        local mode = State.ResolverMode or "Delta Calculation"
        if mode == "Delta Calculation" and realDeltaVel.Magnitude <= (maxVel + 50) then
            rawVel = realDeltaVel
        elseif mode == "MoveDirection" and humanoid then
            local walkSpeed = humanoid.WalkSpeed > 0 and humanoid.WalkSpeed or 16
            rawVel = humanoid.MoveDirection * walkSpeed
            if humanoid.FloorMaterial == Enum.Material.Air and trackerData and trackerData.realVel then
                rawVel = Vector3.new(rawVel.X, trackerData.realVel.Y, rawVel.Z)
            end
        else
            rawVel = realDeltaVel
        end
    end
    if humanoid and humanoid.FloorMaterial ~= Enum.Material.Air and math.abs(rawVel.Y) < 3 then
        rawVel = Vector3.new(rawVel.X, 0, rawVel.Z)
    end
    return rawVel
end
local function GetPredictedTargetPosition(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return nil, nil end
    local char = targetPlayer.Character
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
    if not root then return nil, nil end
    local targetPartName = State.HitboxTarget or "HumanoidRootPart"
    local targetPart = (State.HitboxTarget and char:FindFirstChild(targetPartName)) 
        or char:FindFirstChild("UpperTorso") 
        or char:FindFirstChild("Torso") 
        or char:FindFirstChild("HumanoidRootPart") 
        or char:FindFirstChild("Head") 
        or root
    if not targetPart then return nil, nil end
    local targetPos = targetPart.Position
    local rawTargetPos = targetPos
    if not State.ShootPrediction then
        return targetPos, rawTargetPos
    end
    local vel = GetResolvedVelocity(targetPlayer, char, root, humanoid)
    local myPos = (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.Position) or (workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position) or targetPos
    local dist = (targetPos - myPos).Magnitude
    local ping = 0.04
    if State.PingCompensation then
        pcall(function()
            local stats = game:GetService("Stats")
            if stats and stats.Network and stats.Network.ServerStatsItem and stats.Network.ServerStatsItem["Data Ping"] then
                local rawPing = stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
                if rawPing > 0 and rawPing < 0.5 then
                    ping = rawPing
                end
            end
        end)
    end
    local bulletSpeed = 950
    local timeToTarget = (dist / bulletSpeed) + (State.PingCompensation and ping or 0)
    local predScale = (State.PredictionAmount or 100) / 100
    local effectiveTime = timeToTarget * predScale
    if effectiveTime > 0.35 then
        effectiveTime = 0.35
    end
    local horizVel = Vector3.new(vel.X, 0, vel.Z)
    if State.MoveDirPrediction and humanoid and humanoid.MoveDirection.Magnitude > 0 then
        local moveSpeed = (humanoid.WalkSpeed > 0 and humanoid.WalkSpeed or 16)
        local moveDirVel = humanoid.MoveDirection * moveSpeed
        if horizVel.Magnitude < 1 then
            horizVel = moveDirVel
        else
            horizVel = horizVel:Lerp(moveDirVel, 0.5)
        end
    end
    local inAir = false
    if humanoid then
        local state = humanoid:GetState()
        inAir = (humanoid.FloorMaterial == Enum.Material.Air) 
            or (state == Enum.HumanoidStateType.Freefall) 
            or (state == Enum.HumanoidStateType.Jumping) 
            or (math.abs(vel.Y) > 2)
    else
        inAir = (math.abs(vel.Y) > 2)
    end
    local predictedY = targetPos.Y
    if inAir and State.PredictYAxis then
        local gravity = (workspace.Gravity > 0 and workspace.Gravity) or 196.2
        local vy = vel.Y
        if math.abs(vy) > 100 then
            vy = math.clamp(vy, -100, 100)
        end
        local deltaY = (vy * effectiveTime) - (0.5 * gravity * effectiveTime * effectiveTime)
        predictedY = targetPos.Y + deltaY
        local rayParams = RaycastParams.new()
        rayParams.FilterDescendantsInstances = {char, LocalPlayer.Character or workspace}
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.IgnoreWater = true
        local floorRay = workspace:Raycast(targetPos, Vector3.new(0, -35, 0), rayParams)
        if floorRay then
            local minY = floorRay.Position.Y + (targetPart.Size.Y / 2) + 0.5
            if predictedY < minY then
                predictedY = minY
            end
        end
    end
    local predictedOffset = Vector3.new(horizVel.X * effectiveTime, 0, horizVel.Z * effectiveTime)
    local finalPos = Vector3.new(targetPos.X + predictedOffset.X, predictedY, targetPos.Z + predictedOffset.Z)
    return finalPos, rawTargetPos
end
local lastShootTime = 0
local function PerformShootBadGuy(silent)
    if silent and (tick() - lastShootTime < 0.25) then return end
    if not silent and (tick() - lastShootTime < 0.05) then return end
    local murderer = GetBadGuyPlayer()
    if not murderer or not murderer.Character or not murderer.Character:FindFirstChild("HumanoidRootPart") then
        if not silent then Notif:Notify("Bad Guy not found!", 2, "error") end
        return
    end
    local targetPos, rawTargetPos = GetPredictedTargetPosition(murderer)
    if not targetPos then
        if not silent then Notif:Notify("Target position invalid!", 2, "error") end
        return
    end
    local char = LocalPlayer.Character
    if not char then return end
    local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    if State.WallCheck and head then
        local rayParams = RaycastParams.new()
        rayParams.FilterDescendantsInstances = {char, murderer.Character}
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.IgnoreWater = true
        local dir = (targetPos - head.Position)
        local result = workspace:Raycast(head.Position, dir, rayParams)
        if result and result.Instance and result.Instance.CanCollide and result.Instance.Transparency < 0.9 then
            if rawTargetPos then
                local rawDir = (rawTargetPos - head.Position)
                local rawResult = workspace:Raycast(head.Position, rawDir, rayParams)
                if rawResult and rawResult.Instance and rawResult.Instance.CanCollide and rawResult.Instance.Transparency < 0.9 then
                    return
                else
                    targetPos = rawTargetPos
                end
            else
                return
            end
        end
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local gun = nil
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") and (tool:FindFirstChild("GunServer") or tool:FindFirstChild("ShootGun") or tool:FindFirstChild("Shoot") or tool.Name:lower():find("gun") or tool.Name:lower():find("revolver") or tool.Name == "Party Popper") then
            gun = tool
            break
        end
    end
    if not gun and LocalPlayer:FindFirstChild("Backpack") then
        for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
            if tool:IsA("Tool") and (tool:FindFirstChild("GunServer") or tool:FindFirstChild("ShootGun") or tool:FindFirstChild("Shoot") or tool.Name:lower():find("gun") or tool.Name:lower():find("revolver") or tool.Name == "Party Popper") then
                tool.Parent = char
                if hum and hum.Health > 0 then
                    hum:EquipTool(tool)
                end
                gun = tool
                break
            end
        end
    end
    if not gun then
        local droppedGun = workspace:FindFirstChild("GunDrop") or workspace:FindFirstChild("Gun")
        if droppedGun and char:FindFirstChild("HumanoidRootPart") then
            local myRoot = char.HumanoidRootPart
            if droppedGun:IsA("Model") and droppedGun.PrimaryPart then
                droppedGun:SetPrimaryPartCFrame(myRoot.CFrame)
            elseif droppedGun:IsA("BasePart") then
                droppedGun.CFrame = myRoot.CFrame
            end
            for _, tool in ipairs(char:GetChildren()) do
                if tool:IsA("Tool") and (tool:FindFirstChild("GunServer") or tool:FindFirstChild("ShootGun") or tool:FindFirstChild("Shoot") or tool.Name:lower():find("gun") or tool.Name:lower():find("revolver") or tool.Name == "Party Popper") then
                    gun = tool
                    break
                end
            end
            if not gun and LocalPlayer:FindFirstChild("Backpack") then
                for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
                    if tool:IsA("Tool") and (tool:FindFirstChild("GunServer") or tool:FindFirstChild("ShootGun") or tool:FindFirstChild("Shoot") or tool.Name:lower():find("gun") or tool.Name:lower():find("revolver") or tool.Name == "Party Popper") then
                        tool.Parent = char
                        if hum then hum:EquipTool(tool) end
                        gun = tool
                        break
                    end
                end
            end
        end
    end
    if gun then
        local startPos = (char:FindFirstChild("RightHand") and char.RightHand.Position) or (char:FindFirstChild("Right Arm") and char["Right Arm"].Position) or (char:FindFirstChild("HumanoidRootPart") and char.HumanoidRootPart.Position) or (head and head.Position) or targetPos
        local argsLegacy = { 1, targetPos, "LF" }
        local argsModern = { CFrame.new(startPos), CFrame.new(targetPos) }
        local success = false
        local gunServer = gun:FindFirstChild("GunServer")
        if gunServer and gunServer:FindFirstChild("ShootStart") and gunServer.ShootStart:IsA("RemoteEvent") then
            gunServer.ShootStart:FireServer(targetPos)
            success = true
        elseif gun:FindFirstChild("GunScript_Server") and gun.GunScript_Server:FindFirstChild("InvokeServer") then
            task.spawn(function() pcall(function() gun.GunScript_Server.InvokeServer:InvokeServer(unpack(argsLegacy)) end) end)
            success = true
        elseif gun:FindFirstChild("KnifeLocal") and gun.KnifeLocal:FindFirstChild("CreateBeam") then
            task.spawn(function() pcall(function() gun.KnifeLocal.CreateBeam:InvokeServer(1, targetPos, "AH2") end) end)
            success = true
        else
            local shootRemote = gun:FindFirstChild("Shoot", true) or gun:FindFirstChild("ShootGun", true) or (gun:FindFirstChild("Events") and gun.Events:FindFirstChild("Shoot"))
            if shootRemote then
                if shootRemote:IsA("RemoteEvent") then
                    shootRemote:FireServer(unpack(argsModern))
                    success = true
                elseif shootRemote:IsA("RemoteFunction") then
                    task.spawn(function() pcall(function() shootRemote:InvokeServer(unpack(argsModern)) end) end)
                    success = true
                end
            else
                for _, obj in ipairs(gun:GetDescendants()) do
                    if obj:IsA("RemoteEvent") and (obj.Name == "Shoot" or obj.Name == "ShootGun") then
                        obj:FireServer(unpack(argsModern))
                        success = true
                        break
                    elseif obj:IsA("RemoteFunction") and (obj.Name == "Shoot" or obj.Name == "ShootGun") then
                        task.spawn(function() pcall(function() obj:InvokeServer(unpack(argsModern)) end) end)
                        success = true
                        break
                    end
                end
            end
        end
        if not success and eventsFolder and eventsFolder:FindFirstChild("ShootGun") then
            pcall(function() eventsFolder.ShootGun:FireServer(unpack(argsModern)) end)
            success = true
        end
        if success then
            lastShootTime = tick()
            if not silent then Notif:Notify("Shot at Bad Guy!", 2, "success") end
        else
            if not silent then Notif:Notify("Failed to find shoot remote!", 2, "error") end
        end
    else
        if not silent then Notif:Notify("Gun not found!", 2, "error") end
    end
end
task.spawn(function()
    while task.wait(0.1) do
        if State.AutoShootBadGuy then
            pcall(function() PerformShootBadGuy(true) end)
        end
    end
end)
local HttpService = game:GetService("HttpService")
local CONFIG_DIR = "MM2KidsConfigs"
if makefolder and not isfolder(CONFIG_DIR) then
    pcall(function() makefolder(CONFIG_DIR) end)
end
local function CleanConfigName(path)
    if not path or path == "" then return "" end
    local s = tostring(path)
    s = s:gsub(string.char(92), "/")
    s = s:gsub("%.json$", "")
    s = s:gsub(".*/", "")
    return s
end
local function GetConfigList()
    local list = {}
    local seen = {}
    if listfiles and isfolder and isfolder(CONFIG_DIR) then
        pcall(function()
            for _, path in ipairs(listfiles(CONFIG_DIR)) do
                if path:sub(-5) == ".json" then
                    local name = CleanConfigName(path)
                    if name ~= "" and name ~= "configs_index" and name ~= "autoload" and not seen[name] then
                        seen[name] = true
                        table.insert(list, name)
                    end
                end
            end
        end)
    end
    if not seen["default"] and isfile and (isfile(CONFIG_DIR .. "/default.json") or isfile("MM2KidsConfig.json")) then
        seen["default"] = true
        table.insert(list, "default")
    end
    if #list == 0 then
        table.insert(list, "default")
    end
    table.sort(list)
    return list
end
local function SaveConfigNamed(cfgName)
    local cleanName = CleanConfigName(cfgName)
    if cleanName == "" then cleanName = "default" end
    local config = {
        toggles = {},
        sliders = {},
        keybinds = {},
        selectors = {}
    }
    for name, element in pairs(State.Toggles) do
        pcall(function() config.toggles[name] = element:Get() end)
    end
    for name, element in pairs(State.Sliders) do
        pcall(function() config.sliders[name] = element:Get() end)
    end
    for name, element in pairs(State.Keybinds) do
        pcall(function() config.keybinds[name] = element:GetKey() end)
    end
    for name, element in pairs(State.Selectors) do
        if name ~= "Select Config" then
            pcall(function() config.selectors[name] = element:Get() end)
        end
    end
    local success, encoded = pcall(HttpService.JSONEncode, HttpService, config)
    if success then
        if makefolder and not isfolder(CONFIG_DIR) then
            pcall(function() makefolder(CONFIG_DIR) end)
        end
        local filePath = CONFIG_DIR .. "/" .. cleanName .. ".json"
        writefile(filePath, encoded)
        State.SelectedConfigName = cleanName
        State.CurrentConfigName = cleanName
        local list = GetConfigList()
        if State.ConfigDropdown then
            pcall(function() State.ConfigDropdown:UpdateOptions(list) end)
            pcall(function() State.ConfigDropdown:Set(cleanName) end)
        end
        Notif:Notify("Config '" .. cleanName .. "' Saved!", 2, "success")
    else
        Notif:Notify("Failed to encode config!", 2, "error")
    end
end
local function LoadConfigNamed(cfgName)
    local cleanName = CleanConfigName(cfgName)
    if cleanName == "" then cleanName = "default" end
    local filePath = CONFIG_DIR .. "/" .. cleanName .. ".json"
    if not isfile or not isfile(filePath) then
        if cleanName == "default" and isfile and isfile("MM2KidsConfig.json") then
            filePath = "MM2KidsConfig.json"
        else
            Notif:Notify("Config '" .. cleanName .. "' not found!", 2, "error")
            return
        end
    end
    local content = readfile(filePath)
    local success, config = pcall(HttpService.JSONDecode, HttpService, content)
    if not success or not config then
        Notif:Notify("Failed to parse config file!", 2, "error")
        return
    end
    if config.toggles then
        for name, value in pairs(config.toggles) do
            local element = State.Toggles[name]
            if element then
                pcall(function() element:Set(value) end)
            end
        end
    end
    if config.sliders then
        for name, value in pairs(config.sliders) do
            local element = State.Sliders[name]
            if element then
                pcall(function() element:Value(value) end)
            end
        end
    end
    if config.keybinds then
        for name, value in pairs(config.keybinds) do
            local element = State.Keybinds[name]
            if element then
                pcall(function() element:SetKey(value) end)
            end
        end
    end
    if config.selectors then
        for name, value in pairs(config.selectors) do
            if name ~= "Select Config" then
                local element = State.Selectors[name]
                if element then
                    pcall(function() element:Set(value) end)
                end
            end
        end
    end
    State.SelectedConfigName = cleanName
    if State.ConfigDropdown then
        pcall(function() State.ConfigDropdown:Set(cleanName) end)
    end
    Notif:Notify("Config '" .. cleanName .. "' Loaded!", 2, "success")
end
local AUTOLOAD_FILE = CONFIG_DIR .. "/autoload.txt"
local function SetAutoload(enabled)
    State.Autoload = enabled
    if enabled then
        local chosen = CleanConfigName(State.SelectedConfigName or State.CurrentConfigName or "default")
        if chosen == "" then chosen = "default" end
        if makefolder and not isfolder(CONFIG_DIR) then
            pcall(function() makefolder(CONFIG_DIR) end)
        end
        pcall(function() writefile(AUTOLOAD_FILE, chosen) end)
        Notif:Notify("Autoload set to '" .. chosen .. "'", 2, "success")
    else
        if isfile and isfile(AUTOLOAD_FILE) then
            pcall(function() delfile(AUTOLOAD_FILE) end)
        end
        Notif:Notify("Autoload disabled", 2, "information")
    end
end
local MainTab = Init:NewTab("Main")
local GameSection = MainTab:NewSection("Game Information")
local currentGameName = "Murder Mystery 2"
pcall(function()
    local MarketplaceService = game:GetService("MarketplaceService")
    local info = MarketplaceService:GetProductInfo(game.PlaceId)
    if info and info.Name then
        currentGameName = info.Name
    end
end)
MainTab:NewLabel("Game: " .. currentGameName)
MainTab:NewLabel("Place ID: " .. tostring(game.PlaceId))
MainTab:NewLabel("Player: " .. (LocalPlayer.DisplayName or LocalPlayer.Name))
local CreditsSection = MainTab:NewSection("Credits")
MainTab:NewLabel("dev: @Nexzan_Hub")
MainTab:NewLabel("UI Library: Arcane UI (Da7mu) x NEXZAN HUB")
MainTab:NewButton("Copy Discord Server", function()
    local copyFunc = setclipboard or toclipboard or set_clipboard or writeclipboard or (syn and syn.write_clipboard)
    if copyFunc then
        local success, err = pcall(function()
            copyFunc("https://discord.gg/yyWdWas8mx")
        end)
        if success then
            if Notif then
                Notif:Notify("Discord Server link copied to clipboard!", 2, "success")
            end
        else
            if Notif then
                Notif:Notify("Failed to copy link: " .. tostring(err), 3, "error")
            end
        end
    else
        if Notif then
            Notif:Notify("Your executor does not support clipboard copying!", 3, "error")
        end
    end
end)
local LocalTab = Init:NewTab("Local Player")
local VisualsTab = Init:NewTab("Visuals")
local CombatTab = Init:NewTab("Combat")
local FarmingTab = Init:NewTab("Farming")
local FlingTab = Init:NewTab("Fling")
local MiscTab = Init:NewTab("Misc")
local ConfigsTab = Init:NewTab("Configs")
local VisualsSection = VisualsTab:NewSection("ESP Settings")
State.Toggles["Enable Chams"] = VisualsTab:NewToggle("Enable Chams", false, function(value) State.Chams = value end)
State.Toggles["Enable Nametags"] = VisualsTab:NewToggle("Enable Nametags", false, function(value)
    State.Nametags = value
    if not value then
        for player, _ in pairs(State.NametagObjects) do
            RemovePlayerNametag(player)
        end
    end
end)
if not UserInputService.TouchEnabled then
    State.Toggles["Keybinds Widget"] = VisualsTab:NewToggle("Keybinds Widget", false, function(value)
        library:SetKeybindsWidgetVisible(value)
    end)
end
local ShaderSection = VisualsTab:NewSection("Shaders")
State.Toggles["Enable Shaders"] = VisualsTab:NewToggle("Enable Shaders", false, function(value) UpdateShaders(value) end)
local LocalSection = LocalTab:NewSection("Character")
State.Toggles["Noclip"] = LocalTab:NewToggle("Noclip", false, function(value) State.Noclip = value end)
State.Toggles["Infinite Jump"] = LocalTab:NewToggle("Infinite Jump", false, function(value) SetInfJump(value) end)
State.Toggles["Enable Walkspeed"] = LocalTab:NewToggle("Enable Walkspeed", false, function(value) State.WalkSpeedEnabled = value end)
State.Sliders["Walkspeed Amount"] = LocalTab:NewSlider("Walkspeed Amount", "", true, "/", {min = 16, max = 500, default = 16}, function(value) State.WalkSpeed = value end)
State.Toggles["TP Walk"] = LocalTab:NewToggle("TP Walk", false, function(value) UpdateTPWalk(value) end)
State.Sliders["TP Walk Speed"] = LocalTab:NewSlider("TP Walk Speed", "", true, "/", {min = 1, max = 50, default = 3}, function(value) State.TPWalkSpeed = value end)
State.Toggles["Bhop"] = LocalTab:NewToggle("Bhop", false, function(value) UpdateBhop(value) end)
State.Sliders["Bhop Speed"] = LocalTab:NewSlider("Bhop Speed", "", true, "/", {min = 16, max = 250, default = 50}, function(value) State.BhopSpeed = value end)
State.Toggles["Anti-AFK"] = LocalTab:NewToggle("Anti-AFK", false, function(value) State.AntiAfk = value end)
State.Toggles["Anti-Sit"] = LocalTab:NewToggle("Anti-Sit", false, function(value)
    State.AntiSit = value
    if not value and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):SetStateEnabled(Enum.HumanoidStateType.Seated, true)
    end
end)
State.Toggles["Anti-Fling"] = LocalTab:NewToggle("Anti-Fling", false, function(value) State.AntiFling = value end)
State.Toggles["Ctrl+Click TP"] = LocalTab:NewToggle("Ctrl+Click TP", false, function(value) State.CtrlClickTp = value end)
local CombatSection = CombatTab:NewSection("Combat Features")
State.Toggles["Auto Kill All"] = CombatTab:NewToggle("Auto Kill All", false, function(value) State.AutoKillAll = value end)
State.Toggles["Auto Grab Gun"] = CombatTab:NewToggle("Auto Grab Gun", false, function(value) State.AutoGrabGun = value end)
State.Toggles["Auto Shoot Bad Guy"] = CombatTab:NewToggle("Auto Shoot Bad Guy", false, function(value) State.AutoShootBadGuy = value end)
if not UserInputService.TouchEnabled then
    State.Toggles["Silent Aim (LMB)"] = CombatTab:NewToggle("Silent Aim (LMB)", false, function(value) State.SilentAim = value end)
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if State.SilentAim and input.UserInputType == Enum.UserInputType.MouseButton1 then
            if UserInputService:GetFocusedTextBox() == nil then
                pcall(function() PerformShootBadGuy(true) end)
            end
        end
    end)
end
local killBtns = CombatTab:NewButton("Kill All", PerformKillAll)
local killProtBtn = killBtns:AddButton("Kill Protector", PerformKillProtector)
local flingBtns = CombatTab:NewButton("Fling Bad Guy", PerformFlingBadGuy)
local flingProtBtn = flingBtns:AddButton("Fling Protector", PerformFlingProtector)
local gunBtns = CombatTab:NewButton("Grab Gun", PerformGrabGun)
local shootBtn = gunBtns:AddButton("Shoot Bad Guy", function() PerformShootBadGuy(false) end)
local KeybindsSection = CombatTab:NewSection("Keybinds")
State.Keybinds["Kill All Key"] = CombatTab:NewKeybind("Kill All Key", Enum.KeyCode.None, PerformKillAll)
State.Keybinds["Kill Protector Key"] = CombatTab:NewKeybind("Kill Protector Key", Enum.KeyCode.None, PerformKillProtector)
State.Keybinds["Fling Bad Guy Key"] = CombatTab:NewKeybind("Fling Bad Guy Key", Enum.KeyCode.None, PerformFlingBadGuy)
State.Keybinds["Fling Protector Key"] = CombatTab:NewKeybind("Fling Protector Key", Enum.KeyCode.None, PerformFlingProtector)
State.Keybinds["Grab Gun Key"] = CombatTab:NewKeybind("Grab Gun Key", Enum.KeyCode.None, PerformGrabGun)
State.Keybinds["Shoot Bad Guy Key"] = CombatTab:NewKeybind("Shoot Bad Guy Key", Enum.KeyCode.None, function() PerformShootBadGuy(false) end)
if UserInputService.TouchEnabled then
    CombatTab:NewToggle("Mobile Button: Kill All", false, function(v)
        if v then getgenv().CreateMobileButton("Kill All", nil, PerformKillAll) else getgenv().RemoveMobileButton("Kill All") end
    end)
    CombatTab:NewToggle("Mobile Button: Kill Protector", false, function(v)
        if v then getgenv().CreateMobileButton("Kill Protector", nil, PerformKillProtector) else getgenv().RemoveMobileButton("Kill Protector") end
    end)
    CombatTab:NewToggle("Mobile Button: Fling Bad Guy", false, function(v)
        if v then getgenv().CreateMobileButton("Fling Bad Guy", nil, PerformFlingBadGuy) else getgenv().RemoveMobileButton("Fling Bad Guy") end
    end)
    CombatTab:NewToggle("Mobile Button: Fling Protector", false, function(v)
        if v then getgenv().CreateMobileButton("Fling Protector", nil, PerformFlingProtector) else getgenv().RemoveMobileButton("Fling Protector") end
    end)
    CombatTab:NewToggle("Mobile Button: Grab Gun", false, function(v)
        if v then getgenv().CreateMobileButton("Grab Gun", nil, PerformGrabGun) else getgenv().RemoveMobileButton("Grab Gun") end
    end)
    CombatTab:NewToggle("Mobile Button: Shoot Bad Guy", false, function(v)
        if v then getgenv().CreateMobileButton("Shoot Bad Guy", nil, function() PerformShootBadGuy(false) end) else getgenv().RemoveMobileButton("Shoot Bad Guy") end
    end)
end
local PredSection = CombatTab:NewSection("Prediction Settings")
State.Toggles["Enable Prediction"] = CombatTab:NewToggle("Enable Prediction", true, function(value) State.ShootPrediction = value end)
State.Sliders["Prediction Factor"] = CombatTab:NewSlider("Prediction Factor", "%", true, "/", {min = 0, max = 200, default = 100}, function(value) State.PredictionAmount = value end)
State.Toggles["Ping Compensation"] = CombatTab:NewToggle("Ping Compensation", true, function(value) State.PingCompensation = value end)
State.Toggles["MoveDirection Boost"] = CombatTab:NewToggle("MoveDirection Boost", true, function(value) State.MoveDirPrediction = value end)
State.Toggles["Predict Y-Axis (Jumps)"] = CombatTab:NewToggle("Predict Y-Axis (Jumps)", true, function(value) State.PredictYAxis = value end)
State.Toggles["Wall Check"] = CombatTab:NewToggle("Wall Check", true, function(value) State.WallCheck = value end)
State.Selectors["Target Hitbox"] = CombatTab:NewSelector("Target Hitbox", "HumanoidRootPart", {"HumanoidRootPart", "Head", "UpperTorso", "Torso"}, function(value) State.HitboxTarget = value end)
local ResolverSection = CombatTab:NewSection("Resolver Settings")
State.Toggles["Enable Resolver"] = CombatTab:NewToggle("Enable Resolver", true, function(value) State.AntiAimResolver = value end)
State.Selectors["Resolver Mode"] = CombatTab:NewSelector("Resolver Mode", "Delta Calculation", {"Delta Calculation", "MoveDirection", "Zero Velocity"}, function(value) State.ResolverMode = value end)
State.Sliders["Max Velocity Clamp"] = CombatTab:NewSlider("Max Velocity Clamp", "", true, "/", {min = 16, max = 200, default = 65}, function(value) State.ResolverMaxVel = value end)
local FarmSection = FarmingTab:NewSection("Autofarm")
State.Toggles["Auto Farm"] = FarmingTab:NewToggle("Auto Farm", false, function(value) State.AutoCoins = value end)
local MiscSection = MiscTab:NewSection("Miscellaneous")
local function SetNotificationsDisabled(disabled)
    State.DisableNotifications = disabled
    if library then library.DisableNotifications = disabled end
    if getgenv then getgenv().DisableNotifications = disabled end
    pcall(function()
        local coreGui = game:GetService("CoreGui")
        local notifGui = coreGui:FindFirstChild("Notifications")
        if notifGui then
            notifGui.Enabled = not disabled
            if disabled then
                for _, child in ipairs(notifGui:GetChildren()) do
                    if child.Name == "edge" or child:IsA("Frame") then
                        child:Destroy()
                    end
                end
            end
        end
    end)
end
State.Toggles["Disable Notifications"] = MiscTab:NewToggle("Disable Notifications", false, function(value)
    SetNotificationsDisabled(value)
end)
State.Keybinds["GUI Toggle Key"] = MiscTab:NewKeybind("GUI Toggle Key", Enum.KeyCode.LeftAlt, function(keyName)
    if Enum.KeyCode[keyName] then
        library.ToggleKey = Enum.KeyCode[keyName]
    end
end)
local function PerformSafeTeleport()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        if not State.SafePlatform then
            State.SafePlatform = Instance.new("Part")
            State.SafePlatform.Name = "SafeMM2KidsPlatform"
            State.SafePlatform.Size = Vector3.new(50, 1, 50)
            State.SafePlatform.Position = Vector3.new(0, 500, 0)
            State.SafePlatform.Anchored = true
            State.SafePlatform.Parent = workspace
        end
        LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(0, 505, 0)
        Notif:Notify("Teleported to Safe Place", 2, "success")
    end
end
State.Toggles["Auto Teleport to Safe Place"] = MiscTab:NewToggle("Auto Teleport to Safe Place", false, function(value)
    State.AutoSafeTeleport = value
    if value then
        if not State.SafePlatform then
            State.SafePlatform = Instance.new("Part")
            State.SafePlatform.Name = "SafeMM2KidsPlatform"
            State.SafePlatform.Size = Vector3.new(50, 1, 50)
            State.SafePlatform.Position = Vector3.new(0, 500, 0)
            State.SafePlatform.Anchored = true
            State.SafePlatform.Parent = workspace
        end
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(State.SafeTeleportPos)
        end
    end
end)
State.Keybinds["Teleport to Safe Place Key"] = MiscTab:NewKeybind("Teleport to Safe Place Key", Enum.KeyCode.None, PerformSafeTeleport)
MiscTab:NewButton("Teleport to Lobby", function()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(-3, -42, 12)
        Notif:Notify("Teleported to Lobby", 2, "success")
    end
end)
MiscTab:NewButton("Teleport to Map", function()
    local map = workspace:FindFirstChild("CurrentMap")
    if map then
        local spawns = map:FindFirstChild("Spawns", true)
        if spawns then
            local spawnsList = spawns:GetChildren()
            if #spawnsList > 0 then
                local randomSpawn = spawnsList[math.random(1, #spawnsList)]
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    LocalPlayer.Character.HumanoidRootPart.CFrame = randomSpawn.CFrame + Vector3.new(0, 3, 0)
                    Notif:Notify("Teleported to Map!", 2, "success")
                end
                return
            end
        end
    end
    Notif:Notify("Map or spawns not found!", 2, "error")
end)
State.Toggles["Auto Remove Toy Cars"] = MiscTab:NewToggle("Auto Remove Toy Cars", false, function(value)
    State.AutoRemoveCars = value
    if value then
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj.Name == "Toy Car" or obj.Name == "ToyCar" or obj.Name == "Car" then
                pcall(function() obj:Destroy() end)
            end
        end
    end
end)
State.Toggles["Anti Gameplay Paused"] = MiscTab:NewToggle("Anti Gameplay Paused", false, function(value)
    State.AntiGameplayPaused = value
    pcall(function()
        game:GetService("GuiService"):SetGameplayPausedNotificationEnabled(not value)
    end)
    if value then
    end
end)
workspace.DescendantAdded:Connect(function(obj)
    if State.AutoRemoveCars and (obj.Name == "Toy Car" or obj.Name == "ToyCar" or obj.Name == "Car") then
        task.wait()
        pcall(function() obj:Destroy() end)
    end
end)
MiscTab:NewButton("Teleport to Safe Place", PerformSafeTeleport)
MiscTab:NewButton("Send Protector Name", SendProtectorToChat)
MiscTab:NewButton("Send Bad Guy Name", SendBadGuyToChat)
MiscTab:NewButton("Copy Discord Server", function()
    local copyFunc = setclipboard or toclipboard or set_clipboard or writeclipboard or (syn and syn.write_clipboard)
    if copyFunc then
        local success, err = pcall(function()
            copyFunc("https://discord.gg/yyWdWas8mx")
        end)
        if success then
            if Notif then
                Notif:Notify("Discord Server link copied to clipboard!", 2, "success")
            end
        else
            if Notif then
                Notif:Notify("Failed to copy link: " .. tostring(err), 3, "error")
            end
        end
    else
        if Notif then
            Notif:Notify("Your executor does not support clipboard copying!", 3, "error")
        end
    end
end)
local ConfigSection = ConfigsTab:NewSection("Configurations")
State.NewConfigName = "default"
State.SelectedConfigName = "default"
local configList = GetConfigList()
ConfigsTab:NewTextbox("New Config Name", "default", "Enter name...", "all", "small", true, false, function(value)
    State.NewConfigName = CleanConfigName(value)
end)
ConfigsTab:NewButton("Create Config", function()
    local nameToCreate = CleanConfigName(State.NewConfigName)
    if nameToCreate == "" then nameToCreate = "default" end
    SaveConfigNamed(nameToCreate)
    State.SelectedConfigName = nameToCreate
    if State.ConfigDropdown then
        State.ConfigDropdown:UpdateOptions(GetConfigList())
        State.ConfigDropdown:Set(nameToCreate)
    end
end)
State.ConfigDropdown = ConfigsTab:NewSelector("Select Config", configList[1] or "default", configList, function(value)
    State.SelectedConfigName = CleanConfigName(value)
end)
State.Selectors["Select Config"] = State.ConfigDropdown
ConfigsTab:NewButton("Save Config", function()
    local nameToSave = CleanConfigName(State.SelectedConfigName)
    if nameToSave == "" then nameToSave = "default" end
    SaveConfigNamed(nameToSave)
end)
ConfigsTab:NewButton("Load Config", function()
    local nameToLoad = CleanConfigName(State.SelectedConfigName)
    if nameToLoad == "" then nameToLoad = "default" end
    LoadConfigNamed(nameToLoad)
end)
ConfigsTab:NewButton("Delete Config", function()
    local cleanName = CleanConfigName(State.SelectedConfigName or "default")
    if cleanName == "" then cleanName = "default" end
    local filePath = CONFIG_DIR .. "/" .. cleanName .. ".json"
    if isfile and isfile(filePath) then
        pcall(function() delfile(filePath) end)
        local list = GetConfigList()
        if State.ConfigDropdown then
            pcall(function() State.ConfigDropdown:UpdateOptions(list) end)
            if #list > 0 then
                State.ConfigDropdown:Set(list[1])
                State.SelectedConfigName = list[1]
            end
        end
        Notif:Notify("Deleted config '" .. cleanName .. "'", 2, "information")
    else
        Notif:Notify("Config file not found to delete!", 2, "error")
    end
end)
State.AutoloadToggle = ConfigsTab:NewToggle("Autoload Config", false, function(value)
    SetAutoload(value)
end)
local function GetFormattedName(player)
    local char = player.Character
    local function checkAttr(name)
        if player:GetAttribute(name) == true then return true end
        if char and char:GetAttribute(name) == true then return true end
        return false
    end
    local hasGun = false
    if char then
        for _, obj in pairs(char:GetChildren()) do
            if obj:IsA("Tool") and obj:FindFirstChild("GunServer") then hasGun = true break end
        end
    end
    if not hasGun and player:FindFirstChild("Backpack") then
        for _, obj in pairs(player.Backpack:GetChildren()) do
            if obj:IsA("Tool") and obj:FindFirstChild("GunServer") then hasGun = true break end
        end
    end
    if checkAttr("murderer") or checkAttr("Murderer") or checkAttr("murder") then
        return '<font color="#FF0000">' .. player.Name .. '</font>'
    elseif checkAttr("innocent") or checkAttr("Innocent") or checkAttr("inocent") then
        return '<font color="#00FF00">' .. player.Name .. '</font>'
    elseif checkAttr("sheriff") or checkAttr("Sheriff") or checkAttr("sherif") or hasGun then
        return '<font color="#0096FF">' .. player.Name .. '</font>'
    end
    return '<font color="#808080">' .. player.Name .. '</font>'
end
local TouchSection = FlingTab:NewSection("Touch Fling")
State.Toggles["Touch Fling"] = FlingTab:NewToggle("Touch Fling", false, function(value)
    UpdateTouchFling(value)
end)
local FlingSection = FlingTab:NewSection("Fling Player")
local initialList = {}
for _, p in pairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then
        table.insert(initialList, GetFormattedName(p))
    end
end
if #initialList == 0 then table.insert(initialList, "No Players") end
local FlingDropdown = FlingTab:NewSelector("Select Player", initialList[1] or "No Players", initialList, function(value)
    local rawName = value:gsub("<[^>]+>", ""):gsub("%[.-%]%s*", "")
    State.FlingTargetName = rawName
end)
State.Selectors["Select Fling Player"] = FlingDropdown
FlingTab:NewButton("Execute Fling", ExecuteFling)
local function UpdateFlingDropdown()
    local list = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            table.insert(list, GetFormattedName(p))
        end
    end
    pcall(function() FlingDropdown:UpdateOptions(list) end)
end
UpdateFlingDropdown()
local lastRoles = {}
task.spawn(function()
    while task.wait(1) do
        local changed = false
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local currentRole = GetFormattedName(p)
                if lastRoles[p.Name] ~= currentRole then
                    lastRoles[p.Name] = currentRole
                    changed = true
                end
            end
        end
        if changed then
            UpdateFlingDropdown()
        end
    end
end)
Players.PlayerAdded:Connect(function()
    task.wait(1)
    UpdateFlingDropdown()
end)
Players.PlayerRemoving:Connect(function()
    task.wait(0.5)
    UpdateFlingDropdown()
end)
if isfile and isfile(AUTOLOAD_FILE) then
    local autoName = CleanConfigName(readfile(AUTOLOAD_FILE))
    if autoName ~= "" then
        pcall(function() if State.AutoloadToggle then State.AutoloadToggle:Set(true) end end)
        task.spawn(function()
            task.wait(1)
            LoadConfigNamed(autoName)
        end)
    end
end
Notif:Notify("NEXZAN HUB Loaded Successfully", 3, "success")