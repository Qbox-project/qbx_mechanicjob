local config = require 'config.server'
local clientConfig = require 'config.client'
local sharedConfig = require 'config.shared'
local vehicleStatus = {}
local vehicleDrivingDistance = {}
local repairAuthorizations = {}
local vehiclesSpawning = {}
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

---@param plate any
---@return string?
local function normalizePlate(plate)
    if type(plate) ~= 'string' or #plate > 16 then return end
    return plate:match('^%s*(.-)%s*$')
end

---@param source number
---@return Player?
local function getOnDutyMechanic(source)
    local player = exports.qbx_core:GetPlayer(source)
    if player and player.PlayerData.job.type == 'mechanic' and player.PlayerData.job.onduty then return player end
end

---@param source number
---@param plate string
---@return number?
local function getCurrentVehicle(source, plate)
    local vehicle = GetVehiclePedIsIn(GetPlayerPed(source), false)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end
    if normalizePlate(GetVehicleNumberPlateText(vehicle)) ~= plate then return end
    return vehicle
end

---@param source number
---@param plate string
---@return number?
local function getLiftVehicle(source, plate)
    local playerCoords = GetEntityCoords(GetPlayerPed(source))
    for i = 1, #sharedConfig.plates do
        local lift = sharedConfig.plates[i]
        local vehicle = lift.AttachedVehicle
        if vehicle and DoesEntityExist(vehicle)
            and #(playerCoords - lift.coords.xyz) <= 8.0
            and normalizePlate(GetVehicleNumberPlateText(vehicle)) == plate
        then
            return vehicle
        end
    end
end

local function isValidLevel(part, level)
    local maxLevel = sharedConfig.maxStatusValues[part]
    return maxLevel and type(level) == 'number' and level == level and level >= 0 and level <= maxLevel
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

lib.callback.register('qbx_mechanicjob:server:spawnVehicle', function(source, vehicleName)
	if not getOnDutyMechanic(source) or vehiclesSpawning[source] or type(vehicleName) ~= 'string' or not clientConfig.vehicles[vehicleName] then return end
	if #(GetEntityCoords(GetPlayerPed(source)) - sharedConfig.locations.vehicle.xyz) > 10.0 then return end
	vehiclesSpawning[source] = true
	local netId = qbx.spawnVehicle({
        model = joaat(vehicleName),
        spawnSource = sharedConfig.locations.vehicle,
        warp = GetPlayerPed(source)
    })
	vehiclesSpawning[source] = nil
	return netId
end)

lib.callback.register('qbx_mechanicjob:server:checkForItems', function(source, part, suppliedPlate)
    local plate = normalizePlate(suppliedPlate)
    local repairCost = type(part) == 'string' and sharedConfig.repairCostAmount[part]
    if not plate or not repairCost or not getOnDutyMechanic(source) or not getLiftVehicle(source, plate) then return false end

    local itemName = repairCost.item
    local amountRequired = repairCost.costs
    local amount = exports.ox_inventory:Search(source, 'count', itemName)
    local hasEnough = amount >= amountRequired
    if hasEnough then
        hasEnough = exports.ox_inventory:RemoveItem(source, itemName, amountRequired) == true
        if hasEnough then
            repairAuthorizations[source] = { plate = plate, part = part, expires = os.time() + 30 }
        end
    end
    return hasEnough
end)

-- Events

RegisterNetEvent('qb-vehicletuning:server:SaveVehicleProps', function(vehicleProps)
    if type(vehicleProps) ~= 'table' then return end
    local plate = normalizePlate(vehicleProps.plate)
    if not plate or not getCurrentVehicle(source, plate) or not isVehicleOwned(plate) then return end

    vehicleProps.plate = plate
    MySQL.update.await('UPDATE player_vehicles SET mods = ? WHERE plate = ?', {json.encode(vehicleProps), plate})
end)

RegisterNetEvent('vehiclemod:server:setupVehicleStatus', function(plate, engineHealth, bodyHealth)
    plate = normalizePlate(plate)
    if not plate or not getCurrentVehicle(source, plate) then return end
    if type(engineHealth) ~= 'number' or engineHealth ~= engineHealth then engineHealth = 1000.0 end
    if type(bodyHealth) ~= 'number' or bodyHealth ~= bodyHealth then bodyHealth = 1000.0 end
    engineHealth = math.max(0, math.min(1000, engineHealth))
    bodyHealth = math.max(0, math.min(1000, bodyHealth))

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
    plate = normalizePlate(plate)
    local vehicle = plate and getCurrentVehicle(source, plate)
    if not vehicle or GetPedInVehicleSeat(vehicle, -1) ~= GetPlayerPed(source)
        or type(amount) ~= 'number' or amount ~= amount or amount < 0 or amount > 1000000000
    then
        return
    end
    local previous = vehicleDrivingDistance[plate]
    if previous and (amount < previous or amount - previous > 10000) then return end
    if not previous and isVehicleOwned(plate) and amount > 10000 then return end
    vehicleDrivingDistance[plate] = amount
    TriggerClientEvent('qb-vehicletuning:client:UpdateDrivingDistance', -1, vehicleDrivingDistance[plate], plate)
    local result = MySQL.query.await('SELECT plate FROM player_vehicles WHERE plate = ?', {plate})
    if not result[1] then return end

    MySQL.update.await('UPDATE player_vehicles SET drivingdistance = ? WHERE plate = ?', {amount, plate})
end)

RegisterNetEvent('qb-vehicletuning:server:LoadStatus', function(veh, plate) -- Used in old qb-garages
    plate = normalizePlate(plate)
    if not plate or type(veh) ~= 'table' or not getCurrentVehicle(source, plate) then return end
    vehicleStatus[plate] = veh
    TriggerClientEvent("vehiclemod:client:setVehicleStatus", -1, plate, veh)
end)

RegisterNetEvent('vehiclemod:server:updatePart', function(plate, part, level)
    plate = normalizePlate(plate)
    if not plate or type(part) ~= 'string' or not vehicleStatus[plate] or not isValidLevel(part, level) then return end

    local currentLevel = vehicleStatus[plate][part]
    if type(currentLevel) ~= 'number' then return end
    if level > currentLevel then
        local authorization = repairAuthorizations[source]
        if not getOnDutyMechanic(source) or not getLiftVehicle(source, plate)
            or not authorization or authorization.plate ~= plate or authorization.part ~= part or authorization.expires < os.time()
        then
            return
        end
        repairAuthorizations[source] = nil
    elseif not getCurrentVehicle(source, plate) and not getLiftVehicle(source, plate) then
        return
    end

    vehicleStatus[plate][part] = level
    TriggerClientEvent("vehiclemod:client:setVehicleStatus", -1, plate, vehicleStatus[plate])
end)

RegisterNetEvent('qb-vehicletuning:server:SetPartLevel', function(plate, part, level)
    plate = normalizePlate(plate)
    if not plate or type(part) ~= 'string' or not vehicleStatus[plate] or not isValidLevel(part, level) or not getCurrentVehicle(source, plate) then return end
    if type(vehicleStatus[plate][part]) ~= 'number' or level > vehicleStatus[plate][part] then return end

    vehicleStatus[plate][part] = level
    TriggerClientEvent("vehiclemod:client:setVehicleStatus", -1, plate, vehicleStatus[plate])
end)

RegisterNetEvent('vehiclemod:server:fixEverything', function(plate)
    plate = normalizePlate(plate)
    if not plate or not vehicleStatus[plate] or not IsPlayerAceAllowed(source, 'group.admin') or not getCurrentVehicle(source, plate) then return end

    for k, v in pairs(sharedConfig.maxStatusValues) do
        vehicleStatus[plate][k] = v
    end

    TriggerClientEvent("vehiclemod:client:setVehicleStatus", -1, plate, vehicleStatus[plate])
end)

RegisterNetEvent('vehiclemod:server:saveStatus', function(plate) -- Used in old qb-garages
    plate = normalizePlate(plate)
    if not plate or not vehicleStatus[plate] or not getCurrentVehicle(source, plate) then return end

    MySQL.update.await('UPDATE player_vehicles SET status = ? WHERE plate = ?', { json.encode(vehicleStatus[plate]), plate })
end)

RegisterNetEvent('qb-vehicletuning:server:SetAttachedVehicle', function(k, veh)
    if math.type(k) ~= 'integer' or not sharedConfig.plates[k] or not getOnDutyMechanic(source) then return end
    local lift = sharedConfig.plates[k]
    if #(GetEntityCoords(GetPlayerPed(source)) - lift.coords.xyz) > 8.0 then return end
    if veh ~= false and (type(veh) ~= 'number' or not DoesEntityExist(veh) or #(GetEntityCoords(veh) - lift.coords.xyz) > 8.0) then return end

    lift.AttachedVehicle = veh
    TriggerClientEvent('qb-vehicletuning:client:SetAttachedVehicle', -1, veh, k)
end)

AddEventHandler('playerDropped', function()
    repairAuthorizations[source] = nil
    vehiclesSpawning[source] = nil
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
