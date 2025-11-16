-- tab_troll.lua
-- Minimal Troll tab: one section + one placeholder switch

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

    -- Section header (matches style from your Auto tab)
    tab:Section({
        Title = "Troll Controls",
        Icon  = "skull",
    })

    -- Placeholder toggle (WindUI-style: tab:Toggle, using Title / Value / Callback)
    tab:Toggle({
        Title    = "Block Deletion (Placeholder)",
        Value    = false,
        Callback = function(enabled)
            -- Placeholder only for now
            -- Later you can wire this to your actual delete logic
            if C and C.State then
                C.State.BlockDeletionEnabled = enabled
            end
        end,
    })
end
