--[[
    ╔═══════════════════════════════════════╗
    ║       JUGG RIVALS PREMIUM MENU        ║
    ║         Exact UI Profile Match        ║
    ║         File Binding: jugg.lua        ║
    ╚═══════════════════════════════════════╝
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Camera = workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer
local character = LocalPlayer.Character
local hrp

task.spawn(function()
    character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    hrp = character:WaitForChild("HumanoidRootPart")
end)

LocalPlayer.CharacterAdded:Connect(function(newChar)
    character = newChar
    hrp = newChar:WaitForChild("HumanoidRootPart")
end)
local trip_hrp
local rs = game:GetService("RunService")
local trip_conn_a, trip_conn_b

-- CLEAR COMPONENT: Wipes out previous menus to stop duplicate rendering
local targetGui = (gethui and gethui()) or game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui")
for _, oldUi in pairs(targetGui:GetChildren()) do
    if oldUi.Name == "JuggProfileGui" or oldUi.Name == "JuggCrosshairGui" then
        oldUi:Destroy()
    end
end

local RegisteredUIComponents = {}

--------------------------------------------------
-- SAVED CONFIGURATIONS (ISOLATED TO JUGGLUA FOLDER)
--------------------------------------------------
local FOLDER_NAME = "jugglua"
local CONFIG_FILE = FOLDER_NAME .. "/jugg_config.json"

local Settings = {
    UIColor = Color3.fromRGB(147, 51, 234), 
    UITransparency = 0,
    AnimationSpeed = 0.2,
    ToggleKey = Enum.KeyCode.RightShift,
    VoidKey = Enum.KeyCode.V,
    AutoExecute = true,
    ShowWatermark = true, 
    ShowGuiOnLoad = true, 
}

local FeatureStates = {
    OrbitAura = false,
    SmoothOrbit = false,
    AntiTrip = false,
    AutoCollect = false,
    AutoRespawn = false,
    AntiMod = false,
    AntiAFK = false,
    FPSBoost = false,

    -- VOID FEATURES
    VoidEnabled = false,
    VoidDistancePercent = 100,
    HeightOffset = 0,
    MotionMode = "None",
    MotionSpeed = 10,
    OrbitRadius = 25,

    -- VISUAL FEATURES
    Crosshair = false,
    HideGameCrosshair = false,
    CrosshairSize = 10,
    CrosshairTextSize = 12,
    CrosshairOpacity = 100,
    CrosshairText = true,
    CrosshairCustomText = "jugg.lua",
    CrosshairTextStyle = "Rainbow",
    CrosshairShape = "Square",
    CrosshairColor = "#9333EA",
    CrosshairColorMode = "Custom",        -- "Custom" or "Rainbow"
    CrosshairOutline = false,
    CrosshairOutlineThickness = 1,        -- outline thickness for shapes
    CrosshairOutlineColor = "#000000",
    CrosshairTextOutlineThickness = 1,    -- outline thickness for text specifically
    CrosshairGap = 0,
    CrosshairThickness = 2,
    CrosshairLength = 15,
    CrosshairTextOffsetX = 0,
    CrosshairTextOffsetY = 8,
    CrosshairSpinSpeed = 0,               -- degrees per second multiplier
    CrosshairSpinDirection = "None",      -- "Clockwise", "Anticlockwise", "None"
}

local function saveSettings()
    if makefolder and isfolder and not isfolder(FOLDER_NAME) then
        pcall(function() makefolder(FOLDER_NAME) end)
    end

    local saveData = {
        Settings = {
            UIColor = {Settings.UIColor.R, Settings.UIColor.G, Settings.UIColor.B},
            UITransparency = Settings.UITransparency,
            AnimationSpeed = Settings.AnimationSpeed,
            ToggleKey = (typeof(Settings.ToggleKey) == "EnumItem" and Settings.ToggleKey.Name) or "RightShift",
            AutoExecute = Settings.AutoExecute,
            ShowWatermark = Settings.ShowWatermark,
            ShowGuiOnLoad = Settings.ShowGuiOnLoad,
        },
        FeatureStates = FeatureStates
    }
    
    if writefile then
        pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(saveData)) end)
    end
end

local updateUIToggleVisual

local function loadSettings()
    if not isfile or not isfile(CONFIG_FILE) then return end
    if readfile then
        pcall(function()
            local data = HttpService:JSONDecode(readfile(CONFIG_FILE))
            if data then
                if data.Settings then
                    if data.Settings.UIColor then Settings.UIColor = Color3.new(data.Settings.UIColor[1], data.Settings.UIColor[2], data.Settings.UIColor[3]) end
                    if data.Settings.UITransparency ~= nil then Settings.UITransparency = data.Settings.UITransparency end
                    if data.Settings.AnimationSpeed ~= nil then Settings.AnimationSpeed = data.Settings.AnimationSpeed end
                    if data.Settings.ToggleKey then 
                        pcall(function() Settings.ToggleKey = Enum.KeyCode[data.Settings.ToggleKey] end) 
                    end
                    if data.Settings.AutoExecute ~= nil then Settings.AutoExecute = data.Settings.AutoExecute end
                    if data.Settings.ShowWatermark ~= nil then Settings.ShowWatermark = data.Settings.ShowWatermark end
                    if data.Settings.ShowGuiOnLoad ~= nil then Settings.ShowGuiOnLoad = data.Settings.ShowGuiOnLoad end
                end
                if data.FeatureStates then
                    for key, value in pairs(data.FeatureStates) do FeatureStates[key] = value end
                end
            end
        end)
    end
end

loadSettings()

--------------------------------------------------
-- ANTI-MOD DETECTION ENGINE
--------------------------------------------------
local staffUserIds = {}
local groupId = game.CreatorId
local notify_sound = nil
local CACHE_FILE = "jugglua/modDetect_" .. groupId .. ".json"

if game.CreatorType ~= Enum.CreatorType.Group then
    return
end

task.spawn(function()
    if not isfile("jugglua/modDetect.mp3") then writefile("jugglua/modDetect.mp3", tostring(game:HttpGetAsync("https://github.com/csgofever/api/raw/refs/heads/main/modDetect.mp3"))) end
    notify_sound = Instance.new("Sound", workspace)
    notify_sound.SoundId = getcustomasset("jugglua/modDetect.mp3")
    notify_sound.Volume = 3
    notify_sound.Looped = true
end)

local function fetchURL(url)
    local ok, res = pcall(game.HttpGet, game, url)
    return ok and HttpService:JSONDecode(res) or nil
end

local function extractStaffRoleIds()
    local data = fetchURL(("https://groups.roblox.com/v1/groups/%d/roles"):format(groupId))
    local ids = {}
    if data and data.roles then
        for _, r in ipairs(data.roles) do
            local n = string.lower(r.name)
            if string.find(n, "mod") or string.find(n, "staff") then table.insert(ids, r.id) end
        end
    end
    return ids
end

local function fetchUsersInRole(roleId)
    local collected = {}
    local url = string.format("https://groups.roproxy.com/v1/groups/%d/roles/%d/users?limit=100", groupId, roleId)
    local data = fetchURL(url)
    if data and data.data then
        for _, u in ipairs(data.data) do collected[u.userId] = true end
    end
    return collected
end

local function runDetection()
    task.spawn(function()
        local staffNames, friendStaffNames = {}, {}
        for _, plr in ipairs(Players:GetPlayers()) do
            if staffUserIds[plr.UserId] then table.insert(staffNames, plr.Name) end
            
            task.wait(0.035)
            local ok, pages = pcall(function() return Players:GetFriendsAsync(plr.UserId) end)
            if ok and pages then
                for _, friend in ipairs(pages:GetCurrentPage()) do
                    if staffUserIds[friend.Id] then table.insert(friendStaffNames, friend.Username) end
                end
            end
        end
        print("========================================")
        print("Server Mods: " .. (#staffNames > 0 and table.concat(staffNames, ", ") or "None"))
        print("Friend Mods: " .. (#friendStaffNames > 0 and table.concat(friendStaffNames, ", ") or "None"))
        if #staffNames > 0 or #friendStaffNames > 0 then
            if notify_sound then notify_sound:Play() end
            task.wait(2.6)
            TeleportService:Teleport(17625359962)
        end
        print("-- jugg.lua --")
        print("========================================")
    end)

    if not _G.AntiModConnected then
        _G.AntiModConnected = true
        Players.PlayerAdded:Connect(function(plr)
            if not FeatureStates.AntiMod then return end
            local isMod = false
            
            if staffUserIds[plr.UserId] then
                print("[jugg.lua] ALERT: Server Mod late-joined! ->", plr.Name)
                isMod = true
            end
            
            local ok, pages = pcall(function() return Players:GetFriendsAsync(plr.UserId) end)
            if ok and pages then
                for _, friend in ipairs(pages:GetCurrentPage()) do
                    if staffUserIds[friend.Id] then
                        print("[jugg.lua] ALERT: Friend of Mod late-joined! ->", plr.Name)
                        isMod = true
                    end
                end
            end
            
            if isMod then
                if notify_sound then notify_sound:Play() end
                task.wait(2.6)
                TeleportService:Teleport(17625359962)
            end
        end)
    end
end

task.spawn(function()
    local roleIds = extractStaffRoleIds()
    if roleIds then
        for _, roleId in ipairs(roleIds) do
            local users = fetchUsersInRole(roleId)
            if users then
                for uid, _ in pairs(users) do 
                    staffUserIds[uid] = true 
                end
            end
        end
    end
end)

--------------------------------------------------
-- AUTO EXECUTE / TELEPORT INTEGRATION
--------------------------------------------------
local function setupAutoExecute()
    pcall(function()
        if not Settings.AutoExecute then return end
        if queue_on_teleport then
            queue_on_teleport([[
                task.wait(3)
                pcall(function()
                    local GitRequests = loadstring(game:HttpGet('https://raw.githubusercontent.com/csgofever/Roblox-GitRequests/refs/heads/main/GitRequests.lua'))()
                    local Repo = GitRequests.Repo("csgofever", "Modules")
                    loadstring(Repo:getFileContent("mod.lua"))()
                end)
            ]])
        end
        pcall(function()
            if not isfolder("jugglua") then makefolder("jugglua") end
        end)
    end)
end

--------------------------------------------------
-- MOTION UTILITIES & IN-GAME UTILS
--------------------------------------------------
local function createTween(instance, properties, duration)
    local tweenInfo = TweenInfo.new(duration or Settings.AnimationSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local tween = TweenService:Create(instance, tweenInfo, properties)
    tween:Play()
    return tween
end

local function addCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 6)
    corner.Parent = parent
    return corner
end

local function addSafeBorder(parent, color)
    local success, stroke = pcall(function()
        local s = Instance.new("UIStroke")
        s.Color = color or Color3.fromRGB(35, 35, 42)
        s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        s.Parent = parent
        return s
    end)
    if not success then
        local line = Instance.new("Frame")
        line.Size = UDim2.new(1, 0, 0, 1)
        line.Position = UDim2.new(0, 0, 1, -1)
        line.BackgroundColor3 = color or Color3.fromRGB(35, 35, 42)
        line.BorderSizePixel = 0
        line.Parent = parent
    end
end

local function makeDraggable(frame, handle)
    local dragging, dragInput, dragStart, startPos
    
    local function update(input)
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
    
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    
    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then update(input) end
    end)
end

--------------------------------------------------
-- REFACTORED CROSSHAIR SYSTEM
--------------------------------------------------
local crosshairGui = nil
local crosshairUpdateLoop = nil
local gapSliderRow = nil
local thicknessSliderRow = nil
local lengthSliderRow = nil

local function parseColor(str)
    if not str then return Settings.UIColor or Color3.fromRGB(147, 51, 234) end
    
    -- Hex format: #RRGGBB or RRGGBB
    local hex = str:gsub("#", "")
    if #hex == 6 then
        local r = tonumber(hex:sub(1, 2), 16)
        local g = tonumber(hex:sub(3, 4), 16)
        local b = tonumber(hex:sub(5, 6), 16)
        if r and g and b then
            return Color3.fromRGB(r, g, b)
        end
    end
    
    -- RGB format: R, G, B
    local r, g, b = str:match("(%d+)%s*,%s*(%d+)%s*,%s*(%d+)")
    if r and g and b then
        return Color3.fromRGB(math.clamp(tonumber(r), 0, 255), math.clamp(tonumber(g), 0, 255), math.clamp(tonumber(b), 0, 255))
    end
    
    -- Fallback/Default
    return Settings.UIColor or Color3.fromRGB(147, 51, 234)
end

local function updateCrosshairVisuals()
    local shape = FeatureStates.CrosshairShape or "Square"
    if gapSliderRow then
        gapSliderRow.Visible = (shape == "Classic" or shape == "Horizontal Line")
    end
    if thicknessSliderRow then
        thicknessSliderRow.Visible = (shape == "Classic" or shape == "X" or shape == "Horizontal Line")
    end
    if lengthSliderRow then
        lengthSliderRow.Visible = (shape == "Classic" or shape == "X" or shape == "Horizontal Line")
    end
    
    if not crosshairGui then return end
    
    local shapeContainer = crosshairGui:FindFirstChild("ShapeContainer")
    local label = crosshairGui:FindFirstChild("TextLabel", true)
    
    if shapeContainer then
        shapeContainer:ClearAllChildren()
        
        local size   = FeatureStates.CrosshairSize or 10
        local scale  = size / 10
        local opacity = 1 - (FeatureStates.CrosshairOpacity / 100)
        local color  = parseColor(FeatureStates.CrosshairColor)
        local colorMode = FeatureStates.CrosshairColorMode or "Custom"
        local shape  = FeatureStates.CrosshairShape or "Square"
        local gap    = (FeatureStates.CrosshairGap or 0) * scale
        local sThickness = math.max(1, (FeatureStates.CrosshairThickness or 2) * scale)
        local sLength    = (FeatureStates.CrosshairLength or 15) * scale
        
        local function applyOutline(instance, isText)
            if FeatureStates.CrosshairOutline then
                local stroke = Instance.new("UIStroke")
                if isText then
                    stroke.Thickness = FeatureStates.CrosshairTextOutlineThickness or 1
                else
                    stroke.Thickness = FeatureStates.CrosshairOutlineThickness or 1
                end
                stroke.Color = parseColor(FeatureStates.CrosshairOutlineColor)
                if instance:IsA("TextLabel") then
                    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
                else
                    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
                end
                stroke.Parent = instance
            end
        end
        
        local function createColoredInstance(factory)
            local inst = factory()
            -- if Rainbow mode, initial color placeholder; runtime RenderStepped will update colors
            if colorMode == "Custom" then
                if inst:IsA("TextLabel") then
                    inst.TextColor3 = color
                    inst.TextTransparency = opacity
                else
                    inst.BackgroundColor3 = color
                    inst.BackgroundTransparency = opacity
                end
            end
            return inst
        end
        
        if shape == "Square" then
            local f = createColoredInstance(function()
                local obj = Instance.new("Frame", shapeContainer)
                obj.Size = UDim2.new(0, size, 0, size)
                obj.AnchorPoint = Vector2.new(0.5, 0.5)
                obj.Position = UDim2.new(0.5, 0, 0.5, 0)
                obj.BorderSizePixel = 0
                return obj
            end)
            applyOutline(f, false)
        elseif shape == "Circle" then
            local f = createColoredInstance(function()
                local obj = Instance.new("Frame", shapeContainer)
                obj.Size = UDim2.new(0, size, 0, size)
                obj.AnchorPoint = Vector2.new(0.5, 0.5)
                obj.Position = UDim2.new(0.5, 0, 0.5, 0)
                obj.BorderSizePixel = 0
                addCorner(obj, size)
                return obj
            end)
            applyOutline(f, false)
        elseif shape == "Classic" then
            if gap == 0 then
                local v = createColoredInstance(function()
                    local obj = Instance.new("Frame", shapeContainer)
                    obj.Size = UDim2.new(0, sThickness, 0, sLength)
                    obj.AnchorPoint = Vector2.new(0.5, 0.5)
                    obj.Position = UDim2.new(0.5, 0, 0.5, 0)
                    obj.BorderSizePixel = 0
                    return obj
                end)
                applyOutline(v, false)
                
                local h = createColoredInstance(function()
                    local obj = Instance.new("Frame", shapeContainer)
                    obj.Size = UDim2.new(0, sLength, 0, sThickness)
                    obj.AnchorPoint = Vector2.new(0.5, 0.5)
                    obj.Position = UDim2.new(0.5, 0, 0.5, 0)
                    obj.BorderSizePixel = 0
                    return obj
                end)
                applyOutline(h, false)
            else
                local armLen = sLength / 2
                
                local left = createColoredInstance(function()
                    local obj = Instance.new("Frame", shapeContainer)
                    obj.Size = UDim2.new(0, armLen, 0, sThickness)
                    obj.AnchorPoint = Vector2.new(1, 0.5)
                    obj.Position = UDim2.new(0.5, -gap, 0.5, 0)
                    obj.BorderSizePixel = 0
                    return obj
                end)
                applyOutline(left, false)
                
                local right = createColoredInstance(function()
                    local obj = Instance.new("Frame", shapeContainer)
                    obj.Size = UDim2.new(0, armLen, 0, sThickness)
                    obj.AnchorPoint = Vector2.new(0, 0.5)
                    obj.Position = UDim2.new(0.5, gap, 0.5, 0)
                    obj.BorderSizePixel = 0
                    return obj
                end)
                applyOutline(right, false)
                
                local top = createColoredInstance(function()
                    local obj = Instance.new("Frame", shapeContainer)
                    obj.Size = UDim2.new(0, sThickness, 0, armLen)
                    obj.AnchorPoint = Vector2.new(0.5, 1)
                    obj.Position = UDim2.new(0.5, 0, 0.5, -gap)
                    obj.BorderSizePixel = 0
                    return obj
                end)
                applyOutline(top, false)
                
                local bottom = createColoredInstance(function()
                    local obj = Instance.new("Frame", shapeContainer)
                    obj.Size = UDim2.new(0, sThickness, 0, armLen)
                    obj.AnchorPoint = Vector2.new(0.5, 0)
                    obj.Position = UDim2.new(0.5, 0, 0.5, gap)
                    obj.BorderSizePixel = 0
                    return obj
                end)
                applyOutline(bottom, false)
            end
        elseif shape == "X" then
            local d1 = createColoredInstance(function()
                local obj = Instance.new("Frame", shapeContainer)
                obj.Size = UDim2.new(0, sLength, 0, sThickness)
                obj.AnchorPoint = Vector2.new(0.5, 0.5)
                obj.Position = UDim2.new(0.5, 0, 0.5, 0)
                obj.BorderSizePixel = 0
                obj.Rotation = 45
                return obj
            end)
            applyOutline(d1, false)
            
            local d2 = createColoredInstance(function()
                local obj = Instance.new("Frame", shapeContainer)
                obj.Size = UDim2.new(0, sLength, 0, sThickness)
                obj.AnchorPoint = Vector2.new(0.5, 0.5)
                obj.Position = UDim2.new(0.5, 0, 0.5, 0)
                obj.BorderSizePixel = 0
                obj.Rotation = -45
                return obj
            end)
            applyOutline(d2, false)
        elseif shape == "Horizontal Line" then
            if gap == 0 then
                local h = createColoredInstance(function()
                    local obj = Instance.new("Frame", shapeContainer)
                    obj.Size = UDim2.new(0, sLength, 0, sThickness)
                    obj.AnchorPoint = Vector2.new(0.5, 0.5)
                    obj.Position = UDim2.new(0.5, 0, 0.5, 0)
                    obj.BorderSizePixel = 0
                    return obj
                end)
                applyOutline(h, false)
            else
                local armLen = sLength / 2
                
                local left = createColoredInstance(function()
                    local obj = Instance.new("Frame", shapeContainer)
                    obj.Size = UDim2.new(0, armLen, 0, sThickness)
                    obj.AnchorPoint = Vector2.new(1, 0.5)
                    obj.Position = UDim2.new(0.5, -gap, 0.5, 0)
                    obj.BorderSizePixel = 0
                    return obj
                end)
                applyOutline(left, false)
                
                local right = createColoredInstance(function()
                    local obj = Instance.new("Frame", shapeContainer)
                    obj.Size = UDim2.new(0, armLen, 0, sThickness)
                    obj.AnchorPoint = Vector2.new(0, 0.5)
                    obj.Position = UDim2.new(0.5, gap, 0.5, 0)
                    obj.BorderSizePixel = 0
                    return obj
                end)
                applyOutline(right, false)
            end
        elseif shape == "Triangle" then
            local t = createColoredInstance(function()
                local obj = Instance.new("TextLabel", shapeContainer)
                obj.BackgroundTransparency = 1
                obj.Size = UDim2.new(0, sLength, 0, sLength)
                obj.AnchorPoint = Vector2.new(0.5, 0.5)
                obj.Position = UDim2.new(0.5, 0, 0.5, 0)
                obj.Text = "▲"
                obj.TextTransparency = opacity
                obj.TextSize = math.clamp(sLength, 8, 200)
                obj.Font = Enum.Font.GothamBold
                obj.BorderSizePixel = 0
                return obj
            end)
            applyOutline(t, true)
        elseif shape == "Arrow" then
            local t = createColoredInstance(function()
                local obj = Instance.new("TextLabel", shapeContainer)
                obj.BackgroundTransparency = 1
                obj.Size = UDim2.new(0, sLength, 0, sLength)
                obj.AnchorPoint = Vector2.new(0.5, 0.5)
                obj.Position = UDim2.new(0.5, 0, 0.5, 0)
                obj.Text = "↑"
                obj.TextTransparency = opacity
                obj.TextSize = math.clamp(sLength, 8, 200)
                obj.Font = Enum.Font.GothamBold
                obj.BorderSizePixel = 0
                return obj
            end)
            applyOutline(t, true)
        end
    end
    
    if label then
        label.Visible = FeatureStates.CrosshairText
        label.Text = FeatureStates.CrosshairCustomText
        label.TextSize = FeatureStates.CrosshairTextSize
        
        -- Adjust text label offset based on actual scaled shape dimensions
        local size      = FeatureStates.CrosshairSize or 10
        local scale     = size / 10
        local sLength   = (FeatureStates.CrosshairLength or 15) * scale
        local sThickness = math.max(1, (FeatureStates.CrosshairThickness or 2) * scale)
        local sGap      = (FeatureStates.CrosshairGap or 0) * scale
        local offset    = 8
        local shape     = FeatureStates.CrosshairShape or "Square"
        if shape == "Classic" then
            if sGap == 0 then
                offset = math.max(8, (sLength / 2) + 4)
            else
                offset = math.max(8, sGap + (sLength / 2) + 4)
            end
        elseif shape == "Horizontal Line" then
            offset = math.max(8, (sThickness / 2) + 6)
        elseif shape == "X" then
            offset = math.max(8, (sLength / 2) * 0.75 + 4)
        elseif shape == "Triangle" or shape == "Arrow" then
            offset = math.max(8, (sLength / 2) + 4)
        else
            offset = math.max(8, (size / 2) + 6)
        end
        local extraX = FeatureStates.CrosshairTextOffsetX or 0
        local extraY = FeatureStates.CrosshairTextOffsetY or 0
        label.AnchorPoint = Vector2.new(0.5, 0)
        label.Position = UDim2.new(0.5, extraX, 0.5, offset + extraY)
        
        -- Handle Style Logic
        local gradient = label:FindFirstChild("UIGradient")
        if FeatureStates.CrosshairTextStyle == "Rainbow" then
            label.TextColor3 = Color3.fromRGB(255, 255, 255)
            if gradient then gradient.Enabled = true end
        elseif FeatureStates.CrosshairTextStyle == "UI Color" then
            if gradient then gradient.Enabled = false end
            label.TextColor3 = Settings.UIColor or Color3.fromRGB(147, 51, 234)
        elseif FeatureStates.CrosshairTextStyle == "White" then
            if gradient then gradient.Enabled = false end
            label.TextColor3 = Color3.fromRGB(255, 255, 255)
        end

        -- apply text outline thickness if outline enabled
        if FeatureStates.CrosshairOutline and not label:FindFirstChildOfClass("UIStroke") then
            applyOutline(label, true)
        elseif not FeatureStates.CrosshairOutline then
            for _,c in ipairs(label:GetChildren()) do if c:IsA("UIStroke") then c:Destroy() end end
        end
    end
end

-- UPDATED: Robust Crosshair Hide Logic (persistent across respawns)
local hideCrosshairConnection = nil

local function applyHideCrosshair(playerGui)
    local function recursiveFind(parent)
        for _, child in pairs(parent:GetChildren()) do
            if child:IsA("GuiObject") and string.find(string.lower(child.Name), "crosshair") then
                child.Visible = false
            end
            recursiveFind(child)
        end
    end
    recursiveFind(playerGui)
end

local function toggleHideGameCrosshair(enabled)
    FeatureStates.HideGameCrosshair = enabled
    
    -- Disconnect any existing watcher
    if hideCrosshairConnection then
        hideCrosshairConnection:Disconnect()
        hideCrosshairConnection = nil
    end
    
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return end
    
    if enabled then
        -- Hide all existing crosshair elements now
        applyHideCrosshair(playerGui)
        -- Watch for newly added descendants (e.g. after respawn rebuilds the GUI)
        hideCrosshairConnection = playerGui.DescendantAdded:Connect(function(descendant)
            if descendant:IsA("GuiObject") and string.find(string.lower(descendant.Name), "crosshair") then
                -- Small delay so the game finishes parenting the element first
                task.defer(function()
                    if descendant and descendant.Parent and FeatureStates.HideGameCrosshair then
                        descendant.Visible = false
                    end
                end)
            end
        end)
    else
        -- Restore all hidden crosshair elements
        local function recursiveShow(parent)
            for _, child in pairs(parent:GetChildren()) do
                if child:IsA("GuiObject") and string.find(string.lower(child.Name), "crosshair") then
                    child.Visible = true
                end
                recursiveShow(child)
            end
        end
        recursiveShow(playerGui)
    end
end

local function toggleCrosshair(enabled)
    FeatureStates.Crosshair = enabled
    if enabled then
        if targetGui:FindFirstChild("JuggCrosshairGui") then targetGui.JuggCrosshairGui:Destroy() end
        
        crosshairGui = Instance.new("ScreenGui")
        crosshairGui.Name = "JuggCrosshairGui"
        crosshairGui.ResetOnSpawn = false
        crosshairGui.IgnoreGuiInset = true 
        crosshairGui.Parent = targetGui
        
        local shapeContainer = Instance.new("Frame", crosshairGui)
        shapeContainer.Name = "ShapeContainer"
        shapeContainer.BackgroundTransparency = 1
        shapeContainer.BorderSizePixel = 0
        shapeContainer.AnchorPoint = Vector2.new(0.5, 0.5)
        shapeContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
        shapeContainer.Size = UDim2.new(0, 0, 0, 0)
        
        local label = Instance.new("TextLabel", crosshairGui)
        label.Name = "TextLabel"
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBold
        label.TextSize = FeatureStates.CrosshairTextSize
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.AutomaticSize = Enum.AutomaticSize.XY
        label.AnchorPoint = Vector2.new(0.5, 0)
        label.Position = UDim2.new(0.5, 0, 0.5, 8) 
        
        local textGradient = Instance.new("UIGradient", label)
        textGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
            ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 255, 0)),
            ColorSequenceKeypoint.new(0.4, Color3.fromRGB(0, 255, 0)),
            ColorSequenceKeypoint.new(0.6, Color3.fromRGB(0, 255, 255)),
            ColorSequenceKeypoint.new(0.8, Color3.fromRGB(0, 0, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 255))
        })
        
        updateCrosshairVisuals()
        
        -- live update loop: handles text rainbow sliding, crosshair rainbow coloring, and spinning
        crosshairUpdateLoop = RunService.RenderStepped:Connect(function(dt)
            -- text rainbow animation
            if FeatureStates.CrosshairTextStyle == "Rainbow" and textGradient.Parent and textGradient.Enabled then
                textGradient.Offset = Vector2.new(-((tick() * 1.3) % 1), 0)
            end

            -- spin logic
            if shapeContainer and FeatureStates.CrosshairSpinDirection ~= "None" and FeatureStates.CrosshairSpinSpeed and FeatureStates.CrosshairSpinSpeed ~= 0 then
                local dir = FeatureStates.CrosshairSpinDirection == "Clockwise" and 1 or -1
                -- shapeContainer.Rotation exists on UI elements; increment by degrees based on speed
                shapeContainer.Rotation = (shapeContainer.Rotation + dir * (FeatureStates.CrosshairSpinSpeed * dt * 60)) % 360
            end

            -- rainbow color update for live shapes
            if FeatureStates.CrosshairColorMode == "Rainbow" and shapeContainer then
                -- compute a base hue that shifts over time
                local baseHue = (tick() * 0.2) % 1
                local children = shapeContainer:GetChildren()
                for i,child in ipairs(children) do
                    -- use offset to spread the rainbow across pieces
                    local offset = ((i-1) / math.max(1, #children)) * 0.2
                    local hue = (baseHue + offset) % 1
                    local c = Color3.fromHSV(hue, 1, 1)
                    if child:IsA("TextLabel") then
                        child.TextColor3 = c
                        child.TextTransparency = 1 - (FeatureStates.CrosshairOpacity / 100)
                    elseif child:IsA("Frame") then
                        child.BackgroundColor3 = c
                        child.BackgroundTransparency = 1 - (FeatureStates.CrosshairOpacity / 100)
                    end
                end
            end
        end)
    else
        if crosshairUpdateLoop then crosshairUpdateLoop:Disconnect() end
        if crosshairGui then crosshairGui:Destroy() end
    end
end

-- Other Feature Modules
local VOID_POS = Vector3.new(0, -500, 0)
local orbitConnection, smoothOrbitConnection, collectConnection, antiAFKConnection

local function getClosestEnemy()
    local closest, shortestDist = nil, math.huge
    for _, v in pairs(Players:GetPlayers()) do
        if v ~= LocalPlayer and v.Character then
            local enemyHrp = v.Character:FindFirstChild("HumanoidRootPart")
            local enemyHum = v.Character:FindFirstChild("Humanoid")
            if enemyHrp and enemyHum and enemyHum.Health > 0 then
                local dist = (hrp.Position - enemyHrp.Position).Magnitude
                if dist < shortestDist then shortestDist = dist closest = v.Character end
            end
        end
    end
    return closest
end

local function toggleOrbitAura(enabled)
    FeatureStates.OrbitAura = enabled
    if enabled then
        local orbitAngle = 0
        orbitConnection = RunService.Stepped:Connect(function()
            if character and hrp then
                if hrp.Position.Y > -450 then hrp.CFrame = CFrame.new(VOID_POS) end
                local enemy = getClosestEnemy()
                if enemy and enemy:FindFirstChild("HumanoidRootPart") then
                    orbitAngle = orbitAngle + 2
                    local x = math.cos(math.rad(orbitAngle)) * 10
                    local z = math.sin(math.rad(orbitAngle)) * 10
                    Camera.CFrame = CFrame.new(VOID_POS, enemy.HumanoidRootPart.Position + Vector3.new(x, 5, z))
                end
            end
        end)
    else
        if orbitConnection then orbitConnection:Disconnect() orbitConnection = nil end
    end
end

local function toggleSmoothOrbit(enabled)
    FeatureStates.SmoothOrbit = enabled
    if enabled then
        local smoothOrbitAngle = 0
        smoothOrbitConnection = RunService.RenderStepped:Connect(function()
            if not hrp then return end
            smoothOrbitAngle = (smoothOrbitAngle + 4) % 360
            local targetPos = VOID_POS + Vector3.new(math.cos(math.rad(smoothOrbitAngle)) * 4, 5, math.sin(math.rad(smoothOrbitAngle)) * 4)
            hrp.CFrame = hrp.CFrame:Lerp(CFrame.new(targetPos), 0.15)
            local enemy = getClosestEnemy()
            if enemy and enemy:FindFirstChild("HumanoidRootPart") then Camera.CFrame = CFrame.new(hrp.Position, enemy.HumanoidRootPart.Position) end
        end)
    else
        if smoothOrbitConnection then smoothOrbitConnection:Disconnect() smoothOrbitConnection = nil end
    end
end

local function gethrp()
    pcall(function()
        local pl = game:GetService("Players").LocalPlayer
        trip_hrp = pl and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
    end)
end

local function det()
    pcall(function()
        if not trip_hrp then return end
        for _, s in ipairs(workspace:GetChildren()) do
            if s.Name == "SubspaceTripmineHitbox" then
                local hb = s:FindFirstChild("Hitbox")
                if hb and trip_hrp and trip_hrp:IsA("BasePart") then
                    firetouchinterest(trip_hrp, hb, 1)
                    firetouchinterest(trip_hrp, hb, 0)
                end
            end
        end
    end)
end

local function startAntiSubspace()
    if not trip_conn_a then
        trip_conn_a = game:GetService("RunService").Heartbeat:Connect(gethrp)
        trip_conn_b = game:GetService("RunService").Heartbeat:Connect(det)
    end
end

local function stopAntiSubspace()
    if trip_conn_a then trip_conn_a:Disconnect(); trip_conn_a = nil end
    if trip_conn_b then trip_conn_b:Disconnect(); trip_conn_b = nil end
end

local function toggleAntiTrip(enabled)
    FeatureStates.AntiTrip = enabled
    if enabled then startAntiSubspace() else stopAntiSubspace() end
end

local function toggleAutoCollect(enabled)
    FeatureStates.AutoCollect = enabled
    if enabled then
        collectConnection = RunService.RenderStepped:Connect(function()
            if not character or not character:FindFirstChild("HumanoidRootPart") then return end
            for _, obj in pairs(workspace:GetChildren()) do
                if obj.Name == "_drop" and obj:IsA("BasePart") then
                    firetouchinterest(character.HumanoidRootPart, obj, 0)
                    firetouchinterest(character.HumanoidRootPart, obj, 1)
                end
            end
        end)
    else
        if collectConnection then collectConnection:Disconnect() collectConnection = nil end
    end
end

local function setupRespawn(char)
    local humanoid = char:WaitForChild("Humanoid")
    humanoid.Died:Connect(function()
        if not FeatureStates.AutoRespawn then return end
        task.wait()
        pcall(function()
            local rem = ReplicatedStorage:FindFirstChild("Remotes")
            if rem then
                local target = rem:FindFirstChild("RespawnNow") or rem:FindFirstChild("Respawn")
                if target then target:FireServer() end
            end
        end)
    end)
end

local function toggleAutoRespawn(enabled)
    FeatureStates.AutoRespawn = enabled
    if enabled and character then setupRespawn(character) end
end

local function toggleAntiMod(enabled)
    if enabled then runDetection() end
end

local function toggleAntiAFK(enabled)
    FeatureStates.AntiAFK = enabled
    if enabled then
        local vu = game:GetService("VirtualUser")
        antiAFKConnection = LocalPlayer.Idled:Connect(function() vu:Button2Down(Vector2.new(0,0), Camera.CFrame) task.wait(0.5) vu:Button2Up(Vector2.new(0,0), Camera.CFrame) end)
    else
        if antiAFKConnection then antiAFKConnection:Disconnect() antiAFKConnection = nil end
    end
end

local function toggleFPSBoost(enabled)
    FeatureStates.FPSBoost = enabled
    if enabled then
        Lighting.GlobalShadows = false
        for _, v in pairs(workspace:GetDescendants()) do
            if v:IsA("Part") or v:IsA("MeshPart") then v.Material = Enum.Material.Plastic elseif v:IsA("Decal") then v.Transparency = 1 end
        end
    end
end

--------------------------------------------------
-- VOID TELEPORT SYSTEM
--------------------------------------------------
local OriginalCFrame
local isReturning = false
local returnStartTime = 0
local returnDuration = 0.5
local TeleportCount = 0
local spinAngle = 0
local voidConnection

local function getVoidPosition()
    local yOffset = (FeatureStates.VoidDistancePercent * 25000) + FeatureStates.HeightOffset
    if FeatureStates.MotionMode == "Random" then
        local x = math.random(-FeatureStates.OrbitRadius, FeatureStates.OrbitRadius)
        local z = math.random(-FeatureStates.OrbitRadius, FeatureStates.OrbitRadius)
        return Vector3.new(x, yOffset, z)
    end
    return Vector3.new(0, yOffset, 0)
end

local function applyVoidMotion(deltaTime)
    if not FeatureStates.VoidEnabled then return end
    if not hrp then return end

    spinAngle = spinAngle + (FeatureStates.MotionSpeed * deltaTime)
    local yOffset = (FeatureStates.VoidDistancePercent * 25000) + FeatureStates.HeightOffset

    if FeatureStates.MotionMode == "Spin" then
        hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, spinAngle, 0)
    elseif FeatureStates.MotionMode == "Orbit" then
        local angle = spinAngle * 1.5
        local x = math.cos(angle) * FeatureStates.OrbitRadius
        local z = math.sin(angle) * FeatureStates.OrbitRadius
        hrp.CFrame = CFrame.new(Vector3.new(x, yOffset, z))
    elseif FeatureStates.MotionMode == "Desync" then
        local desyncX = math.sin(spinAngle * 50) * 10
        local desyncZ = math.cos(spinAngle * 50) * 10
        hrp.CFrame = CFrame.new(Vector3.new(desyncX, yOffset, desyncZ)) * CFrame.Angles(math.sin(spinAngle) * 0.5, math.cos(spinAngle) * 0.5, 0)
    end
end

local function toggleVoidHide(enabled)
    FeatureStates.VoidEnabled = enabled
    if enabled then
        if hrp then OriginalCFrame = hrp.CFrame end
        TeleportCount = TeleportCount + 1
        
        if not voidConnection then
            voidConnection = RunService.Heartbeat:Connect(function(dt)
                if not hrp then return end
                if FeatureStates.MotionMode == "None" then
                    hrp.CFrame = CFrame.new(getVoidPosition())
                else
                    applyVoidMotion(dt)
                end
            end)
        end
    else
        isReturning = true
        returnStartTime = tick()
        if voidConnection then voidConnection:Disconnect(); voidConnection = nil end

        task.spawn(function()
            while isReturning and OriginalCFrame and hrp do
                local elapsed = tick() - returnStartTime
                if elapsed < returnDuration then
                    local alpha = elapsed / returnDuration
                    local newPos = OriginalCFrame.Position:Lerp(hrp.Position, alpha)
                    hrp.CFrame = CFrame.new(newPos)
                else
                    hrp.CFrame = OriginalCFrame
                    isReturning = false
                end
                RunService.Heartbeat:Wait()
            end
        end)
    end
end

--------------------------------------------------
-- MAIN MENU GENERATION
--------------------------------------------------
local function InitializeMainMenu()
    -- ensure single GUI instance
    if targetGui:FindFirstChild("JuggProfileGui") then
        targetGui.JuggProfileGui:Destroy()
    end

    -- DIAGNOSTIC UI LIBRARY LOADER
    local success, library = pcall(function()
        local library_source = game:HttpGet("https://raw.githubusercontent.com/csgofever/UiLib/refs/heads/main/ui-library.lua")
        
        -- Check for leftover git conflict markers before running
        if library_source:match("<<<<<<<") or library_source:match("=======") or library_source:match(">>>>>>>") then
            error("Syntax Error: There are still leftover Git merge conflict markers (<<<<<<<, =======, or >>>>>>>) inside your ui-library.lua file on GitHub!")
        end

        local loader_func, compile_err = loadstring(library_source)
        if not loader_func then 
            error("Syntax/Compile Error: " .. tostring(compile_err)) 
        end
        
        local run_success, run_res = pcall(loader_func)
        if not run_success then 
            error("Runtime Execution Error: " .. tostring(run_res)) 
        end
        
        return run_res
    end)

    if not success then
        -- This will print the exact line number and problem directly into your console
        warn("============= UI LIBRARY LOAD ERROR =============")
        warn(tostring(library))
        warn("=================================================")
        return
    end

    -- fallback simple UI if library fails
    if not ok or not library then
        warn("[jugg.lua] ui-library load failed, falling back to minimal menu.")

        local ScreenGui = Instance.new("ScreenGui")
        ScreenGui.Name = "JuggProfileGui"
        ScreenGui.ResetOnSpawn = false
        ScreenGui.DisplayOrder = 2136372536
        ScreenGui.Parent = targetGui

        local MainFrame = Instance.new("Frame")
        MainFrame.Name = "MainFrame"
        MainFrame.Size = UDim2.new(0, 520, 0, 340)
        MainFrame.Position = UDim2.new(0.5, -260, 0.5, -170)
        MainFrame.BackgroundColor3 = Color3.fromRGB(9, 9, 11)
        MainFrame.BackgroundTransparency = Settings.UITransparency
        MainFrame.BorderSizePixel = 0
        MainFrame.Visible = Settings.ShowGuiOnLoad
        MainFrame.Parent = ScreenGui
        addCorner(MainFrame, 8)
        addSafeBorder(MainFrame, Color3.fromRGB(28, 28, 35))
        makeDraggable(MainFrame, MainFrame)

        -- minimal keybind toggle for fallback
        UserInputService.InputBegan:Connect(function(input, processed)
            if not processed and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Settings.ToggleKey then
                MainFrame.Visible = not MainFrame.Visible
            end
        end)

        return
    end

    -- build menu with ui-library (single, clean definition)
    local menu = library.new([[jugg <font color="rgb(147, 51, 234)">lua</font>]], "jugglua\\")
    local tabs = {
        menu.new_tab("http://www.roblox.com/asset/?id=7300477598"),
        menu.new_tab("http://www.roblox.com/asset/?id=7300535052"),
        menu.new_tab("http://www.roblox.com/asset/?id=7300480952"),
    }

    -- Visuals tab (two-column crosshair controls)
    do
        local visuals = tabs[1].new_section("visuals")

        -- create two real sectors (left + right) so the library places UI in correct columns
        local left = visuals.new_sector("crosshair")
        local right = visuals.new_sector("crosshair text", "Right")

        -- store references used by crosshair updater
        gapSliderRow = nil
        thicknessSliderRow = nil
        lengthSliderRow = nil

        -- helper aliases
        local function L(...) return left.element(...) end
        local function R(...) return right.element(...) end

        L("Toggle", "Hide Game Crosshair", {default = {Toggle = FeatureStates.HideGameCrosshair}}, function(v)
            FeatureStates.HideGameCrosshair = v.Toggle
            toggleHideGameCrosshair(v.Toggle)
        end)

        L("Toggle", "Custom Crosshair", {default = {Toggle = FeatureStates.Crosshair}}, function(v)
            FeatureStates.Crosshair = v.Toggle
            toggleCrosshair(v.Toggle)
            updateCrosshairVisuals()
        end)

        local shapeElem = L("Dropdown", "Crosshair Shape", {options = {"Square","Circle","Classic","X","Triangle","Arrow","Horizontal Line"}}, function(v)
            FeatureStates.CrosshairShape = v.Dropdown
            updateCrosshairVisuals()
        end)
        shapeElem:set_value({Dropdown = FeatureStates.CrosshairShape}, true)

        L("Slider", "Crosshair Size", {default = {min=1,max=30,default=FeatureStates.CrosshairSize}}, function(v) FeatureStates.CrosshairSize = v.Slider updateCrosshairVisuals() end)
        gapSliderRow = L("Slider", "Crosshair Gap", {default = {min=0,max=30,default=FeatureStates.CrosshairGap}}, function(v) FeatureStates.CrosshairGap = v.Slider updateCrosshairVisuals() end)
        thicknessSliderRow = L("Slider", "Crosshair Thickness", {default = {min=1,max=10,default=FeatureStates.CrosshairThickness}}, function(v) FeatureStates.CrosshairThickness = v.Slider updateCrosshairVisuals() end)
        lengthSliderRow = L("Slider", "Crosshair Length", {default = {min=4,max=60,default=FeatureStates.CrosshairLength}}, function(v) FeatureStates.CrosshairLength = v.Slider updateCrosshairVisuals() end)
        L("Slider", "Crosshair Opacity", {default = {min=0,max=100,default=FeatureStates.CrosshairOpacity}}, function(v) FeatureStates.CrosshairOpacity = v.Slider updateCrosshairVisuals() end)

        local colorElem = L("Toggle", "Crosshair Color (preview)")
        colorElem:add_color({Color = parseColor(FeatureStates.CrosshairColor)}, false, function(val)
            if val and val.Color then
                FeatureStates.CrosshairColor = "#" .. val.Color:ToHex():upper()
                updateCrosshairVisuals()
            end
        end)

        L("Dropdown", "Color Mode", {options = {"Custom","Rainbow"}}, function(v) FeatureStates.CrosshairColorMode = v.Dropdown updateCrosshairVisuals() end)
        L("Toggle", "Crosshair Outline", {default = {Toggle = FeatureStates.CrosshairOutline}}, function(v) FeatureStates.CrosshairOutline = v.Toggle updateCrosshairVisuals() end)
        L("Slider", "Outline Thickness (Shapes)", {default = {min=1,max=5,default=FeatureStates.CrosshairOutlineThickness}}, function(v) FeatureStates.CrosshairOutlineThickness = v.Slider updateCrosshairVisuals() end)

        local outlineDummy = L("Toggle", "Outline Color (preview)")
        outlineDummy:add_color({Color = parseColor(FeatureStates.CrosshairOutlineColor) or Settings.UIColor}, false, function(val)
            if val and val.Color then FeatureStates.CrosshairOutlineColor = "#" .. val.Color:ToHex():upper() updateCrosshairVisuals() end
        end)

        L("Slider", "Spin Speed (deg/s)", {default={min=0,max=20,default=FeatureStates.CrosshairSpinSpeed}}, function(v) FeatureStates.CrosshairSpinSpeed = v.Slider updateCrosshairVisuals() end)
        L("Dropdown", "Spin Direction", {options={"None","Clockwise","Anticlockwise"}}, function(v) FeatureStates.CrosshairSpinDirection = v.Dropdown updateCrosshairVisuals() end)

        -- right column: text settings
        R("Toggle", "Show Crosshair Text", {default={Toggle=FeatureStates.CrosshairText}}, function(v) FeatureStates.CrosshairText = v.Toggle updateCrosshairVisuals() end)
        R("TextBox", "Custom Text", {default = FeatureStates.CrosshairCustomText}, function(v) FeatureStates.CrosshairCustomText = v.Text updateCrosshairVisuals() end)
        R("Slider", "Text Size", {default={min=8,max=24,default=FeatureStates.CrosshairTextSize}}, function(v) FeatureStates.CrosshairTextSize = v.Slider updateCrosshairVisuals() end)
        R("Dropdown", "Text Style", {options={"Rainbow","UI Color","White"}}, function(v) FeatureStates.CrosshairTextStyle = v.Dropdown updateCrosshairVisuals() end)
        R("Slider", "Text Offset X", {default={min=-100,max=100,default=FeatureStates.CrosshairTextOffsetX}}, function(v) FeatureStates.CrosshairTextOffsetX = v.Slider updateCrosshairVisuals() end)
        R("Slider", "Text Offset Y", {default={min=-100,max=100,default=FeatureStates.CrosshairTextOffsetY}}, function(v) FeatureStates.CrosshairTextOffsetY = v.Slider updateCrosshairVisuals() end)
        R("Slider", "Text Outline Thickness", {default={min=0,max=8,default=FeatureStates.CrosshairTextOutlineThickness}}, function(v) FeatureStates.CrosshairTextOutlineThickness = v.Slider updateCrosshairVisuals() end)

        menu.on_load_cfg:Connect(function() updateCrosshairVisuals() end)
        updateCrosshairVisuals()
    end

    -- Misc tab
    do
        local misc = tabs[2].new_section("misc")
        local main = misc.new_sector("main")
        main.element("Toggle", "Anti Subspace Tripmine", {default = {Toggle = FeatureStates.AntiTrip}}, function(v) toggleAntiTrip(v.Toggle) end)
        main.element("Toggle", "Auto Collect Drops", {default = {Toggle = FeatureStates.AutoCollect}}, function(v) toggleAutoCollect(v.Toggle) end)
        main.element("Toggle", "Auto Respawn", {default = {Toggle = FeatureStates.AutoRespawn}}, function(v) toggleAutoRespawn(v.Toggle) end)
        main.element("Toggle", "Anti-Mod", {default = {Toggle = FeatureStates.AntiMod}}, function(v) FeatureStates.AntiMod = v.Toggle if v.Toggle then toggleAntiMod(true) end end)
        main.element("Toggle", "Anti-AFK", {default = {Toggle = FeatureStates.AntiAFK}}, function(v) toggleAntiAFK(v.Toggle) end)
        main.element("Toggle", "FPS Boost", {default = {Toggle = FeatureStates.FPSBoost}}, function(v) toggleFPSBoost(v.Toggle) end)
    end

    -- Settings tab
    do
        local sett = tabs[3].new_section("settings")
        local main = sett.new_sector("main")
        main.element("Toggle", "Auto Execute", {default = {Toggle = Settings.AutoExecute}}, function(v) Settings.AutoExecute = v.Toggle end)
        main.element("Toggle", "Show Intro Watermark", {default = {Toggle = Settings.ShowWatermark}}, function(v) Settings.ShowWatermark = v.Toggle end)
        main.element("Toggle", "Show GUI on Startup", {default = {Toggle = Settings.ShowGuiOnLoad}}, function(v) Settings.ShowGuiOnLoad = v.Toggle end)

        main.element("Keybind", "Menu Toggle Key", {default = (typeof(Settings.ToggleKey) == "EnumItem" and Settings.ToggleKey.Name) or "RightShift"}, function(v)
            if v and v.Key then
                if v.Key == "None" then return end
                local success, key = pcall(function() return Enum.KeyCode[v.Key] end)
                if success and key then
                    Settings.ToggleKey = key
                end
            end
        end)
        main.element("Button", "Save Current Settings", nil, function() saveSettings() end)
    end

    -- create anchor gui so keybind toggles reliably
    local anchorGui = Instance.new("ScreenGui")
    anchorGui.Name = "JuggProfileGui"
    anchorGui.ResetOnSpawn = false
    anchorGui.DisplayOrder = 2136372536
    anchorGui.Parent = targetGui

    local function findMainFrame()
        -- prefer library-provided main frame if present
        for _,c in ipairs(anchorGui:GetChildren()) do
            if c:IsA("Frame") and c.Visible then
                return c
            end
        end
        return anchorGui
    end
    local mainToggleTarget = findMainFrame()

    -- We no longer need the anchorGui hack. We directly call the library's toggle function.
    UserInputService.InputBegan:Connect(function(input, processed)
        if not processed and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Settings.ToggleKey then
            if menu.SetOpen and menu.IsOpen then
                menu.SetOpen(not menu.IsOpen())
            end
        end
    end)
    
    updateCrosshairVisuals()
end

--------------------------------------------------
-- INITIALIZATION THREAD EXECUTOR (INSTANT RUN)
--------------------------------------------------
local function initializeCoreThreads()
    if Settings.AutoExecute then setupAutoExecute() end
    if FeatureStates.AntiTrip then toggleAntiTrip(true) end       
    if FeatureStates.AutoCollect then toggleAutoCollect(true) end 
    if FeatureStates.AutoRespawn then toggleAutoRespawn(true) end
    if FeatureStates.AntiMod then toggleAntiMod(true) end
    if FeatureStates.AntiAFK then toggleAntiAFK(true) end
    if FeatureStates.FPSBoost then toggleFPSBoost(true) end
    
    -- Silent initialization of Visual threads
    if FeatureStates.Crosshair then toggleCrosshair(true) end
end

--------------------------------------------------
-- INITIALIZATION SEQUENCE 
--------------------------------------------------
initializeCoreThreads() 

task.spawn(function()
    if Settings.ShowWatermark then
        task.wait(5)

        local overlayGui = gethui() or game:GetService("CoreGui")
        local watermarkGui = Instance.new("ScreenGui")
        watermarkGui.Name = "JuggWatermark"
        watermarkGui.DisplayOrder = 2147483647
        watermarkGui.Parent = overlayGui

        local container = Instance.new("Frame")
        container.Size = UDim2.new(0, 750, 0, 260) 
        container.Position = UDim2.new(0.5, 0, 0.5, -25)
        container.AnchorPoint = Vector2.new(0.5, 0.5)
        container.BackgroundTransparency = 1
        container.Parent = watermarkGui

        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.new(1, 0, 0, 190) 
        textLabel.BackgroundTransparency = 1
        textLabel.Text = "<i>jugg</i>"
        textLabel.RichText = true
        textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        textLabel.TextScaled = true
        textLabel.Font = Enum.Font.ArialBold
        textLabel.TextTransparency = 1
        textLabel.Parent = container

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(15, 15, 20)
        stroke.Thickness = 14
        stroke.Transparency = 1
        stroke.Parent = textLabel

        local subtitleLabel = Instance.new("TextLabel")
        subtitleLabel.Size = UDim2.new(1, 0, 0, 35)
        subtitleLabel.Position = UDim2.new(0, 0, 0, 195) 
        subtitleLabel.BackgroundTransparency = 1
        subtitleLabel.Text = "<i>the best lua</i>"
        subtitleLabel.RichText = true 
        subtitleLabel.TextColor3 = Color3.fromRGB(140, 20, 255)
        subtitleLabel.TextSize = 24
        subtitleLabel.Font = Enum.Font.GothamBold
        subtitleLabel.TextTransparency = 1
        subtitleLabel.Parent = container

        local subtitleStroke = Instance.new("UIStroke")
        subtitleStroke.Color = Color3.fromRGB(10, 10, 10)
        subtitleStroke.Thickness = 3
        subtitleStroke.Transparency = 1
        subtitleStroke.Parent = subtitleLabel

        local uiGradient = Instance.new("UIGradient")
        uiGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0,    Color3.fromRGB(255, 0, 50)),
            ColorSequenceKeypoint.new(0.2,  Color3.fromRGB(255, 140, 0)),
            ColorSequenceKeypoint.new(0.4,  Color3.fromRGB(0, 255, 100)),
            ColorSequenceKeypoint.new(0.6,  Color3.fromRGB(0, 220, 255)),
            ColorSequenceKeypoint.new(0.8,  Color3.fromRGB(150, 0, 255)),
            ColorSequenceKeypoint.new(1,    Color3.fromRGB(255, 0, 50))
        })
        uiGradient.Parent = textLabel

        local waveSpeed = 1.3
        local animationLoop = RunService.RenderStepped:Connect(function()
            local offset = (tick() * waveSpeed) % 1
            uiGradient.Offset = Vector2.new(-offset, 0)
        end)

        TweenService:Create(textLabel, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
        TweenService:Create(stroke, TweenInfo.new(0.2), {Transparency = 0}):Play()
        TweenService:Create(subtitleLabel, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
        TweenService:Create(subtitleStroke, TweenInfo.new(0.2), {Transparency = 0}):Play()
        
        task.wait(3.5)

        local slideTime = 0.55
        local slideTweenInfo = TweenInfo.new(slideTime, Enum.EasingStyle.Back, Enum.EasingDirection.In)
        
        TweenService:Create(container, slideTweenInfo, {Position = UDim2.new(0.5, 0, 0.5, 180)}):Play()
        TweenService:Create(textLabel, TweenInfo.new(slideTime - 0.1), {TextTransparency = 1}):Play()
        TweenService:Create(stroke, TweenInfo.new(slideTime - 0.1), {Transparency = 1}):Play()
        TweenService:Create(subtitleLabel, TweenInfo.new(slideTime - 0.1), {TextTransparency = 1}):Play()
        TweenService:Create(subtitleStroke, TweenInfo.new(slideTime - 0.1), {Transparency = 1}):Play()
        
        task.wait(slideTime)
        animationLoop:Disconnect()
        watermarkGui:Destroy()
    end
    
    InitializeMainMenu()
end)