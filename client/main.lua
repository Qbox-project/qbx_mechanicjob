local config = require 'config.client'
local sharedConfig = require 'config.shared'

VehicleStatus = {}

local openingDoor = false

-- zone check
local plateZones = {}
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
    if config.useTarget then
        exports.ox_target:removeZone(id)
    else
        if config.targets[id] and config.targets[id].zone then
            config.targets[id].zone:remove()
        end
    end

    config.targets[id] = nil
end

local function registerDutyTarget()
    local coords = sharedConfig.locations.duty
    local boxData = config.targets[dutyTargetBoxId] or {}

    if boxData and boxData.created then
        return
    end

    if QBX.PlayerData.job.type ~= 'mechanic' then
        return
    end

    local label = QBX.PlayerData.job.onduty and Lang:t('labels.sign_off') or Lang:t('labels.sign_in')

    if config.useTarget then
        dutyTargetBoxId = exports.ox_target:addBoxZone({
            coords = coords,
            size = vec3(2.5, 1.5, 1),
            rotation = 338.16,
            debug = config.debugPoly,
            options = {{
                label = label,
                name = dutyTargetBoxId,
                icon = 'fa fa-clipboard',
                distance = 2.0,
                serverEvent = "QBCore:ToggleDuty",
                canInteract = function()
                    return QBX.PlayerData.job.type == 'mechanic'
                end
            }},
        })

        config.targets[dutyTargetBoxId] = {created = true}
    else
        local zone = lib.zones.box({
            coords = coords,
            size = vec3(1.5, 2, 2),
            rotation = 338.16,
            debug = config.debugPoly,
            inside = function()
                if QBX.PlayerData.job.onduty then
                    if IsControlJustPressed(0, 38) then
                        TriggerServerEvent("QBCore:ToggleDuty")
                        Wait(500)
                    end
                end
            end,
            onEnter = function()
                if QBX.PlayerData.job.onduty then
                    lib.showTextUI("[E] " .. label, {position = 'left-center'})
                end
            end,
            onExit = function()
                lib.hideTextUI()
            end,
        })

        config.targets[dutyTargetBoxId] = {created = true, zone = zone}
    end
end

local function registerStashTarget()
    local coords = sharedConfig.locations.stash
    local boxData = config.targets[stashTargetBoxId] or {}

    if boxData and boxData.created then
        return
    end

    if QBX.PlayerData.job.type ~= 'mechanic' then
        return
    end

    if config.useTarget then
        stashTargetBoxId = exports.ox_target:addBoxZone({
            coords = coords,
            size = vec3(1.5, 1.0, 2),
            rotation = 248.41,
            debug = config.debugPoly,
            options = {{
                label = Lang:t('labels.o_stash'),
                name = stashTargetBoxId,
                icon = 'fa fa-archive',
                distance = 2.0,
                event = "qb-mechanicjob:client:target:OpenStash",
                canInteract = function()
                    return QBX.PlayerData.job.onduty and QBX.PlayerData.job.type == 'mechanic'
                end
            }},
        })

        config.targets[stashTargetBoxId] = {created = true}
    else
        local zone = lib.zones.box({
            coords = coords,
            size = vec3(1.5, 1.5, 2),
            rotation = 248.41,
            debug = config.debugPoly,
            inside = function()
                if QBX.PlayerData.job.onduty and QBX.PlayerData.job.type == 'mechanic' then
                    if IsControlJustPressed(0, 38) then
                        TriggerEvent("qb-mechanicjob:client:target:OpenStash")
                        Wait(500)
                    end
                end
            end,
            onEnter = function()
                if QBX.PlayerData.job.onduty and QBX.PlayerData.job.type == 'mechanic' then
                    lib.showTextUI(Lang:t('labels.o_stash'), {position = 'left-center'})
                end
            end,
            onExit = function()
                lib.hideTextUI()
            end,
        })

        config.targets[stashTargetBoxId] = {created = true, zone = zone}
    end
end

local function registerGarageZone()
    local coords = sharedConfig.locations.vehicle
    local veh = cache.vehicle

    lib.zones.box({
        coords = coords.xyz,
        size = vec3(15, 5, 6),
        rotation = 340.0,
        debug = config.debugPoly,
        inside = function()
            if QBX.PlayerData.job.onduty and QBX.PlayerData.job.type == 'mechanic' then
                if IsControlJustPressed(0, 38) then
                    if veh then
                        DeleteVehicle(veh)
                        lib.hideTextUI()
                    else
                        lib.showContext('mechanicVehicles')
                        lib.hideTextUI()
                    end
                    Wait(500)
                end
            end
        end,
        onEnter = function()
            if QBX.PlayerData.job.onduty and QBX.PlayerData.job.type == 'mechanic' then
                local inVehicle = cache.vehicle
                if inVehicle then
                    lib.showTextUI(Lang:t('labels.h_vehicle'), {position = 'left-center'})
                else
                    lib.showTextUI(Lang:t('labels.g_vehicle'), {position = 'left-center'})
                end
            end
        end,
        onExit = function()
            lib.hideTextUI()
        end,
    })
end


local closestPlate = nil

local function destroyVehiclePlateZone(id)
    if plateZones[id] then
        plateZones[id]:remove()
        plateZones[id] = nil
    end
end

local function registerVehiclePlateZone(id, plate)
    local coords = plate.coords
    local boxData = plate.boxData
    closestPlate = id

    local plateZone = lib.zones.box({
        coords = coords.xyz,
        size = vec3(boxData.width, boxData.length, 4),
        rotation = boxData.heading,
        debug = boxData.debugPoly,
        inside = function()
            if QBX.PlayerData.job.onduty then
                local veh = cache.vehicle
                if plate.AttachedVehicle then
                    if IsControlJustPressed(0, 38) then
                        lib.hideTextUI()
                        lib.showContext('lift')
                    end
                elseif IsControlJustPressed(0, 38) and veh then
                    DoScreenFadeOut(150)
                    Wait(150)
                    plate.AttachedVehicle = veh
                    SetEntityCoords(veh, coords.x, coords.y, coords.z, false, false, false, false)
                    SetEntityHeading(veh, coords.w)
                    FreezeEntityPosition(veh, true)
                    Wait(500)
                    DoScreenFadeIn(150)
                    TriggerServerEvent('qb-vehicletuning:server:SetAttachedVehicle', veh, plate)
                    destroyVehiclePlateZone(plate)
                    registerVehiclePlateZone(plate, sharedConfig.plates[plate])
                end
            end
        end,
        onEnter = function()
            if QBX.PlayerData.job.onduty then
                if plate.AttachedVehicle then
                    lib.showTextUI(Lang:t('labels.o_menu'), {position = 'left-center'})
                elseif cache.vehicle then
                    lib.showTextUI(Lang:t('labels.work_v'), {position = 'left-center'})
                end
            end
        end,
        onExit = function()
            lib.hideTextUI()
        end,
    })

    plateZones[id] = plateZone
end

local function setVehiclePlateZones()
    if #sharedConfig.plates > 0 then
        for i = 1, #sharedConfig.plates do
            local plate = sharedConfig.plates[i]
            registerVehiclePlateZone(i, plate)
        end
    else
        print('No vehicle plates configured')
    end
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
    local templateStart = '<div class="chat-message normal"><div class="chat-message-body"><strong>{0}:</strong><br><br> '
    local templateEnd = '</div></div>'
    local templateMiddle = '<strong>'.. config.partLabels.engine ..' (engine):</strong> {1} <br><strong>'.. config.partLabels.body ..' (body):</strong> {2} <br><strong>'.. config.partLabels.radiator ..' (radiator):</strong> {3} <br><strong>'.. config.partLabels.axle ..' (axle):</strong> {4}<br><strong>'.. config.partLabels.brakes ..' (brakes):</strong> {5}<br><strong>'.. config.partLabels.clutch ..' (clutch):</strong> {6}<br><strong>'.. config.partLabels.fuel ..' (fuel):</strong> {7}'
    TriggerEvent('chat:addMessage', {
        template = templateStart .. templateMiddle .. templateEnd,
        args = {Lang:t('labels.veh_status'),
            round(statusList.engine) .. "/" .. sharedConfig.maxStatusValues.engine .. " ("..exports.ox_inventory:Items()['advancedrepairkit'].label..")",
            round(statusList.body) .. "/" .. sharedConfig.maxStatusValues.body .. " ("..exports.ox_inventory:Items()[sharedConfig.repairCost.body].label..")",
            round(statusList.radiator) .. "/" .. sharedConfig.maxStatusValues.radiator .. ".0 ("..exports.ox_inventory:Items()[sharedConfig.repairCost.radiator].label..")",
            round(statusList.axle) .. "/" .. sharedConfig.maxStatusValues.axle .. ".0 ("..exports.ox_inventory:Items()[sharedConfig.repairCost.axle].label..")",
            round(statusList.brakes) .. "/" .. sharedConfig.maxStatusValues.brakes .. ".0 ("..exports.ox_inventory:Items()[sharedConfig.repairCost.brakes].label..")",
            round(statusList.clutch) .. "/" .. sharedConfig.maxStatusValues.clutch .. ".0 ("..exports.ox_inventory:Items()[sharedConfig.repairCost.clutch].label..")",
            round(statusList.fuel) .. "/" .. sharedConfig.maxStatusValues.fuel .. ".0 ("..exports.ox_inventory:Items()[sharedConfig.repairCost.fuel].label..")"
        }
    })
end

local function unattachVehicle()
    DoScreenFadeOut(150)
    Wait(150)
    local plate = sharedConfig.plates[closestPlate]
    FreezeEntityPosition(plate.AttachedVehicle, false)
    SetEntityCoords(plate.AttachedVehicle, plate.coords.x, plate.coords.y, plate.coords.z, false, false, false, false)
    SetEntityHeading(plate.AttachedVehicle, plate.coords.w)
    TaskWarpPedIntoVehicle(cache.ped, plate.AttachedVehicle, -1)
    Wait(500)
    DoScreenFadeIn(250)

    plate.AttachedVehicle = nil
    TriggerServerEvent('qb-vehicletuning:server:SetAttachedVehicle', false, closestPlate)

    destroyVehiclePlateZone(closestPlate)
    registerVehiclePlateZone(closestPlate, plate)
end

local function checkStatus()
    local plate = GetPlate(sharedConfig.plates[closestPlate].AttachedVehicle)
    sendStatusMessage(VehicleStatus[plate])
end

local function repairPart(part)
    exports.scully_emotemenu:playEmoteByCommand('mechanic')
    if lib.progressBar({
        duration = math.random(5000, 10000),
        label = Lang:t('labels.progress_bar') .. string.lower(config.partLabels[part]),
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true,
            mouse = false,
        }
    }) then
        exports.scully_emotemenu:cancelEmote()
        TriggerServerEvent('qb-vehicletuning:server:CheckForItems', part)
        SetTimeout(250, function()
            OpenVehicleStatusMenu()
        end)
    else
        exports.scully_emotemenu:cancelEmote()
        exports.qbx_core:Notify(Lang:t('notifications.rep_canceled'), "error")
    end
end

local function openPartMenu(data)
    local partName = data.name
    local part = data.parts
    local options = {
        {
            title = partName,
            description = Lang:t('parts_menu.repair_op')..exports.ox_inventory:Items()[sharedConfig.repairCostAmount[part].item].label.." "..sharedConfig.repairCostAmount[part].costs.."x",
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
    local plate = GetPlate(sharedConfig.plates[closestPlate].AttachedVehicle)
    if not VehicleStatus[plate] then return end

    local options = {}

    for partName, label in pairs(config.partLabels) do
        if math.ceil(VehicleStatus[plate][partName]) ~= sharedConfig.maxStatusValues[partName] then
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
            local percentage = math.ceil(sharedConfig.maxStatusValues[partName])
            if percentage > 100 then
                percentage = math.ceil(sharedConfig.maxStatusValues[partName]) / 10
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
        title = Lang:t('labels.status'),
        options = options,
    })

    lib.showContext('vehicleStatus')
end

local function resetClosestVehiclePlate()
    destroyVehiclePlateZone(closestPlate)
    registerVehiclePlateZone(closestPlate, sharedConfig.plates[closestPlate])
end

local function spawnListVehicle(model)
    local coords = {
        x = sharedConfig.locations.vehicle.x,
        y = sharedConfig.locations.vehicle.y,
        z = sharedConfig.locations.vehicle.z,
        w = sharedConfig.locations.vehicle.w,
    }

    local netId = lib.callback.await('qbx_mechanicjob:server:spawnVehicle', false, model, coords, true)
    local timeout = 100
    while not NetworkDoesEntityExistWithNetworkId(netId) and timeout > 0 do
        Wait(10)
        timeout -= 1
    end
    local veh = NetworkGetEntityFromNetworkId(netId)
    SetVehicleNumberPlateText(veh, "MECH"..tostring(math.random(1000, 9999)))
    SetEntityHeading(veh, coords.w)
    SetVehicleFuelLevel(veh, 100.0)
    TaskWarpPedIntoVehicle(cache.ped, veh, -1)
    TriggerEvent("vehiclekeys:client:SetOwner", GetPlate(veh))
    SetVehicleEngineOn(veh, true, true, false)
end

local function createBlip()
    local blip = AddBlipForCoord(sharedConfig.locations.exit.x, sharedConfig.locations.exit.y, sharedConfig.locations.exit.z)
    SetBlipSprite(blip, 446)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.7)
    SetBlipColour(blip, 0)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Lang:t('labels.job_blip'))
    EndTextCommandSetBlipName(blip)
end

-- Events

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    createBlip()
    registerGarageZone()
    registerDutyTarget()
    registerStashTarget()
    setVehiclePlateZones()
    if QBX.PlayerData.job.onduty and QBX.PlayerData.type == 'mechanic' then
        TriggerServerEvent("QBCore:ToggleDuty")
    end

    lib.callback('qb-vehicletuning:server:GetAttachedVehicle', false, function(plates)
        for k, v in pairs(plates) do
            sharedConfig.plates[k].AttachedVehicle = v.AttachedVehicle
        end
    end)

    lib.callback('qb-vehicletuning:server:GetDrivingDistances', false, function(retval)
        DrivingDistance = retval
    end)
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function()
    deleteTarget(dutyTargetBoxId)
    deleteTarget(stashTargetBoxId)

    if QBX.PlayerData.type == 'mechanic' then
        registerDutyTarget()
        if QBX.PlayerData.job.onduty then
            registerStashTarget()
        end
    end
end)

RegisterNetEvent('QBCore:Client:SetDuty', function()
    deleteTarget(dutyTargetBoxId)
    deleteTarget(stashTargetBoxId)

    if QBX.PlayerData.type == 'mechanic' then
        registerDutyTarget()
        if QBX.PlayerData.job.onduty then
            registerStashTarget()
        end
    end
end)

RegisterNetEvent('qb-vehicletuning:client:SetAttachedVehicle', function(veh, key)
    if veh ~= false then
        sharedConfig.plates[key].AttachedVehicle = veh
    else
        sharedConfig.plates[key].AttachedVehicle = nil
    end
end)

RegisterNetEvent('qb-vehicletuning:client:RepaireeePart', function(part)
    local veh = sharedConfig.plates[closestPlate].AttachedVehicle
    local plate = GetPlate(veh)
    if part == "engine" then
        SetVehicleEngineHealth(veh, sharedConfig.maxStatusValues[part])
        TriggerServerEvent("vehiclemod:server:updatePart", plate, "engine", sharedConfig.maxStatusValues[part])
    elseif part == "body" then
        local enhealth = GetVehicleEngineHealth(veh)
        local realFuel = GetVehicleFuelLevel(veh)
        SetVehicleBodyHealth(veh, sharedConfig.maxStatusValues[part])
        TriggerServerEvent("vehiclemod:server:updatePart", plate, "body", sharedConfig.maxStatusValues[part])
        SetVehicleFixed(veh)
        SetVehicleEngineHealth(veh, enhealth)
        if GetVehicleFuelLevel(veh) ~= realFuel then
            SetVehicleFuelLevel(veh, realFuel)
        end
    else
        TriggerServerEvent("vehiclemod:server:updatePart", plate, part, sharedConfig.maxStatusValues[part])
    end
    exports.qbx_core:Notify(Lang:t('notifications.partrep', {value = config.partLabels[part]}))
end)

RegisterNetEvent('vehiclemod:client:setVehicleStatus', function(plate, status)
    VehicleStatus[plate] = status
end)

RegisterNetEvent('vehiclemod:client:getVehicleStatus', function()
    if cache.vehicle then
        exports.qbx_core:Notify(Lang:t('notifications.outside'), "error")
        return
    end
    local veh = GetVehiclePedIsIn(cache.ped, true)
    if not veh or veh == 0 then
        exports.qbx_core:Notify(Lang:t('notifications.veh_first'), "error")
        return
    end

    local vehpos = GetEntityCoords(veh)
    local pos = GetEntityCoords(cache.ped)
    if #(pos - vehpos) >= 5.0 then
        exports.qbx_core:Notify(Lang:t('notifications.not_close'), "error")
        return
    end
    if IsThisModelABicycle(GetEntityModel(veh)) then
        exports.qbx_core:Notify(Lang:t('notifications.not_valid'), "error")
        return
    end
    local plate = GetPlate(veh)
    if not VehicleStatus[plate] then
        exports.qbx_core:Notify(Lang:t('notifications.uknown'), "error")
        return
    end

    sendStatusMessage(VehicleStatus[plate])
end)

RegisterNetEvent('vehiclemod:client:fixEverything', function()
    local veh = cache.vehicle
    if not veh then
        exports.qbx_core:Notify(Lang:t('notifications.not_vehicle'), "error")
        return
    end

    if IsThisModelABicycle(GetEntityModel(veh)) or cache.seat ~= -1 then
        exports.qbx_core:Notify(Lang:t('notifications.wrong_seat'), "error")
    end

    local plate = GetPlate(veh)
    TriggerServerEvent("vehiclemod:server:fixEverything", plate)
end)

RegisterNetEvent('vehiclemod:client:setPartLevel', function(part, level)
    local veh = cache.vehicle
    if not veh then
        exports.qbx_core:Notify(Lang:t('notifications.not_vehicle'), "error")
        return
    end

    if IsThisModelABicycle(GetEntityModel(veh)) or cache.seat ~= -1 then
        exports.qbx_core:Notify(Lang:t('notifications.wrong_seat'), "error")
        return
    end

    local plate = GetPlate(veh)
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
        exports.qbx_core:Notify(Lang:t('notifications.not_vehicle'), "error")
        return
    end
    local veh = GetVehiclePedIsIn(cache.ped, true)
    if not veh or veh == 0 then
        exports.qbx_core:Notify(Lang:t('notifications.veh_first'), "error")
        return
    end

    local vehpos = GetEntityCoords(veh)
    local pos = GetEntityCoords(cache.ped)
    if #(pos - vehpos) >= 5.0 then
        exports.qbx_core:Notify(Lang:t('notifications.not_close'), "error")
        return
    end
    if IsThisModelABicycle(GetEntityModel(veh)) then
        exports.qbx_core:Notify(Lang:t('notifications.not_valid'), "error")
        return
    end
    local plate = GetPlate(veh)
    if not VehicleStatus[plate] or not VehicleStatus[plate][part] then
        exports.qbx_core:Notify(Lang:t('notifications.not_part'), "error")
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
        exports.qbx_core:Notify(Lang:t('notifications.process_canceled'), "error")
    end
end)

AddEventHandler('qb-mechanicjob:client:target:OpenStash', function ()
    exports.ox_inventory:openInventory('stash', {id='mechanicstash'})
end)

-- Threads

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
    for k,v in pairs(config.vehicles) do
        options[#options+1] = {
            title = v,
            description = Lang:t('labels.vehicle_title', {value = v}),
            onSelect = function()
                spawnListVehicle(k)
            end,
        }
    end

    lib.registerContext({
        id = 'mechanicVehicles',
        title = Lang:t('labels.vehicle_list'),
        options = options,
    })
end

registerLiftMenu()
registerVehicleListMenu()
