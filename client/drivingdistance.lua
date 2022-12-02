drivingDistance = {}
local inVehicle = false
local currentSeat = false
local vehicleMeters = -1
local previousVehiclePos = nil
local owned = false

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    QBCore.Functions.TriggerCallback('qb-vehicletuning:server:GetDrivingDistances', function(retval)
        drivingDistance = retval
    end)
end)

-- Functions
local function round(num, numDecimalPlaces)
    return tonumber(string.format("%." .. (numDecimalPlaces or 1) .. "f", num))
end

local function GetDamageMultiplier(meters)
    local check = round(meters / 1000, 2)
    local retval = nil

    for k, v in pairs(Config.MinimalMetersForDamage) do
        if check >= v.min and check <= v.max then
            retval = k
            break
        elseif check >= Config.MinimalMetersForDamage[#Config.MinimalMetersForDamage].min then
            retval = #Config.MinimalMetersForDamage
            break
        end
    end

    return retval
end

function trim(plate)
    if not plate then
        return nil
    end

    return string.gsub(plate, '^%s*(.-)%s*$', '%1')
end

-- Events
RegisterNetEvent('qb-vehicletuning:client:UpdateDrivingDistance', function(amount, plate)
    drivingDistance[plate] = amount
end)

lib.onCache('vehicle', function(value)
    if value then
        inVehicle = true

        local seat = GetPedInVehicleSeat(value, -1)

        if seat ~= cache.ped then
            return
        end

        calcDistance(vehicle)
    else
        inVehicle = false
        vehicleMeters = -1
        previousVehiclePos = nil
    end
end)

lib.onCache('seat', function(value)
    currentSeat = value

    if value ~= -1 then
        return
    end

    calcDistance(cache.vehicle)
end)

function calcDistance(vehicle)
    local plate = trim(GetVehicleNumberPlateText(vehicle))

    QBCore.Functions.TriggerCallback('qb-vehicletuning:server:IsVehicleOwned', function(isOwned)
        owned = isOwned

        if isOwned then
            if drivingDistance[plate] then
                vehicleMeters = drivingDistance[plate]
            else
                drivingDistance[plate] = 0
                vehicleMeters = drivingDistance[plate]
            end
        else
            if drivingDistance[plate] then
                vehicleMeters = drivingDistance[plate]
            else
                drivingDistance[plate] = math.random(111111, 999999)
                vehicleMeters = drivingDistance[plate]
            end
        end
    end, plate)

    previousVehiclePos = nil

    while inVehicle and currentSeat == -1 do
        local pos = GetEntityCoords(cache.ped)

        if previousVehiclePos then
            local Distance = #(pos - previousVehiclePos)
            local DamageKey = GetDamageMultiplier(vehicleMeters)

            vehicleMeters = vehicleMeters + ((Distance / 100) * 325)
            drivingDistance[plate] = vehicleMeters

            if DamageKey then
                local DamageData = Config.MinimalMetersForDamage[DamageKey]
                local chance = math.random(3)
                local odd = math.random(3)
                local CurrentData = VehicleStatus[plate]

                if chance == odd then
                    for k, v in pairs(Config.Parts) do
                        if not v.canDamage then
                            return
                        end

                        local randmultiplier = (math.random(DamageData.multiplier.min, DamageData.multiplier.max) / 100)
                        local newDamage = 0

                        if CurrentData[k] - randmultiplier >= 0 then
                            newDamage = CurrentData[k] - randmultiplier
                        end

                        TriggerServerEvent('qb-vehicletuning:server:SetPartLevel', plate, k, newDamage)
                    end
                end
            end

            local amount = round(drivingDistance[plate] / 1000, 2)

            TriggerEvent('hud:client:UpdateDrivingMeters', true, amount)

            if owned then
                TriggerServerEvent('qb-vehicletuning:server:UpdateDrivingDistance', drivingDistance[plate], plate)
            end
        end

        previousVehiclePos = pos

        Citizen.Wait(2000)
    end
end