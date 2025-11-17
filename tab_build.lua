-- tab_build.lua
-- Blokziez • Build tab: block selection + basic house

return function(C, R, UI)
    C  = C  or _G.C
    R  = R  or _G.R
    UI = UI or _G.UI

    assert(UI and UI.Tabs and UI.Tabs.Build, "tab_build.lua: Build tab missing")

    local tab = UI.Tabs.Build

    C.State  = C.State  or {}
    C.Config = C.Config or {}

    ----------------------------------------------------------------------
    -- Services / player
    ----------------------------------------------------------------------
    local Services = C.Services or {}
    local Players  = Services.Players  or game:GetService("Players")
    local WS       = Services.WS       or game:GetService("Workspace")
    local RS       = Services.RS       or game:GetService("ReplicatedStorage")

    local lp = C.LocalPlayer or Players.LocalPlayer

    local EventsFolder = RS:FindFirstChild("Events")
    local Place        = EventsFolder and EventsFolder:FindFirstChild("Place")
    local baseplate    = WS:FindFirstChild("Baseplate")

    local function hrp()
        local ch = lp and (lp.Character or lp.CharacterAdded:Wait())
        return ch and ch:FindFirstChild("HumanoidRootPart")
    end

    ----------------------------------------------------------------------
    -- Block list
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

    ----------------------------------------------------------------------
    -- State / helpers
    ----------------------------------------------------------------------

    C.Config.BuildBlockName = C.Config.BuildBlockName or BLOCK_ITEMS[1]

    local function findIndex(list, value)
        for i, v in ipairs(list) do
            if v == value then
                return i
            end
        end
        return nil
    end

    local function setSelectedBlock(v)
        if typeof(v) == "string" then
            C.Config.BuildBlockName = v
        else
            local idx = tonumber(v)
            if idx and BLOCK_ITEMS[idx] then
                C.Config.BuildBlockName = BLOCK_ITEMS[idx]
            end
        end
    end

    local function getSelectedBlockName()
        return C.Config.BuildBlockName or BLOCK_ITEMS[1]
    end

    -- Optional helper: other modules can ask what block is selected
    R = R or {}
    R.Build = R.Build or {}
    R.Build.GetSelectedBlockName = function()
        return getSelectedBlockName()
    end

    ----------------------------------------------------------------------
    -- House builder
    ----------------------------------------------------------------------

    local function buildSmallHouseAroundPlayer()
        if not (lp and Place) then
            return
        end

        local root = hrp()
        if not root then
            return
        end

        local blockName = getSelectedBlockName()
        if not blockName then
            return
        end

        local origin = root.Position

        -- Try to find ground under the player so the floor sits nicely
        local baseY
        do
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = { lp.Character }

            local result = WS:Raycast(origin, Vector3.new(0, -50, 0), params)
            if result then
                -- Assume block center is a bit above the hit point
                baseY = result.Position.Y + 2
            else
                baseY = origin.Y - 4
            end
        end

        -- House dimensions in blocks
        local BLOCK_STEP     = 4      -- world studs per block step (matches your column code)
        local halfSizeBlocks = 2      -- 2 blocks from center => 5x5 footprint
        local heightBlocks   = 3      -- wall height (plus floor/roof)

        -- Choose which side to put the door on, based on camera facing
        local look = root.CFrame.LookVector
        local lx, lz = look.X, look.Z
        local doorSide
        if math.abs(lx) > math.abs(lz) then
            doorSide = (lx >= 0) and "posX" or "negX"
        else
            doorSide = (lz >= 0) and "posZ" or "negZ"
        end

        local function shouldSkipForDoor(bx, bz, by)
            -- Only skip on the second layer (by == 1) to create door opening
            if by ~= 1 then return false end
            if doorSide == "posX" and bx == halfSizeBlocks and bz == 0 then return true end
            if doorSide == "negX" and bx == -halfSizeBlocks and bz == 0 then return true end
            if doorSide == "posZ" and bz == halfSizeBlocks and bx == 0 then return true end
            if doorSide == "negZ" and bz == -halfSizeBlocks and bx == 0 then return true end
            return false
        end

        task.spawn(function()
            for by = 0, heightBlocks - 1 do
                local y = baseY + by * BLOCK_STEP
                for bx = -halfSizeBlocks, halfSizeBlocks do
                    for bz = -halfSizeBlocks, halfSizeBlocks do
                        local onOuter = (math.abs(bx) == halfSizeBlocks or math.abs(bz) == halfSizeBlocks)
                        local isFloorOrRoof = (by == 0 or by == heightBlocks - 1)

                        -- Floor & roof are filled; walls are only outer ring
                        if isFloorOrRoof or onOuter then
                            if not shouldSkipForDoor(bx, bz, by) then
                                local pos = Vector3.new(
                                    origin.X + bx * BLOCK_STEP,
                                    y,
                                    origin.Z + bz * BLOCK_STEP
                                )
                                local cf = CFrame.new(pos)
                                pcall(function()
                                    Place:InvokeServer(blockName, cf, baseplate)
                                end)
                                task.wait(0.01)
                            end
                        end
                    end
                end
            end
        end)
    end

    ----------------------------------------------------------------------
    -- UI
    ----------------------------------------------------------------------

    tab:Section({ Title = "Build Settings", Icon = "box" })

    tab:Dropdown({
        Title   = "Block Type",
        Values  = BLOCK_ITEMS,
        Default = findIndex(BLOCK_ITEMS, C.Config.BuildBlockName) or 1,
        Callback = function(value)
            setSelectedBlock(value)
        end,
    })

    tab:Button({
        Title       = "Build Small House Around Me",
        Description = "Uses the selected block type to build a small box house around your character.",
        Callback    = function()
            buildSmallHouseAroundPlayer()
        end,
    })
end
