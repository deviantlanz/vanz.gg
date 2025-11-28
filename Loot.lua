local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local MAX_CHEST_DISTANCE = 10000
local CHEST_COOLDOWN = 0.050
local NO_CHEST_RESET_DELAY = 0.1
local LOOT_SCAN_INTERVAL = 0.1

local LOOT_ITEMS = {
    ["Nut"] = true, ["Poker Card"] = true, ["Mouse"] = true, ["Scissors"] = true,
    ["Rusty Iron Ingot"] = true, ["Adv Resource Crate"] = true, ["Ancient Copper Coin"] = true,
    ["Camera"] = true, ["Radiator"] = true, ["Utility Knife"] = true, ["Circuit Board"] = true,
    ["Exotic Dagger"] = true, ["Hard Disk Drive"] = true, ["Solar Panel"] = true,
    ["Ruler"] = true, ["Wrench"] = true, ["Battery"] = true, ["Mechanical Part"] = true,
    ["Thermometer"] = true, ["Syringe"] = true, ["Precision Caliper"] = true,
    ["Ancient Silver Coin"] = true, ["Epic Resource Crate"] = true, ["Ancient Gold Coin"] = true,
    ["Radio"] = true, ["RAM"] = true, ["Music Box"] = true, ["Coffee"] = true,
    ["USB Flash Drive"] = true, ["Cola"] = true, ["Pressure Gauge"] = true,
    ["Angle Grinder"] = true, ["Power Supply"] = true, ["Legendary Resource Crate"] = true,
    ["Legendary Item Crate"] = true, ["Drone Crate"] = true, ["Module Crate"] = true,
    ["CPU"] = true, ["Merit Medal"] = true, ["DSLR Camera"] = true, ["Golden Crown"] = true,
    ["Golden Chalice"] = true, ["Zombie Crystal"] = true, ["24K Gold Bar"] = true,
    ["Missile Model"] = true, ["Laptop"] = true, ["Drone"] = true, ["RTX GPU"] = true,
    ["Satellite Phone"] = true
}

local lastChestTeleport = 0
local noChestTimer = 0
local isTeleportingToChest = false
local lastLootScan = 0
local automationRunning = false
local autoLootConnection, chestFarmConnection

local function replayGame()
    local args = {3463932402}
    local remoteFolder = ReplicatedStorage:FindFirstChild("Remote")
    if remoteFolder then
        local remoteEvent = remoteFolder:FindFirstChild("RemoteEvent")
        if remoteEvent then
            remoteEvent:FireServer(unpack(args))
            return true
        end
    end
    return false
end

local function isChestObject(obj)
    if not obj or not obj.Name then return false end
    local name = string.lower(obj.Name)
    return string.find(name, "chest") ~= nil
end

local function findAllChests()
    local chests = {}
    local char = LocalPlayer.Character
    if not char then return chests end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return chests end

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if isChestObject(obj) then
            if obj:IsA("Model") then
                local part = obj:FindFirstChildWhichIsA("BasePart")
                if part then
                    local distance = (part.Position - root.Position).Magnitude
                    if distance <= MAX_CHEST_DISTANCE then
                        table.insert(chests, {model = obj, part = part, distance = distance})
                    end
                end
            elseif obj:IsA("BasePart") and isChestObject(obj) then
                local distance = (obj.Position - root.Position).Magnitude
                if distance <= MAX_CHEST_DISTANCE then
                    table.insert(chests, {model = obj, part = obj, distance = distance})
                end
            end
        end
    end

    table.sort(chests, function(a, b) return a.distance < b.distance end)
    return chests
end

local function lookAtChest(chestPart)
    local camera = workspace.CurrentCamera
    if not camera then return end
    local direction = (chestPart.Position - camera.CFrame.Position).Unit
    local lookCFrame = CFrame.new(camera.CFrame.Position, camera.CFrame.Position + direction)
    camera.CFrame = lookCFrame
end

local function activateProximityPrompts(chestPart)
    local character = LocalPlayer.Character
    if not character then return end
    lookAtChest(chestPart)
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end

    for _, prompt in ipairs(Workspace:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") then
            local distance = (prompt.Parent.Position - humanoidRootPart.Position).Magnitude
            if distance <= prompt.MaxActivationDistance then
                prompt:InputHoldBegin()
                wait(prompt.HoldDuration)
                prompt:InputHoldEnd()
            end
        end
    end
end

local function teleportToChest(chestData)
    if not chestData or not chestData.part then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    isTeleportingToChest = true
    local safeCFrame = chestData.part.CFrame + Vector3.new(0, 5, 0)
    pcall(function() hrp.CFrame = safeCFrame end)
    wait(0.5)
    activateProximityPrompts(chestData.part)
    isTeleportingToChest = false
    lastChestTeleport = tick()
end

local function teleportItemToPlayer(item)
    if not item then return false end
    local character = LocalPlayer.Character
    if not character then return false end
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return false end

    if item:IsDescendantOf(Workspace.FX) then
        if item:IsA("BasePart") then
            item.CFrame = humanoidRootPart.CFrame
            return true
        elseif item:IsA("Model") then
            local primaryPart = item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")
            if primaryPart then
                item:SetPrimaryPartCFrame(humanoidRootPart.CFrame)
                return true
            end
        end
    end
    return false
end

local function findLootItems()
    local lootItems = {}
    local currentTime = tick()
    if currentTime - lastLootScan < LOOT_SCAN_INTERVAL then return lootItems end
    lastLootScan = currentTime
    local fxFolder = Workspace:FindFirstChild("FX")
    if fxFolder then
        for _, item in ipairs(fxFolder:GetChildren()) do
            if LOOT_ITEMS[item.Name] then table.insert(lootItems, item) end
        end
    end
    return lootItems
end

local function startAutomation()
    if automationRunning then return end
    automationRunning = true

    autoLootConnection = RunService.Heartbeat:Connect(function()
        local lootItems = findLootItems()
        for _, item in ipairs(lootItems) do teleportItemToPlayer(item) end
    end)

    chestFarmConnection = RunService.Heartbeat:Connect(function()
        if isTeleportingToChest then return end
        local currentTime = tick()
        if currentTime - lastChestTeleport < CHEST_COOLDOWN then return end

        local allChests = findAllChests()
        local nearestChest = #allChests > 0 and allChests[1] or nil

        if nearestChest then
            noChestTimer = 0
            teleportToChest(nearestChest)
        else
            noChestTimer = noChestTimer + RunService.Heartbeat:Wait()
            if noChestTimer >= NO_CHEST_RESET_DELAY then
                if autoLootConnection then autoLootConnection:Disconnect() end
                if chestFarmConnection then chestFarmConnection:Disconnect() end
                automationRunning = false
                replayGame()
                wait(3)
                startAutomation()
            end
        end
    end)
end

if LocalPlayer.Character then
    startAutomation()
else
    LocalPlayer.CharacterAdded:Connect(function()
        wait(3)
        startAutomation()
    end)
end
