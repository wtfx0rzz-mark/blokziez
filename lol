local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local WS         = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local lp   = Players.LocalPlayer
local char = lp.Character or lp.CharacterAdded:Wait()
local hrp  = char:WaitForChild("HumanoidRootPart")

local EventsFolder = RS:WaitForChild("Events")
local Place        = EventsFolder:WaitForChild("Place")

local baseplate = WS:FindFirstChild("Baseplate")

local BLOCK_NAME                = "Black Wool"
local BLOCK_STEP                = 4
local HORIZONTAL_BLOCKS         = 15
local VERTICAL_BLOCKS           = 8
local EXTENDED_HORIZONTAL_BLOCKS = 40
local EXTENDED_VERTICAL_BLOCKS   = 40
local EXTEND_PROB               = 0.05

local HORIZONTAL_TICK   = 0.2
local VERTICAL_TICK     = 0.2
local MAX_HEIGHT_ABOVE  = 100
local NUM_GROW_POINTS   = 8

local JITTER_VERTICAL_PROB = 0.7
local VERT_JITTER_BLOCKS   = 1

local rng = Random.new()

local function snapToGrid(v)
    local function snap(n)
        return math.floor(n / BLOCK_STEP + 0.5) * BLOCK_STEP
    end
    return Vector3.new(snap(v.X), snap(v.Y), snap(v.Z))
end

local function hashPos(v)
    return string.format("%d,%d,%d",
        math.floor(v.X + 0.5),
        math.floor(v.Y + 0.5),
        math.floor(v.Z + 0.5)
    )
end

local function placeBlock(pos)
    if not Place or not baseplate then return end
    local cf = CFrame.new(pos)
    pcall(function()
        Place:InvokeServer(BLOCK_NAME, cf, baseplate)
    end)
end

local originPos = snapToGrid(hrp.Position)
local originY   = originPos.Y
local maxY      = originY + MAX_HEIGHT_ABOVE

placeBlock(originPos)

local occupied = {}
occupied[hashPos(originPos)] = true

local activePoints = {}
table.insert(activePoints, originPos)

local running    = true
local upWeight   = 1
local downWeight = 1

local function clampWeight(w)
    if w < 0.05 then
        w = 0.05
    end
    if w > 10 then
        w = 10
    end
    return w
end

local function markAndPlace(pos)
    if pos.Y < originY or pos.Y > maxY then
        return false
    end
    local key = hashPos(pos)
    if occupied[key] then
        return false
    end
    occupied[key] = true
    placeBlock(pos)
    return true
end

local function chooseGrowthPoints()
    local count = math.min(NUM_GROW_POINTS, #activePoints)
    if count == 0 then
        return {}
    end
    local chosen      = {}
    local usedIndices = {}
    for i = 1, count do
        local idx
        repeat
            idx = rng:NextInteger(1, #activePoints)
        until not usedIndices[idx]
        usedIndices[idx] = true
        chosen[i] = activePoints[idx]
    end
    return chosen
end

local function growHorizontalFrom(p)
    local axis = rng:NextInteger(1, 2)
    local sign = rng:NextInteger(0, 1) == 0 and -1 or 1

    local baseStep
    if axis == 1 then
        baseStep = Vector3.new(sign * BLOCK_STEP, 0, 0)
    else
        baseStep = Vector3.new(0, 0, sign * BLOCK_STEP)
    end

    local steps
    if rng:NextNumber() < EXTEND_PROB then
        steps = EXTENDED_HORIZONTAL_BLOCKS
    else
        steps = HORIZONTAL_BLOCKS
    end

    local lastPos   = p
    local lastValid = nil

    for _ = 1, steps do
        local stepVec = baseStep

        if rng:NextNumber() < JITTER_VERTICAL_PROB then
            local signY = rng:NextInteger(0, 1) == 0 and -1 or 1
            stepVec += Vector3.new(0, signY * BLOCK_STEP, 0)
        end

        local candidate = lastPos + stepVec
        if candidate.Y < originY or candidate.Y > maxY then
            break
        end

        if markAndPlace(candidate) then
            lastValid = candidate
        end

        lastPos = candidate
    end

    if lastValid then
        table.insert(activePoints, lastValid)
    end
end

local function chooseVerticalDir(y)
    local canUp   = (y + BLOCK_STEP * VERTICAL_BLOCKS) <= maxY
    local canDown = (y - BLOCK_STEP * VERTICAL_BLOCKS) >= originY

    local uw = upWeight
    local dw = downWeight

    if not canUp then uw = 0 end
    if not canDown then dw = 0 end

    if uw == 0 and dw == 0 then
        return nil
    elseif uw == 0 then
        return "down"
    elseif dw == 0 then
        return "up"
    else
        local total = uw + dw
        local r = rng:NextNumber()
        if r < uw / total then
            return "up"
        else
            return "down"
        end
    end
end

local function growVerticalFrom(p)
    local dir = chooseVerticalDir(p.Y)
    if not dir then
        return
    end

    local signY    = dir == "up" and 1 or -1
    local baseStep = Vector3.new(0, signY * BLOCK_STEP, 0)

    local steps
    if rng:NextNumber() < EXTEND_PROB then
        steps = EXTENDED_VERTICAL_BLOCKS
    else
        steps = VERTICAL_BLOCKS
    end

    local lastPos   = p
    local lastValid = nil

    for _ = 1, steps do
        local stepVec = baseStep

        if rng:NextNumber() < JITTER_VERTICAL_PROB then
            local jitterDir = rng:NextInteger(1, 4)
            local sideStep
            if jitterDir == 1 then
                sideStep = Vector3.new(VERT_JITTER_BLOCKS * BLOCK_STEP, 0, 0)
            elseif jitterDir == 2 then
                sideStep = Vector3.new(-VERT_JITTER_BLOCKS * BLOCK_STEP, 0, 0)
            elseif jitterDir == 3 then
                sideStep = Vector3.new(0, 0, VERT_JITTER_BLOCKS * BLOCK_STEP)
            else
                sideStep = Vector3.new(0, 0, -VERT_JITTER_BLOCKS * BLOCK_STEP)
            end
            stepVec += sideStep
        end

        local candidate = lastPos + stepVec
        if candidate.Y < originY or candidate.Y > maxY then
            break
        end

        if markAndPlace(candidate) then
            lastValid = candidate
        end

        lastPos = candidate
    end

    if lastValid then
        table.insert(activePoints, lastValid)
        if dir == "up" then
            upWeight = clampWeight(upWeight * 0.9)
        else
            downWeight = clampWeight(downWeight * 0.9)
        end
    end
end

task.spawn(function()
    while running do
        local points = chooseGrowthPoints()
        if #points > 0 then
            for _, p in ipairs(points) do
                growHorizontalFrom(p)
            end
        end
        task.wait(HORIZONTAL_TICK)
    end
end)

task.spawn(function()
    while running do
        local points = chooseGrowthPoints()
        if #points > 0 then
            for _, p in ipairs(points) do
                growVerticalFrom(p)
            end
        end
        task.wait(VERTICAL_TICK)
    end
end)
