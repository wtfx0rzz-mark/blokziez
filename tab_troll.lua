-- tab_troll.lua
-- Troll tab with text + working "Delete Blocks" auto-delete toggle

return function(C, R, UI)
    -- Fallback to globals if not passed
    C  = C  or _G.C
    R  = R  or _G.R
    UI = UI or _G.UI

    if not UI or not UI.Tabs then
        warn("tab_troll.lua: UI or UI.Tabs missing")
        return
    end

    local tab = UI.Tabs.Troll
    if not tab then
        warn("tab_troll.lua: Tabs.Troll not found")
        return
    end

    C.State    = C.State or {}
    local S    = C.State

    ------------------------------------------------
    -- Services / player
    ------------------------------------------------
    local Services = C.Services or {}
    local Players  = Services.Players or game:GetService("Players")
    local RS       = Services.RS      or game:GetService("ReplicatedStorage")
    local WS       = Services.WS      or game:GetService("Workspace")

    local lp       = C.LocalPlayer or Players.LocalPlayer

    ------------------------------------------------
    -- Delete-blocks runtime
    ------------------------------------------------
    local DELETE_RADIUS = 30       -- studs around player
    local MAX_PER_TICK  = 200      -- max parts per sweep
    local SLEEP_BETWEEN = 0.001     -- delay between sweeps

    local DestroyRemote = nil

    local function ensureDestroyRemote()
        if DestroyRemote and DestroyRemote.Parent then
            return true
        end

        local events = RS:FindFirstChild("Events")
        if not events then
            warn("tab_troll.lua: ReplicatedStorage.Events not found")
            return false
        end

        local destroy = events:FindFirstChild("DestroyBlock")
        if not destroy then
            warn("tab_troll.lua: Events.DestroyBlock remote not found")
            return false
        end

        DestroyRemote = destroy
        return true
    end

    local function getHRP()
        local char = lp.Character or lp.CharacterAdded:Wait()
        return char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart")
    end

    local function getBuildRoots()
        local roots = {}

        local built = WS:FindFirstChild("Built")
        if built then
            table.insert(roots, built)
        end

        local personal = WS:FindFirstChild(lp.Name)
        if personal then
            table.insert(roots, personal)
        end

        return roots
    end

    local function deleteStep()
        if not ensureDestroyRemote() then
            return
        end

        local hrp = getHRP()
        if not hrp or not hrp.Parent then
            return
        end

        local origin  = hrp.Position
        local deleted = 0
        local roots   = getBuildRoots()

        for _, root in ipairs(roots) do
            if not S.AutoDeleteBlocksEnabled then
                return
            end

            for _, inst in ipairs(root:GetDescendants()) do
                if not S.AutoDeleteBlocksEnabled then
                    return
                end

                if inst:IsA("BasePart") then
                    local dist = (inst.Position - origin).Magnitude
                    if dist <= DELETE_RADIUS then
                        pcall(function()
                            DestroyRemote:InvokeServer(inst)
                        end)

                        deleted += 1
                        if deleted >= MAX_PER_TICK then
                            return
                        end
                    end
                end
            end
        end
    end

    local deleteLoopRunning = false

    local function startDeleteLoop()
        if deleteLoopRunning then
            return
        end
        deleteLoopRunning = true

        task.spawn(function()
            while deleteLoopRunning and S.AutoDeleteBlocksEnabled do
                deleteStep()
                task.wait(SLEEP_BETWEEN)
            end
            deleteLoopRunning = false
        end)
    end

    local function stopDeleteLoop()
        deleteLoopRunning           = false
        S.AutoDeleteBlocksEnabled   = false
    end

    ------------------------------------------------
    -- Troll tab UI
    ------------------------------------------------

    -- Intro text
    tab:Paragraph({
        Title = "Troll Tab",
        Desc  = "Use this tab for troll / utility features.",
        Color = "Blue",
    })

    -- Label above the toggle
    tab:Paragraph({
        Title = "",
        Desc  = "Delete Blocks:",
        Color = "White",
    })

    -- Working toggle for auto delete
    tab:Toggle({
        Title    = "Auto Delete Nearby Blocks",
        Value    = false,
        Callback = function(enabled)
            S.AutoDeleteBlocksEnabled = enabled and true or false

            if enabled then
                startDeleteLoop()
            else
                stopDeleteLoop()
            end
        end,
    })
end
