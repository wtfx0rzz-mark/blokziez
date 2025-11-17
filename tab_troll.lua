-- tab_troll.lua

return function(C, R, UI)
    C  = C  or _G.C
    R  = R  or _G.R
    UI = UI or _G.UI

    assert(UI and UI.Tabs and UI.Tabs.Troll, "tab_troll.lua: Troll tab missing")

    local tab = UI.Tabs.Troll

    local Services = C.Services or {}
    local Players  = Services.Players or game:GetService("Players")
    local RS       = Services.RS      or game:GetService("ReplicatedStorage")
    local WS       = Services.WS      or game:GetService("Workspace")
    local Run      = Services.Run     or game:GetService("RunService")

    local lp = C.LocalPlayer or Players.LocalPlayer

    C.State  = C.State  or {}
    C.Config = C.Config or {}

    local EventsFolder = RS:WaitForChild("Events")
    local Destroy      = EventsFolder:FindFirstChild("DestroyBlock")
    local Place        = EventsFolder:FindFirstChild("Place")

    local baseplate    = WS:FindFirstChild("Baseplate")

    local function getHRP()
        local char = lp.Character or lp.CharacterAdded:Wait()
        return char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart")
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
    local TUNNEL_DIST_MAX       = 15
    local TUNNEL_MAX_PER_STEP   = 6  -- up to 2 blocks per ray * 3 vertical rays

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
    -- Black Wool Infection (random spreading)
    --------------------------------------------------------------------

    local SPREAD_BLOCK             = "Black Wool"
    local SPREAD_BLOCK_SIZE        = 4
    local SPREAD_MAX_STEPS_PER_TICK = 5
    local SPREAD_MAX_TOTAL_BLOCKS  = 800

    C.State.SpreadEnabled = C.State.SpreadEnabled or false

    local spreadFrontier = {}
    local spreadVisited  = {}
    local spreadConn     = nil
    local spreadCount    = 0

    local spreadRayParams = RaycastParams.new()
    spreadRayParams.FilterType  = Enum.RaycastFilterType.Blacklist
    spreadRayParams.IgnoreWater = true

    local function gridKey(gx, gy, gz)
        return string.format("%d:%d:%d", gx, gy, gz)
    end

    local function worldToGrid(pos)
        local s = SPREAD_BLOCK_SIZE
        local gx = math.floor(pos.X / s + 0.5)
        local gy = math.floor(pos.Y / s + 0.5)
        local gz = math.floor(pos.Z / s + 0.5)
        return gx, gy, gz
    end

    local function gridToWorld(gx, gy, gz)
        local s = SPREAD_BLOCK_SIZE
        return Vector3.new(gx * s, gy * s, gz * s)
    end

    local function seedSpread()
        spreadFrontier = {}
        spreadVisited  = {}
        spreadCount    = 0

        if not (Place and baseplate) then return end

        local hrp = getHRP()
        if not hrp then return end

        spreadRayParams.FilterDescendantsInstances = { lp.Character }

        local origin = hrp.Position
        local result = WS:Raycast(origin, Vector3.new(0, -100, 0), spreadRayParams)

        local hitPos = result and result.Position or Vector3.new(origin.X, origin.Y - 5, origin.Z)
        local gx, gy, gz = worldToGrid(hitPos)
        local centerPos  = gridToWorld(gx, gy, gz)
        local key        = gridKey(gx, gy, gz)

        spreadVisited[key] = true
        table.insert(spreadFrontier, { gx = gx, gy = gy, gz = gz })

        pcall(function()
            Place:InvokeServer(SPREAD_BLOCK, CFrame.new(centerPos), baseplate)
        end)
        spreadCount = 1
    end

    local neighborDirs = {
        {  1,  0,  0 },
        { -1,  0,  0 },
        {  0,  1,  0 },
        {  0, -1,  0 },
        {  0,  0,  1 },
        {  0,  0, -1 },
    }

    local function spreadStep()
        if not (Place and baseplate) then return end
        if spreadCount >= SPREAD_MAX_TOTAL_BLOCKS then
            C.State.SpreadEnabled = false
            return
        end

        local steps = 0

        while steps < SPREAD_MAX_STEPS_PER_TICK and #spreadFrontier > 0 do
            steps += 1

            -- pick random frontier cell
            local idx  = math.random(1, #spreadFrontier)
            local cell = spreadFrontier[idx]

            local dir  = neighborDirs[math.random(1, #neighborDirs)]
            local ngx  = cell.gx + dir[1]
            local ngy  = cell.gy + dir[2]
            local ngz  = cell.gz + dir[3]

            local key  = gridKey(ngx, ngy, ngz)
            if not spreadVisited[key] then
                spreadVisited[key] = true

                local pos = gridToWorld(ngx, ngy, ngz)

                pcall(function()
                    Place:InvokeServer(SPREAD_BLOCK, CFrame.new(pos), baseplate)
                end)

                spreadCount += 1
                table.insert(spreadFrontier, { gx = ngx, gy = ngy, gz = ngz })

                if spreadCount >= SPREAD_MAX_TOTAL_BLOCKS then
                    C.State.SpreadEnabled = false
                    break
                end
            end
        end
    end

    local function startSpread()
        if spreadConn or not Place or not baseplate then return end

        C.State.SpreadEnabled = true
        seedSpread()

        spreadConn = Run.Heartbeat:Connect(function()
            if not C.State.SpreadEnabled then return end
            spreadStep()
        end)
    end

    local function stopSpread()
        C.State.SpreadEnabled = false
        if spreadConn then
            spreadConn:Disconnect()
            spreadConn = nil
        end
    end

    tab:Toggle({
        Title = "Black Wool Infection",
        Value = C.State.SpreadEnabled or false,
        Callback = function(enabled)
            if enabled then
                startSpread()
            else
                stopSpread()
            end
        end,
    })

    --------------------------------------------------------------------
    -- Column spam (always Black Wool)
    --------------------------------------------------------------------

    C.Config.ColumnMaxHeight = C.Config.ColumnMaxHeight or 20
    C.Config.ColumnRadius    = C.Config.ColumnRadius    or 50
    C.Config.ColumnWorkers   = C.Config.ColumnWorkers   or 40

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
                local workers = C.Config.ColumnWorkers or 40
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
            Min     = 10,
            Max     = 150,
            Default = C.Config.ColumnRadius or 50,
        },
        Callback = function(v)
            local nv = extractNumber(v, 10, 150, C.Config.ColumnRadius or 50)
            C.Config.ColumnRadius = nv
        end,
    })
end
