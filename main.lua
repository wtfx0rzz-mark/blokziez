-- Bootstrap loader for WindUI tab modules
repeat task.wait() until game:IsLoaded()

local function httpget(u)
    return game:HttpGet(u)
end

local UI = (function()
    local ok, ret = pcall(function()
        return loadstring(httpget("https://raw.githubusercontent.com/wtfx0rzz-mark/blokziez/refs/heads/main/ui.lua"))()
    end)
    if ok and type(ret) == "table" then
        return ret
    end
    warn("ui.lua load error: " .. tostring(ret))
    error("ui.lua failed to load")
end)()

local C = {}
C.Services = {
    Players = game:GetService("Players"),
    RS = game:GetService("ReplicatedStorage"),
    WS = game:GetService("Workspace"),
    Run = game:GetService("RunService"),
}
C.LocalPlayer = C.Services.Players.LocalPlayer
C.Config = {}
C.State = {}

_G.C = C
_G.R = _G.R or {}
_G.UI = UI

local paths = {
    Main = "https://raw.githubusercontent.com/wtfx0rzz-mark/blokziez/refs/heads/main/tab_main.lua",
    Combat = "https://raw.githubusercontent.com/wtfx0rzz-mark/blokziez/refs/heads/main/tab_combat.lua",
    Misc = "https://raw.githubusercontent.com/wtfx0rzz-mark/blokziez/refs/heads/main/tab_misc.lua",
}

for name, url in pairs(paths) do
    local ok, mod = pcall(function()
        return loadstring(httpget(url))()
    end)

    if ok and type(mod) == "function" then
        local success, err = pcall(mod, _G.C, _G.R, _G.UI)
        if not success then
            warn("Module execution failed for " .. name .. ": " .. tostring(err))
        end
    else
        warn("Module failed to load: " .. tostring(name) .. " from " .. tostring(url))
    end
end
