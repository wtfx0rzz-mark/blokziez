repeat task.wait() until game:IsLoaded()

local function httpget(u)
    return game:HttpGet(u)
end

local UI = (function()
    local ok, ret = pcall(function()
        return loadstring(httpget("https://raw.githubusercontent.com/wtfx0rzz-mark/blokziez/main/ui.lua"))()
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

local paths = {
    Main  = "https://raw.githubusercontent.com/wtfx0rzz-mark/blokziez/main/tab_main.lua",
    Build = "https://raw.githubusercontent.com/wtfx0rzz-mark/blokziez/main/tab_build.lua",
    Troll = "https://raw.githubusercontent.com/wtfx0rzz-mark/blokziez/main/tab_troll.lua"
}

for name, url in pairs(paths) do
    local okLoad, chunkOrErr = pcall(function()
        local src = httpget(url)
        return loadstring(src)
    end)

    if not okLoad or type(chunkOrErr) ~= "function" then
        warn("Module failed to load [" .. tostring(name) .. "] from " .. tostring(url) .. " : " .. tostring(chunkOrErr))
    else
        local okRun, err = pcall(chunkOrErr, _G.C, _G.R, _G.UI)
        if not okRun then
            warn("Module execution failed for [" .. tostring(name) .. "]: " .. tostring(err))
        end
    end
end
