-- ================================================================
--  DARK HUB  v1.3  |  WindUI-style
--  Made by Lovesaken Team
-- ================================================================

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer       = Players.LocalPlayer
local Camera            = workspace.CurrentCamera

-- ================================================================
--  REMOTE FINDER
-- ================================================================
local function findRemote(svc, name)
    local ok, r = pcall(function()
        return ReplicatedStorage
            :WaitForChild("Knit",10):WaitForChild("Knit",10)
            :WaitForChild("Services",10):WaitForChild(svc,10)
            :WaitForChild("RE",10):WaitForChild(name,10)
    end)
    return ok and r or nil
end

-- ================================================================
--  REMOTES
-- ================================================================
local m1Remote   = nil
local dashRemote = nil

task.spawn(function()
    dashRemote = findRemote("MovementService", "Dash")
    print("[Dark Hub] Dash remote:", dashRemote)
end)

-- ================================================================
--  STATE
-- ================================================================
local upperEnabled    = false
local downEnabled     = false
local m1Count         = 0
local lastM1Time      = 0
local M1_COMBO_WINDOW = 3.0
local downLocked      = false

local lockEnabled     = false
local charLockEnabled = false
local lockTarget      = nil
local lockConn        = nil

local loopDashEnabled = false
local loopDashConn    = nil
local DASH_INTERVAL   = 0.18

local hlEnabled  = false
local hlAlpha    = 0.75
local highlights = {}

-- ================================================================
--  PALETTE
-- ================================================================
local P = {
    win      = Color3.fromRGB(15, 15, 20),
    titlebar = Color3.fromRGB(18, 18, 24),
    tabbar   = Color3.fromRGB(13, 13, 18),
    content  = Color3.fromRGB(17, 17, 23),
    row      = Color3.fromRGB(22, 22, 30),
    tabActive= Color3.fromRGB(22, 22, 30),
    accent   = Color3.fromRGB(99, 179, 255),
    on       = Color3.fromRGB(80, 220, 140),
    off      = Color3.fromRGB(75, 75, 100),
    text1    = Color3.fromRGB(225, 230, 245),
    text2    = Color3.fromRGB(130, 140, 165),
    text3    = Color3.fromRGB(80,  88, 110),
    divider  = Color3.fromRGB(30,  30,  42),
}

-- ================================================================
--  HELPERS
-- ================================================================
local function cr(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = p
end

local function tw(o, props, t, s, d)
    TweenService:Create(o, TweenInfo.new(
        t or .15, s or Enum.EasingStyle.Quad, d or Enum.EasingDirection.Out
    ), props):Play()
end

local function mkFrame(parent, size, pos, bg, zi, rad)
    local f = Instance.new("Frame")
    f.Size = size
    f.Position = pos or UDim2.new(0,0,0,0)
    f.BackgroundColor3 = bg or Color3.new(0,0,0)
    f.BackgroundTransparency = bg and 0 or 1
    f.BorderSizePixel = 0
    if zi then f.ZIndex = zi end
    f.Parent = parent
    if rad then cr(f, rad) end
    return f
end

local function mkLabel(parent, txt, sz, col, font, xa, zi)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text = txt
    l.TextSize = sz or 13
    l.TextColor3 = col or P.text1
    l.Font = font or Enum.Font.Gotham
    l.TextXAlignment = xa or Enum.TextXAlignment.Left
    l.BorderSizePixel = 0
    if zi then l.ZIndex = zi end
    l.Parent = parent
    return l
end

-- ================================================================
--  SCREEN GUI
-- ================================================================
local sg = Instance.new("ScreenGui")
sg.Name = "DarkHub"
sg.ResetOnSpawn = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.DisplayOrder = 999
pcall(function() sg.Parent = LocalPlayer:WaitForChild("PlayerGui") end)
pcall(function() sg.Parent = game:GetService("CoreGui") end)

-- ================================================================
--  MAIN WINDOW
-- ================================================================
local W, H      = 480, 420
local TITLE_H   = 42
local TABBAR_H  = 36
local CONTENT_H = H - TITLE_H - TABBAR_H

local win = Instance.new("Frame")
win.Name = "DarkHubWindow"
win.Size = UDim2.new(0,W,0,H)
win.Position = UDim2.new(0.5,-W/2,0.5,-H/2)
win.BackgroundColor3 = P.win
win.BorderSizePixel = 0
win.Active = true
win.Draggable = true
win.ClipsDescendants = false
win.Parent = sg
cr(win, 10)
mkFrame(win, UDim2.new(1,0,0,2), UDim2.new(0,0,0,0), P.accent, 3)
Instance.new("UIStroke", win).Color = Color3.fromRGB(40,44,60)

local titleBar = mkFrame(win, UDim2.new(1,0,0,TITLE_H), UDim2.new(0,0,0,0), P.titlebar, 4)
mkFrame(titleBar, UDim2.new(0,8,0,8), UDim2.new(0,14,0.5,-4), P.accent, 5, 4)
local hn = mkLabel(titleBar, "Dark Hub", 14, P.text1, Enum.Font.GothamBold, Enum.TextXAlignment.Left, 5)
hn.Size = UDim2.new(0,160,1,0) hn.Position = UDim2.new(0,30,0,0)
local vt = mkLabel(titleBar, "v1.3", 10, P.text3, Enum.Font.Gotham, Enum.TextXAlignment.Left, 5)
vt.Size = UDim2.new(0,40,0,14) vt.Position = UDim2.new(0,118,0.5,-7)

local function makeWinBtn(xpos, bg, txt)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0,20,0,20) b.Position = xpos
    b.BackgroundColor3 = bg b.BackgroundTransparency = 0.4
    b.Text = "" b.BorderSizePixel = 0 b.ZIndex = 5 b.Parent = titleBar
    cr(b, 10)
    mkLabel(b, txt, 16, P.text1, Enum.Font.GothamBold, Enum.TextXAlignment.Center, 6).Size = UDim2.new(1,0,1,0)
    return b
end
local miniBtn  = makeWinBtn(UDim2.new(1,-56,0.5,-10), Color3.fromRGB(255,180,30), "–")
local closeBtn = makeWinBtn(UDim2.new(1,-30,0.5,-10), Color3.fromRGB(255,70,80),  "×")

mkFrame(win, UDim2.new(1,0,0,1), UDim2.new(0,0,0,TITLE_H), P.divider, 4)
local tabBar = mkFrame(win, UDim2.new(1,0,0,TABBAR_H), UDim2.new(0,0,0,TITLE_H+1), P.tabbar, 4)
mkFrame(win, UDim2.new(1,0,0,1), UDim2.new(0,0,0,TITLE_H+1+TABBAR_H), P.divider, 4)
local contentArea = mkFrame(win, UDim2.new(1,0,0,CONTENT_H), UDim2.new(0,0,0,TITLE_H+1+TABBAR_H+1), P.content, 3)

-- ================================================================
--  OPEN BUTTON
-- ================================================================
local openBtn = Instance.new("TextButton")
openBtn.Size = UDim2.new(0,90,0,28) openBtn.Position = UDim2.new(0,8,0,8)
openBtn.BackgroundColor3 = Color3.fromRGB(18,18,28) openBtn.BackgroundTransparency = 0.1
openBtn.BorderSizePixel = 0 openBtn.Text = "Dark Hub"
openBtn.TextColor3 = P.accent openBtn.Font = Enum.Font.GothamBold openBtn.TextSize = 12
openBtn.ZIndex = 9999 openBtn.Visible = false openBtn.Parent = sg
cr(openBtn, 6)
local obs = Instance.new("UIStroke", openBtn)
obs.Color = P.accent obs.Thickness = 1 obs.Transparency = 0.5

-- ================================================================
--  TARGET WIDGET  (small floating GUI, shows when cam lock ON)
-- ================================================================
local targetWidget = Instance.new("Frame")
targetWidget.Name = "TargetWidget"
targetWidget.Size = UDim2.new(0,180,0,52)
targetWidget.Position = UDim2.new(0.5,-90,0,12)
targetWidget.BackgroundColor3 = Color3.fromRGB(12,12,18)
targetWidget.BackgroundTransparency = 0.1
targetWidget.BorderSizePixel = 0
targetWidget.Active = true
targetWidget.Draggable = true
targetWidget.Visible = false
targetWidget.ZIndex = 9999
targetWidget.Parent = sg
cr(targetWidget, 8)
local twStroke = Instance.new("UIStroke", targetWidget)
twStroke.Color = P.accent twStroke.Thickness = 1 twStroke.Transparency = 0.5

local twBar = mkFrame(targetWidget, UDim2.new(1,0,0,22), UDim2.new(0,0,0,0), Color3.fromRGB(16,16,26), 10000, 8)
local twTitle = mkLabel(twBar, "Cam Lock", 11, P.accent, Enum.Font.GothamBold, Enum.TextXAlignment.Center, 10001)
twTitle.Size = UDim2.new(1,0,1,0)

local twPill = mkFrame(targetWidget, UDim2.new(0,36,0,16), UDim2.new(1,-44,0,3), P.off, 10001, 8)
local twPillLbl = mkLabel(twPill, "OFF", 9, P.text1, Enum.Font.GothamBold, Enum.TextXAlignment.Center, 10002)
twPillLbl.Size = UDim2.new(1,0,1,0)

local twTargetLbl = mkLabel(targetWidget, "No Target", 11, P.text2, Enum.Font.Gotham, Enum.TextXAlignment.Center, 10001)
twTargetLbl.Size = UDim2.new(1,-16,0,14) twTargetLbl.Position = UDim2.new(0,8,0,30)

local function updateWidget()
    if lockEnabled then
        tw(twPill, {BackgroundColor3=P.on}, .15) twPillLbl.Text = "ON"
        twTargetLbl.Text  = lockTarget and lockTarget.DisplayName or "Searching..."
        twTargetLbl.TextColor3 = lockTarget and P.accent or P.text3
    else
        tw(twPill, {BackgroundColor3=P.off}, .15) twPillLbl.Text = "OFF"
        twTargetLbl.Text = "No Target" twTargetLbl.TextColor3 = P.text2
    end
end

-- ================================================================
--  LOCK LOGIC
-- ================================================================
local function getClosestEnemy()
    local myChar = LocalPlayer.Character
    local myHRP  = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return nil end
    local closest, closestDist = nil, math.huge
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl == LocalPlayer then continue end
        local c   = pl.Character
        local h   = c and c:FindFirstChild("HumanoidRootPart")
        local hum = c and c:FindFirstChildOfClass("Humanoid")
        if h and hum and hum.Health > 0 then
            local d = (myHRP.Position - h.Position).Magnitude
            if d < closestDist then closestDist = d closest = pl end
        end
    end
    return closest
end

local function startLock()
    if lockConn then lockConn:Disconnect() lockConn = nil end
    lockConn = RunService.RenderStepped:Connect(function()
        lockTarget = getClosestEnemy()
        updateWidget()
        if not lockTarget then return end
        local tc = lockTarget.Character
        local th  = tc and tc:FindFirstChild("HumanoidRootPart")
        if not th then return end

        -- CAM LOCK
        if lockEnabled then
            local targetPos = th.Position + Vector3.new(0,1.5,0)
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPos)
        end

        -- CHAR LOCK
        if charLockEnabled then
            local myChar = LocalPlayer.Character
            local myHRP  = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if myHRP then
                local dir = (th.Position - myHRP.Position) * Vector3.new(1,0,1)
                if dir.Magnitude > 0.1 then
                    myHRP.CFrame = CFrame.new(myHRP.Position, myHRP.Position + dir.Unit)
                end
            end
        end
    end)
end

local function stopLock()
    if lockConn then lockConn:Disconnect() lockConn = nil end
    lockTarget = nil
    updateWidget()
end

local function anyLockActive()
    return lockEnabled or charLockEnabled or loopDashEnabled
end

-- ================================================================
--  LOOP DASH LOGIC
-- ================================================================
local function startLoopDash()
    if loopDashConn then loopDashConn:Disconnect() loopDashConn = nil end
    local lastDash = 0
    loopDashConn = RunService.Heartbeat:Connect(function()
        if not loopDashEnabled or not dashRemote then return end
        local now = tick()
        if now - lastDash < DASH_INTERVAL then return end
        lastDash = now
        pcall(function() dashRemote:FireServer() end)
    end)
end

local function stopLoopDash()
    if loopDashConn then loopDashConn:Disconnect() loopDashConn = nil end
end

-- ================================================================
--  PAGE FACTORY
-- ================================================================
local TABS = {
    {name="Combat",  key="combat"},
    {name="Visuals", key="visuals"},
    {name="Credits", key="credits"},
}
local tabPages = {} local tabBtns = {} local currentTab = "combat"

local function newPage(key)
    local p = Instance.new("ScrollingFrame")
    p.Name = key p.Size = UDim2.new(1,0,1,0)
    p.BackgroundTransparency = 1 p.BorderSizePixel = 0 p.ScrollBarThickness = 3
    p.ScrollBarImageColor3 = Color3.fromRGB(60,70,100)
    p.CanvasSize = UDim2.new(0,0,0,0) p.AutomaticCanvasSize = Enum.AutomaticSize.Y
    p.Visible = (key == currentTab) p.ZIndex = 3 p.Parent = contentArea
    local l = Instance.new("UIListLayout")
    l.SortOrder = Enum.SortOrder.LayoutOrder l.Padding = UDim.new(0,0) l.Parent = p
    local pad = Instance.new("UIPadding") pad.PaddingBottom = UDim.new(0,8) pad.Parent = p
    return p
end

-- ================================================================
--  COMPONENTS
-- ================================================================
local function addSection(page, title, order)
    local f = mkFrame(page, UDim2.new(1,0,0,32), nil, nil, 4) f.LayoutOrder = order
    mkFrame(f, UDim2.new(0,2,0,14), UDim2.new(0,16,0.5,-7), P.accent, 5, 1)
    local t = mkLabel(f, string.upper(title), 10, P.accent, Enum.Font.GothamBold, Enum.TextXAlignment.Left, 5)
    t.Size = UDim2.new(1,-20,1,0) t.Position = UDim2.new(0,24,0,0)
    mkFrame(f, UDim2.new(1,-32,0,1), UDim2.new(0,16,1,-1), P.divider, 5)
end

local function addToggle(page, label, desc, order, default, onChange)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1,0,0,38) f.BackgroundColor3 = P.content
    f.BorderSizePixel = 0 f.LayoutOrder = order f.ZIndex = 4 f.Parent = page
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,0,1,0) btn.BackgroundTransparency = 1 btn.Text = "" btn.ZIndex = 7 btn.Parent = f
    btn.MouseEnter:Connect(function() tw(f, {BackgroundColor3=P.row}, .1) end)
    btn.MouseLeave:Connect(function() tw(f, {BackgroundColor3=P.content}, .15) end)
    mkFrame(f, UDim2.new(1,-32,0,1), UDim2.new(0,16,1,0), P.divider, 5)
    local lbl = mkLabel(f, label, 13, P.text1, Enum.Font.GothamBold, Enum.TextXAlignment.Left, 6)
    lbl.Size = UDim2.new(0,200,0,18)
    if desc and desc ~= "" then
        lbl.Position = UDim2.new(0,16,0,4)
        local d = mkLabel(f, desc, 10, P.text3, Enum.Font.Gotham, Enum.TextXAlignment.Left, 6)
        d.Size = UDim2.new(0,220,0,13) d.Position = UDim2.new(0,16,0,21)
    else
        lbl.Position = UDim2.new(0,16,0.5,-9)
    end
    local pill = mkFrame(f, UDim2.new(0,38,0,20), UDim2.new(1,-52,0.5,-10), P.off, 6, 10)
    local knob = mkFrame(pill, UDim2.new(0,14,0,14), UDim2.new(0,3,0.5,-7), P.text1, 7, 7)
    local on = default or false
    local function sync(anim)
        local t = anim and .15 or 0
        if on then tw(pill,{BackgroundColor3=P.on},t) tw(knob,{Position=UDim2.new(1,-17,0.5,-7)},t)
        else      tw(pill,{BackgroundColor3=P.off},t) tw(knob,{Position=UDim2.new(0,3,0.5,-7)},t) end
    end
    sync(false)
    local ctrl = {}
    ctrl.forceOff = function() on = false sync(true) end
    btn.MouseButton1Click:Connect(function() on = not on sync(true) if onChange then onChange(on) end end)
    return ctrl
end

local function addSlider(page, label, minV, maxV, initV, suffix, order, onChange, isInt)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1,0,0,52) f.BackgroundColor3 = P.content
    f.BorderSizePixel = 0 f.LayoutOrder = order f.ZIndex = 4 f.Parent = page
    f.MouseEnter:Connect(function() tw(f,{BackgroundColor3=P.row},.1) end)
    f.MouseLeave:Connect(function() tw(f,{BackgroundColor3=P.content},.15) end)
    mkFrame(f, UDim2.new(1,-32,0,1), UDim2.new(0,16,1,0), P.divider, 5)
    local lbl = mkLabel(f, label, 13, P.text1, Enum.Font.GothamBold, Enum.TextXAlignment.Left, 6)
    lbl.Size = UDim2.new(0,180,0,16) lbl.Position = UDim2.new(0,16,0,6)
    local fmt = isInt and "%d" or "%.2f"
    local vl = mkLabel(f, string.format(fmt,initV)..(suffix or ""), 11, P.accent, Enum.Font.GothamBold, Enum.TextXAlignment.Right, 6)
    vl.Size = UDim2.new(0,70,0,16) vl.Position = UDim2.new(1,-86,0,6)
    local track = mkFrame(f, UDim2.new(1,-32,0,4), UDim2.new(0,16,0,34), P.divider, 6, 2)
    local fill  = mkFrame(track, UDim2.new((initV-minV)/(maxV-minV),0,1,0), UDim2.new(0,0,0,0), P.accent, 7, 2)
    local knob  = mkFrame(track, UDim2.new(0,12,0,12), UDim2.new((initV-minV)/(maxV-minV),-6,0.5,-6), P.text1, 8, 6)
    local dragging = false
    local drag = Instance.new("TextButton")
    drag.Size = UDim2.new(1,0,0,24) drag.Position = UDim2.new(0,0,-1.5,0)
    drag.BackgroundTransparency = 1 drag.Text = "" drag.ZIndex = 9 drag.Parent = track
    drag.MouseButton1Down:Connect(function() dragging = true end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local rel = math.clamp((i.Position.X-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
            local val = isInt and math.floor(minV+(maxV-minV)*rel+0.5) or math.floor((minV+(maxV-minV)*rel)*100+.5)/100
            vl.Text = string.format(fmt,val)..(suffix or "")
            tw(fill,{Size=UDim2.new(rel,0,1,0)},.04) tw(knob,{Position=UDim2.new(rel,-6,0.5,-6)},.04)
            if onChange then onChange(val) end
        end
    end)
end

-- ================================================================
--  BUILD PAGES
-- ================================================================
local combatPage  = newPage("combat")
local visualsPage = newPage("visuals")
local creditsPage = newPage("credits")

-- ================================================================
--  COMBAT TAB
-- ================================================================
addSection(combatPage, "M1 Ender", 10)

local upperCtrl, downCtrl

upperCtrl = addToggle(combatPage, "Always Uppercut", "4th M1 always launches enemy upward", 11, false, function(v)
    upperEnabled = v
    if v then downEnabled = false if downCtrl then downCtrl.forceOff() end end
end)

downCtrl = addToggle(combatPage, "Always Downslam", "3rd M1 auto jumps then downslams", 12, false, function(v)
    downEnabled = v
    if v then
        upperEnabled = false if upperCtrl then upperCtrl.forceOff() end
        m1Count = 0 downLocked = false
    end
end)

addSection(combatPage, "Cam Lock", 20)

addToggle(combatPage, "Cam Lock", "Camera locks onto nearest enemy", 21, false, function(v)
    lockEnabled = v
    targetWidget.Visible = v or charLockEnabled or loopDashEnabled
    if anyLockActive() then startLock() else stopLock() end
    updateWidget()
end)

addToggle(combatPage, "Char Lock", "Character always faces locked target", 22, false, function(v)
    charLockEnabled = v
    targetWidget.Visible = lockEnabled or v or loopDashEnabled
    if anyLockActive() then startLock() else stopLock() end
end)

addSection(combatPage, "Loop Dash", 30)

addToggle(combatPage, "Loop Dash", "360 dash loop around target (use with Cam+Char Lock)", 31, false, function(v)
    loopDashEnabled = v
    targetWidget.Visible = lockEnabled or charLockEnabled or v
    if v then
        startLoopDash()
        if not lockConn then startLock() end
    else
        stopLoopDash()
        if not anyLockActive() then stopLock() end
    end
end)

addSlider(combatPage, "Dash Speed", 0.08, 0.5, 0.18, "s", 32, function(v)
    DASH_INTERVAL = v
end)

-- ================================================================
--  VISUALS TAB
-- ================================================================
addSection(visualsPage, "Player Highlight", 1)

local function applyHL(pl)
    if pl == LocalPlayer or highlights[pl] then return end
    local char = pl.Character if not char then return end
    local hl = Instance.new("Highlight")
    hl.FillColor = Color3.fromRGB(0,200,255) hl.OutlineColor = Color3.fromRGB(0,200,255)
    hl.FillTransparency = hlAlpha hl.OutlineTransparency = 0.3
    hl.Adornee = char hl.Parent = char highlights[pl] = hl
end

local function removeHL(pl)
    if highlights[pl] then highlights[pl]:Destroy() highlights[pl] = nil end
end

local function refreshHL()
    for pl, hl in pairs(highlights) do hl:Destroy() highlights[pl] = nil end
    if not hlEnabled then return end
    for _, pl in ipairs(Players:GetPlayers()) do applyHL(pl) end
end

Players.PlayerAdded:Connect(function(pl)
    pl.CharacterAdded:Connect(function()
        if not hlEnabled then return end
        task.wait(0.1) removeHL(pl) applyHL(pl)
    end)
end)
for _, pl in ipairs(Players:GetPlayers()) do
    if pl ~= LocalPlayer then
        pl.CharacterAdded:Connect(function()
            if not hlEnabled then return end
            task.wait(0.1) removeHL(pl) applyHL(pl)
        end)
    end
end
Players.PlayerRemoving:Connect(removeHL)

addToggle(visualsPage, "Player Highlight", "Outlines all players in cyan", 2, false, function(v)
    hlEnabled = v refreshHL()
end)

addSlider(visualsPage, "Fill Opacity", 0, 1, 0.25, "", 3, function(v)
    hlAlpha = 1-v
    for _, hl in pairs(highlights) do hl.FillTransparency = hlAlpha end
end)

-- ================================================================
--  CREDITS TAB
-- ================================================================
local function creditRow(page, txt, col, order, bold)
    local f = mkFrame(page, UDim2.new(1,0,0,34), nil, nil, 4) f.LayoutOrder = order
    mkFrame(f, UDim2.new(1,-32,0,1), UDim2.new(0,16,1,0), P.divider, 5)
    local l = mkLabel(f, txt, bold and 13 or 12, col or (bold and P.text1 or P.text2),
        bold and Enum.Font.GothamBold or Enum.Font.Gotham, Enum.TextXAlignment.Left, 5)
    l.Size = UDim2.new(1,-32,1,0) l.Position = UDim2.new(0,16,0,0) l.TextWrapped = true
end

addSection(creditsPage, "Dark Hub", 1)
creditRow(creditsPage, "Dark Hub", P.accent, 2, true)
creditRow(creditsPage, "Made by Lovesaken Team", P.text2, 3, false)
addSection(creditsPage, "Developers", 10)
creditRow(creditsPage, "Luna", P.accent, 11, true)
creditRow(creditsPage, "M1 Ender  |  Cam Lock  |  Loop Dash  |  Visuals", P.text2, 12, false)
addSection(creditsPage, "Info", 20)
creditRow(creditsPage, "More things coming soon...", P.text3, 21, false)
addSection(creditsPage, "Community", 30)
local df = Instance.new("Frame")
df.Size = UDim2.new(1,-24,0,46) df.BackgroundColor3 = Color3.fromRGB(88,101,242)
df.BackgroundTransparency = 0.15 df.BorderSizePixel = 0 df.LayoutOrder = 31
df.ZIndex = 4 df.Parent = creditsPage cr(df, 8)
local dTop = mkLabel(df,"Join our Discord for updates",13,Color3.fromRGB(255,255,255),Enum.Font.GothamBold,Enum.TextXAlignment.Left,5)
dTop.Size = UDim2.new(1,-20,0,18) dTop.Position = UDim2.new(0,12,0,6)
local dLink = mkLabel(df,"discord.gg/XugrGvnnR",11,Color3.fromRGB(200,210,255),Enum.Font.Gotham,Enum.TextXAlignment.Left,5)
dLink.Size = UDim2.new(1,-20,0,14) dLink.Position = UDim2.new(0,12,0,26)

-- ================================================================
--  TAB BUTTONS
-- ================================================================
local TBW = math.floor(W/#TABS)
for i, td in ipairs(TABS) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0,TBW,1,0) btn.Position = UDim2.new(0,(i-1)*TBW,0,0)
    btn.BackgroundColor3 = (td.key==currentTab) and P.tabActive or P.tabbar
    btn.BorderSizePixel = 0 btn.Text = "" btn.ZIndex = 5 btn.Parent = tabBar
    local tl = mkLabel(btn,td.name,12,(td.key==currentTab) and P.text1 or P.text2,Enum.Font.GothamBold,Enum.TextXAlignment.Center,6)
    tl.Size = UDim2.new(1,0,1,-3)
    local ul = mkFrame(btn, UDim2.new(0,30,0,2), UDim2.new(0.5,-15,1,-2), P.accent, 6, 1)
    ul.Visible = (td.key==currentTab)
    tabBtns[td.key] = {btn=btn,lbl=tl,line=ul}
    tabPages[td.key] = (td.key=="combat" and combatPage) or (td.key=="visuals" and visualsPage) or creditsPage
    btn.MouseButton1Click:Connect(function()
        if currentTab==td.key then return end
        tabBtns[currentTab].lbl.TextColor3=P.text2 tabBtns[currentTab].line.Visible=false
        tw(tabBtns[currentTab].btn,{BackgroundColor3=P.tabbar},.12)
        tabPages[currentTab].Visible=false currentTab=td.key
        tl.TextColor3=P.text1 ul.Visible=true
        tw(btn,{BackgroundColor3=P.tabActive},.12) tabPages[currentTab].Visible=true
    end)
    btn.MouseEnter:Connect(function() if currentTab~=td.key then tw(btn,{BackgroundColor3=Color3.fromRGB(20,20,28)},.1) tl.TextColor3=P.text1 end end)
    btn.MouseLeave:Connect(function() if currentTab~=td.key then tw(btn,{BackgroundColor3=P.tabbar},.12) tl.TextColor3=P.text2 end end)
end

-- ================================================================
--  CHARACTER CONNECTION
-- ================================================================
local function connectCharacter()
    local char = LocalPlayer.Character
    if not char then return end
    local moveset = char:GetAttribute("Moveset")
    if not moveset then
        char:GetAttributeChangedSignal("Moveset"):Wait()
        moveset = char:GetAttribute("Moveset")
    end
    if moveset then
        local remote = findRemote(moveset.."Service", "Activated")
        if remote then
            m1Remote = remote
            print("[Dark Hub] M1 connected: "..moveset.."Service")
        else
            m1Remote = nil
            warn("[Dark Hub] Remote not found: "..moveset.."Service")
        end
    end
    m1Count = 0 downLocked = false
end

if LocalPlayer.Character then task.spawn(connectCharacter) end
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    connectCharacter()
end)

-- ================================================================
--  HOOK
-- ================================================================
local oldNC
oldNC = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()

    if m1Remote and self == m1Remote and method == "FireServer" then
        local arg1 = select(1, ...)
        if arg1 == false then
            if downLocked then return end
            local now = tick()
            if now - lastM1Time > M1_COMBO_WINDOW then m1Count = 0 end
            lastM1Time = now
            m1Count = m1Count + 1

            if upperEnabled and m1Count == 4 then
                m1Count = 0
                return oldNC(self, "Up")
            end

            if downEnabled and m1Count == 3 then
                downLocked = true
                m1Count = 0
                local res = oldNC(self, ...)
                task.spawn(function()
                    local char = LocalPlayer.Character
                    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        hrp.AssemblyLinearVelocity = Vector3.new(
                            hrp.AssemblyLinearVelocity.X, 65, hrp.AssemblyLinearVelocity.Z
                        )
                        task.wait(0.13)
                        pcall(function() m1Remote:FireServer("Down") end)
                    end
                    task.wait(0.1)
                    downLocked = false
                end)
                return res
            end
        end
    end

    return oldNC(self, ...)
end)

-- ================================================================
--  WINDOW CONTROLS
-- ================================================================
local minimized = false

closeBtn.MouseButton1Click:Connect(function()
    tw(win,{Size=UDim2.new(0,W,0,0),BackgroundTransparency=1},.18)
    task.delay(.2,function()
        win.Visible=false win.Size=UDim2.new(0,W,0,H) win.BackgroundTransparency=0
        openBtn.Visible=true
    end)
end)

miniBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        win.ClipsDescendants=true tw(win,{Size=UDim2.new(0,W,0,TITLE_H)},.2,Enum.EasingStyle.Quart)
    else
        tw(win,{Size=UDim2.new(0,W,0,H)},.22,Enum.EasingStyle.Quart)
        task.delay(.22,function() win.ClipsDescendants=false end)
    end
end)

openBtn.MouseButton1Click:Connect(function()
    openBtn.Visible=false win.Visible=true
    win.Size=UDim2.new(0,W,0,0) win.BackgroundTransparency=1
    minimized=false win.ClipsDescendants=false
    tw(win,{Size=UDim2.new(0,W,0,H),BackgroundTransparency=0},.25,Enum.EasingStyle.Quart,Enum.EasingDirection.Out)
end)

UserInputService.InputBegan:Connect(function(inp, gp)
    if gp then return end
    if inp.KeyCode == Enum.KeyCode.RightShift then
        if win.Visible then closeBtn.MouseButton1Click:Fire()
        else openBtn.MouseButton1Click:Fire() end
    end
end)

-- ================================================================
--  OPEN ANIMATION
-- ================================================================
win.Size = UDim2.new(0,W,0,0) win.BackgroundTransparency = 1
tw(win,{Size=UDim2.new(0,W,0,H),BackgroundTransparency=0},.3,Enum.EasingStyle.Quart,Enum.EasingDirection.Out)

print("[Dark Hub] v1.3 Loaded | RightShift = toggle")
