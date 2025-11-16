-- tab_troll.lua
-- Simple placeholder text for the Troll tab

return function(C, R, UI)
    -- Fallback to globals if not passed
    C  = C  or _G.C
    R  = R  or _G.R
    UI = UI or _G.UI

    if not UI or not UI.Tabs then
        warn("tab_troll.lua: UI or UI.Tabs missing")
        return
    end

    local Tabs = UI.Tabs
    local tab  = Tabs.Troll
    if not tab then
        warn("tab_troll.lua: Tabs.Troll not found")
        return
    end

    -- Simple text-only content using a Paragraph element
    tab:Paragraph({
        Title = "Troll Tab",
        Desc  = "This is a placeholder for future troll / utility features.",
        Color = "Blue",  -- any valid WindUI color name
    })
end
