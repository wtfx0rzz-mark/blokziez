-- WindUI wrapper and window setup
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Players = game:GetService("Players")
local lp = Players.LocalPlayer

local Window = WindUI:Window({
    Title = "1337 Nights",
    Icon = "moon",
    Author = "Mark",
    Folder = "99Nights",
    Size = UDim2.fromOffset(500, 350),
    Transparent = false,
    Theme = "Dark",
    Resizable = true,
    SideBarWidth = 150,
    HideSearchBar = false,
    ScrollBarEnabled = true,
    Buttons = {
        User = {
            Text = "User",
            Icon = "user",
            Callback = function()
                WindUI:Notify({
                    Title = "User",
                    Content = "Logged In As: " .. (lp and (lp.DisplayName or lp.Name) or "Unknown"),
                    Duration = 4,
                    Icon = "user"
                })
            end,
        },
    },
})

Window:SetToggleKey(Enum.KeyCode.V)

local Tabs = {
    Main = Window:Tab({ Title = "Main", Icon = "home", Desc = "Main controls" }),
    Combat = Window:Tab({ Title = "Combat", Icon = "sword", Desc = "Combat options" }),
    Misc = Window:Tab({ Title = "Misc", Icon = "settings", Desc = "Miscellaneous" }),
}

return {
    Lib = WindUI,
    Window = Window,
    Tabs = Tabs,
}
