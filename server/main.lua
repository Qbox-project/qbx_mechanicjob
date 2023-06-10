local QBCore = exports['qbx-core']:GetCoreObject()
local vehicleStatus = {}
local vehicleDrivingDistance = {}

-- Functions

local function isVehicleOwned(plate)
    local count = MySQL.scalar.await('SELECT count(*) from player_vehicles WHERE plate = ?', {plate})
    return count > 0
end

local function getVehicleStatus(plate)
    local result = MySQL.query.await('SELECT status FROM player_vehicles WHERE plate = ?', {plate})
    if result[1] and result[1].status then
        return json.decode(result[1].status)
    end
end

local function isAuthorized(citizenId)
    for _, cid in pairs(Config.AuthorizedIds) do
        if cid == citizenId then
            return true
        end
    end
    return false
end

-- Callbacks

lib.callback.register('qb-vehicletuning:server:GetDrivingDistances', function()
    return VehicleDrivingDistance
end)

lib.callback.register('qb-vehicletuning:server:IsVehicleOwned', function(_, plate)
    return MySQL.scalar.await('SELECT 1 from player_vehicles WHERE plate = ?', {plate})
end)

lib.callback.register('qb-vehicletuning:server:GetAttachedVehicle', function()
    return Config.Plates
end)

-- Events

RegisterNetEvent('qb-vehicletuning:server:SaveVehicleProps', function(vehicleProps)
    if isVehicleOwned(vehicleProps.plate) then
        MySQL.update('UPDATE player_vehicles SET mods = ? WHERE plate = ?', {json.encode(vehicleProps), vehicleProps.plate})
    end
end)

RegisterNetEvent('vehiclemod:server:setupVehicleStatus', function(plate, engineHealth, bodyHealth)
    engineHealth = engineHealth or 1000.0
    bodyHealth = bodyHealth or 1000.0

    local statusInfo = vehicleStatus[plate] or getVehicleStatus(plate) or
        {
            engine = engineHealth,
            body = bodyHealth,
            radiator = Config.MaxStatusValues.radiator,
            axle = Config.MaxStatusValues.axle,
            brakes = Config.MaxStatusValues.brakes,
            clutch = Config.MaxStatusValues.clutch,
            fuel = Config.MaxStatusValues.fuel
        }

    vehicleStatus[plate] = statusInfo
    TriggerClientEvent("vehiclemod:client:setVehicleStatus", -1, plate, statusInfo)
end)

RegisterNetEvent('qb-vehicletuning:server:UpdateDrivingDistance', function(amount, plate)
    vehicleDrivingDistance[plate] = amount
    TriggerClientEvent('qb-vehicletuning:client:UpdateDrivingDistance', -1, vehicleDrivingDistance[plate], plate)
    local result = MySQL.query.await('SELECT plate FROM player_vehicles WHERE plate = ?', {plate})
    if result[1] then
        MySQL.update('UPDATE player_vehicles SET drivingdistance = ? WHERE plate = ?', {amount, plate})
    end
end)

RegisterNetEvent('qb-vehicletuning:server:LoadStatus', function(veh, plate)
    vehicleStatus[plate] = veh
    TriggerClientEvent("vehiclemod:client:setVehicleStatus", -1, plate, veh)
end)

RegisterNetEvent('vehiclemod:server:updatePart', function(plate, part, level)
    if vehicleStatus[plate] == nil then return end

    local maxLevel = (part == "engine" or part == "body") and 1000 or 100
    if level < 0 then
        level = 0
    elseif level > maxLevel then
        level = maxLevel
    end

    vehicleStatus[plate][part] = level
    TriggerClientEvent("vehiclemod:client:setVehicleStatus", -1, plate, vehicleStatus[plate])
end)

RegisterNetEvent('qb-vehicletuning:server:SetPartLevel', function(plate, part, level)
    if vehicleStatus[plate] ~= nil then
        vehicleStatus[plate][part] = level
        TriggerClientEvent("vehiclemod:client:setVehicleStatus", -1, plate, vehicleStatus[plate])
    end
end)

RegisterNetEvent('vehiclemod:server:fixEverything', function(plate)
    if vehicleStatus[plate] == nil then return end
    for k, v in pairs(Config.MaxStatusValues) do
        vehicleStatus[plate][k] = v
    end
    TriggerClientEvent("vehiclemod:client:setVehicleStatus", -1, plate, vehicleStatus[plate])
end)

RegisterNetEvent('vehiclemod:server:saveStatus', function(plate)
    if vehicleStatus[plate] ~= nil then
        MySQL.update('UPDATE player_vehicles SET status = ? WHERE plate = ?', { json.encode(vehicleStatus[plate]), plate })
    end
end)

RegisterNetEvent('qb-vehicletuning:server:SetAttachedVehicle', function(veh, k)
    Config.Plates[k].AttachedVehicle = (veh == false) and nil or veh
    TriggerClientEvent('qb-vehicletuning:client:SetAttachedVehicle', -1, veh, k)
end)

RegisterNetEvent('qb-vehicletuning:server:CheckForItems', function(part)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    local itemName = Config.RepairCostAmount[part].item
    local amountRequired = Config.RepairCostAmount[part].costs
    local amount = exports.ox_inventory:Search(src, 'count', itemName)

    if amount < amountRequired then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('notifications.not_enough') .. exports.ox_inventory:Items()[itemName].label .. " (min. " ..
        amountRequired .. "x)", "error")
        return
    end

    TriggerClientEvent('qb-vehicletuning:client:RepaireeePart', src, part)
    player.Functions.RemoveItem(itemName, amountRequired)
end)

RegisterNetEvent('qb-mechanicjob:server:removePart', function(part, amount)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then return end
    player.Functions.RemoveItem(Config.RepairCost[part], amount)
end)

-- Commands

QBCore.Commands.Add("setvehiclestatus", "Set Vehicle Status", {{
    name = "part",
    help = "Type The Part You Want To Edit"
}, {
    name = "amount",
    help = "The Percentage Fixed"
}}, true, function(source, args)
    local part = args[1]:lower()
    local level = tonumber(args[2])
    TriggerClientEvent("vehiclemod:client:setPartLevel", source, part, level)
end, "god")

QBCore.Commands.Add("setmechanic", "Give Someone The Mechanic job", {{
    name = "id",
    help = "ID Of The Player"
}}, false, function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)

    if isAuthorized(Player.PlayerData.citizenid) then
        local TargetId = tonumber(args[1])
        if TargetId ~= nil then
            local TargetData = QBCore.Functions.GetPlayer(TargetId)
            if TargetData ~= nil then
                TargetData.Functions.SetJob("mechanic")
                TriggerClientEvent('QBCore:Notify', TargetData.PlayerData.source,
                    "You Were Hired As An Autocare Employee!")
                TriggerClientEvent('QBCore:Notify', source, "You have (" .. TargetData.PlayerData.charinfo.firstname ..
                    ") Hired As An Autocare Employee!")
            end
        else
            TriggerClientEvent('QBCore:Notify', source, "You Must Provide A Player ID!")
        end
    else
        TriggerClientEvent('QBCore:Notify', source, "You Cannot Do This!", "error")
    end
end)

QBCore.Commands.Add("firemechanic", "Fire A Mechanic", {{
    name = "id",
    help = "ID Of The Player"
}}, false, function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)

    if isAuthorized(Player.PlayerData.citizenid) then
        local TargetId = tonumber(args[1])
        if TargetId ~= nil then
            local TargetData = QBCore.Functions.GetPlayer(TargetId)
            if TargetData ~= nil then
                if TargetData.PlayerData.job.name == "mechanic" then
                    TargetData.Functions.SetJob("unemployed")
                    TriggerClientEvent('QBCore:Notify', TargetData.PlayerData.source,
                        "You Were Fired As An Autocare Employee!")
                    TriggerClientEvent('QBCore:Notify', source,
                        "You have (" .. TargetData.PlayerData.charinfo.firstname .. ") Fired As Autocare Employee!")
                else
                    TriggerClientEvent('QBCore:Notify', source, "Youre Not An Employee of Autocare!", "error")
                end
            end
        else
            TriggerClientEvent('QBCore:Notify', source, "You Must Provide A Player ID!", "error")
        end
    else
        TriggerClientEvent('QBCore:Notify', source, "You Cannot Do This!", "error")
    end
end)
