--- TODO: change qb-target to ox_target
--- TODO: replace notify calls with NotifyV2 calls

QBCore = exports['qbx-core']:GetCoreObject()
VehicleStatus = {}

local closestPlate = nil
local playerJob = {}
local onDuty = false
local openingDoor = false

-- zone check
local isInsideDutyZone = false
local isInsideStashZone = false
local isInsideGarageZone = false
local isInsideVehiclePlateZone = false
local plateZones = {}
local plateTargetBoxId = 'plateTarget_'
local dutyTargetBoxId = 'dutyTarget'
local stashTargetBoxId = 'stashTarget'

-- Exports

---@param plate string
---@return table?
local function getVehicleStatusList(plate)
    if VehicleStatus[plate] then
        return VehicleStatus[plate]
    end
end

local function getVehicleStatus(plate, part)
    if VehicleStatus[plate] then
        return VehicleStatus[plate][part]
    end
end

local function setVehicleStatus(plate, part, level)
    TriggerServerEvent("vehiclemod:server:updatePart", plate, part, level)
end

exports('GetVehicleStatusList', getVehicleStatusList)
exports('GetVehicleStatus', getVehicleStatus)
exports('SetVehicleStatus', setVehicleStatus)


-- Functions

---@param id string
local function deleteTarget(id)
    if Config.UseTarget then
        exports['qb-target']:RemoveZone(id)
    else
        if Config.Targets[id] and Config.Targets[id].zone then
            Config.Targets[id].zone:destroy()
        end
    end

    Config.Targets[id] = nil
end

local function registerDutyTarget()
    local coords = Config.Locations.duty
    local boxData = Config.Targets[dutyTargetBoxId] or {}

    if boxData and boxData.created then
        return
    end

    if playerJob.type ~= 'mechanic' then
        return
    end

    local label = onDuty and Lang:t('labels.sign_off') or Lang:t('labels.sign_in')

    if Config.UseTarget then
        exports['qb-target']:AddBoxZone(dutyTargetBoxId, coords, 1.5, 1.5, {
            name = dutyTargetBoxId,
            heading = 0,
            debugPoly = false,
            minZ = coords.z - 1.0,
            maxZ = coords.z + 1.0,
        }, {
            options = {{
                type = "server",
                event = "QBCore:ToggleDuty",
                label = label,
            }},
            distance = 2.0
        })

        Config.Targets[dutyTargetBoxId] = {created = true}
    else
        local zone = BoxZone:Create(coords, 1.5, 1.5, {
            name = dutyTargetBoxId,
            heading = 0,
            debugPoly = false,
            minZ = coords.z - 1.0,
            maxZ = coords.z + 1.0,
        })
        zone:onPlayerInOut(function (isPointInside)
            if isPointInside then
                exports['qbx-core']:DrawText("[E] " .. label, 'left')
            else
                exports['qbx-core']:HideText()
            end

            isInsideDutyZone = isPointInside
        end)

        Config.Targets[dutyTargetBoxId] = {created = true, zone = zone}
    end
end

local function registerStashTarget()
    local coords = Config.Locations.stash
    local boxData = Config.Targets[stashTargetBoxId] or {}

    if boxData and boxData.created then
        return
    end

    if playerJob.type ~= 'mechanic' then
        return
    end

    if Config.UseTarget then
        exports['qb-target']:AddBoxZone(stashTargetBoxId, coords, 1.5, 1.5, {
            name = stashTargetBoxId,
            heading = 0,
            debugPoly = false,
            minZ = coords.z - 1.0,
            maxZ = coords.z + 1.0,
        }, {
            options = {{
                type = "client",
                event = "qb-mechanicjob:client:target:OpenStash",
                label = Lang:t('labels.o_stash'),
            }},
            distance = 2.0
        })

        Config.Targets[stashTargetBoxId] = {created = true}
    else
        local zone = BoxZone:Create(coords, 1.5, 1.5, {
            name = stashTargetBoxId,
            heading = 0,
            debugPoly = false,
            minZ = coords.z - 1.0,
            maxZ = coords.z + 1.0,
        })
        zone:onPlayerInOut(function (isPointInside)
            if isPointInside then
                exports['qbx-core']:DrawText(Lang:t('labels.o_stash'), 'left')
            else
                exports['qbx-core']:HideText()
            end

            isInsideStashZone = isPointInside
        end)

        Config.Targets[stashTargetBoxId] = {created = true, zone = zone}
    end
end

local function registerGarageZone()
    local coords = Config.Locations.vehicle
    local vehicleZone = BoxZone:Create(coords.xyz, 5, 15, {
        name = 'vehicleZone',
        heading = 340.0,
        minZ = coords.z - 1.0,
        maxZ = coords.z + 5.0,
        debugPoly = false
    })

    vehicleZone:onPlayerInOut(function (isPointInside)
        if isPointInside and onDuty then
            local inVehicle = cache.vehicle
            if inVehicle then
                exports['qbx-core']:DrawText(Lang:t('labels.h_vehicle'), 'left')
            else
                exports['qbx-core']:DrawText(Lang:t('labels.g_vehicle'), 'left')
            end
        else
            exports['qbx-core']:HideText()
        end

        isInsideGarageZone = isPointInside
    end)
end

local function destroyVehiclePlateZone(id)
    if plateZones[id] then
        plateZones[id]:destroy()
        plateZones[id] = nil
    end
end

local function registerVehiclePlateZone(id, plate)
    local coords = plate.coords
    local boxData = plate.boxData
    local plateZone = BoxZone:Create(coords.xyz, boxData.length, boxData.width, {
        name = plateTargetBoxId .. id,
        heading = boxData.heading,
        minZ = coords.z - 1.0,
        maxZ = coords.z + 3.0,
        debugPoly = boxData.debugPoly
    })

    plateZones[id] = plateZone

    plateZone:onPlayerInOut(function (isPointInside)
        if isPointInside and onDuty then
            if plate.AttachedVehicle then
                exports['qbx-core']:DrawText(Lang:t('labels.o_menu'), 'left')
            elseif cache.vehicle then
                exports['qbx-core']:DrawText(Lang:t('labels.work_v'), 'left')
            end
        else
            exports['qbx-core']:HideText()
        end

        isInsideVehiclePlateZone = isPointInside
    end)
end

local function setVehiclePlateZones()
    if #Config.Plates > 0 then
        for i = 1, #Config.Plates do
            local plate = Config.Plates[i]
            registerVehiclePlateZone(i, plate)
        end
    else
        print('No vehicle plates configured')
    end
end

local function setClosestPlate()
    local pos = GetEntityCoords(cache.ped, true)
    local current = nil
    local closestDist = nil

    for i = 1, #Config.Plates do
        local plate = Config.Plates[i]
        local distance = #(pos - plate.coords.xyz)
        if not current or distance < closestDist then
            closestDist = distance
            current = i
        end
    end
    closestPlate = current
end

local function scrapAnim(time)
    time = time / 1000
    lib.requestAnimDict('mp_car_bomb')
    TaskPlayAnim(cache.ped, "mp_car_bomb", "car_bomb_mechanic" ,3.0, 3.0, -1, 16, 0, false, false, false)
    openingDoor = true
    CreateThread(function()
        repeat
            TaskPlayAnim(cache.ped, "mp_car_bomb", "car_bomb_mechanic", 3.0, 3.0, -1, 16, 0, false, false, false)
            Wait(2000)
            time -= 2
            if time <= 0 then
                openingDoor = false
                StopAnimTask(cache.ped, "mp_car_bomb", "car_bomb_mechanic", 1.0)
            end
        until not openingDoor
    end)
end

local function round(num, numDecimalPlaces)
    return tonumber(string.format("%." .. (numDecimalPlaces or 1) .. "f", num))
end

local function sendStatusMessage(statusList)
    if not statusList then return end
    TriggerEvent('chat:addMessage', {
        template = '<div class="chat-message normal"><div class="chat-message-body"><strong>{0}:</strong><br><br> <strong>'.. Config.PartLabels.engine ..' (engine):</strong> {1} <br><strong>'.. Config.PartLabels.body ..' (body):</strong> {2} <br><strong>'.. Config.PartLabels.radiator ..' (radiator):</strong> {3} <br><strong>'.. Config.PartLabels.axle ..' (axle):</strong> {4}<br><strong>'.. Config.PartLabels.brakes ..' (brakes):</strong> {5}<br><strong>'.. Config.PartLabels.clutch ..' (clutch):</strong> {6}<br><strong>'.. Config.PartLabels.fuel ..' (fuel):</strong> {7}</div></div>',
        args = {Lang:t('labels.veh_status'), round(statusList.engine) .. "/" .. Config.MaxStatusValues.engine .. " ("..exports.ox_inventory:Items()['advancedrepairkit'].label..")", round(statusList.body) .. "/" .. Config.MaxStatusValues.body .. " ("..exports.ox_inventory:Items()[Config.RepairCost.body].label..")", round(statusList.radiator) .. "/" .. Config.MaxStatusValues.radiator .. ".0 ("..exports.ox_inventory:Items()[Config.RepairCost.radiator].label..")", round(statusList.axle) .. "/" .. Config.MaxStatusValues.axle .. ".0 ("..exports.ox_inventory:Items()[Config.RepairCost.axle].label..")", round(statusList.brakes) .. "/" .. Config.MaxStatusValues.brakes .. ".0 ("..exports.ox_inventory:Items()[Config.RepairCost.brakes].label..")", round(statusList.clutch) .. "/" .. Config.MaxStatusValues.clutch .. ".0 ("..exports.ox_inventory:Items()[Config.RepairCost.clutch].label..")", round(statusList.fuel) .. "/" .. Config.MaxStatusValues.fuel .. ".0 ("..exports.ox_inventory:Items()[Config.RepairCost.fuel].label..")"}
    })
end

local function unattachVehicle()
    DoScreenFadeOut(150)
    Wait(150)
    local plate = Config.Plates[closestPlate]
    FreezeEntityPosition(plate.AttachedVehicle, false)
    SetEntityCoords(plate.AttachedVehicle, plate.coords.x, plate.coords.y, plate.coords.z, false, false, false, false)
    SetEntityHeading(plate.AttachedVehicle, plate.coords.w)
    TaskWarpPedIntoVehicle(cache.ped, plate.AttachedVehicle, -1)
    Wait(500)
    DoScreenFadeIn(250)
    Config.Plates[closestPlate] = nil
    TriggerServerEvent('qb-vehicletuning:server:SetAttachedVehicle', false, closestPlate)

    destroyVehiclePlateZone(closestPlate)
    registerVehiclePlateZone(closestPlate, plate)
end

local function checkStatus()
    local plate = QBCore.Functions.GetPlate(Config.Plates[closestPlate].AttachedVehicle)
    sendStatusMessage(VehicleStatus[plate])
end

local function repairPart(part)
    TriggerEvent('animations:client:EmoteCommandStart', {"mechanic"})
    if lib.progressBar({
        duration = math.random(5000, 10000),
        label = Lang:t('labels.progress_bar') ..Config.PartLabels[part],
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true,
            mouse = false,
        }
    }) then
        TriggerEvent('animations:client:EmoteCommandStart', {"c"})
        TriggerServerEvent('qb-vehicletuning:server:CheckForItems', part)
        SetTimeout(250, function()
            OpenVehicleStatusMenu()
        end)
    else
        TriggerEvent('animations:client:EmoteCommandStart', {"c"})
        QBCore.Functions.Notify(Lang:t('notifications.rep_canceled'), "error")
    end
end

local function openPartMenu(data)
    local partName = data.name
    local part = data.parts
    local options = {
        {
            title = partName,
            description = Lang:t('parts_menu.repair_op')..exports.ox_inventory:Items()[Config.RepairCostAmount[part].item].label.." "..Config.RepairCostAmount[part].costs.."x",
            onSelect = function()
                repairPart(part)
            end,
        },
    }

    lib.registerContext({
        id = 'part',
        title = Lang:t('parts_menu.menu_header'),
        options = options,
        menu = 'vehicleStatus',
    })

    lib.showContext('part')
end

function OpenVehicleStatusMenu()
    local plate = QBCore.Functions.GetPlate(Config.Plates[closestPlate].AttachedVehicle)
    if not VehicleStatus[plate] then return end

    local options = {}

    for partName, label in pairs(Config.PartLabels) do
        if math.ceil(VehicleStatus[plate][partName]) ~= Config.MaxStatusValues[partName] then
            local percentage = math.ceil(VehicleStatus[plate][partName])
            if percentage > 100 then
                percentage = math.ceil(VehicleStatus[plate][partName]) / 10
            end
            options[#options+1] = {
                title = label,
                description = "Status: " .. percentage .. ".0% / 100.0%",
                onSelect = function()
                    openPartMenu({
                        name = label,
                        parts = partName
                    })
                end,
                arrow = true,
            }
        else
            local percentage = math.ceil(Config.MaxStatusValues[partName])
            if percentage > 100 then
                percentage = math.ceil(Config.MaxStatusValues[partName]) / 10
            end
            options[#options+1] = {
                title = label,
                description = Lang:t('parts_menu.status') .. percentage .. ".0% / 100.0%",
                onSelect = OpenVehicleStatusMenu,
                arrow = true,
            }
        end
    end

    lib.registerContext({
        id = 'vehicleStatus',
        title = 'Status',
        options = options,
    })

    lib.showContext('vehicleStatus')
end

local function resetClosestVehiclePlate()
    destroyVehiclePlateZone(closestPlate)
    registerVehiclePlateZone(closestPlate, Config.Plates[closestPlate])
end

local function spawnListVehicle(model)
    local coords = {
        x = Config.Locations.vehicle.x,
        y = Config.Locations.vehicle.y,
        z = Config.Locations.vehicle.z,
        w = Config.Locations.vehicle.w,
    }

    QBCore.Functions.TriggerCallback('QBCore:Server:SpawnVehicle', function(netId)
        local veh = NetToVeh(netId)
        SetVehicleNumberPlateText(veh, "ACBV"..tostring(math.random(1000, 9999)))
        SetEntityHeading(veh, coords.w)
        SetVehicleFuelLevel(veh, 100.0)
        TaskWarpPedIntoVehicle(cache.ped, veh, -1)
        TriggerEvent("vehiclekeys:client:SetOwner", QBCore.Functions.GetPlate(veh))
        SetVehicleEngineOn(veh, true, true, false)
    end, model, coords, true)
end

-- Events

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    QBCore.Functions.GetPlayerData(function(PlayerData)
        playerJob = PlayerData.job
        if PlayerData.job.onduty then
            if playerJob.type == 'mechanic' then
                TriggerServerEvent("QBCore:ToggleDuty")
            end
        end
    end)
    lib.callback('qb-vehicletuning:server:GetAttachedVehicle', false, function(plates)
        for k, v in pairs(plates) do
            Config.Plates[k].AttachedVehicle = v.AttachedVehicle
        end
    end)

    lib.callback('qb-vehicletuning:server:GetDrivingDistances', false, function(retval)
        DrivingDistance = retval
    end)
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(jobInfo)
    playerJob = jobInfo
    onDuty = playerJob.onduty

    deleteTarget(dutyTargetBoxId)
    deleteTarget(stashTargetBoxId)
    registerDutyTarget()

    if onDuty then
        registerStashTarget()
    end
end)

RegisterNetEvent('QBCore:Client:SetDuty', function(duty)
    onDuty = duty

    deleteTarget(dutyTargetBoxId)
    deleteTarget(stashTargetBoxId)
    registerDutyTarget()

    if onDuty then
        registerStashTarget()
    end
end)

RegisterNetEvent('qb-vehicletuning:client:SetAttachedVehicle', function(veh, key)
    if veh ~= false then
        Config.Plates[key].AttachedVehicle = veh
    else
        Config.Plates[key].AttachedVehicle = nil
    end
end)

RegisterNetEvent('qb-vehicletuning:client:RepaireeePart', function(part)
    local veh = Config.Plates[closestPlate].AttachedVehicle
    local plate = QBCore.Functions.GetPlate(veh)
    if part == "engine" then
        SetVehicleEngineHealth(veh, Config.MaxStatusValues[part])
        TriggerServerEvent("vehiclemod:server:updatePart", plate, "engine", Config.MaxStatusValues[part])
    elseif part == "body" then
        local enhealth = GetVehicleEngineHealth(veh)
        local realFuel = GetVehicleFuelLevel(veh)
        SetVehicleBodyHealth(veh, Config.MaxStatusValues[part])
        TriggerServerEvent("vehiclemod:server:updatePart", plate, "body", Config.MaxStatusValues[part])
        SetVehicleFixed(veh)
        SetVehicleEngineHealth(veh, enhealth)
        if GetVehicleFuelLevel(veh) ~= realFuel then
            SetVehicleFuelLevel(veh, realFuel)
        end
    else
        TriggerServerEvent("vehiclemod:server:updatePart", plate, part, Config.MaxStatusValues[part])
    end
    QBCore.Functions.Notify(Lang:t('notifications.partrep', {value = Config.PartLabels[part]}))
end)

RegisterNetEvent('vehiclemod:client:setVehicleStatus', function(plate, status)
    VehicleStatus[plate] = status
end)

RegisterNetEvent('vehiclemod:client:getVehicleStatus', function()
    if cache.vehicle then
        QBCore.Functions.Notify(Lang:t('notifications.outside'), "error")
        return
    end
    local veh = GetVehiclePedIsIn(cache.ped, true)
    if not veh or veh == 0 then
        QBCore.Functions.Notify(Lang:t('notifications.veh_first'), "error")
        return
    end

    local vehpos = GetEntityCoords(veh)
    local pos = GetEntityCoords(cache.ped)
    if #(pos - vehpos) >= 5.0 then
        QBCore.Functions.Notify(Lang:t('notifications.not_close'), "error")
        return
    end
    if IsThisModelABicycle(GetEntityModel(veh)) then
        QBCore.Functions.Notify(Lang:t('notifications.not_valid'), "error")
        return
    end
    local plate = QBCore.Functions.GetPlate(veh)
    if not VehicleStatus[plate] then
        QBCore.Functions.Notify(Lang:t('notifications.uknown'), "error")
        return
    end

    sendStatusMessage(VehicleStatus[plate])
end)

RegisterNetEvent('vehiclemod:client:fixEverything', function()
    local veh = cache.vehicle
    if not veh then
        QBCore.Functions.Notify(Lang:t('notifications.not_vehicle'), "error")
        return
    end

    if IsThisModelABicycle(GetEntityModel(veh)) or cache.seat ~= -1 then
        QBCore.Functions.Notify(Lang:t('notifications.wrong_seat'), "error")
    end

    local plate = QBCore.Functions.GetPlate(veh)
    TriggerServerEvent("vehiclemod:server:fixEverything", plate)
end)

RegisterNetEvent('vehiclemod:client:setPartLevel', function(part, level)
    local veh = cache.vehicle
    if not veh then
        QBCore.Functions.Notify(Lang:t('notifications.not_vehicle'), "error")
        return
    end

    if IsThisModelABicycle(GetEntityModel(veh)) or cache.seat ~= -1 then
        QBCore.Functions.Notify(Lang:t('notifications.wrong_seat'), "error")
        return
    end

    local plate = QBCore.Functions.GetPlate(veh)
    if part == "engine" then
        SetVehicleEngineHealth(veh, level)
        TriggerServerEvent("vehiclemod:server:updatePart", plate, "engine", GetVehicleEngineHealth(veh))
    elseif part == "body" then
        SetVehicleBodyHealth(veh, level)
        TriggerServerEvent("vehiclemod:server:updatePart", plate, "body", GetVehicleBodyHealth(veh))
    else
        TriggerServerEvent("vehiclemod:server:updatePart", plate, part, level)
    end
end)

RegisterNetEvent('vehiclemod:client:repairPart', function(part, level, needAmount)

    -- FIXME: if ped is in a vehicle then we tell them they aren't in a vehicle? Something is wrong here.
    if cache.vehicle then
        QBCore.Functions.Notify(Lang:t('notifications.not_vehicle'), "error")
        return
    end
    local veh = GetVehiclePedIsIn(cache.ped, true)
    if not veh or veh == 0 then
        QBCore.Functions.Notify(Lang:t('notifications.veh_first'), "error")
        return
    end

    local vehpos = GetEntityCoords(veh)
    local pos = GetEntityCoords(cache.ped)
    if #(pos - vehpos) >= 5.0 then
        QBCore.Functions.Notify(Lang:t('notifications.not_close'), "error")
        return
    end
    if IsThisModelABicycle(GetEntityModel(veh)) then
        QBCore.Functions.Notify(Lang:t('notifications.not_valid'), "error")
        return
    end
    local plate = QBCore.Functions.GetPlate(veh)
    if not VehicleStatus[plate] or not VehicleStatus[plate][part] then
        QBCore.Functions.Notify(Lang:t('notifications.not_part'), "error")
        return
    end

    local lockpickTime = (1000 * level)
    if part == "body" then
        lockpickTime = lockpickTime / 10
    end
    scrapAnim(lockpickTime)
    if lib.progressBar({
        duration = lockpickTime,
        label = Lang:t('notifications.progress_bar'),
        canCancel = true,
        anim = {
            dict = 'mp_car_bomb',
            clip = 'car_bomb_mechanic',
            flag = 16,
        }
    }) then
        openingDoor = false
        ClearPedTasks(cache.ped)
        if part == "body" then
            local enhealth = GetVehicleEngineHealth(veh)
            SetVehicleBodyHealth(veh, GetVehicleBodyHealth(veh) + level)
            SetVehicleFixed(veh)
            SetVehicleEngineHealth(veh, enhealth)
            TriggerServerEvent("vehiclemod:server:updatePart", plate, part, GetVehicleBodyHealth(veh))
            TriggerServerEvent("qb-mechanicjob:server:removePart", part, needAmount)
        elseif part ~= "engine" then
            TriggerServerEvent("vehiclemod:server:updatePart", plate, part, getVehicleStatus(plate, part) + level)
            TriggerServerEvent("qb-mechanicjob:server:removePart", part, level)
        end
    else
        openingDoor = false
        ClearPedTasks(cache.ped)
        QBCore.Functions.Notify(Lang:t('notifications.process_canceled'), "error")
    end
end)

---TODO: replace with ox_inventory stash
AddEventHandler('qb-mechanicjob:client:target:OpenStash', function ()
    TriggerEvent("inventory:client:SetCurrentStash", "mechanicstash")
    TriggerServerEvent("inventory:server:OpenInventory", "stash", "mechanicstash", {
        maxweight = 4000000,
        slots = 500,
    })
end)

-- Threads

local function listenForInteractions()
    local wait = 500
    if playerJob.type ~= 'mechanic' then return wait end
    local veh = cache.vehicle

    if isInsideDutyZone then
        wait = 0
        if IsControlJustPressed(0, 38) then
            TriggerServerEvent("QBCore:ToggleDuty")
        end
    end

    if not onDuty then return wait end

    if isInsideStashZone then
        wait = 0
        if IsControlJustPressed(0, 38) then
            TriggerEvent("qb-mechanicjob:client:target:OpenStash")
        end
    end

    if isInsideGarageZone then
        wait = 0
        if IsControlJustPressed(0, 38) then
            if veh then
                DeleteVehicle(veh)
                exports['qbx-core']:HideText()
            else
                lib.showContext('mechanicVehicles')
                exports['qbx-core']:HideText()
            end
        end
    end

    if isInsideVehiclePlateZone then
        wait = 0
        local attachedVehicle = Config.Plates[closestPlate].AttachedVehicle
        local coords = Config.Plates[closestPlate].coords
        if attachedVehicle then
            if IsControlJustPressed(0, 38) then
                exports['qbx-core']:HideText()
                lib.showContext('lift')
            end
        elseif IsControlJustPressed(0, 38) and veh then
            DoScreenFadeOut(150)
            Wait(150)
            Config.Plates[closestPlate].AttachedVehicle = veh
            SetEntityCoords(veh, coords.x, coords.y, coords.z, false, false, false, false)
            SetEntityHeading(veh, coords.w)
            FreezeEntityPosition(veh, true)
            Wait(500)
            DoScreenFadeIn(150)
            TriggerServerEvent('qb-vehicletuning:server:SetAttachedVehicle', veh, closestPlate)

            destroyVehiclePlateZone(closestPlate)
            registerVehiclePlateZone(closestPlate, Config.Plates[closestPlate])
        end
    end

    return wait
end

local function createBlip()
    local Blip = AddBlipForCoord(Config.Locations.exit.x, Config.Locations.exit.y, Config.Locations.exit.z)
    SetBlipSprite (Blip, 446)
    SetBlipDisplay(Blip, 4)
    SetBlipScale  (Blip, 0.7)
    SetBlipAsShortRange(Blip, true)
    SetBlipColour(Blip, 0)
    SetBlipAlpha(Blip, 0.7)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(Lang:t('labels.job_blip'))
    EndTextCommandSetBlipName(Blip)
end

CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do
        Wait(500)
    end

    createBlip()
    registerGarageZone()
    registerDutyTarget()
    registerStashTarget()
    setVehiclePlateZones()

    while true do
        setClosestPlate()
        local wait = listenForInteractions()
        Wait(wait)
    end
end)

CreateThread(function()
    while true do
        Wait(1000)
        local wait = UpdatePartHealth()
        Wait(wait)
    end
end)


--- STATIC MENUS

local function registerLiftMenu()
    local options = {
        {
            title = Lang:t('lift_menu.header_vehdc'),
            description = Lang:t('lift_menu.desc_vehdc'),
            onSelect = unattachVehicle,
        },
        {
            title = Lang:t('lift_menu.header_stats'),
            description = Lang:t('lift_menu.desc_stats'),
            onSelect = checkStatus,
        },
        {
            title = Lang:t('lift_menu.header_parts'),
            description = Lang:t('lift_menu.desc_parts'),
            arrow = true,
            onSelect = OpenVehicleStatusMenu,
        },
    }
    lib.registerContext({
        id = 'lift',
        title = Lang:t('lift_menu.header_menu'),
        onExit = resetClosestVehiclePlate,
        options = options,
    })
end

local function registerVehicleListMenu()
    local options = {}
    for k,v in pairs(Config.Vehicles) do
        options[#options+1] = {
            title = v,
            description = "Vehicle: "..v.."",
            onSelect = function()
                spawnListVehicle(k)
            end,
        }
    end

    lib.registerContext({
        id = 'mechanicVehicles',
        title = 'Vehicle List',
        options = options,
    })
end

registerLiftMenu()
registerVehicleListMenu()
