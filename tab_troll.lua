-- tab_troll.lua
-- Troll tab with "Delete Nearby Blocks" toggle wired to DestroyBlock

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

    ------------------------------------------------
    -- Services / player / remotes
    ------------------------------------------------
    local Services = C.Services or {}
    local Players  = Services.Players or game:GetService("Players")
    local RS       = Services.RS      or game:GetService("ReplicatedStorage")
    local WS       = Services.WS      or game:GetService("Workspace")
    local Run      = Services.Run     or game:GetService("RunService")

    local lp = C.LocalPlayer or Players.LocalPlayer

    local EventsFolder  = RS:WaitForChild("Events")
    local DestroyBlock  = EventsFolder:WaitForChild("DestroyBlock")

    C.State = C.State or {}
    local S = C.State

    ------------------------------------------------
    -- Constants (match working standalone script)
    ------------------------------------------------
    local DELETE_RADIUS = 30       -- studs around player
    local MAX_PER_TICK  = 200      -- safety cap per pass

    ------------------------------------------------
    -- Helpers
    ------------------------------------------------
    local function getHRP()
        local char = lp.Character or lp.CharacterAdded:Wait()
        return char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart")
    end

    -- We mirror the “buildRoots” logic from the working script
    local buildRoots = {}

    local function refreshBuildRoots()
        buildRoots = {}

        local built = WS:FindFirstChild("Built")
        if built then
            table.insert(buildRoots, built)
        end

        local personal = WS:FindFirstChild(lp.Name)
        if personal then
            table.insert(buildRoots, personal)
        end
    end

    refreshBuildRoots()

    local function deleteStep()
        if not S.DeleteBlocksEnabled then
            return
        end

        local hrp = getHRP()
        if not hrp or not hrp.Parent then
            return
        end

        -- Ensure roots stay valid
        if #buildRoots == 0 then
            refreshBuildRoots()
            if #buildRoots == 0 then
                return
            end
        end

        local origin  = hrp.Position
        local deleted = 0

        for _, root in ipairs(buildRoots) do
            if not S.DeleteBlocksEnabled then
                return
            end

            if root and root.Parent then
                for _, inst in ipairs(root:GetDescendants()) do
                    if not S.DeleteBlocksEnabled then
                        return
                    end

                    if inst:IsA("BasePart") then
                        local dist = (inst.Position - origin).Magnitude
                        if dist <= DELETE_RADIUS then
                            pcall(function()
                                DestroyBlock:InvokeServer(inst)
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
    end

    ------------------------------------------------
    -- Background loop (runs every Heartbeat, no extra wait)
    ------------------------------------------------
    local deleteLoopRunning = false

    local function startDeleteLoop()
        if deleteLoopRunning then
            return
        end
        deleteLoopRunning = true

        task.spawn(function()
            while deleteLoopRunning and S.DeleteBlocksEnabled do
                deleteStep()
                Run.Heartbeat:Wait()  -- no artificial delay, per your request
            end
            deleteLoopRunning = false
        end)
    end

    local function stopDeleteLoop()
        deleteLoopRunning = false
    end

    ------------------------------------------------
    -- Troll tab UI
    ------------------------------------------------
    tab:Paragraph({
        Title = "Troll Tab",
        Desc  = "Utility / troll helpers.",
        Color = "Blue",
    })

    tab:Toggle({
        Title = "Delete Nearby Blocks",
        Value = false,
        Callback = function(enabled)
            S.DeleteBlocksEnabled = enabled and true or false

            if enabled then
                -- Make sure roots are up to date when you enable
                refreshBuildRoots()
                startDeleteLoop()
            else
                stopDeleteLoop()
            end
        end,
    })
end
