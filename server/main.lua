local config = require 'config.server'
local sharedConfig = require 'config.shared'
local vehicleStatus = {}
local vehicleDrivingDistance = {}
local stash = {
    id = 'mechanicstash',
    label = locale('labels.stash'),
    slots = 500,
    weight = 4000000,
    owner = false,
    groups = {mechanic = 0},
    coords = sharedConfig.locations.stash
}
exports.ox_inventory:RegisterStash(stash.id, stash.label, stash.slots, stash.weight, stash.owner, stash.groups, stash.coords)

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
    for i = 1, #config.authorizedIds do
        if config.authorizedIds[i] == citizenId then
            return true
        end
    end
    return false
end

-- Callbacks

lib.callback.register('qb-vehicletuning:server:GetDrivingDistances', function()
    return vehicleDrivingDistance
end)

lib.callback.register('qb-vehicletuning:server:IsVehicleOwned', function(_, plate)
    return MySQL.scalar.await('SELECT 1 from player_vehicles WHERE plate = ?', {plate})
end)

lib.callback.register('qb-vehicletuning:server:GetAttachedVehicle', function()
    return sharedConfig.plates
end)

lib.callback.register('qbx_mechanicjob:server:spawnVehicle', function(source, vehicleName, vehicleCoords)
	local netId = qbx.spawnVehicle({
        model = joaat(vehicleName),
        spawnSource = vehicleCoords,
        warp = GetPlayerPed(source)
    })
	return netId
end)

lib.callback.register('qbx_mechanicjob:server:checkForItems', function(source, part)
    local itemName = sharedConfig.repairCostAmount[part].item
    local amountRequired = sharedConfig.repairCostAmount[part].costs
    local amount = exports.ox_inventory:Search(source, 'count', itemName)
    local hasEnough = amount >= amountRequired
    if hasEnough then
        exports.ox_inventory:RemoveItem(source, itemName, amountRequired)
    end
    return hasEnough
end)

-- Events

RegisterNetEvent('qb-vehicletuning:server:SaveVehicleProps', function(vehicleProps)
    if not isVehicleOwned(vehicleProps.plate) then return end

    MySQL.update.await('UPDATE player_vehicles SET mods = ? WHERE plate = ?', {json.encode(vehicleProps), vehicleProps.plate})
end)

RegisterNetEvent('vehiclemod:server:setupVehicleStatus', function(plate, engineHealth, bodyHealth)
    engineHealth = engineHealth or 1000.0
    bodyHealth = bodyHealth or 1000.0

    local statusInfo = vehicleStatus[plate] or getVehicleStatus(plate) or
        {
            engine = engineHealth,
            body = bodyHealth,
            radiator = sharedConfig.maxStatusValues.radiator,
            axle = sharedConfig.maxStatusValues.axle,
            brakes = sharedConfig.maxStatusValues.brakes,
            clutch = sharedConfig.maxStatusValues.clutch,
            fuel = sharedConfig.maxStatusValues.fuel
        }

    vehicleStatus[plate] = statusInfo
    TriggerClientEvent("vehiclemod:client:setVehicleStatus", -1, plate, statusInfo)
end)

RegisterNetEvent('qb-vehicletuning:server:UpdateDrivingDistance', function(amount, plate)
    vehicleDrivingDistance[plate] = amount
    TriggerClientEvent('qb-vehicletuning:client:UpdateDrivingDistance', -1, vehicleDrivingDistance[plate], plate)
    local result = MySQL.query.await('SELECT plate FROM player_vehicles WHERE plate = ?', {plate})
    if not result[1] then return end

    MySQL.update.await('UPDATE player_vehicles SET drivingdistance = ? WHERE plate = ?', {amount, plate})
end)

RegisterNetEvent('qb-vehicletuning:server:LoadStatus', function(veh, plate) -- Used in old qb-garages
    vehicleStatus[plate] = veh
    TriggerClientEvent("vehiclemod:client:setVehicleStatus", -1, plate, veh)
end)

RegisterNetEvent('vehiclemod:server:updatePart', function(plate, part, level)
    if not vehicleStatus[plate] then return end

    local maxLevel = (part == "engine" or part == "body") and 1000 or 100
    vehicleStatus[plate][part] = level < 0 and 0 or level > maxLevel and maxLevel or level
    TriggerClientEvent("vehiclemod:client:setVehicleStatus", -1, plate, vehicleStatus[plate])
end)

RegisterNetEvent('qb-vehicletuning:server:SetPartLevel', function(plate, part, level)
    if not vehicleStatus[plate] then return end

    vehicleStatus[plate][part] = level
    TriggerClientEvent("vehiclemod:client:setVehicleStatus", -1, plate, vehicleStatus[plate])
end)

RegisterNetEvent('vehiclemod:server:fixEverything', function(plate)
    if not vehicleStatus[plate] then return end

    for k, v in pairs(sharedConfig.maxStatusValues) do
        vehicleStatus[plate][k] = v
    end

    TriggerClientEvent("vehiclemod:client:setVehicleStatus", -1, plate, vehicleStatus[plate])
end)

RegisterNetEvent('vehiclemod:server:saveStatus', function(plate) -- Used in old qb-garages
    if not vehicleStatus[plate] then return end

    MySQL.update.await('UPDATE player_vehicles SET status = ? WHERE plate = ?', { json.encode(vehicleStatus[plate]), plate })
end)

RegisterNetEvent('qb-vehicletuning:server:SetAttachedVehicle', function(k, veh)
    if not sharedConfig.plates[k] then return end

    sharedConfig.plates[k].AttachedVehicle = veh
    TriggerClientEvent('qb-vehicletuning:client:SetAttachedVehicle', -1, veh, k)
end)

-- Commands

lib.addCommand('setvehiclestatus', {
    help = 'Set Vehicle Status',
    params = {
        {
            name = 'part',
            type = 'string',
            help = 'Type The Part You Want To Edit',
        },
        {
            name = 'amount',
            type = 'number',
            help = 'The Percentage Fixed',
        },
    },
    restricted = 'group.god'
}, function(source, args)
    local part = args.part:lower()
    local level = args.amount
    TriggerClientEvent("vehiclemod:client:setPartLevel", source, part, level)
end)

lib.addCommand('setmechanic', {
    help = 'Give Someone The Mechanic job',
    params = {
        {
            name = 'target',
            type = 'playerId',
            help = 'ID Of The Player',
        },
    },
}, function(source, args)
    local player = exports.qbx_core:GetPlayer(source)

    if isAuthorized(player.PlayerData.citizenid) then
        if args.target then
            local targetData = exports.qbx_core:GetPlayer(args.target)
            if targetData then
                targetData.Functions.SetJob("mechanic")
                TriggerClientEvent('QBCore:Notify', targetData.PlayerData.source, "You Were Hired As An Autocare Employee!")
                TriggerClientEvent('QBCore:Notify', source, "You have (" .. targetData.PlayerData.charinfo.firstname .. ") Hired As An Autocare Employee!")
            end
        else
            TriggerClientEvent('QBCore:Notify', source, "You Must Provide A Player ID!")
        end
    else
        TriggerClientEvent('QBCore:Notify', source, "You Cannot Do This!", "error")
    end
end)

lib.addCommand('firemechanic', {
    help = 'Fire A Mechanic',
    params = {
        {
            name = 'target',
            type = 'playerId',
            help = 'ID Of The Player',
        },
    },
}, function(source, args)
    local player = exports.qbx_core:GetPlayer(source)

    if isAuthorized(player.PlayerData.citizenid) then
        if args.target then
            local TargetData = exports.qbx_core:GetPlayer(args.target)
            if TargetData then
                if TargetData.PlayerData.job.name == "mechanic" then
                    TargetData.Functions.SetJob("unemployed")
                    TriggerClientEvent('QBCore:Notify', TargetData.PlayerData.source,  "You Were Fired As An Autocare Employee!")
                    TriggerClientEvent('QBCore:Notify', source, "You have (" .. TargetData.PlayerData.charinfo.firstname .. ") Fired As Autocare Employee!")
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