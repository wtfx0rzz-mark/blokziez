-- tab_troll.lua
-- Troll tab with text + a simple "Delete Blocks" switch (no functionality yet)

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

    -- Text at the top of the Troll tab
    tab:Paragraph({
        Title = "Troll Tab",
        Desc  = "Use this tab for troll / utility features.",
        Color = "Blue",
    })

    -- Spacer paragraph (optional, just for a little vertical padding)
    tab:Paragraph({
        Title = "",
        Desc  = "Delete Blocks:",
        Color = "White",
    })

    -- Simple switch (WindUI-style Toggle, no functionality yet)
    tab:Toggle({
        Title    = "Delete Blocks",
        Value    = false,
        Callback = function(enabled)
            -- Placeholder only; no behavior wired yet
            -- You can later hook this to your delete logic
        end,
    })
end
