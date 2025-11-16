--=====================================================
-- tab_misc.lua  (Troll tab)
--=====================================================

return function(C, R, UI)
    C  = C  or _G.C
    R  = R  or _G.R
    UI = UI or _G.UI

    if not UI or not UI.Tabs then
        warn("Troll tab: UI or UI.Tabs is missing")
        return
    end

    local tab = UI.Tabs.Troll
    if not tab then
        warn("Troll tab: Tabs.Troll not found")
        return
    end

    C.State = C.State or {}

    -- Optional info paragraph at top
    local infoParagraph = tab:Paragraph({
        Title     = "Troll Utilities",
        Desc      = "Use these tools in your own worlds to delete placed blocks.",
        Color     = "Red",
        Image     = "",
        ImageSize = 0,
        Thumbnail = "",
        ThumbnailSize = 0,
        Locked    = false,
        Buttons   = {},
    })

    -- Main toggle to control your block deletion logic
    local blockDeletionToggle = tab:Toggle({
        Title   = "Block Deletion",
        Desc    = "Enable / disable the block deletion script.",
        Icon    = "trash",
        Type    = "Checkbox",
        Value   = false,
        Callback = function(enabled)
            C.State.BlockDeletionEnabled = enabled

            -- If you’ve implemented helper logic, wire it here
            if R and type(R.BlockDeletionHelper) == "function" then
                -- true  => start deletion
                -- false => stop deletion
                local ok, err = pcall(R.BlockDeletionHelper, enabled)
                if not ok then
                    warn("BlockDeletionHelper error: " .. tostring(err))
                end
            end

            if UI and UI.Lib and UI.Lib.Notify then
                UI.Lib:Notify({
                    Title   = "Block Deletion",
                    Content = enabled and "Block deletion ENABLED" or "Block deletion DISABLED",
                    Duration = 3,
                    Icon    = enabled and "check" or "x-circle",
                })
            end
        end,
    })

    -- Optional manual “pulse” button if you want a one-shot call
    local pulseButton = tab:Button({
        Title    = "Run Deletion Once",
        Desc     = "Invoke a single deletion pass (if helper is implemented).",
        Icon     = "zap",
        Callback = function()
            if R and type(R.BlockDeletionHelper) == "function" then
                local ok, err = pcall(R.BlockDeletionHelper, true)
                if not ok then
                    warn("BlockDeletionHelper one-shot error: " .. tostring(err))
                end
            end

            if UI and UI.Lib and UI.Lib.Notify then
                UI.Lib:Notify({
                    Title   = "Troll",
                    Content = "One-shot block deletion invoked.",
                    Duration = 3,
                    Icon    = "zap",
                })
            end
        end,
    })
end
