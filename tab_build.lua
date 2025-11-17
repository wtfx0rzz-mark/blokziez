-- tab_build.lua
-- Blokziez • Build tab: block selection

return function(C, R, UI)
    C  = C  or _G.C
    R  = R  or _G.R
    UI = UI or _G.UI

    assert(UI and UI.Tabs and UI.Tabs.Build, "tab_build.lua: Build tab missing")

    local tab = UI.Tabs.Build

    C.State  = C.State  or {}
    C.Config = C.Config or {}

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

    -- Remember last-selected block across reloads
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

    -- Optional helper: other modules can call this to know which block to use
    R = R or {}
    R.Build = R.Build or {}
    R.Build.GetSelectedBlockName = function()
        return C.Config.BuildBlockName
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
end
