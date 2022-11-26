local drivingDistance = {}

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    QBCore.Functions.TriggerCallback('qb-vehicletuning:server:GetDrivingDistances', function(retval)
        drivingDistance = retval
    end)
end)

-- Functions
local function round(num, numDecimalPlaces)
    if numDecimalPlaces and numDecimalPlaces>0 then
        local mult = 10 ^ numDecimalPlaces

        return math.floor(num * mult + 0.5) / mult
    end

    return math.floor(num + 0.5)
end

local function GetDamageMultiplier(meters)
    local check = round(meters / 1000, -2)
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

local function trim(plate)
    if not plate then
        return nil
    end

    return string.gsub(plate, '^%s*(.-)%s*$', '%1')
end

-- Events
RegisterNetEvent('qb-vehicletuning:client:UpdateDrivingDistance', function(amount, plate)
    drivingDistance[plate] = amount
end)

-- Threads
CreateThread(function()
    local vehicleMeters = -1
    local previousVehiclePos = nil
    local checkDone = false

    while true do
        if cache.vehicle then
            local seat = GetPedInVehicleSeat(cache.vehicle, -1)
            local pos = GetEntityCoords(cache.ped)
            local plate = trim(GetVehicleNumberPlateText(cache.vehicle))

            if seat == cache.ped then
                if not checkDone then
                    if vehicleMeters == -1 then
                        checkDone = true

                        QBCore.Functions.TriggerCallback('qb-vehicletuning:server:IsVehicleOwned', function(IsOwned)
                            if IsOwned then
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
                    end
                end
            else
                if vehicleMeters == -1 then
                    if drivingDistance[plate] ~= nil then
                        vehicleMeters = drivingDistance[plate]
                    end
                end
            end

            if vehicleMeters ~= -1 then
                if seat == cache.ped then
                    if previousVehiclePos ~= nil then
                        local Distance = #(pos - previousVehiclePos)
                        local DamageKey = GetDamageMultiplier(vehicleMeters)

                        vehicleMeters = vehicleMeters + ((Distance / 100) * 325)
                        drivingDistance[plate] = vehicleMeters

                        if DamageKey ~= nil then
                            local DamageData = Config.MinimalMetersForDamage[DamageKey]
                            local chance = math.random(3)
                            local odd = math.random(3)
                            local CurrentData = VehicleStatus[plate]

                            if chance == odd then
                                for k, _ in pairs(Config.Damages) do
                                    local randmultiplier = (math.random(DamageData.multiplier.min, DamageData.multiplier.max) / 100)
                                    local newDamage = 0

                                    if CurrentData[k] - randmultiplier >= 0 then
                                        newDamage = CurrentData[k] - randmultiplier
                                    end

                                    TriggerServerEvent('qb-vehicletuning:server:SetPartLevel', plate, k, newDamage)
                                end
                            end
                        end

                        local amount = round(drivingDistance[plate] / 1000, -2)

                        TriggerEvent('hud:client:UpdateDrivingMeters', true, amount)
                        TriggerServerEvent('qb-vehicletuning:server:UpdateDrivingDistance', drivingDistance[plate], plate)
                    end
                else
                    if cache.vehicle then
                        if drivingDistance[plate] ~= nil then
                            local amount = round(drivingDistance[plate] / 1000, -2)

                            TriggerEvent('hud:client:UpdateDrivingMeters', true, amount)
                        end
                    else
                        if vehicleMeters ~= -1 then
                            vehicleMeters = -1
                        end

                        if checkDone then
                            checkDone = false
                        end
                    end
                end
            end

            previousVehiclePos = pos

            Wait(2000)
        else
            if vehicleMeters ~= -1 then
                vehicleMeters = -1
            end

            if checkDone then
                checkDone = false
            end

            if previousVehiclePos ~= nil then
                previousVehiclePos = nil
            end

            Wait(500)
        end

        Wait(0)
    end
end)