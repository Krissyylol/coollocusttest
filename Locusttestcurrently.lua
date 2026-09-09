--============================================================================--
-- Speed Script + Locust ESP + Fullbright
-- Tries Obsidian (Krissyylol) first, falls back to manual GUI if needed.
--============================================================================--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ---- Try loading Obsidian (correct repo) ----
local Library, ThemeManager, SaveManager
local useObsidian = false

local function loadObsidian()
    local repo = "https://raw.githubusercontent.com/Krissyylol/Obsidian/main/"
    local success, lib = pcall(function()
        return loadstring(game:HttpGet(repo .. "Library.lua"))()
    end)
    if success and lib then
        Library = lib
        ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
        SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()
        return true
    end
    return false
end

local obsidianLoaded = loadObsidian()

-- ---- Shared state ----
local speedEnabled = false
local speedBonus = 100
local sprintBonus = 100
local multiplier = 3
local forceStateEnabled = false
local forcedState = "Sliding"
local isMoving = false

local espEnabled = false
local fullbrightEnabled = false
local ESP_Targets = {}
local BOSS_NAME = "TheLocust"
local THEME_COLOR = Color3.fromRGB(255, 25, 25)

-- ---- Refs ----
local GameConfig = ReplicatedStorage:WaitForChild("GameConfig", 180)
local MovementState = ReplicatedStorage:WaitForChild("MovementState", 20)

-- ---- Hook MovementState (logging) ----
if MovementState then
    local oldFire
    oldFire = hookfunction(MovementState.FireServer, function(self, ...)
        local args = {...}
        print("[MovementState]", table.unpack(args))
        return oldFire(self, ...)
    end)
end

-- ---- Speed functions ----
local function applySpeed()
    if not GameConfig then return end
    if speedEnabled then
        GameConfig:SetAttribute("BonusVelocita", speedBonus)
        GameConfig:SetAttribute("BonusSprint", sprintBonus)
        LocalPlayer:SetAttribute("SpeedMultiplier", multiplier)
    else
        GameConfig:SetAttribute("BonusVelocita", 0)
        GameConfig:SetAttribute("BonusSprint", 0)
        LocalPlayer:SetAttribute("SpeedMultiplier", 1)
    end
end

if GameConfig then
    GameConfig:GetAttributeChangedSignal("BonusVelocita"):Connect(function()
        if speedEnabled then GameConfig:SetAttribute("BonusVelocita", speedBonus) end
    end)
    GameConfig:GetAttributeChangedSignal("BonusSprint"):Connect(function()
        if speedEnabled then GameConfig:SetAttribute("BonusSprint", sprintBonus) end
    end)
end

local function forceState(state)
    if MovementState and forceStateEnabled and state then
        pcall(function() MovementState:FireServer(state) end)
    end
end

-- Movement detection
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    local key = input.KeyCode
    if key == Enum.KeyCode.W or key == Enum.KeyCode.A or key == Enum.KeyCode.S or key == Enum.KeyCode.D then
        isMoving = true
    end
end)
UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    local key = input.KeyCode
    if key == Enum.KeyCode.W or key == Enum.KeyCode.A or key == Enum.KeyCode.S or key == Enum.KeyCode.D then
        local stillMoving = false
        for _, k in ipairs({Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D}) do
            if UserInputService:IsKeyDown(k) then stillMoving = true; break end
        end
        if not stillMoving then isMoving = false end
    end
end)

RunService.Heartbeat:Connect(function()
    if forceStateEnabled and isMoving and speedEnabled then
        forceState(forcedState)
    end
end)

-- ---- Fullbright ----
local function setFullbright(on)
    if on then
        Lighting.Brightness = 1
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 10000
        Lighting.FogStart = 0
    else
        Lighting.Brightness = 0.5
        Lighting.Ambient = Color3.fromRGB(128, 128, 128)
        Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
        Lighting.GlobalShadows = true
        Lighting.FogEnd = 1000
        Lighting.FogStart = 0
    end
end

-- ---- ESP ----
local function CreateDrawing(type)
    local success, obj = pcall(function() return Drawing.new(type) end)
    return success and obj or nil
end

local function AddCustomESP(instance, displayName, displayColor)
    if not instance then return end
    local box = CreateDrawing("Square")
    local text = CreateDrawing("Text")
    if not box or not text then return end

    box.Visible = false
    box.Color = displayColor or Color3.fromRGB(255, 255, 255)
    box.Thickness = 1.5

    text.Visible = false
    text.Color = displayColor or Color3.fromRGB(255, 255, 255)
    text.Size = 13
    text.Center = true
    text.Outline = true
    text.Font = 2

    local data = {
        Instance = instance,
        Box = box,
        Text = text,
        Name = displayName,
        Connection = nil,
    }

    data.Connection = instance.AncestryChanged:Connect(function(_, parent)
        if not parent then
            pcall(function() box:Remove() end)
            pcall(function() text:Remove() end)
            data.Connection:Disconnect()
            for i, target in ipairs(ESP_Targets) do
                if target.Instance == instance then
                    table.remove(ESP_Targets, i)
                    break
                end
            end
        end
    end)

    table.insert(ESP_Targets, data)
end

local function ClearESP()
    for _, target in ipairs(ESP_Targets) do
        pcall(function() target.Box:Remove() end)
        pcall(function() target.Text:Remove() end)
        if target.Connection then pcall(function() target.Connection:Disconnect() end) end
    end
    ESP_Targets = {}
end

RunService.RenderStepped:Connect(function()
    if not espEnabled then
        for _, target in ipairs(ESP_Targets) do
            target.Box.Visible = false
            target.Text.Visible = false
        end
        return
    end

    for _, target in ipairs(ESP_Targets) do
        local inst = target.Instance
        local part = inst:IsA("Model") and (inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart")) or inst

        if part and part:IsA("BasePart") then
            local vector, onScreen = Camera:WorldToViewportPoint(part.Position)

            if onScreen then
                local distance = (Camera.CFrame.Position - part.Position).Magnitude
                local factor = 1000 / distance
                local sizeX, sizeY = 4 * factor, 6 * factor

                target.Box.Size = Vector2.new(sizeX, sizeY)
                target.Box.Position = Vector2.new(vector.X - sizeX / 2, vector.Y - sizeY / 2)
                target.Box.Visible = true

                target.Text.Text = string.format("%s [%d Studs]", target.Name, math.floor(distance))
                target.Text.Position = Vector2.new(vector.X, vector.Y - (sizeY / 2) - 15)
                target.Text.Visible = true
            else
                target.Box.Visible = false
                target.Text.Visible = false
            end
        else
            target.Box.Visible = false
            target.Text.Visible = false
        end
    end
end)

task.spawn(function()
    while true do
        if espEnabled then
            local model = Workspace:FindFirstChild(BOSS_NAME)
            local alreadyTracked = false
            for _, target in ipairs(ESP_Targets) do
                if target.Instance == model then
                    alreadyTracked = true
                    break
                end
            end

            if model and model:IsA("Model") and not alreadyTracked then
                AddCustomESP(model, "THE LOCUST", THEME_COLOR)
            end
        end
        task.wait(1)
    end
end)

-- ---- Build UI (Obsidian or fallback) ----
if obsidianLoaded and Library then
    -- ==================== OBSIDIAN UI ====================
    local Window = Library:CreateWindow({
        Title = "Speed + ESP",
        Footer = "State Forcing | Locust ESP",
        NotifySide = "Right",
        ShowCustomCursor = true,
        MobileButtonsSide = "Right",
    })

    local MainTab = Window:AddTab("Main", "gauge")
    local SpeedGroup = MainTab:AddGroupbox({ Side = "Left", Name = "Speed Control", IconName = "rocket" })

    SpeedGroup:AddToggle("SpeedToggle", {
        Text = "Enable Speed Boost",
        Default = false,
        Callback = function(v)
            speedEnabled = v
            applySpeed()
            Library:Notify({ Title = "Speed", Description = v and "Enabled" or "Disabled", Duration = 2 })
        end,
    })
    SpeedGroup:AddSlider("SpeedBonus", {
        Text = "Speed Bonus",
        Default = 100, Min = 0, Max = 500, Rounding = 1,
        Callback = function(v) speedBonus = v; if speedEnabled then applySpeed() end end,
    })
    SpeedGroup:AddSlider("SprintBonus", {
        Text = "Sprint Bonus",
        Default = 100, Min = 0, Max = 300, Rounding = 1,
        Callback = function(v) sprintBonus = v; if speedEnabled then applySpeed() end end,
    })
    SpeedGroup:AddSlider("Multiplier", {
        Text = "Speed Multiplier",
        Default = 3, Min = 1, Max = 10, Rounding = 1,
        Callback = function(v) multiplier = v; if speedEnabled then applySpeed() end end,
    })

    local StateGroup = MainTab:AddGroupbox({ Side = "Right", Name = "State Forcing", IconName = "refresh" })
    StateGroup:AddToggle("ForceStateToggle", {
        Text = "Force Movement State",
        Default = false,
        Callback = function(v)
            forceStateEnabled = v
            Library:Notify({ Title = "State", Description = v and "Forcing ON" or "Forcing OFF", Duration = 2 })
        end,
    })
    StateGroup:AddDropdown("StateSelect", {
        Text = "State to Force",
        Default = "Sliding",
        Values = {"Sliding", "Sprinting", "Walking", "Crouching", "Falling"},
        Callback = function(v) forcedState = v end,
    })
    StateGroup:AddButton({
        Text = "Send State Now",
        Func = function()
            if MovementState then MovementState:FireServer(forcedState) end
            Library:Notify({ Title = "State Sent", Description = forcedState, Duration = 2 })
        end,
    })

    -- Visuals Tab
    local VisualsTab = Window:AddTab("Visuals", "eye")
    local ESPGroup = VisualsTab:AddGroupbox({ Side = "Left", Name = "LOCUST ESP", IconName = "target" })
    ESPGroup:AddToggle("ESPToggle", {
        Text = "Enable Locust ESP",
        Default = false,
        Callback = function(v)
            espEnabled = v
            if not v then ClearESP() end
            Library:Notify({ Title = "ESP", Description = v and "Enabled" or "Disabled", Duration = 2 })
        end,
    })
    ESPGroup:AddButton({
        Text = "Refresh ESP",
        Func = function()
            if espEnabled then ClearESP() else Library:Notify({ Title = "ESP", Description = "Enable ESP first", Duration = 2 }) end
        end,
    })

    -- Fullbright
    local FBGroup = VisualsTab:AddGroupbox({ Side = "Right", Name = "Fullbright", IconName = "sun" })
    FBGroup:AddToggle("FullbrightToggle", {
        Text = "Enable Fullbright",
        Default = false,
        Callback = function(v)
            fullbrightEnabled = v
            setFullbright(v)
            Library:Notify({ Title = "Fullbright", Description = v and "On" or "Off", Duration = 2 })
        end,
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

    SaveManager:SetFolder("SpeedESP")
    SaveManager:BuildConfigTable({
        Toggles = { SpeedToggle = true, ForceStateToggle = true, ESPToggle = true, FullbrightToggle = true },
        Options = { SpeedBonus = true, SprintBonus = true, Multiplier = true, StateSelect = true },
    })
    SaveManager:Load()

    print("[Obsidian UI] Loaded. RightShift to toggle.")
else
    -- ==================== FALLBACK MANUAL UI ====================
    local gui = Instance.new("ScreenGui")
    gui.Name = "SpeedESPUI"
    gui.ResetOnSpawn = false
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 320, 0, 480)
    frame.Position = UDim2.new(0.5, -160, 0.5, -240)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    frame.BackgroundTransparency = 0.15
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.Text = "Speed + ESP"
    title.TextSize = 16
    title.TextColor3 = Color3.fromRGB(255, 200, 100)
    title.Parent = frame

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -10, 1, -50)
    scroll.Position = UDim2.new(0, 5, 0, 35)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.ScrollBarThickness = 4
    scroll.Parent = frame

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = scroll

    -- Helpers
    local function addSection(text)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, 22)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamBold
        lbl.Text = text
        lbl.TextSize = 13
        lbl.TextColor3 = Color3.fromRGB(240, 180, 60)
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = scroll
        return lbl
    end

    local function addToggle(label, initial, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -8, 0, 30)
        btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
        btn.Text = label .. (initial and " [ON]" or " [OFF]")
        btn.TextSize = 13
        btn.TextColor3 = Color3.fromRGB(230, 230, 240)
        btn.Font = Enum.Font.Gotham
        btn.AutoButtonColor = true
        btn.Parent = scroll
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
        local state = initial
        btn.Activated:Connect(function()
            state = not state
            btn.Text = label .. (state and " [ON]" or " [OFF]")
            callback(state)
        end)
        return btn
    end

    local function addSlider(label, min, max, default, callback)
        local frame2 = Instance.new("Frame")
        frame2.Size = UDim2.new(1, -8, 0, 36)
        frame2.BackgroundTransparency = 1
        frame2.Parent = scroll

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.5, -4, 1, 0)
        lbl.Position = UDim2.new(0, 0, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.Gotham
        lbl.Text = label .. ": " .. tostring(default)
        lbl.TextSize = 12
        lbl.TextColor3 = Color3.fromRGB(200, 200, 210)
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = frame2

        local slider = Instance.new("TextBox")
        slider.Size = UDim2.new(0.5, -4, 1, 0)
        slider.Position = UDim2.new(0.5, 4, 0, 0)
        slider.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
        slider.Text = tostring(default)
        slider.TextSize = 12
        slider.TextColor3 = Color3.fromRGB(230, 230, 240)
        slider.Font = Enum.Font.Gotham
        slider.ClearTextOnFocus = false
        slider.Parent = frame2
        Instance.new("UICorner", slider).CornerRadius = UDim.new(0, 4)

        local function update(val)
            local num = tonumber(val) or default
            num = math.clamp(num, min, max)
            slider.Text = tostring(num)
            lbl.Text = label .. ": " .. tostring(num)
            callback(num)
        end

        slider.FocusLost:Connect(function(enterPressed)
            if enterPressed then update(slider.Text) end
        end)
        slider:GetPropertyChangedSignal("Text"):Connect(function()
            local num = tonumber(slider.Text)
            if num then
                num = math.clamp(num, min, max)
                lbl.Text = label .. ": " .. tostring(num)
                callback(num)
            end
        end)
        return slider
    end

    local function addDropdown(label, values, default, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -8, 0, 30)
        btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
        local current = default
        btn.Text = label .. ": " .. current
        btn.TextSize = 13
        btn.TextColor3 = Color3.fromRGB(230, 230, 240)
        btn.Font = Enum.Font.Gotham
        btn.AutoButtonColor = true
        btn.Parent = scroll
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
        local index = 1
        for i, v in ipairs(values) do if v == default then index = i; break end end
        btn.Activated:Connect(function()
            index = index % #values + 1
            current = values[index]
            btn.Text = label .. ": " .. current
            callback(current)
        end)
        return btn
    end

    -- Build UI
    addSection("SPEED")
    addToggle("Speed Boost", false, function(v) speedEnabled = v; applySpeed() end)
    addSlider("Speed Bonus", 0, 500, 100, function(v) speedBonus = v; if speedEnabled then applySpeed() end end)
    addSlider("Sprint Bonus", 0, 300, 100, function(v) sprintBonus = v; if speedEnabled then applySpeed() end end)
    addSlider("Multiplier", 1, 10, 3, function(v) multiplier = v; if speedEnabled then applySpeed() end end)

    addSection("STATE FORCING")
    addToggle("Force State", false, function(v) forceStateEnabled = v end)
    addDropdown("State", {"Sliding", "Sprinting", "Walking", "Crouching", "Falling"}, "Sliding", function(v) forcedState = v end)

    local sendBtn = Instance.new("TextButton")
    sendBtn.Size = UDim2.new(1, -8, 0, 30)
    sendBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    sendBtn.Text = "Send State Now"
    sendBtn.TextSize = 13
    sendBtn.TextColor3 = Color3.fromRGB(230, 230, 240)
    sendBtn.Font = Enum.Font.Gotham
    sendBtn.AutoButtonColor = true
    sendBtn.Parent = scroll
    Instance.new("UICorner", sendBtn).CornerRadius = UDim.new(0, 4)
    sendBtn.Activated:Connect(function()
        if MovementState then MovementState:FireServer(forcedState) end
    end)

    addSection("VISUALS")
    addToggle("Locust ESP", false, function(v) espEnabled = v; if not v then ClearESP() end end)
    addToggle("Fullbright", false, function(v) fullbrightEnabled = v; setFullbright(v) end)

    local refreshBtn = Instance.new("TextButton")
    refreshBtn.Size = UDim2.new(1, -8, 0, 30)
    refreshBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    refreshBtn.Text = "Refresh ESP"
    refreshBtn.TextSize = 13
    refreshBtn.TextColor3 = Color3.fromRGB(230, 230, 240)
    refreshBtn.Font = Enum.Font.Gotham
    refreshBtn.AutoButtonColor = true
    refreshBtn.Parent = scroll
    Instance.new("UICorner", refreshBtn).CornerRadius = UDim.new(0, 4)
    refreshBtn.Activated:Connect(function()
        if espEnabled then ClearESP() end
    end)

    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(1, -8, 0, 30)
    closeBtn.Position = UDim2.new(0, 4, 1, -40)
    closeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    closeBtn.Text = "Close Panel"
    closeBtn.TextSize = 13
    closeBtn.TextColor3 = Color3.fromRGB(230, 230, 240)
    closeBtn.Font = Enum.Font.Gotham
    closeBtn.AutoButtonColor = true
    closeBtn.Parent = frame
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)
    closeBtn.Activated:Connect(function() gui.Enabled = false end)

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.RightShift then
            gui.Enabled = not gui.Enabled
        end
    end)

    print("[Fallback UI] Loaded (Obsidian unavailable). RightShift to toggle.")
end
