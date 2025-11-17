-- tab_main.lua
-- Blokziez • Main tab: movement + utilities

return function(C, R, UI)
    C  = C  or _G.C
    R  = R  or _G.R
    UI = UI or _G.UI

    local Services   = C and C.Services or {}
    local Players    = Services.Players  or game:GetService("Players")
    local Run        = Services.Run      or game:GetService("RunService")
    local UIS        = Services.UIS      or game:GetService("UserInputService")
    local RS         = Services.RS       or game:GetService("ReplicatedStorage")
    local WS         = Services.WS       or game:GetService("Workspace")

    local lp   = Players.LocalPlayer
    local Tabs = (UI and UI.Tabs) or {}
    local tab  = Tabs.Main
    if not tab then return end

    C.State  = C.State  or {}
    C.Config = C.Config or {}
    C.State.Toggles = C.State.Toggles or {}
    C.State.AuraRadius = C.State.AuraRadius or 150

    ----------------------------------------------------------------------
    -- Helpers
    ----------------------------------------------------------------------
    local function hrp(p)
        p = p or lp
        local ch = p.Character or p.CharacterAdded:Wait()
        return ch and ch:FindFirstChild("HumanoidRootPart")
    end

    local function humanoid()
        local ch = lp.Character
        return ch and ch:FindFirstChildOfClass("Humanoid")
    end

    local function clearInstance(x)
        if x then pcall(function() x:Destroy() end) end
    end

    local function disconnectConn(c)
        if c then pcall(function() c:Disconnect() end) end
    end

    ----------------------------------------------------------------------
    -- Shockwave Nudge (from nudge.lua)
    ----------------------------------------------------------------------
    local function mainPart(obj)
        if not obj or not obj.Parent then return nil end
        if obj:IsA("BasePart") then return obj end
        if obj:IsA("Model") then
            if obj.PrimaryPart then return obj.PrimaryPart end
            return obj:FindFirstChildWhichIsA("BasePart")
        end
        return nil
    end

    local function getParts(target)
        local t = {}
        if not target then return t end
        if target:IsA("BasePart") then
            t[1] = target
        elseif target:IsA("Model") then
            for _, d in ipairs(target:GetDescendants()) do
                if d:IsA("BasePart") then
                    t[#t+1] = d
                end
            end
        end
        return t
    end

    -- Never changes CanCollide; only snapshots state
    local function setCollide(model, on, snap)
        local parts = getParts(model)
        if on and snap then
            return
        end
        local s = {}
        for _, p in ipairs(parts) do
            s[p] = p.CanCollide
        end
        return s
    end

    local function zeroAssembly(model)
        for _, p in ipairs(getParts(model)) do
            p.AssemblyLinearVelocity  = Vector3.new()
            p.AssemblyAngularVelocity = Vector3.new()
        end
    end

    local function getRemote(...)
        local re = RS:FindFirstChild("RemoteEvents")
        if not re then return nil end
        for _, n in ipairs({...}) do
            local x = re:FindFirstChild(n)
            if x then return x end
        end
        return nil
    end

    local REM = { StartDrag = nil, StopDrag = nil }

    local function resolveRemotes()
        REM.StartDrag = getRemote("RequestStartDraggingItem", "StartDraggingItem")
        REM.StopDrag  = getRemote("StopDraggingItem", "RequestStopDraggingItem")
    end

    resolveRemotes()

    local function safeStartDrag(model)
        if REM.StartDrag and model and model.Parent then
            pcall(function()
                REM.StartDrag:FireServer(model)
            end)
            return true
        end
        return false
    end

    local function safeStopDrag(model)
        if REM.StopDrag and model and model.Parent then
            pcall(function()
                REM.StopDrag:FireServer(model)
            end)
            return true
        end
        return false
    end

    local function finallyStopDrag(model)
        task.delay(0.05, function()
            pcall(safeStopDrag, model)
        end)
        task.delay(0.20, function()
            pcall(safeStopDrag, model)
        end)
    end

    local function pulseDragOnce(model)
        if not (model and model.Parent) then return end
        if REM.StartDrag then
            pcall(function()
                REM.StartDrag:FireServer(model)
            end)
        end
        if REM.StopDrag then
            pcall(function()
                REM.StopDrag:FireServer(model)
            end)
        end
    end

    local function isCharacterModel(m)
        return m
            and m:IsA("Model")
            and m:FindFirstChildOfClass("Humanoid") ~= nil
    end

    local function isNPCModel(m)
        if not isCharacterModel(m) then return false end
        if Players:GetPlayerFromCharacter(m) then return false end
        local n = (m.Name or ""):lower()
        if n:find("horse", 1, true) then return false end
        return true
    end

    local function charDistancePart(m)
        if not (m and m:IsA("Model")) then return nil end
        local h = m:FindFirstChild("HumanoidRootPart")
        if h and h:IsA("BasePart") then return h end
        local pp = m.PrimaryPart
        if pp and pp:IsA("BasePart") then return pp end
        return nil
    end

    local function horiz(v)
        return Vector3.new(v.X, 0, v.Z)
    end

    local function unitOr(v, fallback)
        local m = v.Magnitude
        if m > 1e-3 then
            return v / m
        end
        return fallback
    end

    local Nudge = {
        Dist     = 50,
        Up       = 20,
        Radius   = 15,
        SelfSafe = 3.5
    }

    local AutoNudge = {
        Enabled     = false,
        MaxPerFrame = 16
    }

    local function preDrag(model)
        local started = safeStartDrag(model)
        if started then
            task.wait(0.02)
        end
        return started
    end

    local function impulseItem(model, fromPos)
        local mp = mainPart(model)
        if not mp then return end

        pulseDragOnce(model)

        local pos  = mp.Position
        local away = horiz(pos - fromPos)
        local dist = away.Magnitude
        if dist < 1e-3 then return end

        if dist < Nudge.SelfSafe then
            local out = fromPos + away.Unit * (Nudge.SelfSafe + 0.5)
            local snap0 = setCollide(model, false)
            zeroAssembly(model)
            if model:IsA("Model") then
                model:PivotTo(CFrame.new(Vector3.new(out.X, pos.Y + 0.5, out.Z)))
            else
                mp.CFrame = CFrame.new(Vector3.new(out.X, pos.Y + 0.5, out.Z))
            end
            setCollide(model, true, snap0)

            mp   = mainPart(model) or mp
            pos  = mp.Position
            away = horiz(pos - fromPos)
            dist = away.Magnitude
            if dist < 1e-3 then
                away = Vector3.new(0, 0, 1)
            end
        end

        local dir        = unitOr(away, Vector3.new(0, 0, 1))
        local horizSpeed = math.clamp(Nudge.Dist, 10, 160) * 4.0
        local upSpeed    = math.clamp(Nudge.Up,   5,  80) * 7.0

        task.spawn(function()
            local started = preDrag(model)
            local snap    = setCollide(model, false)

            for _, p in ipairs(getParts(model)) do
                pcall(function()
                    p:SetNetworkOwner(lp)
                end)
                p.AssemblyLinearVelocity  = Vector3.new()
                p.AssemblyAngularVelocity = Vector3.new()
            end

            local mass = math.max(mp:GetMass(), 1)

            pcall(function()
                mp:ApplyImpulse(
                    dir * horizSpeed * mass +
                    Vector3.new(0, upSpeed * mass, 0)
                )
            end)

            pcall(function()
                mp:ApplyAngularImpulse(Vector3.new(
                    (math.random() - 0.5) * 150,
                    (math.random() - 0.5) * 200,
                    (math.random() - 0.5) * 150
                ) * mass)
            end)

            mp.AssemblyLinearVelocity =
                dir * horizSpeed + Vector3.new(0, upSpeed, 0)

            task.delay(0.14, function()
                if started then
                    pcall(safeStopDrag, model)
                end
            end)

            task.delay(0.45, function()
                if snap then
                    setCollide(model, true, snap)
                end
            end)

            task.delay(0.9, function()
                for _, p in ipairs(getParts(model)) do
                    pcall(function()
                        p:SetNetworkOwner(nil)
                    end)
                    pcall(function()
                        if p.SetNetworkOwnershipAuto then
                            p:SetNetworkOwnershipAuto()
                        end
                    end)
                end
            end)
        end)
    end

    local function impulseNPC(mdl, fromPos)
        local r = charDistancePart(mdl)
        if not r then return end

        local pos  = r.Position
        local away = horiz(pos - fromPos)
        local dist = away.Magnitude

        if dist < Nudge.SelfSafe then
            away = unitOr(horiz(pos - fromPos), Vector3.new(0, 0, 1))
            pos  = fromPos + away * (Nudge.SelfSafe + 0.5)
        end

        local dir = unitOr(away, Vector3.new(0, 0, 1))
        local vel =
            dir * (math.clamp(Nudge.Dist, 10, 160) * 2.0) +
            Vector3.new(0, math.clamp(Nudge.Up, 5, 80) * 3.0, 0)

        pcall(function()
            r.AssemblyLinearVelocity = vel
        end)
    end

    local function nudgeShockwave(origin, radius)
        local myChar = lp.Character
        local params = OverlapParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { myChar }

        local parts = WS:GetPartBoundsInRadius(origin, radius, params) or {}
        local seen  = {}

        for _, part in ipairs(parts) do
            if part:IsA("BasePart") and not part.Anchored then
                if myChar and part:IsDescendantOf(myChar) then
                else
                    local mdl = part:FindFirstAncestorOfClass("Model") or part
                    if not seen[mdl] then
                        seen[mdl] = true

                        if isCharacterModel(mdl) then
                            if isNPCModel(mdl) then
                                impulseNPC(mdl, origin)
                            end
                        else
                            impulseItem(mdl, origin)
                        end
                    end
                end
            end
        end
    end

    local playerGui = lp:FindFirstChildOfClass("PlayerGui") or lp:WaitForChild("PlayerGui")
    local edgeGui   = playerGui:FindFirstChild("EdgeButtons")
    if not edgeGui then
        edgeGui = Instance.new("ScreenGui")
        edgeGui.Name = "EdgeButtons"
        edgeGui.ResetOnSpawn = false
        pcall(function()
            edgeGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        end)
        edgeGui.Parent = playerGui
    end

    local stack = edgeGui:FindFirstChild("EdgeStack")
    if not stack then
        stack = Instance.new("Frame")
        stack.Name = "EdgeStack"
        stack.AnchorPoint = Vector2.new(1, 0)
        stack.Position = UDim2.new(1, -6, 0, 6)
        stack.Size = UDim2.new(0, 130, 1, -12)
        stack.BackgroundTransparency = 1
        stack.BorderSizePixel = 0
        stack.Parent = edgeGui

        local list = Instance.new("UIListLayout")
        list.Name = "VList"
        list.FillDirection = Enum.FillDirection.Vertical
        list.SortOrder = Enum.SortOrder.LayoutOrder
        list.Padding = UDim.new(0, 6)
        list.HorizontalAlignment = Enum.HorizontalAlignment.Right
        list.Parent = stack
    end

    local shockBtn = stack:FindFirstChild("ShockwaveEdge")
    if not shockBtn then
        shockBtn = Instance.new("TextButton")
        shockBtn.Name = "ShockwaveEdge"
        shockBtn.Size = UDim2.new(1, 0, 0, 30)
        shockBtn.Text = "Shockwave"
        shockBtn.TextSize = 12
        shockBtn.Font = Enum.Font.GothamBold
        shockBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
        shockBtn.TextColor3 = Color3.new(1, 1, 1)
        shockBtn.BorderSizePixel = 0
        shockBtn.Visible = false
        shockBtn.LayoutOrder = 50
        shockBtn.Parent = stack
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = shockBtn
    else
        shockBtn.Text = "Shockwave"
        shockBtn.LayoutOrder = shockBtn.LayoutOrder ~= 0 and shockBtn.LayoutOrder or 50
        shockBtn.Visible = false
    end

    shockBtn.MouseButton1Click:Connect(function()
        local r = hrp()
        if r then
            nudgeShockwave(r.Position, Nudge.Radius)
        end
    end)

    ----------------------------------------------------------------------
    -- Player highlight helpers (from visuals.lua)
    ----------------------------------------------------------------------
    local function auraRadius()
        return math.clamp(tonumber(C.State.AuraRadius) or 150, 0, 1_000_000)
    end

    local function bestPart(model)
        if not model or not model:IsA("Model") then return nil end
        local hrpPart = model:FindFirstChild("HumanoidRootPart")
        if hrpPart and hrpPart:IsA("BasePart") then return hrpPart end
        if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
            return model.PrimaryPart
        end
        return model:FindFirstChildWhichIsA("BasePart")
    end

    local function ensureHighlight(parent, name)
        local hl = parent:FindFirstChild(name)
        if hl and hl:IsA("Highlight") then return hl end
        hl = Instance.new("Highlight")
        hl.Name = name
        hl.Adornee = parent
        hl.FillTransparency = 1
        hl.OutlineTransparency = 0
        hl.OutlineColor = Color3.fromRGB(255, 255, 0)
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = parent
        return hl
    end

    local function clearHighlight(parent, name)
        local hl = parent and parent:FindFirstChild(name)
        if hl and hl:IsA("Highlight") then hl:Destroy() end
    end

    local runningPlayers = false
    local PLAYER_HL_NAME = "__PlayerTrackerHL__"

    local function trackPlayer(plr)
        if plr == lp then return end
        local function attach(ch)
            if not ch then return end
            local h = ensureHighlight(ch, PLAYER_HL_NAME)
            h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            h.Enabled = true
        end
        if plr.Character then attach(plr.Character) end
        plr.CharacterAdded:Connect(attach)
    end

    local function startPlayerTracker()
        if runningPlayers then return end
        runningPlayers = true
        for _, p in ipairs(Players:GetPlayers()) do trackPlayer(p) end
        Players.PlayerAdded:Connect(trackPlayer)
        task.spawn(function()
            while runningPlayers do
                local lch = lp.Character
                local lhrp = lch and lch:FindFirstChild("HumanoidRootPart")
                local R = auraRadius()
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= lp then
                        local ch = plr.Character
                        if ch then
                            local h = ensureHighlight(ch, PLAYER_HL_NAME)
                            h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                            h.Enabled = true
                            if lhrp then
                                local phrp = ch:FindFirstChild("HumanoidRootPart")
                                local p0 = phrp and phrp.Position or (bestPart(ch) and bestPart(ch).Position)
                                if p0 then
                                    local d = (p0 - lhrp.Position).Magnitude
                                    local t = math.clamp(d / math.max(R, 1), 0, 1)
                                    h.FillTransparency    = 1 - (0.85 * t)  -- near: ~0.15, far: ~0.85
                                    h.OutlineTransparency = 0.2 * (1 - t)   -- near: 0.2, far: 0.0
                                end
                            end
                        end
                    end
                end
                task.wait(0.25)
            end
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= lp and plr.Character then
                    clearHighlight(plr.Character, PLAYER_HL_NAME)
                end
            end
        end)
    end

    local function stopPlayerTracker()
        runningPlayers = false
    end

    ----------------------------------------------------------------------
    -- Fly
    ----------------------------------------------------------------------
    local flyEnabled       = false
    local FLYING           = false
    local flySpeed         = 3

    local mobileFlyEnabled = false
    local keyDownConn, keyUpConn
    local renderConn, mobileRenderConn, mobileAddedConn
    local bodyGyro, bodyVelocity

    local function startDesktopFly()
        if FLYING then return end
        local root = hrp()
        local hum  = humanoid()
        if not root or not hum then return end

        FLYING = true

        bodyGyro           = Instance.new("BodyGyro")
        bodyVelocity       = Instance.new("BodyVelocity")
        bodyGyro.P         = 9e4
        bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        bodyGyro.CFrame    = root.CFrame
        bodyGyro.Parent    = root

        bodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        bodyVelocity.Velocity = Vector3.new()
        bodyVelocity.Parent   = root

        local CONTROL = { F = 0, B = 0, L = 0, R = 0, Q = 0, E = 0 }

        keyDownConn = UIS.InputBegan:Connect(function(input, gpe)
            if gpe or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
            local k = input.KeyCode
            if     k == Enum.KeyCode.W then CONTROL.F =  flySpeed
            elseif k == Enum.KeyCode.S then CONTROL.B = -flySpeed
            elseif k == Enum.KeyCode.A then CONTROL.L = -flySpeed
            elseif k == Enum.KeyCode.D then CONTROL.R =  flySpeed
            elseif k == Enum.KeyCode.E then CONTROL.Q =  flySpeed * 2
            elseif k == Enum.KeyCode.Q then CONTROL.E = -flySpeed * 2
            end
        end)

        keyUpConn = UIS.InputEnded:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
            local k = input.KeyCode
            if     k == Enum.KeyCode.W then CONTROL.F = 0
            elseif k == Enum.KeyCode.S then CONTROL.B = 0
            elseif k == Enum.KeyCode.A then CONTROL.L = 0
            elseif k == Enum.KeyCode.D then CONTROL.R = 0
            elseif k == Enum.KeyCode.E then CONTROL.Q = 0
            elseif k == Enum.KeyCode.Q then CONTROL.E = 0
            end
        end)

        renderConn = Run.RenderStepped:Connect(function()
            local cam = workspace.CurrentCamera
            root      = hrp()
            if not cam or not root then return end

            local humCheck = humanoid()
            if humCheck then humCheck.PlatformStand = true end

            bodyGyro.CFrame = cam.CFrame

            local moveVec = Vector3.new()
            if CONTROL.F ~= 0 or CONTROL.B ~= 0 then
                moveVec = moveVec + cam.CFrame.LookVector * (CONTROL.F + CONTROL.B)
            end
            if CONTROL.L ~= 0 or CONTROL.R ~= 0 then
                moveVec = moveVec + cam.CFrame.RightVector * (CONTROL.R + CONTROL.L)
            end
            if CONTROL.Q ~= 0 or CONTROL.E ~= 0 then
                moveVec = moveVec + cam.CFrame.UpVector * (CONTROL.Q + CONTROL.E)
            end

            if moveVec.Magnitude > 0 then
                bodyVelocity.Velocity = moveVec.Unit * (flySpeed * 50)
            else
                bodyVelocity.Velocity = Vector3.new()
            end
        end)
    end

    local function stopDesktopFly()
        FLYING = false
        disconnectConn(renderConn);   renderConn   = nil
        disconnectConn(keyDownConn);  keyDownConn  = nil
        disconnectConn(keyUpConn);    keyUpConn    = nil

        local hum = humanoid()
        if hum then hum.PlatformStand = false end

        clearInstance(bodyVelocity); bodyVelocity = nil
        clearInstance(bodyGyro);     bodyGyro     = nil
    end

    local function startMobileFly()
        if FLYING then return end
        local root = hrp()
        local hum  = humanoid()
        if not root or not hum then return end

        FLYING = true

        bodyGyro           = Instance.new("BodyGyro")
        bodyVelocity       = Instance.new("BodyVelocity")
        bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        bodyGyro.P         = 1000
        bodyGyro.D         = 50
        bodyGyro.Parent    = root

        bodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        bodyVelocity.Velocity = Vector3.new()
        bodyVelocity.Parent   = root

        mobileAddedConn = lp.CharacterAdded:Connect(function()
            root = hrp()
            if not root then return end
            clearInstance(bodyGyro)
            clearInstance(bodyVelocity)

            bodyGyro           = Instance.new("BodyGyro")
            bodyVelocity       = Instance.new("BodyVelocity")
            bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
            bodyGyro.P         = 1000
            bodyGyro.D         = 50
            bodyGyro.Parent    = root

            bodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
            bodyVelocity.Velocity = Vector3.new()
            bodyVelocity.Parent   = root
        end)

        mobileRenderConn = Run.RenderStepped:Connect(function()
            root = hrp()
            local cam = workspace.CurrentCamera
            if not root or not cam then return end

            local humCheck = humanoid()
            if humCheck then humCheck.PlatformStand = true end
            bodyGyro.CFrame = cam.CFrame

            local move = Vector3.new()
            local ok, controlModule = pcall(function()
                return require(lp.PlayerScripts:WaitForChild("PlayerModule"):WaitForChild("ControlModule"))
            end)
            if ok and controlModule and controlModule.GetMoveVector then
                move = controlModule:GetMoveVector()
            end

            local vel = Vector3.new()
            vel = vel + cam.CFrame.RightVector * (move.X * (flySpeed * 50))
            vel = vel - cam.CFrame.LookVector  * (move.Z * (flySpeed * 50))
            bodyVelocity.Velocity = vel
        end)
    end

    local function stopMobileFly()
        disconnectConn(mobileRenderConn); mobileRenderConn = nil
        disconnectConn(mobileAddedConn);  mobileAddedConn  = nil

        local hum = humanoid()
        if hum then hum.PlatformStand = false end

        clearInstance(bodyVelocity); bodyVelocity = nil
        clearInstance(bodyGyro);     bodyGyro     = nil

        FLYING = false
    end

    local function startFly()
        if UIS.TouchEnabled then
            mobileFlyEnabled = true
            startMobileFly()
        else
            mobileFlyEnabled = false
            startDesktopFly()
        end
    end

    local function stopFly()
        if mobileFlyEnabled then
            stopMobileFly()
        else
            stopDesktopFly()
        end
    end

    ----------------------------------------------------------------------
    -- Walk speed
    ----------------------------------------------------------------------
    local walkSpeedValue = 80
    local speedEnabled   = true

    local function setWalkSpeed(val)
        local hum = humanoid()
        if hum then hum.WalkSpeed = val end
    end

    Run.Heartbeat:Connect(function()
        if not speedEnabled then return end
        local hum = humanoid()
        if hum and hum.WalkSpeed ~= walkSpeedValue then
            hum.WalkSpeed = walkSpeedValue
        end
    end)

    ----------------------------------------------------------------------
    -- Noclip
    ----------------------------------------------------------------------
    local noclipEnabled = false
    local noclipConn

    local function startNoclip()
        disconnectConn(noclipConn)
        noclipEnabled = true
        noclipConn = Run.Stepped:Connect(function()
            local ch = lp.Character
            if not ch then return end
            for _, part in ipairs(ch:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end)
    end

    local function stopNoclip()
        noclipEnabled = false
        disconnectConn(noclipConn)
        noclipConn = nil
    end

    ----------------------------------------------------------------------
    -- Godmode (DamagePlayer remote, like Auto tab)
    ----------------------------------------------------------------------
    local godOn, godHB, godAcc = false, nil, 0
    local GOD_INTERVAL = 0.5

    local function fireGod()
        local f  = RS:FindFirstChild("RemoteEvents")
        local ev = f and f:FindFirstChild("DamagePlayer")
        if ev and ev:IsA("RemoteEvent") then
            pcall(function()
                ev:FireServer(-math.huge)
            end)
        end
    end

    local function enableGod()
        if godOn then return end
        godOn = true
        fireGod()
        godAcc = 0
        if godHB then godHB:Disconnect() end
        godHB = Run.Heartbeat:Connect(function(dt)
            godAcc += dt
            if godAcc >= GOD_INTERVAL then
                godAcc = 0
                fireGod()
            end
        end)
    end

    local function disableGod()
        godOn = false
        if godHB then godHB:Disconnect() godHB = nil end
    end

    ----------------------------------------------------------------------
    -- Infinite Jump
    ----------------------------------------------------------------------
    local infJumpOn  = true
    local jumpConn

    local function enableInfJump()
        infJumpOn = true
        disconnectConn(jumpConn)
        jumpConn = UIS.JumpRequest:Connect(function()
            local hum = humanoid()
            if hum then
                pcall(function()
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                end)
            end
        end)
    end

    local function disableInfJump()
        infJumpOn = false
        disconnectConn(jumpConn)
        jumpConn = nil
    end

    ----------------------------------------------------------------------
    -- UI
    ----------------------------------------------------------------------

    tab:Section({ Title = "Movement", Icon = "activity" })

    tab:Slider({
        Title = "Fly Speed",
        Value = { Min = 1, Max = 20, Default = 3 },
        Callback = function(v)
            local nv = v
            if type(v) == "table" then
                nv = v.Value or v.Current or v.Default or v.min or v.max
            end
            nv = tonumber(nv)
            if nv then
                flySpeed = math.clamp(nv, 1, 20)
            end
        end
    })

    tab:Toggle({
        Title = "Fly",
        Value = false,
        Callback = function(state)
            flyEnabled = state and true or false
            if flyEnabled then
                startFly()
            else
                stopFly()
            end
        end
    })

    tab:Divider()

    tab:Section({ Title = "Walk Speed", Icon = "walk" })

    tab:Slider({
        Title = "Walk Speed",
        Value = { Min = 16, Max = 150, Default = 80 },
        Callback = function(v)
            local nv = v
            if type(v) == "table" then
                nv = v.Value or v.Current or v.Default or v.min or v.max
            end
            nv = tonumber(nv)
            if nv then
                walkSpeedValue = math.clamp(nv, 16, 150)
                if speedEnabled then
                    setWalkSpeed(walkSpeedValue)
                end
            end
        end
    })

    tab:Toggle({
        Title = "Lock Walk Speed",
        Value = true,
        Callback = function(state)
            speedEnabled = state and true or false
            if speedEnabled then
                setWalkSpeed(walkSpeedValue)
            else
                setWalkSpeed(16)
            end
        end
    })

    tab:Divider()

    tab:Section({ Title = "Utilities", Icon = "tool" })

    tab:Toggle({
        Title = "Noclip",
        Value = false,
        Callback = function(state)
            if state then
                startNoclip()
            else
                stopNoclip()
            end
        end
    })

    tab:Toggle({
        Title = "Godmode",
        Value = true,
        Callback = function(state)
            if state then
                enableGod()
            else
                disableGod()
            end
        end
    })

    tab:Toggle({
        Title = "Infinite Jump",
        Value = true,
        Callback = function(state)
            if state then
                enableInfJump()
            else
                disableInfJump()
            end
        end
    })

    ----------------------------------------------------------------------
    -- Shockwave Nudge UI (edge button + sliders)
    ----------------------------------------------------------------------
    local initialEdge = (C.State.Toggles.EdgeShockwave == true)

    tab:Section({ Title = "Shockwave Nudge" })

    tab:Toggle({
        Title = "Edge Button: Shockwave",
        Value = initialEdge,
        Callback = function(v)
            local on = (v == true)
            C.State.Toggles.EdgeShockwave = on
            if shockBtn then
                shockBtn.Visible = on
            end
        end
    })

    tab:Slider({
        Title = "Nudge Distance",
        Value = { Min = 10, Max = 160, Default = Nudge.Dist },
        Callback = function(v)
            local n = tonumber(type(v) == "table" and (v.Value or v.Current or v.Default) or v)
            if n then
                Nudge.Dist = math.clamp(math.floor(n + 0.5), 10, 160)
            end
        end
    })

    tab:Slider({
        Title = "Nudge Height",
        Value = { Min = 5, Max = 80, Default = Nudge.Up },
        Callback = function(v)
            local n = tonumber(type(v) == "table" and (v.Value or v.Current or v.Default) or v)
            if n then
                Nudge.Up = math.clamp(math.floor(n + 0.5), 5, 80)
            end
        end
    })

    tab:Slider({
        Title = "Nudge Radius",
        Value = { Min = 5, Max = 60, Default = Nudge.Radius },
        Callback = function(v)
            local n = tonumber(type(v) == "table" and (v.Value or v.Current or v.Default) or v)
            if n then
                Nudge.Radius = math.clamp(math.floor(n + 0.5), 5, 60)
            end
        end
    })

    tab:Toggle({
        Title = "Auto Nudge (within Radius)",
        Value = AutoNudge.Enabled,
        Callback = function(on)
            AutoNudge.Enabled = (on == true)
        end
    })

    local autoConn
    local acc = 0

    if autoConn then
        autoConn:Disconnect()
        autoConn = nil
    end

    autoConn = Run.Heartbeat:Connect(function(dt)
        if not AutoNudge.Enabled then return end
        acc += dt
        if acc < 0.2 then return end
        acc = 0

        local r = hrp()
        if not r then return end
        nudgeShockwave(r.Position, Nudge.Radius)
    end)

    Players.LocalPlayer.CharacterAdded:Connect(function()
        local pg = lp:WaitForChild("PlayerGui")
        local eg = pg:FindFirstChild("EdgeButtons")
        if eg and eg.Parent ~= pg then
            eg.Parent = pg
        end
        local on = (C.State and C.State.Toggles and C.State.Toggles.EdgeShockwave == true) or false
        if shockBtn then
            shockBtn.Visible = on
        end
    end)

    ----------------------------------------------------------------------
    -- Player highlight toggle (bottom of Main tab)
    ----------------------------------------------------------------------
    tab:Section({ Title = "Visuals", Icon = "eye" })

    tab:Toggle({
        Title = "Highlight Players",
        Value = C.State.Toggles.PlayerTracker or false,
        Callback = function(on)
            C.State.Toggles.PlayerTracker = on
            if on then
                startPlayerTracker()
            else
                stopPlayerTracker()
            end
        end
    })

    if C.State.Toggles.PlayerTracker then
        startPlayerTracker()
    end

    ----------------------------------------------------------------------
    -- Character respawn handling
    ----------------------------------------------------------------------
    lp.CharacterAdded:Connect(function()
        if flyEnabled then
            task.defer(function()
                stopFly()
                startFly()
            end)
        end

        if speedEnabled then
            task.defer(function()
                setWalkSpeed(walkSpeedValue)
            end)
        end

        if noclipEnabled then
            task.defer(function()
                startNoclip()
            end)
        end
    end)

    -- defaults on first load
    enableInfJump()
    enableGod()
end
