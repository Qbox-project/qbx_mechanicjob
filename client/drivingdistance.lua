local config = require 'config.client'
local vehicleMeters = -1
local previousVehiclePos = nil
local checkDone = false
DrivingDistance = {}

-- Functions

---@param num number
---@return integer
local function round(num)
    return math.floor(num + 0.5)
end

---@param meters number
---@return Range?
local function getDamageMultiplier(meters)
    local check = round(meters / 1000)
    for i = 1, #config.minimalMetersForDamage do
        local v = config.minimalMetersForDamage[i]
        if check >= v.min and check <= v.max then
            return v.multiplier
        end
    end

    local data = config.minimalMetersForDamage[#config.minimalMetersForDamage]
    if check >= data.min then
        return data.multiplier
    end
end

---@param multiplierRange Range
---@param plate string
local function damageParts(multiplierRange, plate)
    local currentData = VehicleStatus[plate]
    for i = 1, #config.damageableParts do
        local partName = config.damageableParts[i]
        local randmultiplier = math.random(multiplierRange.min, multiplierRange.max) / 100
        local newDamage = 0
        if currentData[partName] - randmultiplier >= 0 then
            newDamage = currentData[partName] - randmultiplier
        end
        TriggerServerEvent('qb-vehicletuning:server:SetPartLevel', plate, partName, newDamage)
    end
end

---@param pos vector3
---@param plate string
local function trackDistanceFromPreviousPosition(pos, plate)
    local distance = #(pos - previousVehiclePos)
    local multiplierRange = getDamageMultiplier(vehicleMeters)

    vehicleMeters += (distance / 100) * 325
    DrivingDistance[plate] = vehicleMeters

    if multiplierRange and math.random(3) == 3 then
        damageParts(multiplierRange, plate)
    end

    local amount = round(DrivingDistance[plate] / 1000)

    TriggerEvent('hud:client:UpdateDrivingMeters', true, amount)
    TriggerServerEvent('qb-vehicletuning:server:UpdateDrivingDistance', DrivingDistance[plate], plate)
end

---Called in thread loop
local function trackDistance()
    local ped = cache.ped
    local veh = cache.vehicle

    if not veh then
        vehicleMeters = -1
        checkDone = false
        previousVehiclePos = nil
        Wait(500)
        return
    end

    local isDriver = cache.seat == -1
    local pos = GetEntityCoords(ped)
    local plate = qbx.getVehiclePlate(veh)

    if not plate then
        Wait(2000)
        return
    end

    if isDriver then
        if not checkDone then
            if vehicleMeters == -1 then
                checkDone = true
                lib.callback('qb-vehicletuning:server:IsVehicleOwned', false, function(IsOwned)
                    if not DrivingDistance[plate] then
                        DrivingDistance[plate] = IsOwned and 0 or math.random(111111, 999999)
                    end
                    vehicleMeters = DrivingDistance[plate]
                end, plate)
            end
        end
        --- TODO: figure out why this function is called twice
        if previousVehiclePos then
            trackDistanceFromPreviousPosition(pos, plate)
            trackDistanceFromPreviousPosition(pos, plate)
        end
    elseif vehicleMeters == -1 and DrivingDistance[plate] then
        vehicleMeters = DrivingDistance[plate]
    end

    if vehicleMeters ~= -1 and not isDriver and DrivingDistance[plate] then
        local amount = round(DrivingDistance[plate] / 1000)
        TriggerEvent('hud:client:UpdateDrivingMeters', true, amount)
    end

    previousVehiclePos = pos
    Wait(2000)
end

-- Events

---@param amount number
---@param plate string
RegisterNetEvent('qb-vehicletuning:client:UpdateDrivingDistance', function(amount, plate)
    DrivingDistance[plate] = amount
end)

-- Threads

CreateThread(function()
    Wait(500)
    while true do
        trackDistance()
    end
end)