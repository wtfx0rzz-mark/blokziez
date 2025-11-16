-- ui.lua

local Players = game:GetService("Players")
local lp = Players.LocalPlayer

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "Blokziez",
    Icon = "cube",
    Author = "Mark",
    Folder = "Blokziez",
    Size = UDim2.fromOffset(500, 350),
    Transparent = false,
    Theme = "Dark",
    Resizable = true,
    SideBarWidth = 150,
    HideSearchBar = false,
    ScrollBarEnabled = true,
    User = {
        Enabled = true,
        Anonymous = false,
        Callback = function()
            WindUI:Notify({
                Title = "User Info",
                Content = "Logged In As: " .. (lp.DisplayName or lp.Name),
                Duration = 3,
                Icon = "user",
            })
        end,
    },
})

Window:SetToggleKey(Enum.KeyCode.V)

local Tabs = {
    Main = Window:Tab({
        Title = "Main",
        Icon = "home",
        Desc = "Main controls",
    }),

    Build = Window:Tab({
        Title = "Build",
        Icon = "home", -- you can change this icon if you want
        Desc = "Build Controls",
    }),

    Troll = Window:Tab({
        Title = "Troll",
        Icon = "skull",
        Desc = "Troll / Utility Controls",
    }),
}

return {
    Lib = WindUI,
    Window = Window,
    Tabs = Tabs,
}
