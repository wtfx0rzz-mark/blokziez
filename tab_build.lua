-- tab_build.lua
-- Blokziez • Build tab: block picker + small house builder

return function(C, R, UI)
    C  = C  or _G.C
    R  = R  or _G.R
    UI = UI or _G.UI

    local Services = C and C.Services or {}
    local Players  = Services.Players  or game:GetService("Players")
    local RS       = Services.RS       or game:GetService("ReplicatedStorage")
    local WS       = Services.WS       or game:GetService("Workspace")

    local lp   = C.LocalPlayer or Players.LocalPlayer
    local Tabs = (UI and UI.Tabs) or {}
    local tab  = Tabs.Build
    if not tab then return end

    C.Config = C.Config or {}

    local EventsFolder = RS:WaitForChild("Events", 5)
    local Place        = EventsFolder and EventsFolder:FindFirstChild("Place")
    local baseplate    = WS:FindFirstChild("Baseplate")

    local BLOCK_ITEMS = {
        "Birch Log",
        "Sandstone",
        "Rainbow Oak Planks",
        "Oak Log",
        "Green Wool",
        "Red Glass",
        "Light Cobblestone",
        "Mossy Stone Blocks",
        "Yellow Glass",
        "Diamond Block",
        "Orange Wool",
        "Glass",
        "Deepslate Bricks",
        "Gravel",
        "Birch Planks",
        "Rainbow Stone",
        "Gray Wool",
        "Yellow Wool",
        "Red Wool",
        "Rainbow Sand",
        "Spruce Door",
        "Pink Glass",
        "Stripped Oak Log",
        "Stripped Orange Wood Log",
        "Spruce Fence",
        "Oak Leaves",
        "Bricks",
        "Orange Wood Planks",
        "Bookshelf",
        "Stone",
        "White Wool",
        "Lime Wool",
        "Oak Fence Gate",
        "Rainbow Oak Log",
        "Iron Ore",
        "Orange Wood Log",
        "Diamond Ore",
        "Light Stone Bricks",
        "Rainbow TNT",
        "Rainbow Sponge",
        "Blue Glass",
        "Spruce Log",
        "Oak Door",
        "Cyan Wool",
        "Rainbow Wool",
        "Clay",
        "Iron Block",
        "Birch Door",
        "Orange Glass",
        "Gray Glass",
        "Grass",
        "Spruce Planks",
        "Sand",
        "Magenta Wool",
        "Stone Bricks",
        "Coal Ore",
        "Cyan Glass",
        "Oak Planks",
        "Lamp",
        "Rainbow Diamond",
        "Pink Wool",
        "Black Glass",
        "Deepslate",
        "Magma",
        "Dark Stone Bricks",
        "Gold Ore",
        "Spruce Fence Gate",
        "Magenta Glass",
        "Oak Fence",
        "Birch Fence",
        "Birch Fence Gate",
        "Sponge",
        "Green Glass",
        "Black Wool",
        "Dirt",
        "Gold Block",
        "Mud",
        "Stripped Birch Log",
        "Stripped Spruce Log",
        "Blue Wool",
    }

    local defaultBlock = C.Config.BuildBlockName
    if type(defaultBlock) ~= "string" or defaultBlock == "" then
        defaultBlock = "Oak Planks"
    end
    C.Config.BuildBlockName = defaultBlock

    local function hrp()
        local ch = lp.Character or lp.CharacterAdded:Wait()
        return ch and ch:FindFirstChild("HumanoidRootPart")
    end

    local function getBlockName()
        local name = C.Config.BuildBlockName
        if type(name) ~= "string" or name == "" then
            return defaultBlock
        end
        return name
    end

    local function buildHouseAroundPlayer()
        if not Place or not baseplate then return end

        local ch   = lp.Character or lp.CharacterAdded:Wait()
        local root = ch and ch:FindFirstChild("HumanoidRootPart")
        if not root then return end

        local origin = root.Position

        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { ch }

        local ray = WS:Raycast(origin + Vector3.new(0, 20, 0), Vector3.new(0, -200, 0), params)
        local basePos = ray and ray.Position or origin
        basePos = Vector3.new(basePos.X, basePos.Y, basePos.Z)

        local step = 4
        local half = 2

        local function placeRel(dx, dy, dz)
            local cf = CFrame.new(
                basePos.X + dx,
                basePos.Y + dy,
                basePos.Z + dz
            )
            local blockName = getBlockName()
            if Place and blockName and baseplate then
                pcall(function()
                    Place:InvokeServer(blockName, cf, baseplate)
                end)
            end
        end

        for x = -half, half do
            for z = -half, half do
                placeRel(x * step, 0, z * step)
            end
        end

        local wallLevels = { step, step * 2, step * 3 }

        for _, y in ipairs(wallLevels) do
            for x = -half, half do
                placeRel(x * step, y, -half * step)
                placeRel(x * step, y,  half * step)
            end
            for z = -half + 1, half - 1 do
                placeRel(-half * step, y, z * step)
                placeRel( half * step, y, z * step)
            end
        end

        local roofY = step * 4
        for x = -half, half do
            for z = -half, half do
                placeRel(x * step, roofY, z * step)
            end
        end
    end

    tab:Section({ Title = "Builder" })

    tab:Dropdown({
        Title   = "Block Type",
        Values  = BLOCK_ITEMS,
        Multi   = false,
        Default = defaultBlock,
        Callback = function(value)
            if type(value) == "string" and value ~= "" then
                C.Config.BuildBlockName = value
            end
        end
    })

    tab:Button({
        Title = "Build Small House Around Player",
        Callback = function()
            buildHouseAroundPlayer()
        end
    })
end
