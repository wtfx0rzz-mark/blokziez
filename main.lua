--=====================================================
-- main.lua
--=====================================================

-- Bootstrap loader for WindUI tab modules
repeat task.wait() until game:IsLoaded()

local function httpget(u)
    return game:HttpGet(u)
end

-- Load UI (this calls ui.lua above from your GitHub repo)
local UI = (function()
    local ok, ret_or_err = pcall(function()
        return loadstring(httpget("https://raw.githubusercontent.com/wtfx0rzz-mark/blokziez/refs/heads/main/ui.lua"))()
    end)

    if ok and type(ret_or_err) == "table" then
        return ret_or_err
    end

    warn("ui.lua load error: " .. tostring(ret_or_err))
    error("ui.lua failed to load")
end)()

-- Simple shared environment
local C = {}
C.Services = {
    Players = game:GetService("Players"),
    RS      = game:GetService("ReplicatedStorage"),
    WS      = game:GetService("Workspace"),
    Run     = game:GetService("RunService"),
}
C.LocalPlayer = C.Services.Players.LocalPlayer
C.Config      = C.Config or {}
C.State       = C.State or {}

_G.C  = C
_G.R  = _G.R or {}
_G.UI = UI

-- Remote modules for each tab
local paths = {
    Main  = "https://raw.githubusercontent.com/wtfx0rzz-mark/blokziez/refs/heads/main/tab_main.lua",
    Build = "https://raw.githubusercontent.com/wtfx0rzz-mark/blokziez/refs/heads/main/tab_combat.lua",
    Troll = "https://raw.githubusercontent.com/wtfx0rzz-mark/blokziez/refs/heads/main/tab_misc.lua",
}

for name, url in pairs(paths) do
    local okLoad, chunk_or_err = pcall(function()
        local src = httpget(url)
        return loadstring(src)
    end)

    if not okLoad or type(chunk_or_err) ~= "function" then
        warn(("Module failed to load [%s] from %s: %s"):format(
            tostring(name),
            tostring(url),
            tostring(chunk_or_err)
        ))
    else
        local okRun, err = pcall(chunk_or_err, _G.C, _G.R, _G.UI)
        if not okRun then
            warn(("Module execution failed for [%s]: %s"):format(
                tostring(name),
                tostring(err)
            ))
        end
    end
end
