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

    local function deleteStep()
        if not Destroy then return end

        local hrp = getHRP()
        if not hrp or not hrp.Parent then
            return
        end

        local origin  = hrp.Position
        local radius  = C.Config.DeleteRadius or DELETE_RADIUS_DEFAULT
        local deleted = 0

        local roots = {}
        local built = WS:FindFirstChild("Built")
        if built then table.insert(roots, built) end

        local personal = WS:FindFirstChild(lp.Name)
        if personal then table.insert(roots, personal) end

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
    -- Tunnel: raycast-based delete directly ahead (face + above + below)
    --------------------------------------------------------------------

    C.State.TunnelEnabled = C.State.TunnelEnabled or false

    -- Distance to check ahead (studs)
    local TUNNEL_DISTANCE     = 3
    -- Max blocks to delete per step (face + above + below = 3)
    local TUNNEL_MAX_PER_STEP = 3
    -- Vertical range (studs) to look above/below the hit
    local VERTICAL_RANGE      = 5

    local function getDeleteRoots()
        local roots = {}
        local built = WS:FindFirstChild("Built")
        if built then table.insert(roots, built) end

        local personal = WS:FindFirstChild(lp.Name)
        if personal then table.insert(roots, personal) end

        return roots
    end

    local function isTunnelCandidate(part)
        if not (part and part:IsA("BasePart")) then return false end
        if part == baseplate then return false end
        if part:IsDescendantOf(lp.Character) then return false end
        return true
    end

    local tunnelParams = RaycastParams.new()
    tunnelParams.FilterType   = Enum.RaycastFilterType.Include
    tunnelParams.IgnoreWater  = true

    local function tunnelStep()
        if not Destroy then return end

        local hrp = getHRP()
        if not hrp or not hrp.Parent then return end

        local roots = getDeleteRoots()
        if #roots == 0 then return end
        tunnelParams.FilterDescendantsInstances = roots

        local cf      = hrp.CFrame
        local pos     = hrp.Position
        local forward = cf.LookVector
        local right   = cf.RightVector
        local up      = cf.UpVector

        -- Sample rays across a small cross-section in front of the player
        local origins = {
            pos + up * 2 + right * 1,
            pos + up * 2 - right * 1,
            pos + right * 1,
            pos - right * 1,
        }

        local seen = {}
        local hits = {}

        local function markSeen(part)
            if not part then return false end
            if seen[part] then return false end
            seen[part] = true
            return true
        end

        for _, origin in ipairs(origins) do
            if #hits >= TUNNEL_MAX_PER_STEP then
                break
            end

            local result = WS:Raycast(origin, forward * TUNNEL_DISTANCE, tunnelParams)
            if result and result.Instance then
                local baseInst = result.Instance
                if isTunnelCandidate(baseInst) and markSeen(baseInst) then
                    table.insert(hits, baseInst)

                    -- Center for vertical checks
                    local hitPos = result.Position

                    -- Block above
                    if #hits < TUNNEL_MAX_PER_STEP then
                        local aboveResult = WS:Raycast(
                            hitPos + up * 0.1,
                            up * VERTICAL_RANGE,
                            tunnelParams
                        )
                        if aboveResult and aboveResult.Instance then
                            local aboveInst = aboveResult.Instance
                            if isTunnelCandidate(aboveInst) and markSeen(aboveInst) then
                                table.insert(hits, aboveInst)
                            end
                        end
                    end

                    -- Block below
                    if #hits < TUNNEL_MAX_PER_STEP then
                        local belowResult = WS:Raycast(
                            hitPos - up * 0.1,
                            -up * VERTICAL_RANGE,
                            tunnelParams
                        )
                        if belowResult and belowResult.Instance then
                            local belowInst = belowResult.Instance
                            if isTunnelCandidate(belowInst) and markSeen(belowInst) then
                                table.insert(hits, belowInst)
                            end
                        end
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

    private_stopTunnel = nil
    local function stopTunnel()
        C.State.TunnelEnabled = false
        if tunnelConn then
            tunnelConn:Disconnect()
            tunnelConn = nil
        end
    end
    private_stopTunnel = stopTunnel

    tab:Toggle({
        Title = "Tunnel (Delete Ahead)",
        Value = false,
        Callback = function(enabled)
            if enabled then
                startTunnel()
            else
                stopTunnel()
            end
        end,
    })

    --------------------------------------------------------------------
    -- Column spam
    --------------------------------------------------------------------

    C.Config.ColumnMaxHeight = C.Config.ColumnMaxHeight or 20
    C.Config.ColumnRadius    = C.Config.ColumnRadius    or 50
    C.Config.ColumnWorkers   = C.Config.ColumnWorkers   or 40

    local rng                 = Random.new()
    local COLUMN_BASE_Y       = 2
    local COLUMN_BLOCK_HEIGHT = 4
    local COLUMN_MIN_BLOCKS   = 5

    local BLOCK_TYPES = { "Oak Planks", "Stone Bricks" }

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
        Value = false,
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
