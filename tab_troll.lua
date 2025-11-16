-- tab_troll.lua
-- Troll tab with auto-delete nearby blocks toggle

return function(C, R, UI)
    -- Fallback to globals if not passed
    C  = C  or _G.C
    R  = R  or _G.R
    UI = UI or _G.UI

    -- Basic safety checks
    if not UI or not UI.Tabs then
        warn("tab_troll.lua: UI or UI.Tabs missing")
        return
    end

    local Tabs = UI.Tabs
    local tab  = Tabs.Troll
    if not tab then
        warn("tab_troll.lua: Tabs.Troll not found")
        return
    end

    ------------------------------------------------
    -- Services / player / remotes
    ------------------------------------------------
    local Services = C.Services or {}
    local Players  = Services.Players or game:GetService("Players")
    local RS       = Services.RS      or game:GetService("ReplicatedStorage")
    local WS       = Services.WS      or game:GetService("Workspace")

    local lp = C.LocalPlayer or Players.LocalPlayer

    local EventsFolder = RS:WaitForChild("Events")
    local Destroy      = EventsFolder:WaitForChild("DestroyBlock")

    ------------------------------------------------
    -- Constants
    ------------------------------------------------
    local DELETE_RADIUS = 30       -- studs around player
    local MAX_PER_TICK  = 200      -- safety cap per pass
    local SLEEP_BETWEEN = 0.05     -- delay between passes

    ------------------------------------------------
    -- Helpers
    ------------------------------------------------
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
        local hrp = getHRP()
        if not hrp or not hrp.Parent then
            return
        end

        local origin  = hrp.Position
        local deleted = 0
        local roots   = getBuildRoots()

        for _, root in ipairs(roots) do
            -- Allow early exit if disabled mid-iteration
            if not C.State.AutoDeleteEnabled then
                return
            end

            for _, inst in ipairs(root:GetDescendants()) do
                if not C.State.AutoDeleteEnabled then
                    return
                end

                if inst:IsA("BasePart") then
                    local dist = (inst.Position - origin).Magnitude
                    if dist <= DELETE_RADIUS then
                        pcall(function()
                            Destroy:InvokeServer(inst)
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

    -- Background loop (started/stopped by the toggle)
    local deleteLoopRunning = false

    local function startDeleteLoop()
        if deleteLoopRunning then
            return
        end
        deleteLoopRunning = true

        task.spawn(function()
            while deleteLoopRunning and C.State.AutoDeleteEnabled do
                deleteStep()
                task.wait(SLEEP_BETWEEN)
            end
            deleteLoopRunning = false
        end)
    end

    local function stopDeleteLoop()
        -- The loop checks this flag and C.State.AutoDeleteEnabled and exits gracefully
        deleteLoopRunning = false
    end

    ------------------------------------------------
    -- Troll tab UI
    ------------------------------------------------
    local section = tab:Section({
        Title = "Auto Delete Blocks",
        Icon  = "trash",
    })

    -- Main toggle to control auto-delete behavior
    section:Toggle({
        Name    = "Auto Delete Nearby Blocks",
        Default = false,
        Callback = function(enabled)
            C.State = C.State or {}
            C.State.AutoDeleteEnabled = enabled

            if enabled then
                startDeleteLoop()
            else
                stopDeleteLoop()
            end
        end,
    })
end
