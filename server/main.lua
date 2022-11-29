local QBCore = exports['qb-core']:GetCoreObject()
local VehicleStatus = {}
local VehicleDrivingDistance = {}

-- Functions
function IsVehicleOwned(plate)
    local result = MySQL.scalar.await('SELECT 1 from player_vehicles WHERE plate = ?', {
        plate
    })

    if result then
        return true
    else
        return false
    end
end

function GetVehicleStatus(plate)
    local retval = nil
    local result = MySQL.single.await('SELECT status FROM player_vehicles WHERE plate = ?', {
        plate
    })

    if result then
        retval = result.status and json.decode(result.status) or nil
    end

    return retval
end

-- Callbacks
QBCore.Functions.CreateCallback('qb-vehicletuning:server:GetDrivingDistances', function(_, cb)
    cb(VehicleDrivingDistance)
end)

QBCore.Functions.CreateCallback('qb-vehicletuning:server:IsVehicleOwned', function(_, cb, plate)
    local retval = false
    local result = MySQL.scalar.await('SELECT 1 from player_vehicles WHERE plate = ?', {
        plate
    })

    if result then
        retval = true
    end

    cb(retval)
end)

QBCore.Functions.CreateCallback('qb-vehicletuning:server:GetAttachedVehicle', function(_, cb)
    cb(Config.Plates)
end)

QBCore.Functions.CreateCallback('qb-vehicletuning:server:IsMechanicAvailable', function(_, cb)
    local amount = 0

    for _, v in pairs(QBCore.Functions.GetPlayers()) do
        local Player = QBCore.Functions.GetPlayer(v)

        if Player then
            if Player.PlayerData.job.name == "mechanic" and Player.PlayerData.job.onduty then
                amount = amount + 1
            end
        end
    end

    cb(amount)
end)

QBCore.Functions.CreateCallback('qb-vehicletuning:server:GetStatus', function(_, cb, plate)
    if VehicleStatus[plate] and next(VehicleStatus[plate]) then
        cb(VehicleStatus[plate])
    else
        cb(nil)
    end
end)

-- Events
RegisterNetEvent('qb-vehicletuning:server:SaveVehicleProps', function(vehicleProps)
    if IsVehicleOwned(vehicleProps.plate) then
        MySQL.update('UPDATE player_vehicles SET mods = ? WHERE plate = ?', {
            json.encode(vehicleProps),
            vehicleProps.plate
        })
    end
end)

RegisterNetEvent('vehiclemod:server:setupVehicleStatus', function(plate, engineHealth, bodyHealth)
    engineHealth = engineHealth or 1000.0
    bodyHealth = bodyHealth or 1000.0

    if not VehicleStatus[plate] then
        if IsVehicleOwned(plate) then
            local statusInfo = GetVehicleStatus(plate)

            if not statusInfo then
                statusInfo = {
                    ["engine"] = engineHealth,
                    ["body"] = bodyHealth,
                    ["radiator"] = Config.MaxStatusValues["radiator"],
                    ["axle"] = Config.MaxStatusValues["axle"],
                    ["brakes"] = Config.MaxStatusValues["brakes"],
                    ["clutch"] = Config.MaxStatusValues["clutch"],
                    ["fuel"] = Config.MaxStatusValues["fuel"]
                }
            end

            VehicleStatus[plate] = statusInfo

            TriggerClientEvent("vehiclemod:client:setVehicleStatus", -1, plate, statusInfo)
        else
            local statusInfo = {
                ["engine"] = engineHealth,
                ["body"] = bodyHealth,
                ["radiator"] = Config.MaxStatusValues["radiator"],
                ["axle"] = Config.MaxStatusValues["axle"],
                ["brakes"] = Config.MaxStatusValues["brakes"],
                ["clutch"] = Config.MaxStatusValues["clutch"],
                ["fuel"] = Config.MaxStatusValues["fuel"]
            }

            VehicleStatus[plate] = statusInfo

            TriggerClientEvent("vehiclemod:client:setVehicleStatus", -1, plate, statusInfo)
        end
    else
        TriggerClientEvent("vehiclemod:client:setVehicleStatus", -1, plate, VehicleStatus[plate])
    end
end)

RegisterNetEvent('qb-vehicletuning:server:UpdateDrivingDistance', function(amount, plate)
    VehicleDrivingDistance[plate] = amount

    TriggerClientEvent('qb-vehicletuning:client:UpdateDrivingDistance', -1, VehicleDrivingDistance[plate], plate)

    local result = MySQL.single.await('SELECT plate FROM player_vehicles WHERE plate = ?', {
        plate
    })

    if result then
        MySQL.update('UPDATE player_vehicles SET drivingdistance = ? WHERE plate = ?', {
            amount,
            plate
        })
    end
end)

RegisterNetEvent('qb-vehicletuning:server:LoadStatus', function(veh, plate)
    VehicleStatus[plate] = veh

    TriggerClientEvent("vehiclemod:client:setVehicleStatus", -1, plate, veh)
end)

RegisterNetEvent('vehiclemod:server:updatePart', function(plate, part, level)
    if VehicleStatus[plate] then
        if part == "engine" or part == "body" then
            VehicleStatus[plate][part] = level

            if VehicleStatus[plate][part] < 0 then
                VehicleStatus[plate][part] = 0
            elseif VehicleStatus[plate][part] > 1000 then
                VehicleStatus[plate][part] = 1000.0
            end
        else
            VehicleStatus[plate][part] = level

            if VehicleStatus[plate][part] < 0 then
                VehicleStatus[plate][part] = 0
            elseif VehicleStatus[plate][part] > 100 then
                VehicleStatus[plate][part] = 100
            end
        end

        TriggerClientEvent("vehiclemod:client:setVehicleStatus", -1, plate, VehicleStatus[plate])
    end
end)

RegisterNetEvent('qb-vehicletuning:server:SetPartLevel', function(plate, part, level)
    if VehicleStatus[plate] then
        VehicleStatus[plate][part] = level

        TriggerClientEvent("vehiclemod:client:setVehicleStatus", -1, plate, VehicleStatus[plate])
    end
end)

RegisterNetEvent('vehiclemod:server:fixEverything', function(plate)
    if VehicleStatus[plate] then
        for k, v in pairs(Config.MaxStatusValues) do
            VehicleStatus[plate][k] = v
        end

        TriggerClientEvent("vehiclemod:client:setVehicleStatus", -1, plate, VehicleStatus[plate])
    end
end)

RegisterNetEvent('vehiclemod:server:saveStatus', function(plate)
    if VehicleStatus[plate] then
        MySQL.update('UPDATE player_vehicles SET status = ? WHERE plate = ?', {
            json.encode(VehicleStatus[plate]),
            plate
        })
    end
end)

RegisterNetEvent('qb-vehicletuning:server:SetAttachedVehicle', function(veh, k)
    if veh then
        Config.Plates[k].attachedVehicle = veh

        TriggerClientEvent('qb-vehicletuning:client:SetAttachedVehicle', -1, veh, k)
    else
        Config.Plates[k].attachedVehicle = nil

        TriggerClientEvent('qb-vehicletuning:client:SetAttachedVehicle', -1, false, k)
    end
end)

RegisterNetEvent('qb-vehicletuning:server:CheckForItems', function(part)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local RepairPart = Player.Functions.GetItemByName(Config.RepairCostAmount[part].item)

    if RepairPart then
        if RepairPart.amount >= Config.RepairCostAmount[part].costs then
            TriggerClientEvent('qb-vehicletuning:client:RepaireeePart', src, part)

            Player.Functions.RemoveItem(Config.RepairCostAmount[part].item, Config.RepairCostAmount[part].costs)
        else
            TriggerClientEvent('QBCore:Notify', src, Lang:t('notifications.not_enough') .. QBCore.Shared.Items[Config.RepairCostAmount[part].item]["label"] .. " (min. " .. Config.RepairCostAmount[part].costs .. "x)", "error")
        end
    else
        TriggerClientEvent('QBCore:Notify', src, Lang:t('notifications.not_have') .. QBCore.Shared.Items[Config.RepairCostAmount[part].item]["label"], "error")
    end
end)

RegisterNetEvent('qb-mechanicjob:server:removePart', function(part, amount)
    local Player = QBCore.Functions.GetPlayer(source)

    if not Player then return end

    Player.Functions.RemoveItem(Config.RepairCost[part], amount)
end)

-- Commands
QBCore.Commands.Add("setvehiclestatus", "Set Vehicle Status", {
    {name = "part", help = "Type The Part You Want To Edit"},
    {name = "amount", help = "The Percentage Fixed"}
}, true, function(source, args)
    local part = args[1]:lower()
    local level = tonumber(args[2])

    TriggerClientEvent("vehiclemod:client:setPartLevel", source, part, level)
end, "god")

AddEventHandler('onServerResourceStart', function(resourceName)
    if resourceName == 'ox_inventory' or resourceName == GetCurrentResourceName() then
        exports.ox_inventory:RegisterStash('stash_mechanic', "Stash: Mechanic", 500, 4000000, false)
    end
end)