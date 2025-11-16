return function(C, R, UI)
    C = C or _G.C
    R = R or _G.R
    UI = UI or _G.UI

    local Tabs = (UI and UI.Tabs) or {}
    local tab = Tabs.Build
    if not tab then
        return
    end

    local combatSection = tab:Section({ Title = "Build Settings", Icon = "sword" })

    combatSection:Label("Build tab is ready. Add building features here.")

    combatSection:Slider({
        Name = "Example Damage",
        Min = 1,
        Max = 100,
        Default = 25,
        Callback = function(value)
        end,
    })
end
