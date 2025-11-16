-- tab_troll.lua

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
    local S = C.State

    local Services = C.Services or {}
    local Players  = Services.Players or game:GetService("Players")
    local RS       = Services.RS      or game:GetService("ReplicatedStorage")
    local WS       = Services.WS      or game:GetService("Workspace")
    local Run      = Services.Run     or game:GetService("RunService")

    local lp = C.LocalPlayer or Players.LocalPlayer

    local Destroy = RS:WaitForChild("Events"):WaitForChild("DestroyBlock")

    local buildRoots = {}
    do
        local built = WS:FindFirstChild("Built")
        if built then
            table.insert(buildRoots, built)
        end

        local personal = WS:FindFirstChild(lp.Name)
        if personal then
            table.insert(buildRoots, personal)
        end
    end

    local DELETE_RADIUS = 30
    local MAX_PER_TICK  = 200

    local function getHRP()
        local char = lp.Character or lp.CharacterAdded:Wait()
        return char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart")
    end

    local function deleteStep()
        local hrp = getHRP()
        if not hrp or not hrp.Parent then
            return
        end

        local origin  = hrp.Position
        local deleted = 0

        for _, root in ipairs(buildRoots) do
            if not S.DeleteBlocksEnabled then
                return
            end

            for _, inst in ipairs(root:GetDescendants()) do
                if not S.DeleteBlocksEnabled then
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

    local deleteLoopRunning = false

    local function startDeleteLoop()
        if deleteLoopRunning then
            return
        end
        deleteLoopRunning = true

        task.spawn(function()
            while deleteLoopRunning and S.DeleteBlocksEnabled do
                deleteStep()
                Run.Heartbeat:Wait()
            end
            deleteLoopRunning = false
        end)
    end

    local function stopDeleteLoop()
        deleteLoopRunning     = false
        S.DeleteBlocksEnabled = false
    end

    tab:Paragraph({
        Title = "Troll Tab",
        Desc  = "Use this tab for troll / utility features.",
        Color = "Blue",
    })

    tab:Paragraph({
        Title = "",
        Desc  = "Delete Blocks:",
        Color = "White",
    })

    tab:Toggle({
        Title    = "Auto Delete Nearby Blocks",
        Value    = false,
        Callback = function(enabled)
            S.DeleteBlocksEnabled = enabled and true or false
            if enabled then
                startDeleteLoop()
            else
                stopDeleteLoop()
            end
        end,
    })
end
