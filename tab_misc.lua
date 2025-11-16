return function(C, R, UI)
    C = C or _G.C
    R = R or _G.R
    UI = UI or _G.UI

    local Tabs = (UI and UI.Tabs) or {}
    local tab = Tabs.Misc
    if not tab then
        return
    end

    local miscSection = tab:Section({ Title = "Misc Options", Icon = "settings" })

    miscSection:Label("Misc tab is ready. Add utility features here.")

    miscSection:Button({
        Name = "Say Hello",
        Callback = function()
            UI.Lib:Notify({
                Title = "Hello",
                Content = "Misc tab button clicked.",
                Duration = 3,
                Icon = "info",
            })
        end,
    })
end
