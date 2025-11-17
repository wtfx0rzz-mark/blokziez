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

    local lp   = Players.LocalPlayer
    local Tabs = (UI and UI.Tabs) or {}
    local tab  = Tabs.Main
    if not tab then return end

    ----------------------------------------------------------------------
    -- Helpers
    ----------------------------------------------------------------------
    local function hrp()
        local ch = lp.Character or lp.CharacterAdded:Wait()
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
