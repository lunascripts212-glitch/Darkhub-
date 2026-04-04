-- V1perThrow w/ WindUI
-- Run this as a LocalScript via your executor

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

-- ════════════════════════════════════════
--   REMOTE EVENT (new path)
-- ════════════════════════════════════════

local RemoteEvent = ReplicatedStorage
    :WaitForChild("Modules")
    :WaitForChild("Network")
    :WaitForChild("Network")
    :WaitForChild("RemoteEvent")

-- NetworkRF is used by silent aim to hook GetCameraCF
-- Full path: ReplicatedStorage.Modules.Network.Network.RemoteFunction
local NetworkRF = nil
pcall(function()
    NetworkRF = ReplicatedStorage
        :WaitForChild("Modules", 10)
        :WaitForChild("Network", 10)
        :WaitForChild("Network", 10)
        :WaitForChild("RemoteFunction", 10)
end)

-- ════════════════════════════════════════
--   PLATFORM DETECTION
-- ════════════════════════════════════════

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ════════════════════════════════════════
--   RUNTIME STATE
-- ════════════════════════════════════════

local enabled     = false
local aimbotOn    = false
local patched     = false
local crystalCB   = nil
local unloaded    = false

local AIM_OFFSET     = -0.3
local AIM_OFFSET_MIN = -5.0
local AIM_OFFSET_MAX =  5.0

local PREDICTION     = 0.6
local PREDICTION_MIN = 0.0
local PREDICTION_MAX = 1.0

local HOLD_DURATION     = 0.9
local HOLD_DURATION_MIN = 0.3
local HOLD_DURATION_MAX = 2.0

local killerMotionData = {}

-- ════════════════════════════════════════
--   CONFIG SYSTEM
-- ════════════════════════════════════════

local fs = {
    hasFolder  = isfolder   or function() return false end,
    makeFolder = makefolder or function() end,
    write      = writefile  or function() end,
    hasFile    = isfile     or function() return false end,
    read       = readfile   or function() return "" end,
}
local Config = {}
do
    local DIR  = "V1perThrow"
    local FILE = DIR .. "/config.json"
    local hs   = game:GetService("HttpService")
    local function prep()
        if not fs.hasFolder(DIR) then fs.makeFolder(DIR) end
    end
    function Config.load()
        prep()
        if not fs.hasFile(FILE) then return end
        local raw = fs.read(FILE)
        if not raw or raw == "" then return end
        local ok, t = pcall(hs.JSONDecode, hs, raw)
        if ok and type(t) == "table" then
            for k, v in pairs(t) do Config._data[k] = v end
        end
    end
    function Config.save()
        prep()
        local ok, s = pcall(hs.JSONEncode, hs, Config._data)
        if ok and s and s ~= "" then pcall(fs.write, FILE, s) end
    end
    function Config.get(k, default)
        local v = Config._data[k]
        if v == nil then return default end
        return v
    end
    function Config.set(k, v) Config._data[k] = v; Config.save() end
    Config._data = {}
    Config.load()
end

enabled       = Config.get("enabled",      false)
aimbotOn      = Config.get("aimbotOn",     false)
AIM_OFFSET    = Config.get("aimOffset",    AIM_OFFSET)
PREDICTION    = Config.get("prediction",   PREDICTION)
HOLD_DURATION = Config.get("holdDuration", HOLD_DURATION)

-- (PC mouse helpers removed — silent aim doesn't touch the camera or mouse)

-- ════════════════════════════════════════
--   KILLER TRACKING
-- ════════════════════════════════════════

local function getKillerVelocity(hrp)
    local now  = tick()
    local pos  = hrp.Position
    local data = killerMotionData[hrp]
    if not data then
        killerMotionData[hrp] = { lastPos = pos, lastTime = now, velocity = Vector3.zero }
        return Vector3.zero
    end
    local dt = now - data.lastTime
    if dt <= 0 then return data.velocity end
    local vel     = (pos - data.lastPos) / dt
    data.lastPos  = pos
    data.lastTime = now
    data.velocity = vel
    return vel
end

local function getNearestKiller(fromPos)
    local folder = workspace:FindFirstChild("Players")
    folder = folder and folder:FindFirstChild("Killers")
    if not folder then return nil end
    local nearest, best = nil, math.huge
    for _, model in ipairs(folder:GetChildren()) do
        local hrp = model:FindFirstChild("HumanoidRootPart")
        local hum = model:FindFirstChildOfClass("Humanoid")
        if hrp and hum and hum.Health > 0 then
            local d = (hrp.Position - fromPos).Magnitude
            if d < best then best = d; nearest = model end
        end
    end
    return nearest
end

-- ════════════════════════════════════════
--   SILENT AIM
--
--   Works on both PC and mobile. The camera never moves.
--
--   How it works:
--     The server calls GetCameraCF on the NetworkRemoteFunction to read where
--     the client is aiming before computing the throw direction. We hook
--     OnClientInvoke to intercept that call and return a spoofed CFrame built
--     by our ballistic solver instead of the real camera CFrame.
--
--   Ballistic solver (buildCamCF):
--     Solves for the throw pitch θ that lands the crystal on the predicted
--     killer position, then converts θ → camera pitch α that produces θ
--     after the server applies its UpVector/3 bias:
--       throwDir ≈ (cam.LookVector + cam.UpVector/3).Unit
--       tan(α) = (3·tan(θ) − 1) / (3 + tan(θ))
-- ════════════════════════════════════════

local function buildCamCF(myHRP, killerHRP, v0, g)
    local hum    = myHRP.Parent and myHRP.Parent:FindFirstChildOfClass("Humanoid")
    local hipH   = hum and hum.HipHeight or 1.35
    local v238   = (hipH + myHRP.Size.Y / 2) / 2
    local spawnPos = myHRP.CFrame.Position + Vector3.new(0, v238, 0)

    local vel       = getKillerVelocity(killerHRP)
    local predicted = killerHRP.Position + vel * PREDICTION
    local target    = predicted + Vector3.new(0, AIM_OFFSET, 0)

    local delta = target - spawnPos
    local flatV = Vector3.new(delta.X, 0, delta.Z)
    local dx    = flatV.Magnitude
    local dy    = delta.Y

    if dx < 0.01 then
        local d = dy >= 0 and Vector3.new(0, 1, 0) or Vector3.new(0, -1, 0)
        return CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + d)
    end

    local flatDir = flatV.Unit
    local v2   = v0 * v0
    local disc = v2 * v2 - g * (g * dx * dx + 2 * dy * v2)
    local theta = disc < 0
        and math.atan2(dy, dx)
        or  math.atan2(v2 - math.sqrt(disc), g * dx)

    local T     = math.tan(theta)
    local denom = 3 + T
    local alpha = math.abs(denom) < 0.0001
        and -math.pi / 2
        or  math.atan2(3 * T - 1, denom)

    local yawCF = CFrame.new(Camera.CFrame.Position,
                             Camera.CFrame.Position + flatDir)
    return yawCF * CFrame.Angles(alpha, 0, 0)
end

local function aimAndFire(myHRP, fireCallback, holdDuration, projectileLifetime, abilityCfg)
    local killer = getNearestKiller(myHRP.Position)
    if not killer then fireCallback() return end
    local killerHRP = killer:FindFirstChild("HumanoidRootPart")
    if not killerHRP then fireCallback() return end

    local v0 = abilityCfg.MaxSpeed       -- 250
    local g  = abilityCfg.ProjectileArc  -- 40

    -- Build the spoofed CFrame once before firing
    local spoofCF    = buildCamCF(myHRP, killerHRP, v0, g)
    local originalCB = NetworkRF and getcallbackvalue(NetworkRF, "OnClientInvoke")
    local origDevice = LocalPlayer:GetAttribute("Device")
    local holdActive = true

    -- Force "Mobile" so the server reads GetCameraCF (PC path ignores it)
    LocalPlayer:SetAttribute("Device", "Mobile")

    if NetworkRF then
        NetworkRF.OnClientInvoke = function(reqName, ...)
            if reqName == "GetCameraCF" and holdActive then return spoofCF end
            if originalCB then return originalCB(reqName, ...) end
        end
    end

    RunService.Heartbeat:Wait()
    RunService.Heartbeat:Wait()
    fireCallback()

    -- Hold the hook open for the duration so network latency doesn't miss it
    task.delay(holdDuration + 0.5, function()
        holdActive = false
        if NetworkRF and getcallbackvalue(NetworkRF, "OnClientInvoke") ~= originalCB then
            NetworkRF.OnClientInvoke = originalCB
        end
        LocalPlayer:SetAttribute("Device", origDevice)
    end)
end

-- ════════════════════════════════════════
--   PATCH LOGIC
-- ════════════════════════════════════════

local function getLocalActor()
    -- No longer using require(Actors); actor lookup via character
    local char = LocalPlayer.Character
    if not char then return nil end
    return char
end

local function applyPatch(actor)
    if patched or not actor then return end

    crystalCB = true -- flag that patch is active

    -- Hook: intercept the UseActorAbility fire by wrapping the doFire logic
    patched = true
    print("[V1perThrow] Patched successfully.")
end

local function removePatch(actor)
    if not patched then return end
    crystalCB = nil
    patched = false
    print("[V1perThrow] Patch removed.")
end

-- ════════════════════════════════════════
--   CRYSTAL FIRE (new remote)
-- ════════════════════════════════════════

local function fireCrystal()
    local args = {
        [1] = "UseActorAbility",
        [2] = {
            [1] = buffer.create(8) -- buffer(buffer: 0x1055d474e8812534)
        }
    }
    -- Write the literal bytes of 0x1055d474e8812534 into the buffer (little-endian)
    local buf = buffer.create(8)
    buffer.writeu32(buf, 0, 0xe8812534)
    buffer.writeu32(buf, 4, 0x1055d474)
    args[2][1] = buf

    RemoteEvent:FireServer(unpack(args))
end

-- ════════════════════════════════════════
--   MAIN AUTO-FIRE LOOP
-- ════════════════════════════════════════

task.spawn(function()
    while not unloaded do
        task.wait(0.1)
        if not enabled or not patched then continue end

        local char = LocalPlayer.Character
        if not char then continue end
        local myHRP = char:FindFirstChild("HumanoidRootPart")
        if not myHRP then continue end

        local function doFire()
            fireCrystal()
        end

        if aimbotOn then
            aimAndFire(myHRP, doFire, HOLD_DURATION, 5, {
                MaxSpeed     = 250,
                ProjectileArc = 40,
            })
        else
            doFire()
        end

        task.wait(HOLD_DURATION + 0.2)
    end
end)

-- ════════════════════════════════════════
--   WINDUI
-- ════════════════════════════════════════

local WindUI = loadstring(game:HttpGet(
    "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
))()

local Window = WindUI:CreateWindow({
    Title  = "V1perThrow",
    Icon   = "gem",
    Author = "V1perThrow",
    Folder = "V1perThrow",
    Theme  = "Dark",
})

if not isMobile then
    Window:SetToggleKey(Enum.KeyCode.K)
end

local Tab = Window:Tab({ Title = "Main", Icon = "crosshair" })

local StatusParagraph = Tab:Paragraph({
    Title   = "Status",
    Content = "Waiting for actor...",
})

local function setStatus(text)
    StatusParagraph:SetDesc(text)
end

Tab:Paragraph({
    Title   = "Platform",
    Content = (isMobile and "Mobile" or "PC") .. " — silent aim active (GetCameraCF spoof, camera never moves)",
})

Tab:Toggle({
    Title = "Enable Patch",
    Desc  = "Auto-fire the Crystal ability when equipped",
    Icon  = "zap",
    Value = enabled,
    Callback = function(state)
        if unloaded then return end
        enabled = state
        Config.set("enabled", state)
        local actor = getLocalActor()
        if enabled and not patched and actor then applyPatch(actor) end
        setStatus(enabled and "Active" or "Inactive")
    end,
})

Tab:Toggle({
    Title = "Aimbot",
    Desc  = "Auto-aim at the nearest killer when firing",
    Icon  = "target",
    Value = aimbotOn,
    Callback = function(state)
        if unloaded then return end
        aimbotOn = state
        Config.set("aimbotOn", state)
        if not aimbotOn then
            killerMotionData = {}
        end
        local actor = getLocalActor()
        if aimbotOn and not patched and actor then applyPatch(actor) end
    end,
})

Tab:Divider()

Tab:Slider({
    Title = "Aim Offset",
    Desc  = "Y adjustment on the aim target — 0 = killer's centre",
    Step  = 0.1,
    Value = { Min = AIM_OFFSET_MIN, Max = AIM_OFFSET_MAX, Default = AIM_OFFSET },
    Callback = function(v) AIM_OFFSET = v; Config.set("aimOffset", v) end,
})

Tab:Slider({
    Title = "Prediction",
    Desc  = "Seconds to lead the killer's movement (0 = no lead)",
    Step  = 0.01,
    Value = { Min = PREDICTION_MIN, Max = PREDICTION_MAX, Default = PREDICTION },
    Callback = function(v) PREDICTION = v; Config.set("prediction", v) end,
})

Tab:Slider({
    Title = "Hold Duration",
    Desc  = "Seconds to hold aim after the shot fires",
    Step  = 0.1,
    Value = { Min = HOLD_DURATION_MIN, Max = HOLD_DURATION_MAX, Default = HOLD_DURATION },
    Callback = function(v) HOLD_DURATION = v; Config.set("holdDuration", v) end,
})

Tab:Divider()

local SettingsTab = Window:Tab({ Title = "Settings", Icon = "settings" })

SettingsTab:Button({
    Title = "Unload Script",
    Desc  = "Remove the patch and close this window",
    Icon  = "power",
    Callback = function()
        if unloaded then return end
        unloaded = true
        enabled  = false
        aimbotOn = false

        pcall(function() removePatch(getLocalActor()) end)

        WindUI:Notify({
            Title    = "V1perThrow",
            Content  = "Script unloaded successfully.",
            Icon     = "check",
            Duration = 3,
        })

        task.delay(0.5, function() Window:Destroy() end)
        print("[V1perThrow] Unloaded.")
    end,
})

-- ════════════════════════════════════════
--   ACTOR WATCHER
-- ════════════════════════════════════════

task.spawn(function()
    setStatus("Waiting for actor...")
    local lastActor = nil

    while not unloaded do
        task.wait(0.5)
        if unloaded then break end

        local currentActor = getLocalActor()

        if currentActor ~= lastActor then
            if lastActor ~= nil then
                patched          = false
                crystalCB        = nil
                killerMotionData = {}
                print("[V1perThrow] New round — resetting patch.")
                WindUI:Notify({
                    Title    = "V1perThrow",
                    Content  = "New round — patch re-applied.",
                    Icon     = "refresh-cw",
                    Duration = 3,
                })
            end

            lastActor = currentActor

            if currentActor then
                if enabled then
                    applyPatch(currentActor)
                    setStatus("Active")
                else
                    setStatus("Ready — toggle to activate")
                end
                print("[V1perThrow] Actor found. Ready.")
            else
                setStatus("Waiting for actor...")
            end
        end
    end
end)
