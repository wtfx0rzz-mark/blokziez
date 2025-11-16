-- FILE: main.lua
-- Bootstrap loader for WindUI tab modules

repeat task.wait() until game:IsLoaded()

local function httpget(u)
    return game:HttpGet(u)
end

-- Load ui.lua safely and ensure it returns the expected table
local UI = (function()
    local url = "https://raw.githubusercontent.com/wtfx0rzz-mark/blokziez/refs/heads/main/ui.lua"

    -- Step 1: download + compile
    local okLoad, chunkOrErr = pcall(function()
        local src = httpget(url)
        return loadstring(src)
    end)

    if not okLoad or type(chunkOrErr) ~= "function" then
        warn("ui.lua load error (download/compile): " .. tostring(chunkOrErr))
        error("ui.lua failed to load")
    end

    -- Step 2: execute compiled chunk
    local okRun, ret = pcall(chunkOrErr)
    if okRun and type(ret) == "table" then
        return ret
    end

    warn("ui.lua load error (runtime / bad return): " .. tostring(ret))
    error("ui.lua failed to load")
end)()

-- Global environment / config
local C = {}
C.Services = {
    Players = game:GetService("Players"),
    RS      = game:GetService("ReplicatedStorage"),
    WS      = game:GetService("Workspace"),
    Run     = game:GetService("RunService"),
}
C.LocalPlayer = C.Services.Players.LocalPlayer
C.Config = C.Config or {}
C.State  = C.State  or {}

_G.C  = C
_G.R  = _G.R or {}
_G.UI = UI

-- Tab module paths
local paths = {
    Main  = "https://raw.githubusercontent.com/wtfx0rzz-mark/blokziez/refs/heads/main/tab_main.lua",
    Build = "https://raw.githubusercontent.com/wtfx0rzz-mark/blokziez/refs/heads/main/tab_combat.lua", -- attaches to Tabs.Build
    Troll = "https://raw.githubusercontent.com/wtfx0rzz-mark/blokziez/refs/heads/main/tab_misc.lua",   -- attaches to Tabs.Troll
}

for name, url in pairs(paths) do
    local okMod, modOrErr = pcall(function()
        local src = httpget(url)
        return loadstring(src)
    end)

    if not okMod or
