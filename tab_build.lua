-- tab_build.lua
-- Blokziez • Build tab: material picker + basic houses

return function(C, R, UI)
    C  = C  or _G.C
    R  = R  or _G.R
    UI = UI or _G.UI

    assert(UI and UI.Tabs and UI.Tabs.Build, "tab_build.lua: Build tab missing")

    local tab = UI.Tabs.Build

    local Services = C.Services or {}
    local Players  = Services.Players  or game:GetService("Players")
    local RS       = Services.RS       or game:GetService("ReplicatedStorage")
    local WS       = Services.WS       or game:GetService("Workspace")
    local Run      = Services.Run      or game:GetService("RunService")

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

    local function placeBlock(blockName, cf)
        if not (Place and blockName and cf) then return end
        pcall(function()
            Place:InvokeServer(blockName, cf, baseplate)
        end)
    end

    -- Raycast straight down from a point to find the ground
    local function findGroundBelow(origin)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { lp.Character }

        local result = WS:Raycast(origin, Vector3.new(0, -200, 0), params)
        if result then
            return result.Position
        end
        return nil
    end

    ----------------------------------------------------------------------
    -- Block material list (from your backpack log)
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

    local defaultBlock = C.Config.SelectedBuildMaterial or BLOCK_TYPES[1]

    tab:Section({ Title = "Build Material", Icon = "box" })

    tab:Dropdown({
        Title   = "Block Type",
        Values  = BLOCK_TYPES,
        Default = defaultBlock,
        Callback = function(selected)
            if selected then
                C.Config.SelectedBuildMaterial = selected
            end
        end
    })

    ----------------------------------------------------------------------
    -- House builder
    ----------------------------------------------------------------------
    -- We assume world is on a 4x4x4 grid
    local GRID_STEP   = 4
    local BLOCK_STEP_Y = 4

    local function snapToGrid(v)
        return Vector3.new(
            math.floor(v.X / GRID_STEP + 0.5) * GRID_STEP,
            v.Y,
            math.floor(v.Z / GRID_STEP + 0.5) * GRID_STEP
        )
    end

    local function buildHouse(sizePreset)
        if not Place then return end

        local blockName = C.Config.SelectedBuildMaterial or defaultBlock
        if not blockName then return end

        local hrp = getHRP()
        if not hrp then return end

        -- Find ground directly below the player and snap XZ to grid
        local originAbove = hrp.Position + Vector3.new(0, 10, 0)
        local groundPos   = findGroundBelow(originAbove) or (hrp.Position - Vector3.new(0, 4, 0))

        local centerXZ = snapToGrid(Vector3.new(groundPos.X, 0, groundPos.Z))

        -- Fix for floating: use the ground Y as our floor center Y minus a small nudge
        -- so the blocks visually sit on the ground instead of hovering.
        local floorY = groundPos.Y - 0.1  -- slight downward nudge so there is no visible gap

        local cfg
        if sizePreset == "Small" then
            cfg = { halfSize = 3, height = 3 }
        elseif sizePreset == "Medium" then
            cfg = { halfSize = 4, height = 4 }
        elseif sizePreset == "Large" then
            cfg = { halfSize = 5, height = 5 }
        else
            cfg = { halfSize = 3, height = 3 }
        end

        local halfSize = cfg.halfSize
        local height   = cfg.height

        local builtCount = 0

        for yLevel = 0, height do
            local y = floorY + (yLevel * BLOCK_STEP_Y)

            for ix = -halfSize, halfSize do
                for iz = -halfSize, halfSize do
                    local isEdge = (math.abs(ix) == halfSize) or (math.abs(iz) == halfSize)
                    local isFloor = (yLevel == 0)
                    local isRoof  = (yLevel == height)

                    -- Floor and roof are solid; walls only on edges in between
                    if isFloor or isRoof or isEdge then
                        local pos = Vector3.new(
                            centerXZ.X + ix * GRID_STEP,
                            y,
                            centerXZ.Z + iz * GRID_STEP
                        )
                        local cf = CFrame.new(pos)
                        placeBlock(blockName, cf)
                        builtCount += 1

                        if builtCount % 75 == 0 then
                            Run.Heartbeat:Wait()
                        end
                    end
                end
            end
        end
    end

    tab:Section({ Title = "House Builder", Icon = "home" })

    tab:Button({
        Title = "Build Small House",
        Callback = function()
            buildHouse("Small")
        end
    })

    tab:Button({
        Title = "Build Medium House",
        Callback = function()
            buildHouse("Medium")
        end
    })

    tab:Button({
        Title = "Build Large House",
        Callback = function()
            buildHouse("Large")
        end
    })
end
