return function(C, R, UI)
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

    C.State = C.State or {}

    local Services = C.Services or {}
    local Players  = Services.Players or game:GetService("Players")
    local RS       = Services.RS      or game:GetService("ReplicatedStorage")
    local WS       = Services.WS      or game:GetService("Workspace")
    local lp       = C.LocalPlayer or Players.LocalPlayer

    local DELETE_RADIUS = 30
    local MAX_PER_TICK  = 200
    local SLEEP_BETWEEN = 0.05

    local DestroyRemote

    local function ensureDestroyRemote()
        if DestroyRemote and DestroyRemote.Parent then
            return true
        end
        local events = RS:FindFirstChild("Events") or RS:WaitForChild("Events", 5)
        if not events then
            warn("tab_troll.lua: Events folder not found")
            return false
        end
        DestroyRemote = events:FindFirstChild("DestroyBlock") or events:WaitForChild("DestroyBlock", 5)
        if not DestroyRemote then
            warn("tab_troll.lua: DestroyBlock remote not found")
            return false
        end
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
            while deleteLoopRunning and C.State.AutoDeleteEnabled do
                deleteStep()
                task.wait(SLEEP_BETWEEN)
            end
            deleteLoopRunning = false
        end)
    end

    local function stopDeleteLoop()
        deleteLoopRunning = false
    end

    local section = tab:Section({
        Title = "Auto Delete Blocks",
        Icon  = "trash",
    })

    section:Label("Automatically deletes nearby built blocks around you.")

    section:Toggle({
        Name    = "Auto Delete Nearby Blocks",
        Default = false,
        Callback = function(enabled)
            C.State.AutoDeleteEnabled = enabled
            if enabled then
                startDeleteLoop()
            else
                stopDeleteLoop()
            end
        end,
    })
end
