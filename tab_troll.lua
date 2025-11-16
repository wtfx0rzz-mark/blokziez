-- tab_troll.lua
-- Minimal placeholder: one section + one toggle

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

    -- Simple section
    local section = tab:Section({
        Title = "Troll Controls",
        Icon  = "skull",
    })

    -- Single placeholder toggle
    section:Toggle({
        Name    = "Placeholder Switch",
        Default = false,
        Callback = function(value)
            -- no-op for now
        end,
    })
end
