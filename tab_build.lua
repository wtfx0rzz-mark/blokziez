-- tab_build.lua
-- Blokziez • Build tab: block picker + small house builder (no raycast)

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

    local function safePlace(blockName, cf)
        if not (Place and baseplate and blockName) then return end
        pcall(function()
            Place:InvokeServer(blockName, cf, baseplate)
        end)
    end

    local FLOOR_BLOCK = "Oak Planks"
    local WALL_BLOCK  = "Bricks"
    local ROOF_BLOCK  = "Stone"

    local STEP_SIZE = 4

    local HOUSE_SIZES = {
        Small  = { half = 2, wallLevels = 3 }, -- 5x5 footprint
        Medium = { half = 3, wallLevels = 4 }, -- 7x7 footprint
        Large  = { half = 4, wallLevels = 5 }, -- 9x9 footprint
    }

    local function buildHouseAroundPlayer(sizeKey)
        if not Place or not baseplate then return end

        local cfg = HOUSE_SIZES[sizeKey or "Small"] or HOUSE_SIZES.Small
        local half       = cfg.half
        local wallLevels = cfg.wallLevels

        local root = hrp()
        if not root then return end

        local origin  = root.Position
        local basePos = Vector3.new(origin.X, origin.Y, origin.Z)

        local function placeFloor(dx, dy, dz)
            local cf = CFrame.new(
                basePos.X + dx,
                basePos.Y + dy,
                basePos.Z + dz
            )
            safePlace(FLOOR_BLOCK, cf)
        end

        local function placeWall(dx, dy, dz)
            local cf = CFrame.new(
                basePos.X + dx,
                basePos.Y + dy,
                basePos.Z + dz
            )
            safePlace(WALL_BLOCK, cf)
        end

        local function placeRoof(dx, dy, dz)
            local cf = CFrame.new(
                basePos.X + dx,
                basePos.Y + dy,
                basePos.Z + dz
            )
            safePlace(ROOF_BLOCK, cf)
        end

        for x = -half, half do
            for z = -half, half do
                placeFloor(x * STEP_SIZE, 0, z * STEP_SIZE)
            end
        end

        for level = 1, wallLevels do
            local y = level * STEP_SIZE

            for x = -half, half do
                placeWall(x * STEP_SIZE, y, -half * STEP_SIZE)
                placeWall(x * STEP_SIZE, y,  half * STEP_SIZE)
            end

            for z = -half + 1, half - 1 do
                placeWall(-half * STEP_SIZE, y, z * STEP_SIZE)
                placeWall( half * STEP_SIZE, y, z * STEP_SIZE)
            end
        end

        local roofBaseY   = (wallLevels + 1) * STEP_SIZE
        local maxRadius   = half + 1
        local roofLevels  = maxRadius + 1

        for level = 0, roofLevels do
            local radius = maxRadius - level
            if radius < 0 then break end

            local y = roofBaseY + level * STEP_SIZE

            for x = -radius, radius do
                for z = -radius, radius do
                    placeRoof(x * STEP_SIZE, y, z * STEP_SIZE)
                end
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
            buildHouseAroundPlayer("Small")
        end
    })

    tab:Button({
        Title = "Build Medium House Around Player",
        Callback = function()
            buildHouseAroundPlayer("Medium")
        end
    })

    tab:Button({
        Title = "Build Large House Around Player",
        Callback = function()
            buildHouseAroundPlayer("Large")
        end
    })
end
