-- tab_build.lua
-- Blokziez • Build tab: block picker + small/medium/large house builder
-- Grid-aligned (no raycast)

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

    ----------------------------------------------------------------------
    -- Block list from your backpack scan
    ----------------------------------------------------------------------
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

    ----------------------------------------------------------------------
    -- Helpers
    ----------------------------------------------------------------------
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

    ----------------------------------------------------------------------
    -- Grid snapping
    ----------------------------------------------------------------------
    local GRID_SIZE = 4      -- size of one block cell in studs
    local STEP_SIZE = GRID_SIZE

    local function snapAxis(x)
        -- snap to nearest multiple of GRID_SIZE
        return math.floor(x / GRID_SIZE + 0.5) * GRID_SIZE
    end

    local function snapToGrid(v)
        return Vector3.new(
            snapAxis(v.X),
            snapAxis(v.Y),
            snapAxis(v.Z)
        )
    end

    ----------------------------------------------------------------------
    -- Materials
    ----------------------------------------------------------------------
    local FLOOR_BLOCK = "Oak Planks"
    local WALL_BLOCK  = "Bricks"
    local ROOF_BLOCK  = "Stone"

    ----------------------------------------------------------------------
    -- Logical house sizes (in blocks), then scaled
    ----------------------------------------------------------------------
    local SCALE = 3   -- linear scale factor for all sizes

    local HOUSE_SIZES = {
        Small  = { half = 2, wallLevels = 3 }, -- base: 5x5 footprint
        Medium = { half = 3, wallLevels = 4 }, -- base: 7x7 footprint
        Large  = { half = 4, wallLevels = 5 }, -- base: 9x9 footprint
    }

    ----------------------------------------------------------------------
    -- House builder (uses snapped HRP position as base, no raycast)
    ----------------------------------------------------------------------
    local function buildHouseAroundPlayer(sizeKey)
        if not Place or not baseplate then return end

        local baseCfg = HOUSE_SIZES[sizeKey or "Small"] or HOUSE_SIZES.Small
        local half       = baseCfg.half * SCALE
        local wallLevels = baseCfg.wallLevels * SCALE

        local root = hrp()
        if not root then return end

        -- Snap player position to grid so all blocks align to the world grid
        local origin  = snapToGrid(root.Position)
        local basePos = origin

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

        ------------------------------------------------------------------
        -- Floor (filled)
        ------------------------------------------------------------------
        for x = -half, half do
            for z = -half, half do
                placeFloor(x * STEP_SIZE, 0, z * STEP_SIZE)
            end
        end

        ------------------------------------------------------------------
        -- Walls (hollow interior)
        ------------------------------------------------------------------
        for level = 1, wallLevels do
            local y = level * STEP_SIZE

            -- Front/back walls
            for x = -half, half do
                placeWall(x * STEP_SIZE, y, -half * STEP_SIZE)
                placeWall(x * STEP_SIZE, y,  half * STEP_SIZE)
            end

            -- Left/right walls (no double corners)
            for z = -half + 1, half - 1 do
                placeWall(-half * STEP_SIZE, y, z * STEP_SIZE)
                placeWall( half * STEP_SIZE, y, z * STEP_SIZE)
            end
        end

        ------------------------------------------------------------------
        -- Triangular/pyramidal roof with 1-block eaves, snapped to grid
        ------------------------------------------------------------------
        local roofBaseY  = (wallLevels + 1) * STEP_SIZE
        local maxRadius  = half + 1         -- one extra for eaves
        local roofLevels = maxRadius + 1    -- step up to a point

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

    ----------------------------------------------------------------------
    -- UI
    ----------------------------------------------------------------------
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
        Title = "Build SMALL House (grid aligned)",
        Callback = function()
            buildHouseAroundPlayer("Small")
        end
    })

    tab:Button({
        Title = "Build MEDIUM House (grid aligned)",
        Callback = function()
            buildHouseAroundPlayer("Medium")
        end
    })

    tab:Button({
        Title = "Build LARGE House (grid aligned)",
        Callback = function()
            buildHouseAroundPlayer("Large")
        end
    })
end
