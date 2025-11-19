-- tab_troll.lua

return function(C, R, UI)
    C  = C  or _G.C
    R  = R  or _G.R
    UI = UI or _G.UI

    assert(UI and UI.Tabs and UI.Tabs.Troll, "tab_troll.lua: Troll tab missing")

    local tab = UI.Tabs.Troll

    local Services = C.Services or {}
    local Players  = Services.Players  or game:GetService("Players")
    local RS       = Services.RS       or game:GetService("ReplicatedStorage")
    local WS       = Services.WS       or game:GetService("Workspace")
    local Run      = Services.Run      or game:GetService("RunService")

    local lp = C.LocalPlayer or Players.LocalPlayer

    C.State  = C.State  or {}
    C.Config = C.Config or {}

    local EventsFolder = RS:WaitForChild("Events")
    local Destroy      = EventsFolder:FindFirstChild("DestroyBlock")
    local Place        = EventsFolder:FindFirstChild("Place")

    local baseplate    = WS:FindFirstChild("Baseplate")

    --------------------------------------------------------------------
    -- HRP helper (player or model)
    --------------------------------------------------------------------
    local function getHRP(model)
        -- Player HRP (no argument)
        if not model then
            local char = lp.Character or lp.CharacterAdded:Wait()
            local hrp  = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                return hrp
            end
            return char:WaitForChild("HumanoidRootPart")
        end

        -- Model HRP (target)
        if not model:IsA("Model") then
            return nil
        end

        local hrp = model:FindFirstChild("HumanoidRootPart")
        if hrp and hrp:IsA("BasePart") then
            return hrp
        end

        if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
            return model.PrimaryPart
        end

        for _, c in ipairs(model:GetChildren()) do
            if c:IsA("BasePart") then
                return c
            end
        end

        return nil
    end

    local function extractNumber(v, min, max, default)
        local nv = v
        if type(v) == "table" then
            nv = v.Value or v.Current or v.CurrentValue or v.Default or v.min or v.max
        end
        nv = tonumber(nv) or default
        if min and max and nv then
            nv = math.clamp(nv, min, max)
        end
        return nv
    end

    --------------------------------------------------------------------
    -- Delete blocks around player
    --------------------------------------------------------------------

    local DELETE_RADIUS_DEFAULT = 30
    local DELETE_MAX_PER_STEP   = 200

    C.Config.DeleteRadius = C.Config.DeleteRadius or DELETE_RADIUS_DEFAULT

    local function getDeleteRoots()
        local roots = {}
        local built = WS:FindFirstChild("Built")
        if built then table.insert(roots, built) end

        local personal = WS:FindFirstChild(lp.Name)
        if personal then table.insert(roots, personal) end

        return roots
    end

    local function deleteStep()
        if not Destroy then return end

        local hrp = getHRP()
        if not hrp or not hrp.Parent then
            return
        end

        local origin  = hrp.Position
        local radius  = C.Config.DeleteRadius or DELETE_RADIUS_DEFAULT
        local deleted = 0

        local roots = getDeleteRoots()
        if #roots == 0 then return end

        for _, root in ipairs(roots) do
            if not C.State.DeleteBlocksEnabled then return end

            for _, inst in ipairs(root:GetDescendants()) do
                if not C.State.DeleteBlocksEnabled then return end

                if inst:IsA("BasePart") then
                    local dist = (inst.Position - origin).Magnitude
                    if dist <= radius then
                        pcall(function()
                            Destroy:InvokeServer(inst)
                        end)
                        deleted += 1
                        if deleted >= DELETE_MAX_PER_STEP then
                            return
                        end
                    end
                end
            end
        end
    end

    local deleteLoopRunning = false

    local function startDeleteLoop()
        if deleteLoopRunning or not Destroy then return end
        deleteLoopRunning = true

        task.spawn(function()
            while deleteLoopRunning and C.State.DeleteBlocksEnabled do
                deleteStep()
                Run.Heartbeat:Wait()
            end
            deleteLoopRunning = false
        end)
    end

    local function stopDeleteLoop()
        deleteLoopRunning = false
    end

    tab:Toggle({
        Title = "Delete Blocks Around Player",
        Value = false,
        Callback = function(enabled)
            C.State.DeleteBlocksEnabled = enabled and true or false
            if enabled then
                startDeleteLoop()
            else
                stopDeleteLoop()
            end
        end,
    })

    --------------------------------------------------------------------
    -- Tunnel: raycast-based delete directly ahead (3-block vertical column)
    --------------------------------------------------------------------

    local TUNNEL_DIST_DEFAULT   = 3
    local TUNNEL_DIST_MIN       = 1
    local TUNNEL_DIST_MAX       = 50  -- 1..50
    local TUNNEL_MAX_PER_STEP   = 6   -- up to 2 blocks per ray * 3 vertical rays

    C.Config.TunnelDistance = C.Config.TunnelDistance or TUNNEL_DIST_DEFAULT
    C.State.TunnelEnabled   = C.State.TunnelEnabled   or false

    local function isTunnelCandidate(part)
        if not (part and part:IsA("BasePart")) then return false end
        if part == baseplate then return false end
        if lp.Character and part:IsDescendantOf(lp.Character) then return false end
        return true
    end

    local tunnelParams = RaycastParams.new()
    tunnelParams.FilterType  = Enum.RaycastFilterType.Include
    tunnelParams.IgnoreWater = true

    local function tunnelStep()
        if not (Destroy and C.State.TunnelEnabled) then return end

        local hrp = getHRP()
        if not hrp or not hrp.Parent then return end

        local roots = getDeleteRoots()
        if #roots == 0 then return end
        tunnelParams.FilterDescendantsInstances = roots

        local cf      = hrp.CFrame
        local forward = cf.LookVector
        local up      = cf.UpVector

        local dist = C.Config.TunnelDistance or TUNNEL_DIST_DEFAULT
        dist = math.clamp(dist, TUNNEL_DIST_MIN, TUNNEL_DIST_MAX)

        local baseOrigin = hrp.Position + forward * 2

        local origins = {
            baseOrigin,               -- center
            baseOrigin + up * 4,      -- above
            baseOrigin - up * 4,      -- below
        }

        local seen  = {}
        local hits  = {}
        local ahead = forward * dist

        local function markSeen(part)
            if not part then return false end
            if seen[part] then return false end
            seen[part] = true
            return true
        end

        for _, origin in ipairs(origins) do
            local result = WS:Raycast(origin, ahead, tunnelParams)
            if result and result.Instance then
                local inst = result.Instance
                if isTunnelCandidate(inst) and markSeen(inst) then
                    table.insert(hits, inst)
                    if #hits >= TUNNEL_MAX_PER_STEP then break end
                end
            end
            if #hits < TUNNEL_MAX_PER_STEP then
                local result2 = WS:Raycast(origin + forward * (dist * 0.5), ahead * 0.5, tunnelParams)
                if result2 and result2.Instance then
                    local inst2 = result2.Instance
                    if isTunnelCandidate(inst2) and markSeen(inst2) then
                        table.insert(hits, inst2)
                        if #hits >= TUNNEL_MAX_PER_STEP then break end
                    end
                end
            end
        end

        for _, inst in ipairs(hits) do
            if inst and inst.Parent then
                pcall(function()
                    Destroy:InvokeServer(inst)
                end)
            end
        end
    end

    local tunnelConn = nil

    local function startTunnel()
        if tunnelConn or not Destroy then return end
        C.State.TunnelEnabled = true
        tunnelConn = Run.Heartbeat:Connect(function()
            if not C.State.TunnelEnabled then return end
            tunnelStep()
        end)
    end

    private = private or {}
    private.startTunnel = startTunnel

    local function stopTunnel()
        C.State.TunnelEnabled = false
        if tunnelConn then
            tunnelConn:Disconnect()
            tunnelConn = nil
        end
    end

    tab:Toggle({
        Title = "Tunnel (Delete Ahead)",
        Value = C.State.TunnelEnabled or false,
        Callback = function(enabled)
            if enabled then
                startTunnel()
            else
                stopTunnel()
            end
        end,
    })

    tab:Slider({
        Title = "Tunnel Distance",
        Value = {
            Min     = TUNNEL_DIST_MIN,
            Max     = TUNNEL_DIST_MAX,
            Default = C.Config.TunnelDistance or TUNNEL_DIST_DEFAULT,
        },
        Callback = function(v)
            local nv = extractNumber(v, TUNNEL_DIST_MIN, TUNNEL_DIST_MAX, TUNNEL_DIST_DEFAULT)
            C.Config.TunnelDistance = nv
        end,
    })

    --------------------------------------------------------------------
    -- Wide Tunnel: 5 high x 2 wide, up to 1000 studs
    --------------------------------------------------------------------

    local WIDE_TUNNEL_DIST_MAX     = 1000
    local WIDE_TUNNEL_DIST_MIN     = 1
    local WIDE_TUNNEL_DIST_DEFAULT = WIDE_TUNNEL_DIST_MAX  -- default = max (1000)
    local WIDE_TUNNEL_MAX_PER_STEP = 30  -- 5 high * 2 wide, plus mid-ray hits

    C.Config.WideTunnelDistance = C.Config.WideTunnelDistance or WIDE_TUNNEL_DIST_DEFAULT
    C.State.WideTunnelEnabled   = C.State.WideTunnelEnabled   or false

    local wideTunnelConn = nil

    local function wideTunnelStep()
        if not (Destroy and C.State.WideTunnelEnabled) then return end

        local hrp = getHRP()
        if not hrp or not hrp.Parent then return end

        local roots = getDeleteRoots()
        if #roots == 0 then return end
        tunnelParams.FilterDescendantsInstances = roots

        local cf      = hrp.CFrame
        local forward = cf.LookVector
        local up      = cf.UpVector
        local right   = cf.RightVector

        local dist = C.Config.WideTunnelDistance or WIDE_TUNNEL_DIST_DEFAULT
        dist = math.clamp(dist, WIDE_TUNNEL_DIST_MIN, WIDE_TUNNEL_DIST_MAX)

        local baseOrigin = hrp.Position + forward * 2

        -- 5 high (±8, ±4, 0) and 2 wide (center + one side)
        local verticalOffsets = { -8, -4, 0, 4, 8 }
        local horizontalOffsets = {
            Vector3.new(0, 0, 0),
            right * 4,
        }

        local origins = {}
        for _, vOff in ipairs(verticalOffsets) do
            for _, hOff in ipairs(horizontalOffsets) do
                origins[#origins+1] = baseOrigin + up * vOff + hOff
            end
        end

        local seen  = {}
        local hits  = {}
        local ahead = forward * dist

        local function markSeen(part)
            if not part then return false end
            if seen[part] then return false end
            seen[part] = true
            return true
        end

        for _, origin in ipairs(origins) do
            if #hits >= WIDE_TUNNEL_MAX_PER_STEP then break end

            local result = WS:Raycast(origin, ahead, tunnelParams)
            if result and result.Instance then
                local inst = result.Instance
                if isTunnelCandidate(inst) and markSeen(inst) then
                    table.insert(hits, inst)
                    if #hits >= WIDE_TUNNEL_MAX_PER_STEP then break end
                end
            end

            if #hits < WIDE_TUNNEL_MAX_PER_STEP then
                local result2 = WS:Raycast(origin + forward * (dist * 0.5), ahead * 0.5, tunnelParams)
                if result2 and result2.Instance then
                    local inst2 = result2.Instance
                    if isTunnelCandidate(inst2) and markSeen(inst2) then
                        table.insert(hits, inst2)
                        if #hits >= WIDE_TUNNEL_MAX_PER_STEP then break end
                    end
                end
            end
        end

        for _, inst in ipairs(hits) do
            if inst and inst.Parent then
                pcall(function()
                    Destroy:InvokeServer(inst)
                end)
            end
        end
    end

    local function startWideTunnel()
        if wideTunnelConn or not Destroy then return end
        C.State.WideTunnelEnabled = true
        wideTunnelConn = Run.Heartbeat:Connect(function()
            if not C.State.WideTunnelEnabled then return end
            wideTunnelStep()
        end)
    end

    local function stopWideTunnel()
        C.State.WideTunnelEnabled = false
        if wideTunnelConn then
            wideTunnelConn:Disconnect()
            wideTunnelConn = nil
        end
    end

    tab:Toggle({
        Title = "Wide Tunnel (5 High x 2 Wide)",
        Value = C.State.WideTunnelEnabled or false,
        Callback = function(enabled)
            if enabled then
                startWideTunnel()
            else
                stopWideTunnel()
            end
        end,
    })

    tab:Slider({
        Title = "Wide Tunnel Distance",
        Value = {
            Min     = WIDE_TUNNEL_DIST_MIN,
            Max     = WIDE_TUNNEL_DIST_MAX,
            Default = C.Config.WideTunnelDistance or WIDE_TUNNEL_DIST_DEFAULT,
        },
        Callback = function(v)
            local nv = extractNumber(v, WIDE_TUNNEL_DIST_MIN, WIDE_TUNNEL_DIST_MAX, WIDE_TUNNEL_DIST_DEFAULT)
            C.Config.WideTunnelDistance = nv
        end,
    })

    --------------------------------------------------------------------
    -- Column spam (always Black Wool)
    --------------------------------------------------------------------

    C.Config.ColumnMaxHeight = C.Config.ColumnMaxHeight or 20
    C.Config.ColumnRadius    = C.Config.ColumnRadius    or 50
    C.Config.ColumnWorkers   = C.Config.ColumnWorkers   or 100  -- more threads

    local rng                 = Random.new()
    local COLUMN_BASE_Y       = 2
    local COLUMN_BLOCK_HEIGHT = 4
    local COLUMN_MIN_BLOCKS   = 5

    local BLOCK_TYPES = { "Black Wool" }

    local function randomBlockType()
        return BLOCK_TYPES[rng:NextInteger(1, #BLOCK_TYPES)]
    end

    local function randomColumnBase(originPos, radius)
        local r     = rng:NextNumber(0, radius)
        local theta = rng:NextNumber(0, math.pi * 2)
        local x = originPos.X + math.cos(theta) * r
        local z = originPos.Z + math.sin(theta) * r
        return Vector3.new(x, COLUMN_BASE_Y, z)
    end

    local columnWorkersSpawned = false

    local function columnWorker()
        local state = {
            base         = nil,
            level        = 0,
            targetHeight = 0,
        }

        while true do
            if C.State.ColumnSpamEnabled and Place and baseplate then
                local hrp
                pcall(function()
                    hrp = getHRP()
                end)

                if hrp and hrp.Parent then
                    local radius    = C.Config.ColumnRadius    or 50
                    local maxHeight = C.Config.ColumnMaxHeight or 20
                    if maxHeight < COLUMN_MIN_BLOCKS then
                        maxHeight = COLUMN_MIN_BLOCKS
                    end

                    if not state.base or state.level >= state.targetHeight then
                        state.base         = randomColumnBase(hrp.Position, radius)
                        state.level        = 0
                        state.targetHeight = rng:NextInteger(COLUMN_MIN_BLOCKS, maxHeight)
                    end

                    local y  = COLUMN_BASE_Y + state.level * COLUMN_BLOCK_HEIGHT
                    local cf = CFrame.new(state.base.X, y, state.base.Z)

                    pcall(function()
                        Place:InvokeServer(randomBlockType(), cf, baseplate)
                    end)

                    state.level += 1
                end
            end

            Run.Heartbeat:Wait()
        end
    end

    tab:Toggle({
        Title = "Column Spam",
        Value = C.State.ColumnSpamEnabled or false,
        Callback = function(enabled)
            C.State.ColumnSpamEnabled = enabled and true or false

            if enabled and not columnWorkersSpawned then
                columnWorkersSpawned = true
                local workers = C.Config.ColumnWorkers or 100
                for _ = 1, workers do
                    task.spawn(columnWorker)
                end
            end
        end,
    })

    tab:Slider({
        Title = "Column Height",
        Value = {
            Min     = 5,
            Max     = 60,
            Default = C.Config.ColumnMaxHeight or 20,
        },
        Callback = function(v)
            local nv = extractNumber(v, 5, 60, C.Config.ColumnMaxHeight or 20)
            C.Config.ColumnMaxHeight = nv
        end,
    })

    tab:Slider({
        Title = "Blocks Around Player",
        Value = {
            Min     = 4,
            Max     = 150,
            Default = C.Config.ColumnRadius or 50,
        },
        Callback = function(v)
            local nv = extractNumber(v, 4, 150, C.Config.ColumnRadius or 50)
            C.Config.ColumnRadius = nv
        end,
    })

    --------------------------------------------------------------------
    -- Player / NPC Aura lock + autoswing (game.Players targets)
    --------------------------------------------------------------------

    local AURA_RADIUS_DEFAULT         = 10   -- default TP/Hit range = 10
    local AURA_RADIUS_MIN             = 5
    local AURA_RADIUS_MAX             = 300
    local AURA_SWING_INTERVAL_DEFAULT = 0.01  -- your tweaked speed
    local AURA_MAX_TELEPORT_STEP      = 80
    local AURA_TARGET_REFRESH         = 0.15

    C.Config.AuraRadius        = C.Config.AuraRadius        or AURA_RADIUS_DEFAULT
    C.Config.AuraSwingInterval = C.Config.AuraSwingInterval or AURA_SWING_INTERVAL_DEFAULT
    C.State.AuraEnabled        = C.State.AuraEnabled        or false

    local AURA_WHITELIST = {
        DaAxenat0r    = true,
        DaAvanat0r_v2 = true,
    }

    local function getHumanoid(model)
        if not model then return nil end
        return model:FindFirstChildOfClass("Humanoid")
    end

    local function getEquippedTool()
        local char = lp.Character or lp.CharacterAdded:Wait()
        for _, obj in ipairs(char:GetChildren()) do
            if obj:IsA("Tool") then
                return obj
            end
        end

        local backpack = lp:FindFirstChild("Backpack")
        if backpack then
            for _, obj in ipairs(backpack:GetChildren()) do
                if obj:IsA("Tool") then
                    return obj
                end
            end
        end
        return nil
    end

    local function ensureEquipped(tool)
        if not tool then return end
        local char = lp.Character or lp.CharacterAdded:Wait()
        if tool.Parent == char then return end

        local hum = getHumanoid(char)
        if hum then
            hum:EquipTool(tool)
        else
            tool.Parent = char
        end
    end

    local function currentAuraRadius()
        return C.Config.AuraRadius or AURA_RADIUS_DEFAULT
    end

    local function isValidAuraTarget(model, myHRP)
        if not (model and myHRP) then return false end
        if not model:IsA("Model") then return false end

        -- Target must still exist in Workspace (avoid "stuck" when player leaves)
        if not model:IsDescendantOf(WS) then return false end

        local myChar = lp.Character or lp.CharacterAdded:Wait()
        if model == myChar then return false end
        if AURA_WHITELIST[model.Name] then return false end
        if model.Name == lp.Name then return false end

        local hum = getHumanoid(model)
        if hum and hum.Health <= 0 then
            return false
        end

        local part = getHRP(model)
        if not part then return false end
        if not part:IsDescendantOf(WS) then return false end

        local dist = (part.Position - myHRP.Position).Magnitude
        if dist > currentAuraRadius() then return false end

        return true
    end

    local function findNearestAuraTarget(myHRP)
        if not myHRP then return nil end

        local nearest = nil
        local bestDist = currentAuraRadius()
        local myChar = lp.Character or lp.CharacterAdded:Wait()

        -- 1) Other real players' characters
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= lp and not AURA_WHITELIST[p.Name] then
                local char = p.Character
                if char and char:IsA("Model") and isValidAuraTarget(char, myHRP) then
                    local part = getHRP(char)
                    if part then
                        local d = (part.Position - myHRP.Position).Magnitude
                        if d <= bestDist then
                            bestDist = d
                            nearest = char
                        end
                    end
                end
            end
        end

        -- 2) Any Model directly under game.Players that isn't our own character
        for _, obj in ipairs(Players:GetChildren()) do
            if obj:IsA("Model") and obj ~= myChar and not AURA_WHITELIST[obj.Name] then
                if isValidAuraTarget(obj, myHRP) then
                    local part = getHRP(obj)
                    if part then
                        local d = (part.Position - myHRP.Position).Magnitude
                        if d <= bestDist then
                            bestDist = d
                            nearest = obj
                        end
                    end
                end
            end
        end

        return nearest
    end

    local auraConn       = nil
    local auraTarget     = nil
    local auraTargetAcc  = 0
    local auraAttackAcc  = 0

    local function auraStep(dt)
        if not C.State.AuraEnabled then return end

        local hrp = getHRP()
        if not hrp or not hrp.Parent then
            auraTarget = nil
            return
        end

        -- If target's model is gone from Workspace, drop it immediately
        if auraTarget and (not auraTarget.Parent or not auraTarget:IsDescendantOf(WS)) then
            auraTarget = nil
        end

        -- Refresh / validate target periodically
        auraTargetAcc = auraTargetAcc + dt
        if auraTargetAcc >= AURA_TARGET_REFRESH then
            auraTargetAcc = 0
            if not isValidAuraTarget(auraTarget, hrp) then
                auraTarget = findNearestAuraTarget(hrp)
            end
        end

        -- Lock-on movement
        if auraTarget then
            if not auraTarget:IsDescendantOf(WS) then
                auraTarget = nil
            else
                local tPart = getHRP(auraTarget)
                if tPart and tPart:IsDescendantOf(WS) then
                    local desiredPos   = tPart.Position - tPart.CFrame.LookVector * 3
                    local distToTarget = (tPart.Position - hrp.Position).Magnitude

                    if distToTarget > currentAuraRadius() + 5 then
                        auraTarget = nil
                    else
                        if distToTarget > AURA_MAX_TELEPORT_STEP then
                            auraTarget = nil
                        else
                            hrp.CFrame = CFrame.new(desiredPos, tPart.Position)
                        end
                    end
                else
                    -- HRP disappeared (e.g., player left) -> drop target so you are not stuck
                    auraTarget = nil
                end
            end
        end

        -- Auto-swing (always on when aura is enabled)
        auraAttackAcc = auraAttackAcc + dt
        local interval = C.Config.AuraSwingInterval or AURA_SWING_INTERVAL_DEFAULT
        if auraAttackAcc >= interval then
            auraAttackAcc = 0
            local tool = getEquippedTool()
            if tool then
                ensureEquipped(tool)
                tool:Activate()
            end
        end
    end

    tab:Toggle({
        Title = "Aura: Lock + AutoSwing (Players)",
        Value = C.State.AuraEnabled or false,
        Callback = function(enabled)
            C.State.AuraEnabled = enabled and true or false

            if enabled then
                auraTarget    = nil
                auraTargetAcc = 0
                auraAttackAcc = 0

                if not auraConn then
                    auraConn = Run.Heartbeat:Connect(function(dt)
                        auraStep(dt)
                    end)
                end
            else
                if auraConn then
                    auraConn:Disconnect()
                    auraConn = nil
                end
                auraTarget = nil
            end
        end,
    })

    tab:Slider({
        Title = "Aura Lock Distance",
        Value = {
            Min     = AURA_RADIUS_MIN,
            Max     = AURA_RADIUS_MAX,
            Default = C.Config.AuraRadius or AURA_RADIUS_DEFAULT,  -- default 10
        },
        Callback = function(v)
            local nv = extractNumber(v, AURA_RADIUS_MIN, AURA_RADIUS_MAX, AURA_RADIUS_DEFAULT)
            C.Config.AuraRadius = nv
        end,
    })
end
