-- FILE: tab_misc.lua  (Troll tab)
-- Attach to Tabs.Troll and provide a Block Deletion toggle

return function(C, R, UI)
    C  = C  or _G.C
    R  = R  or _G.R
    UI = UI or _G.UI

    local Tabs = (UI and UI.Tabs) or {}
    local tab  = Tabs.Troll
    if not tab then
        return
    end

    -- Ensure state table exists
    C.State = C.State or {}

    -- Helper to enable/disable block deletion behavior
    local function setBlockDeletionEnabled(enabled)
        C.State.BlockDeletionEnabled = enabled

        -- Optional runtime helper; safe to call if present
        local helper = R and R.BlockDeletionHelper
        if type(helper) == "function" then
            local ok, err = pcall(helper, enabled)
            if not ok then
                warn("BlockDeletionHelper error: " .. tostring(err))
            end
        end
    end

    local trollSection = tab:Section({
        Title = "Troll Options",
        Icon  = "settings",
    })

    trollSection:Label("Troll tab is ready. Add utility features here.")

    trollSection:Toggle({
        Name    = "Block Deletion",
        Default = false,
        Callback = function(value)
            setBlockDeletionEnabled(value)
        end,
    })

    trollSection:Button({
        Name = "Say Hello",
        Callback = function()
            local lib = UI and UI.Lib
            if lib and type(lib.Notify) == "function" then
                lib:Notify({
                    Title   = "Hello",
                    Content = "Troll tab button clicked.",
                    Duration = 3,
                    Icon    = "info",
                })
            end
        end,
    })
end
