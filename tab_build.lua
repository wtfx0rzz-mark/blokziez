-- tab_build.lua
-- Blokziez • Build tab: material dropdown + house builder (walls only, grid-aligned)

return function(C, R, UI)
    C  = C  or _G.C
    R  = R  or _G.R
    UI = UI or _G.UI

    assert(UI and UI.Tabs and UI.Tabs.Build, "tab_build.lua: Build tab missing")

    local tab      = UI.Tabs.Build
    local Services = C.Services or {}
    local Players  = Services.Players or game:GetService("Players")
    local RS       = Services.RS      or game:GetService("ReplicatedStorage")
    local WS       = Services.WS      or game:GetService("Workspace")

    local lp = C.LocalPlayer or Players.LocalPlayer

    C.State  = C.State  or {}
    C.Config = C.Config or {}

    local EventsFolder = RS:WaitForChild("Events")
    local Place        = EventsFolder:FindFirstChild("Place")
    local baseplate    = WS:FindFirstChild("Baseplate")

    ----------------------------------------------------------------------
    -- Helpers
    ----------------------------------------------------------------------
    local function getHRP()
        local char = lp.Character or lp.CharacterAdded:Wait()
        return char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart")
    end

    local function extractNumber(v, min, max, default)
        local nv = v
        if type(v) == "table" then
            nv = v.Value or v.Current or v.CurrentValue or v.Default or v.min or v.max
        end
        nv = tonumber(nv) or default
        if min and max and nv then
            nv = math.clamp(nv, min, max)
        end
        return nv
    end

    local function safePlace(blockName, cf)
        if not (Place and baseplate and blockName) then return end
        pcall(function()
            Place:InvokeServer(blockName, cf, baseplate)
        end)
    end

    ----------------------------------------------------------------------
    -- Block dropdown
    ----------------------------------------------------------------------
    local BLOCK_TYPES = {
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
        "Destroy Blocks",
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
        "Cobblestone",
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

    C.Config.BuildBlockName = C.Config.BuildBlockName or "Oak Planks"

    tab:Section({ Title = "Block Type", Icon = "box" })

    tab:Dropdown({
        Title   = "Material",
        Values  = BLOCK_TYPES,
        Multi   = false,
        Default = C.Config.BuildBlockName,
        Callback = function(choice)
            local value = choice
            if type(choice) == "table" then
                value = choice[1] or choice.Value or choice.Current
            end
            if typeof(value) == "string" then
                C.Config.BuildBlockName = value
            end
        end
    })

    ----------------------------------------------------------------------
    -- Ground + house geometry (walls only, no floor)
    ----------------------------------------------------------------------
    local BLOCK_SIZE = 2
    local STEP       = BLOCK_SIZE

    -- Raycast straight down from a position to get the ground height
    local function getGroundY(originPos)
        local origin = originPos + Vector3.new(0, 5, 0)
        local dir    = Vector3.new(0, -1, 0) * 100

        local params = RaycastParams.new()
        params.FilterType                 = Enum.RaycastFilterType.Exclude
        params.IgnoreWater                = true
        params.FilterDescendantsInstances = { lp.Character }

        local result = WS:Raycast(origin, dir, params)
        if result and result.Position then
            return result.Position.Y
        end
        -- Fallback: assume ground a bit below the player
        return originPos.Y - (BLOCK_SIZE * 2)
    end

    -- Build a hollow rectangular house: walls + flat roof
    local function buildBoxHouse(widthBlocks, depthBlocks, wallHeightBlocks)
        if not Place or not baseplate then return end

        local blockName = C.Config.BuildBlockName or "Oak Planks"
        local hrp       = getHRP()
        if not hrp then return end

        -- Horizontal facing directions
        local forward = hrp.CFrame.LookVector
        if forward.Magnitude < 1e-4 then
            forward = Vector3.new(0, 0, -1)
        end
        forward = Vector3.new(forward.X, 0, forward.Z).Unit

        local right = Vector3.new(-forward.Z, 0, forward.X)
        if right.Magnitude < 1e-4 then
            right = Vector3.new(1, 0, 0)
        end
        right = right.Unit

        -- Find ground directly under the player
        local groundY = getGroundY(hrp.Position)

        -- Center of the bottom wall row (block center): sit directly on ground
        local baseBlockY = groundY + (BLOCK_SIZE / 2)

        -- Put the house a bit in front of the player, not on top of them
        local center = Vector3.new(hrp.Position.X, baseBlockY, hrp.Position.Z)
        center = center + forward * (STEP * 2)

        -- Force odd sizes so we have a true center
        if widthBlocks % 2 == 0 then widthBlocks  = widthBlocks  + 1 end
        if depthBlocks % 2 == 0 then depthBlocks  = depthBlocks  + 1 end

        local halfW = (widthBlocks  - 1) / 2
        local halfD = (depthBlocks  - 1) / 2

        -- Walls: bottom row sits at baseBlockY; no floor layer
        for iy = 0, wallHeightBlocks - 1 do
            local yOffset = iy * BLOCK_SIZE

            for ix = -halfW, halfW do
                for iz = -halfD, halfD do
                    local isEdge =
                        (ix == -halfW or ix == halfW or iz == -halfD or iz == halfD)

                    if isEdge then
                        local offset = (right * (ix * STEP)) + (forward * (iz * STEP))
                        local pos    = center + offset + Vector3.new(0, yOffset, 0)
                        local cf     = CFrame.new(pos)
                        safePlace(blockName, cf)
                    end
                end
            end
        end

        -- Flat roof one block above the top wall row
        local roofY = baseBlockY + (wallHeightBlocks * BLOCK_SIZE)
        for ix = -halfW, halfW do
            for iz = -halfD, halfD do
                local offset = (right * (ix * STEP)) + (forward * (iz * STEP))
                local pos    = Vector3.new(center.X + offset.X, roofY, center.Z + offset.Z)
                local cf     = CFrame.new(pos)
                safePlace(blockName, cf)
            end
        end
    end

    ----------------------------------------------------------------------
    -- UI: House Builder
    ----------------------------------------------------------------------
    tab:Section({ Title = "House Builder", Icon = "home" })

    tab:Button({
        Title = "Build Small House",
        Callback = function()
            -- small: tighter footprint, low roof
            buildBoxHouse(7, 7, 4)
        end
    })

    tab:Button({
        Title = "Build Medium House",
        Callback = function()
            buildBoxHouse(11, 9, 5)
        end
    })

    tab:Button({
        Title = "Build Large House",
        Callback = function()
            buildBoxHouse(15, 11, 6)
        end
    })

