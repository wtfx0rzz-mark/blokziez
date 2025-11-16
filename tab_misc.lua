return function(C, R, UI)
    C = C or _G.C
    R = R or _G.R
    UI = UI or _G.UI

    local Tabs = (UI and UI.Tabs) or {}
    local tab = Tabs.Troll
    if not tab then
        return
    end

    local miscSection = tab:Section({ Title = "Troll Options", Icon = "settings" })

    miscSection:Label("Troll tab is ready. Add utility features here.")

    miscSection:Toggle({
        Name = "Block Deletion",
        Default = false,
        Callback = function(value)
            if C and C.State then
                C.State.BlockDeletionEnabled = value
            end

            local helper = R and R.BlockDeletionHelper
            if type(helper) == "function" then
                helper(value)
            end
        end,
    })

    miscSection:Button({
        Name = "Say Hello",
        Callback = function()
            UI.Lib:Notify({
                Title = "Hello",
                Content = "Troll tab button clicked.",
                Duration = 3,
                Icon = "info",
            })
        end,
    })
end
