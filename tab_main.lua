return function(C, R, UI)
    C = C or _G.C
    R = R or _G.R
    UI = UI or _G.UI

    local Tabs = (UI and UI.Tabs) or {}
    local tab = Tabs.Main
    if not tab then
        return
    end

    local mainSection = tab:Section({ Title = "Main Controls", Icon = "home" })

    mainSection:Label("Main tab is ready. Add controls here.")

    mainSection:Toggle({
        Name = "Example Toggle",
        Default = false,
        Callback = function(value)
        end,
    })
end
