--============================================================================--
-- Utilities: Force Sprint + ESP + Fullbright + Auto-Exit + Force Hidden
--============================================================================--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

print("[Script] Loading...")

-- ---- Shared state ----
local forceSprint = false
local espEnabled = false
local fullbrightEnabled = false
local autoExitWardrobe = false
local forceHidden = false
local hideExitUI = false
local ESP_Targets = {}

-- ---- Refs ----
local MovementState = ReplicatedStorage:FindFirstChild("MovementState")
local ArmadiRemotes = ReplicatedStorage:FindFirstChild("ArmadiRemotes")
local ExitRemote = ArmadiRemotes and ArmadiRemotes:FindFirstChild("EsciArmadio")
local ArmadioGui = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("ArmadioGui")

if not MovementState then warn("MovementState missing – force sprint may not work") end
if not ExitRemote then warn("EsciArmadio remote not found – auto-exit disabled") end

-- ---- Force Sprint ----
RunService.Heartbeat:Connect(function()
    if forceSprint and MovementState then
        pcall(function()
            MovementState:FireServer("sprint")
            LocalPlayer:SetAttribute("StaminaVuota", false)
        end)
    end
end)

-- ---- Force Hidden ----
RunService.Heartbeat:Connect(function()
    if forceHidden then
        LocalPlayer:SetAttribute("Nascosto", true)
        if hideExitUI and ArmadioGui then
            ArmadioGui.Enabled = false
        end
    else
        -- optionally revert if we want, but we'll leave it as is unless toggled off
        -- we can set it to false when toggled off (handled in callback)
    end
end)

-- ---- Fullbright ----
local function setFullbright(on)
    if on then
        Lighting.Brightness = 1
        Lighting.Ambient = Color3.new(1,1,1)
        Lighting.OutdoorAmbient = Color3.new(1,1,1)
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 10000
        Lighting.FogStart = 0
    else
        Lighting.Brightness = 0.5
        Lighting.Ambient = Color3.fromRGB(128,128,128)
        Lighting.OutdoorAmbient = Color3.fromRGB(128,128,128)
        Lighting.GlobalShadows = true
        Lighting.FogEnd = 1000
        Lighting.FogStart = 0
    end
end

-- ---- ESP (Drawing-based) ----
local DrawingAvailable = pcall(function() return Drawing.new("Square") end)

if DrawingAvailable then
    local function AddESP(instance)
        local box = Drawing.new("Square")
        local text = Drawing.new("Text")
        box.Visible = false
        box.Color = Color3.fromRGB(255,25,25)
        box.Thickness = 1.5
        text.Visible = false
        text.Color = Color3.fromRGB(255,25,25)
        text.Size = 13
        text.Center = true
        text.Outline = true
        text.Font = 2
        table.insert(ESP_Targets, {Instance=instance, Box=box, Text=text})
    end

    RunService.RenderStepped:Connect(function()
        if not espEnabled then
            for _, t in ipairs(ESP_Targets) do
                t.Box.Visible = false
                t.Text.Visible = false
            end
            return
        end
        for _, t in ipairs(ESP_Targets) do
            local inst = t.Instance
            if not inst or not inst.Parent then
                t.Box.Visible = false
                t.Text.Visible = false
            else
                local part = inst:IsA("Model") and (inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart")) or inst
                if part and part:IsA("BasePart") then
                    local pos, onScreen = Camera:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local dist = (Camera.CFrame.Position - part.Position).Magnitude
                        local size = 1000 / dist
                        local sx, sy = 4*size, 6*size
                        t.Box.Size = Vector2.new(sx, sy)
                        t.Box.Position = Vector2.new(pos.X - sx/2, pos.Y - sy/2)
                        t.Box.Visible = true
                        t.Text.Text = string.format("LOCUST [%d]", math.floor(dist))
                        t.Text.Position = Vector2.new(pos.X, pos.Y - sy/2 - 15)
                        t.Text.Visible = true
                    else
                        t.Box.Visible = false
                        t.Text.Visible = false
                    end
                else
                    t.Box.Visible = false
                    t.Text.Visible = false
                end
            end
        end
    end)

    task.spawn(function()
        while true do
            if espEnabled then
                local model = Workspace:FindFirstChild("TheLocust")
                if model then
                    local already = false
                    for _, t in ipairs(ESP_Targets) do
                        if t.Instance == model then already = true; break end
                    end
                    if not already then
                        AddESP(model)
                    end
                end
            end
            task.wait(2)
        end
    end)
else
    print("[ESP] Drawing not supported – ESP disabled")
end

-- ---- Auto-Exit Wardrobe ----
if ExitRemote then
    LocalPlayer:GetAttributeChangedSignal("Nascosto"):Connect(function()
        if autoExitWardrobe and LocalPlayer:GetAttribute("Nascosto") == true then
            task.wait(0.1)
            ExitRemote:FireServer()
            print("[Auto-Exit] Fired remote")
        end
    end)
end

-- Manual exit key (F)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F and ExitRemote then
        if LocalPlayer:GetAttribute("Nascosto") == true then
            ExitRemote:FireServer()
            print("[Manual Exit] Fired remote")
        end
    end
end)

-- ---- Load Obsidian ----
local Library, ThemeManager, SaveManager
local obsidianLoaded = false

local function tryLoadObsidian(repo)
    print("[Obsidian] Trying repo: " .. repo)
    local ok, lib = pcall(function()
        return loadstring(game:HttpGet(repo .. "Library.lua"))()
    end)
    if not ok or not lib then
        warn("[Obsidian] Library load failed:", ok and "lib is nil" or "error: " .. tostring(ok))
        return false
    end
    Library = lib
    _G.Library = lib

    ok, tm = pcall(function()
        return loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
    end)
    if not ok or not tm then
        warn("[Obsidian] ThemeManager load failed")
        return false
    end
    ThemeManager = tm

    ok, sm = pcall(function()
        return loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()
    end)
    if not ok or not sm then
        warn("[Obsidian] SaveManager load failed")
        return false
    end
    SaveManager = sm
    return true
end

local repos = {
    "https://raw.githubusercontent.com/Krissyylol/Obsidian/main/",
    "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/",
    "https://raw.githubusercontent.com/violin-suzuki/Obsidian/main/",
}

for _, repo in ipairs(repos) do
    if tryLoadObsidian(repo) then
        obsidianLoaded = true
        print("[Obsidian] Loaded successfully from " .. repo)
        break
    end
end

if not obsidianLoaded then
    warn("[Obsidian] All repos failed – using fallback UI.")
end

-- ---- Build UI ----
if obsidianLoaded and Library then
    local Window
    local createOk, err = pcall(function()
        Window = Library:CreateWindow({
            Title = "Utilities",
            Footer = "Force Sprint | ESP | Auto-Exit | Force Hidden",
            NotifySide = "Right",
            ShowCustomCursor = true,
            MobileButtonsSide = "Right",
        })
    end)
    if not createOk or not Window then
        warn("[Obsidian] Window creation failed:", err or "Window is nil")
        obsidianLoaded = false
    else
        print("[Obsidian] Window created")
        Window:Toggle()

        local MainTab = Window:AddTab("Main", "gauge")

        -- Sprint
        local SprintGroup = MainTab:AddGroupbox({ Side = "Left", Name = "Sprint", IconName = "run" })
        SprintGroup:AddToggle("ForceSprintToggle", {
            Text = "Force Sprint (infinite stamina)",
            Default = false,
            Callback = function(v) forceSprint = v end,
        })

        -- Wardrobe
        local WardrobeGroup = MainTab:AddGroupbox({ Side = "Right", Name = "Wardrobe", IconName = "door" })
        WardrobeGroup:AddToggle("AutoExitToggle", {
            Text = "Auto-Exit Wardrobe (when hidden)",
            Default = false,
            Callback = function(v) autoExitWardrobe = v end,
        })
        WardrobeGroup:AddButton({
            Text = "Exit Now (F key also works)",
            Func = function()
                if ExitRemote and LocalPlayer:GetAttribute("Nascosto") == true then
                    ExitRemote:FireServer()
                    print("[Manual Exit] Fired via button")
                else
                    print("Not hidden or remote missing")
                end
            end
        })

        -- Hidden
        local HiddenGroup = MainTab:AddGroupbox({ Side = "Left", Name = "Hidden", IconName = "eye-off" })
        HiddenGroup:AddToggle("ForceHiddenToggle", {
            Text = "Force Hidden (invisible)",
            Default = false,
            Callback = function(v)
                forceHidden = v
                if not v then
                    LocalPlayer:SetAttribute("Nascosto", false) -- revert when off
                    if ArmadioGui then ArmadioGui.Enabled = true end
                end
            end
        })
        HiddenGroup:AddToggle("HideExitUI", {
            Text = "Hide Exit UI when forced",
            Default = false,
            Callback = function(v) hideExitUI = v end
        })
        HiddenGroup:AddButton({
            Text = "Unhide Now (reset attribute)",
            Func = function()
                forceHidden = false
                LocalPlayer:SetAttribute("Nascosto", false)
                if ArmadioGui then ArmadioGui.Enabled = true end
                -- also update toggle state in UI if we can
                -- we'll just let user toggle off manually
            end
        })

        -- Visuals Tab
        local VisualsTab = Window:AddTab("Visuals", "eye")
        local ESPGroup = VisualsTab:AddGroupbox({ Side = "Left", Name = "LOCUST ESP", IconName = "target" })
        ESPGroup:AddToggle("ESPToggle", {
            Text = "Enable Locust ESP",
            Default = false,
            Callback = function(v) espEnabled = v end,
        })

        local FBGroup = VisualsTab:AddGroupbox({ Side = "Right", Name = "Fullbright", IconName = "sun" })
        FBGroup:AddToggle("FullbrightToggle", {
            Text = "Enable Fullbright",
            Default = false,
            Callback = function(v) fullbrightEnabled = v; setFullbright(v) end,
        })

        -- UI Settings
        local UISettingsTab = Window:AddTab("UI Settings", "settings")
        local ThemeGroup = UISettingsTab:AddGroupbox({ Side = "Left", Name = "Theme" })
        ThemeManager:AddThemePickerToGroupbox(ThemeGroup)

        local SaveGroup = UISettingsTab:AddGroupbox({ Side = "Right", Name = "Save/Load" })
        SaveGroup:AddButton({ Text = "Save Config", Func = function() SaveManager:Save() end })
        SaveGroup:AddButton({ Text = "Load Config", Func = function() SaveManager:Load() end })

        Library:AddKeybind({
            Name = "ToggleMenu",
            Default = Enum.KeyCode.RightShift,
            OnPress = function() Window:Toggle() end,
        })

        SaveManager:SetFolder("UtilityScript")
        SaveManager:BuildConfigTable({
            Toggles = {
                ForceSprintToggle = true,
                AutoExitToggle = true,
                ForceHiddenToggle = true,
                HideExitUI = true,
                ESPToggle = true,
                FullbrightToggle = true,
            },
        })
        SaveManager:Load()

        print("[Obsidian UI] Ready. RightShift to toggle.")
    end
end

-- ---- Fallback UI ----
if not obsidianLoaded then
    print("[Fallback UI] Loading manual interface...")
    local gui = Instance.new("ScreenGui")
    gui.Name = "UtilityPanel"
    gui.ResetOnSpawn = false
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 280, 0, 380)
    frame.Position = UDim2.new(1, -300, 0, 60)
    frame.BackgroundColor3 = Color3.fromRGB(18,18,22)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0,10)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1,0,0,30)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.Text = "UTILITIES"
    title.TextSize = 13
    title.TextColor3 = Color3.fromRGB(220,70,70)
    title.Parent = frame

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -16, 1, -60)
    scroll.Position = UDim2.fromOffset(8, 34)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
    scroll.CanvasSize = UDim2.new()
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = frame
    local layout = Instance.new("UIListLayout", scroll)
    layout.Padding = UDim.new(0,4)
    layout.SortOrder = Enum.SortOrder.LayoutOrder

    local function addToggle(label, initial, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -8, 0, 26)
        btn.BackgroundColor3 = Color3.fromRGB(32,32,40)
        btn.Font = Enum.Font.Gotham
        btn.Text = label .. (initial and " [ON]" or " [OFF]")
        btn.TextSize = 12
        btn.TextColor3 = Color3.fromRGB(235,235,240)
        btn.AutoButtonColor = true
        btn.Parent = scroll
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)
        local state = initial
        btn.Activated:Connect(function()
            state = not state
            btn.Text = label .. (state and " [ON]" or " [OFF]")
            callback(state)
        end)
        return btn
    end

    addToggle("Force Sprint", false, function(v) forceSprint = v end)
    addToggle("Auto-Exit Wardrobe", false, function(v) autoExitWardrobe = v end)
    addToggle("Force Hidden", false, function(v)
        forceHidden = v
        if not v then
            LocalPlayer:SetAttribute("Nascosto", false)
            if ArmadioGui then ArmadioGui.Enabled = true end
        end
    end)
    addToggle("Hide Exit UI", false, function(v) hideExitUI = v end)
    addToggle("Locust ESP", false, function(v) espEnabled = v end)
    addToggle("Fullbright", false, function(v) fullbrightEnabled = v; setFullbright(v) end)

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(1, -16, 0, 30)
    closeBtn.Position = UDim2.new(0, 8, 1, -36)
    closeBtn.BackgroundColor3 = Color3.fromRGB(40,40,50)
    closeBtn.Font = Enum.Font.Gotham
    closeBtn.Text = "Close Panel"
    closeBtn.TextSize = 12
    closeBtn.TextColor3 = Color3.fromRGB(235,235,240)
    closeBtn.Parent = frame
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0,6)
    closeBtn.Activated:Connect(function() gui.Enabled = false end)

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.RightShift then
            gui.Enabled = not gui.Enabled
        end
    end)

    print("[Fallback UI] Loaded. RightShift to toggle.")
end

print("[Script] Ready – RightShift to open UI, F to exit wardrobe.")