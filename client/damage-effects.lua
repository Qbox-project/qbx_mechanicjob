local effectTimer = 0

local function applyRadiatorEffects(vehicle, plate)
    local engineHealth = GetVehicleEngineHealth(vehicle)
    if VehicleStatus[plate].radiator <= 80 and VehicleStatus[plate].radiator >= 60 then
        SetVehicleEngineHealth(vehicle, engineHealth - math.random(10, 15))
    elseif VehicleStatus[plate].radiator <= 59 and VehicleStatus[plate].radiator >= 40 then
        SetVehicleEngineHealth(vehicle, engineHealth - math.random(15, 20))
    elseif VehicleStatus[plate].radiator <= 39 and VehicleStatus[plate].radiator >= 20 then
        SetVehicleEngineHealth(vehicle, engineHealth - math.random(20, 30))
    elseif VehicleStatus[plate].radiator <= 19 and VehicleStatus[plate].radiator >= 6 then
        SetVehicleEngineHealth(vehicle, engineHealth - math.random(30, 40))
    else
        SetVehicleEngineHealth(vehicle, engineHealth - math.random(40, 50))
    end
end

local function applyAxleEffects(vehicle, plate)
    if VehicleStatus[plate].axle <= 80 and VehicleStatus[plate].axle >= 60 then
        for i = 0, 360 do
            SetVehicleSteeringScale(vehicle, i)
            Wait(5)
        end
    elseif VehicleStatus[plate].axle <= 59 and VehicleStatus[plate].axle >= 40 then
        for i = 0, 360 do
            Wait(10)
            SetVehicleSteeringScale(vehicle, i)
        end
    elseif VehicleStatus[plate].axle <= 39 and VehicleStatus[plate].axle >= 20 then
        for i = 0, 360 do
            Wait(15)
            SetVehicleSteeringScale(vehicle, i)
        end
    elseif VehicleStatus[plate].axle <= 19 and VehicleStatus[plate].axle >= 6 then
        for i = 0, 360 do
            Wait(20)
            SetVehicleSteeringScale(vehicle, i)
        end
    else
        for i = 0, 360 do
            Wait(25)
            SetVehicleSteeringScale(vehicle, i)
        end
    end
end

local function applyBrakeEffects(vehicle, plate)
    if VehicleStatus[plate].brakes <= 80 and VehicleStatus[plate].brakes >= 60 then
        SetVehicleHandbrake(vehicle, true)
        Wait(1000)
        SetVehicleHandbrake(vehicle, false)
    elseif VehicleStatus[plate].brakes <= 59 and VehicleStatus[plate].brakes >= 40 then
        SetVehicleHandbrake(vehicle, true)
        Wait(3000)
        SetVehicleHandbrake(vehicle, false)
    elseif VehicleStatus[plate].brakes <= 39 and VehicleStatus[plate].brakes >= 20 then
        SetVehicleHandbrake(vehicle, true)
        Wait(5000)
        SetVehicleHandbrake(vehicle, false)
    elseif VehicleStatus[plate].brakes <= 19 and VehicleStatus[plate].brakes >= 6 then
        SetVehicleHandbrake(vehicle, true)
        Wait(7000)
        SetVehicleHandbrake(vehicle, false)
    else
        SetVehicleHandbrake(vehicle, true)
        Wait(9000)
        SetVehicleHandbrake(vehicle, false)
    end
end

local function applyClutchEffects(vehicle, plate)
    if VehicleStatus[plate].clutch <= 80 and VehicleStatus[plate].clutch >= 60 then
        SetVehicleHandbrake(vehicle, true)
        SetVehicleEngineOn(vehicle, false, false, true)
        SetVehicleUndriveable(vehicle, true)
        Wait(50)
        SetVehicleEngineOn(vehicle, true, false, true)
        SetVehicleUndriveable(vehicle, false)
        for i = 1, 360 do
            SetVehicleSteeringScale(vehicle, i)
            Wait(5)
        end
        Wait(500)
        SetVehicleHandbrake(vehicle, false)
    elseif VehicleStatus[plate].clutch <= 59 and VehicleStatus[plate].clutch >= 40 then
        SetVehicleHandbrake(vehicle, true)
        SetVehicleEngineOn(vehicle, false, false, true)
        SetVehicleUndriveable(vehicle, true)
        Wait(100)
        SetVehicleEngineOn(vehicle, true, false, true)
        SetVehicleUndriveable(vehicle, false)
        for i = 1, 360 do
            SetVehicleSteeringScale(vehicle, i)
            Wait(5)
        end
        Wait(750)
        SetVehicleHandbrake(vehicle, false)
    elseif VehicleStatus[plate].clutch <= 39 and VehicleStatus[plate].clutch >= 20 then
        SetVehicleHandbrake(vehicle, true)
        SetVehicleEngineOn(vehicle, false, false, true)
        SetVehicleUndriveable(vehicle, true)
        Wait(150)
        SetVehicleEngineOn(vehicle, true, false, true)
        SetVehicleUndriveable(vehicle, false)
        for i = 1, 360 do
            SetVehicleSteeringScale(vehicle, i)
            Wait(5)
        end
        Wait(1000)
        SetVehicleHandbrake(vehicle, false)
    elseif VehicleStatus[plate].clutch <= 19 and VehicleStatus[plate].clutch >= 6 then
        SetVehicleHandbrake(vehicle, true)
        SetVehicleEngineOn(vehicle, false, false, true)
        SetVehicleUndriveable(vehicle, true)
        Wait(200)
        SetVehicleEngineOn(vehicle, true, false, true)
        SetVehicleUndriveable(vehicle, false)
        for i = 1, 360 do
            SetVehicleSteeringScale(vehicle, i)
            Wait(5)
        end
        Wait(1250)
        SetVehicleHandbrake(vehicle, false)
    else
        SetVehicleHandbrake(vehicle, true)
        SetVehicleEngineOn(vehicle, false, false, true)
        SetVehicleUndriveable(vehicle, true)
        Wait(250)
        SetVehicleEngineOn(vehicle, true, false, true)
        SetVehicleUndriveable(vehicle, false)
        for i = 1, 360 do
            SetVehicleSteeringScale(vehicle, i)
            Wait(5)
        end
        Wait(1500)
        SetVehicleHandbrake(vehicle, false)
    end
end

local function leakFuel(vehicle, plate)
    local fuel = GetVehicleFuelLevel(vehicle)
    if VehicleStatus[plate].fuel <= 80 and VehicleStatus[plate].fuel >= 60 then
        SetVehicleFuelLevel(vehicle, fuel - 2.0)
    elseif VehicleStatus[plate].fuel <= 59 and VehicleStatus[plate].fuel >= 40 then
        SetVehicleFuelLevel(vehicle, fuel - 4.0)
    elseif VehicleStatus[plate].fuel <= 39 and VehicleStatus[plate].fuel >= 20 then
        SetVehicleFuelLevel(vehicle, fuel - 6.0)
    elseif VehicleStatus[plate].fuel <= 19 and VehicleStatus[plate].fuel >= 6 then
        SetVehicleFuelLevel(vehicle, fuel - 8.0)
    else
        SetVehicleFuelLevel(vehicle, fuel - 10.0)
    end
end

local function applyEffects(vehicle)
    local plate = qbx.getVehiclePlate(vehicle)
    local class = GetVehicleClass(vehicle)
    if class == 13 or class == 21 or class == 16 or class == 15 or class == 14 or not VehicleStatus[plate] then return end

    local chance = math.random(1, 100)
    if VehicleStatus[plate].radiator <= 80 and (chance >= 1 and chance <= 20) then
        applyRadiatorEffects(vehicle, plate)

    elseif VehicleStatus[plate].axle <= 80 and (chance >= 21 and chance <= 40) then
        applyAxleEffects(vehicle, plate)

    elseif VehicleStatus[plate].brakes <= 80 and (chance >= 41 and chance <= 60) then
        applyBrakeEffects(vehicle, plate)

    elseif VehicleStatus[plate].clutch <= 80 and (chance >= 61 and chance <= 80) then
        applyClutchEffects(vehicle, plate)

    elseif VehicleStatus[plate].fuel <= 80 and (chance >= 81 and chance <= 100) then
        leakFuel(vehicle, plate)
    end
end

local function updatePartHealth()
    local veh = cache.vehicle
    if not veh then
        effectTimer = 0
        return 2000
    end

    if IsThisModelABicycle(GetEntityModel(veh)) or cache.seat ~= -1 then
        effectTimer = 0
        return 1000
    end

    local engineHealth = GetVehicleEngineHealth(veh)
    local bodyHealth = GetVehicleBodyHealth(veh)
    local plate = qbx.getVehiclePlate(veh)
    if not VehicleStatus[plate] then
        TriggerServerEvent("vehiclemod:server:setupVehicleStatus", plate, engineHealth, bodyHealth)
    else
        TriggerServerEvent("vehiclemod:server:updatePart", plate, "engine", engineHealth)
        TriggerServerEvent("vehiclemod:server:updatePart", plate, "body", bodyHealth)
        effectTimer += 1
        if effectTimer >= math.random(10, 15) then
            applyEffects(veh)
            effectTimer = 0
        end
    end
end

CreateThread(function()
    while true do
        Wait(1000)
        local wait = updatePartHealth()
        Wait(wait)
    end
end)