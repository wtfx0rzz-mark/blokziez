-- tab_troll.lua
-- Troll tab: Delete Blocks + Column Spam

return function(C, R, UI)
    -- Fallback to globals if not passed
    C  = C  or _G.C
    R  = R  or _G.R
    UI = UI or _G.UI

    if not UI or not UI.Tabs or not UI.Tabs.Troll then
        warn("tab_troll.lua: Troll tab missing")
        return
    end

    local tab = UI.Tabs.Troll

    ------------------------------------------------
    -- Services / player / shared state
    ------------------------------------------------
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

    ------------------------------------------------
    -- Header text
    ------------------------------------------------
    tab:Paragraph({
        Title = "Troll / Utility",
        Desc  = "Block utilities for Blokziez.",
        Color = "Blue",
    })

    ------------------------------------------------
    -- DELETE BLOCKS (auto-delete nearby blocks)
    ------------------------------------------------
    local DELETE_RADIUS_DEFAULT = 30
    local DELETE_MAX_PER_STEP   = 200

    C.Config.DeleteRadius = C.Config.DeleteRadius or DELETE_RADIUS_DEFAULT

    local function deleteStep()
        if not Destroy then return end

        local hrp = getHRP()
        if not hrp or not hrp.Parent then
            return
        end

        local origin = hrp.Position
        local radius = C.Config.DeleteRadius or DELETE_RADIUS_DEFAULT
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
                Run.Heartbeat:Wait() -- no artificial delay between sweeps
            end
            deleteLoopRunning = false
        end)
    end

    local function stopDeleteLoop()
        deleteLoopRunning = false
    end

    tab:Paragraph({
        Title = "Delete Blocks",
        Desc  = "Automatically destroy nearby built blocks.",
        Color = "White",
    })

    tab:Toggle({
        Title = "Delete Blocks",
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

    ------------------------------------------------
    -- COLUMN SPAM (random columns around player)
    ------------------------------------------------
    -- Defaults
    C.Config.ColumnMaxHeight = C.Config.ColumnMaxHeight or 20
    C.Config.ColumnRadius    = C.Config.ColumnRadius    or 50
    C.Config.ColumnWorkers   = C.Config.ColumnWorkers   or 40

    local rng                  = Random.new()
    local COLUMN_BASE_Y        = 2
    local COLUMN_BLOCK_HEIGHT  = 4
    local COLUMN_MIN_BLOCKS    = 5

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

    -- Small spacer
    tab:Paragraph({
        Title = "",
        Desc  = "",
        Color = "White",
    })

    tab:Paragraph({
        Title = "Column Spam",
        Desc  = "Spawn random columns of blocks around you.",
        Color = "White",
    })

    -- Slider: Column Height
    tab:Slider({
        Title = "Column Height",
        Step  = 1,
        Value = {
            Min     = 5,
            Max     = 60,
            Default = C.Config.ColumnMaxHeight,
        },
        Callback = function(value)
            value = math.clamp(math.floor(value), 5, 60)
            C.Config.ColumnMaxHeight = value
        end,
    })

    -- Slider: Blocks around player (radius)
    tab:Slider({
        Title = "Blocks Around Player",
        Step  = 1,
        Value = {
            Min     = 10,
            Max     = 150,
            Default = C.Config.ColumnRadius,
        },
        Callback = function(value)
            value = math.clamp(math.floor(value), 10, 150)
            C.Config.ColumnRadius = value
        end,
    })

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
                for i = 1, workers do
                    task.spawn(columnWorker)
                end
            end
        end,
    })
end
