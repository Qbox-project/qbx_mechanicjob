QBCore = exports['qb-core']:GetCoreObject()
VehicleStatus = {}
local Targets = {}

local ClosestPlate = nil
local PlayerJob = {}
local onDuty = false
local effectTimer = 0
local openingDoor = false

-- zone check
local isInsideDutyZone = false
local isInsideStashZone = false
local isInsideGarageZone = false
local isInsideVehiclePlateZone = false
local plateZones = {}
local dutyTargetBoxID = 'dutyTarget'
local stashTargetBoxID = 'stashTarget'

-- Exports
local function GetVehicleStatusList(plate)
    local retval = nil

    if VehicleStatus[plate] then
        retval = VehicleStatus[plate]
    end

    return retval
end
exports('GetVehicleStatusList', GetVehicleStatusList)

local function GetVehicleStatus(plate, part)
    local retval = nil

    if VehicleStatus[plate] then
        retval = VehicleStatus[plate][part]
    end

    return retval
end
exports('GetVehicleStatus', GetVehicleStatus)

local function SetVehicleStatus(plate, part, level)
    TriggerServerEvent("vehiclemod:server:updatePart", plate, part, level)
end
exports('SetVehicleStatus', SetVehicleStatus)


-- Functions
local function DeleteTarget(id)
    if Config.UseTarget then
        if Targets[id] and Targets[id].zone then
            exports.ox_target:removeZone(Targets[id].zone)
        end
    else
        if Targets[id] and Targets[id].zone then
            Targets[id].zone:remove()
        end
    end

    Targets[id] = nil
end

local function RegisterDutyTarget()
    local dutyData = Config.Locations['duty']
    local boxData = Targets[dutyTargetBoxID] or {}

    if boxData and boxData.created then
        return
    end

    if PlayerJob.type ~= 'mechanic' then
        return
    end

    local label = Lang:t('labels.sign_in')

    if onDuty then
        label = Lang:t('labels.sign_off')
    end

    if Config.UseTarget then
        local zone = exports.ox_target:addBoxZone({
            coords = dutyData.coords,
            size = dutyData.size,
            rotation = dutyData.rotation,
            options = {
                {
                    name = 'qb-mechanicjob:duty',
                    serverEvent = 'QBCore:ToggleDuty',
                    icon = 'fa-solid fa-cube',
                    label = label,
                    distance = 2.0
                }
            }
        })

        Targets[dutyTargetBoxID] = {
            created = true,
            zone = zone
        }
    else
        local zone = lib.zones.box({
            coords = dutyData.coords,
            size = dutyData.size,
            rotation = dutyData.rotation,
            onEnter = function(_)
                lib.showTextUI("[E] - " .. label)

                isInsideDutyZone = true
            end,
            onExit = function(_)
                lib.hideTextUI()

                isInsideDutyZone = false
            end
        })

        Targets[dutyTargetBoxID] = {
            created = true,
            zone = zone
        }
    end
end

local function RegisterStashTarget()
    local stashData = Config.Locations['stash']
    local boxData = Targets[stashTargetBoxID] or {}

    if boxData and boxData.created then
        return
    end

    if PlayerJob.type ~= 'mechanic' then
        return
    end

    if Config.UseTarget then
        local zone = exports.ox_target:addBoxZone({
            coords = stashData.coords,
            size = stashData.size,
            rotation = stashData.rotation,
            options = {
                {
                    name = 'qb-mechanicjob:stash',
                    event = 'qb-mechanicjob:client:target:OpenStash',
                    icon = 'fa-solid fa-cube',
                    label = Lang:t('labels.o_stash'),
                    distance = 2.0
                }
            }
        })

        Targets[stashTargetBoxID] = {
            created = true,
            zone = zone
        }
    else
        local zone = lib.zones.box({
            coords = stashData.coords,
            size = stashData.size,
            rotation = stashData.rotation,
            onEnter = function(_)
                lib.showTextUI(Lang:t('labels.o_stash'))

                isInsideStashZone = true
            end,
            onExit = function(_)
                lib.hideTextUI()

                isInsideStashZone = false
            end
        })

        Targets[stashTargetBoxID] = {
            created = true,
            zone = zone
        }
    end
end

local function RegisterGarageZone()
    local coords = Config.Locations['vehicle']

    lib.zones.box({
        coords = vec3(coords.x, coords.y, coords.z),
        size = vec3(5, 1.5, 15),
        rotation = 340.0,
        onEnter = function(_)
            if onDuty then
                if cache.vehicle then
                    lib.showTextUI(Lang:t('labels.h_vehicle'))
                else
                    lib.showTextUI(Lang:t('labels.g_vehicle'))
                end
            end

            isInsideGarageZone = true
        end,
        onExit = function(_)
            if onDuty then
                lib.hideTextUI()
            end

            isInsideGarageZone = false
        end
    })
end

function DestroyVehiclePlateZone(id)
    if plateZones[id] then
        plateZones[id]:remove()
        plateZones[id] = nil
    end
end

function RegisterVehiclePlateZone(id, plate)
    plateZones[id] = lib.zones.box({
        coords = plate.zone.coords,
        size = plate.zone.size,
        rotation = plate.zone.rotation,
        onEnter = function(_)
            if onDuty then
                if plate.attachedVehicle then
                    lib.showTextUI(Lang:t('labels.o_menu'))
                else
                    if IsPedInAnyVehicle(cache.ped) then
                        lib.showTextUI(Lang:t('labels.work_v'))
                    end
                end
            end

            isInsideVehiclePlateZone = true
        end,
        onExit = function(_)
            if onDuty then
                lib.hideTextUI()
            end

            isInsideVehiclePlateZone = false
        end
    })
end

local function SetVehiclePlateZones()
    if Config.Plates and next(Config.Plates) then
        for id, plate in pairs(Config.Plates) do
            RegisterVehiclePlateZone(id, plate)
        end
    else
        print('No vehicle plates configured')
    end
end

local function SetClosestPlate()
    local pos = GetEntityCoords(cache.ped, true)
    local current = nil
    local dist = nil

    for id, data in pairs(Config.Plates) do
        if current then
            if #(pos - data.zone.coords) < dist then
                current = id
                dist = #(pos - data.zone.coords)
            end
        else
            dist = #(pos - data.zone.coords)
            current = id
        end
    end

    ClosestPlate = current
end

local function ScrapAnim(time)
    time = time / 1000

    lib.requestAnimDict("mp_car_bomb")

    TaskPlayAnim(cache.ped, "mp_car_bomb", "car_bomb_mechanic" ,3.0, 3.0, -1, 16, 0, false, false, false)

    openingDoor = true

    CreateThread(function()
        while openingDoor do
            TaskPlayAnim(cache.ped, "mp_car_bomb", "car_bomb_mechanic", 3.0, 3.0, -1, 16, 0, 0, 0, 0)

            Wait(2000)

            time = time - 2

            if time <= 0 then
                openingDoor = false

                StopAnimTask(cache.ped, "mp_car_bomb", "car_bomb_mechanic", 1.0)
                RemoveAnimDict("mp_car_bomb")
            end
        end
    end)
end

local function ApplyEffects(vehicle)
    local plate = QBCore.Functions.GetPlate(vehicle)

    if GetVehicleClass(vehicle) ~= 13 and GetVehicleClass(vehicle) ~= 21 and GetVehicleClass(vehicle) ~= 16 and GetVehicleClass(vehicle) ~= 15 and GetVehicleClass(vehicle) ~= 14 then
        if VehicleStatus[plate] then
            local chance = math.random(1, 100)

            if VehicleStatus[plate]["radiator"] <= 80 and (chance >= 1 and chance <= 20) then
                local engineHealth = GetVehicleEngineHealth(vehicle)

                if VehicleStatus[plate]["radiator"] <= 80 and VehicleStatus[plate]["radiator"] >= 60 then
                    SetVehicleEngineHealth(vehicle, engineHealth - math.random(10, 15))
                elseif VehicleStatus[plate]["radiator"] <= 59 and VehicleStatus[plate]["radiator"] >= 40 then
                    SetVehicleEngineHealth(vehicle, engineHealth - math.random(15, 20))
                elseif VehicleStatus[plate]["radiator"] <= 39 and VehicleStatus[plate]["radiator"] >= 20 then
                    SetVehicleEngineHealth(vehicle, engineHealth - math.random(20, 30))
                elseif VehicleStatus[plate]["radiator"] <= 19 and VehicleStatus[plate]["radiator"] >= 6 then
                    SetVehicleEngineHealth(vehicle, engineHealth - math.random(30, 40))
                else
                    SetVehicleEngineHealth(vehicle, engineHealth - math.random(40, 50))
                end
            end

            if VehicleStatus[plate]["axle"] <= 80 and (chance >= 21 and chance <= 40) then
                if VehicleStatus[plate]["axle"] <= 80 and VehicleStatus[plate]["axle"] >= 60 then
                    for i = 0, 360 do
                        SetVehicleSteeringScale(vehicle, i)

                        Wait(0)
                    end
                elseif VehicleStatus[plate]["axle"] <= 59 and VehicleStatus[plate]["axle"] >= 40 then
                    for i = 0, 360 do
                        Wait(10)

                        SetVehicleSteeringScale(vehicle, i)
                    end
                elseif VehicleStatus[plate]["axle"] <= 39 and VehicleStatus[plate]["axle"] >= 20 then
                    for i = 0, 360 do
                        Wait(15)
                        SetVehicleSteeringScale(vehicle,i)
                    end
                elseif VehicleStatus[plate]["axle"] <= 19 and VehicleStatus[plate]["axle"] >= 6 then
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

            if VehicleStatus[plate]["brakes"] <= 80 and (chance >= 41 and chance <= 60) then
                if VehicleStatus[plate]["brakes"] <= 80 and VehicleStatus[plate]["brakes"] >= 60 then
                    SetVehicleHandbrake(vehicle, true)
                    Wait(1000)
                    SetVehicleHandbrake(vehicle, false)
                elseif VehicleStatus[plate]["brakes"] <= 59 and VehicleStatus[plate]["brakes"] >= 40 then
                    SetVehicleHandbrake(vehicle, true)
                    Wait(3000)
                    SetVehicleHandbrake(vehicle, false)
                elseif VehicleStatus[plate]["brakes"] <= 39 and VehicleStatus[plate]["brakes"] >= 20 then
                    SetVehicleHandbrake(vehicle, true)
                    Wait(5000)
                    SetVehicleHandbrake(vehicle, false)
                elseif VehicleStatus[plate]["brakes"] <= 19 and VehicleStatus[plate]["brakes"] >= 6 then
                    SetVehicleHandbrake(vehicle, true)
                    Wait(7000)
                    SetVehicleHandbrake(vehicle, false)
                else
                    SetVehicleHandbrake(vehicle, true)
                    Wait(9000)
                    SetVehicleHandbrake(vehicle, false)
                end
            end

            if VehicleStatus[plate]["clutch"] <= 80 and (chance >= 61 and chance <= 80) then
                if VehicleStatus[plate]["clutch"] <= 80 and VehicleStatus[plate]["clutch"] >= 60 then
                    SetVehicleHandbrake(vehicle, true)
                    SetVehicleEngineOn(vehicle,0,0,1)
                    SetVehicleUndriveable(vehicle,true)
                    Wait(50)
                    SetVehicleEngineOn(vehicle,1,0,1)
                    SetVehicleUndriveable(vehicle,false)
                    for i=1,360 do
                        SetVehicleSteeringScale(vehicle, i)
                        Wait(0)
                    end
                    Wait(500)
                    SetVehicleHandbrake(vehicle, false)
                elseif VehicleStatus[plate]["clutch"] <= 59 and VehicleStatus[plate]["clutch"] >= 40 then
                    SetVehicleHandbrake(vehicle, true)
                    SetVehicleEngineOn(vehicle,0,0,1)
                    SetVehicleUndriveable(vehicle,true)
                    Wait(100)
                    SetVehicleEngineOn(vehicle,1,0,1)
                    SetVehicleUndriveable(vehicle,false)
                    for i=1,360 do
                        SetVehicleSteeringScale(vehicle, i)
                        Wait(0)
                    end
                    Wait(750)
                    SetVehicleHandbrake(vehicle, false)
                elseif VehicleStatus[plate]["clutch"] <= 39 and VehicleStatus[plate]["clutch"] >= 20 then
                    SetVehicleHandbrake(vehicle, true)
                    SetVehicleEngineOn(vehicle,0,0,1)
                    SetVehicleUndriveable(vehicle,true)
                    Wait(150)
                    SetVehicleEngineOn(vehicle,1,0,1)
                    SetVehicleUndriveable(vehicle,false)
                    for i=1,360 do
                        SetVehicleSteeringScale(vehicle, i)
                        Wait(0)
                    end
                    Wait(1000)
                    SetVehicleHandbrake(vehicle, false)
                elseif VehicleStatus[plate]["clutch"] <= 19 and VehicleStatus[plate]["clutch"] >= 6 then
                    SetVehicleHandbrake(vehicle, true)
                    SetVehicleEngineOn(vehicle,0,0,1)
                    SetVehicleUndriveable(vehicle,true)
                    Wait(200)
                    SetVehicleEngineOn(vehicle,1,0,1)
                    SetVehicleUndriveable(vehicle,false)
                    for i=1,360 do
                        SetVehicleSteeringScale(vehicle, i)
                        Wait(0)
                    end
                    Wait(1250)
                    SetVehicleHandbrake(vehicle, false)
                else
                    SetVehicleHandbrake(vehicle, true)
                    SetVehicleEngineOn(vehicle,0,0,1)
                    SetVehicleUndriveable(vehicle,true)
                    Wait(250)
                    SetVehicleEngineOn(vehicle,1,0,1)
                    SetVehicleUndriveable(vehicle,false)
                    for i=1,360 do
                        SetVehicleSteeringScale(vehicle, i)
                        Wait(0)
                    end
                    Wait(1500)
                    SetVehicleHandbrake(vehicle, false)
                end
            end

            if VehicleStatus[plate]["fuel"] <= 80 and (chance >= 81 and chance <= 100) then
                local fuel = GetVehicleFuelLevel(vehicle)
                if VehicleStatus[plate]["fuel"] <= 80 and VehicleStatus[plate]["fuel"] >= 60 then
                    SetVehicleFuelLevel(vehicle, fuel - 2.0)
                elseif VehicleStatus[plate]["fuel"] <= 59 and VehicleStatus[plate]["fuel"] >= 40 then
                    SetVehicleFuelLevel(vehicle, fuel - 4.0)
                elseif VehicleStatus[plate]["fuel"] <= 39 and VehicleStatus[plate]["fuel"] >= 20 then
                    SetVehicleFuelLevel(vehicle, fuel - 6.0)
                elseif VehicleStatus[plate]["fuel"] <= 19 and VehicleStatus[plate]["fuel"] >= 6 then
                    SetVehicleFuelLevel(vehicle, fuel - 8.0)
                else
                    SetVehicleFuelLevel(vehicle, fuel - 10.0)
                end
            end
        end
    end
end

local function round(num, numDecimalPlaces)
    return tonumber(string.format("%." .. (numDecimalPlaces or 1) .. "f", num))
end

local function SendStatusMessage(statusList)
    if not statusList then
        return
    end

    local options = {}

    for _, v in pairs(Config.Parts) do
        options[#options + 1] = {
            title = v.label,
            description = round(statusList["engine"]) .. "/" .. v.maxValue,
            metadata = {
                {label = 'Item', value = QBCore.Shared.Items[v.repair.item].label},
                {label = 'Cost', value = v.repair.cost}
            }
        }
    end

    lib.registerContext({
        id = 'open_mechanicStatus',
        title = 'Status',
        options = options
    })
    lib.showContext('open_mechanicStatus')
end

local function OpenMenu()
    lib.registerContext({
        id = 'open_mechanicLiftMenu',
        title = Lang:t('lift_menu.header_menu'),
        options = {
            {
                title = Lang:t('lift_menu.header_vehdc'),
                icon = "fa-solid fa-square",
                description = Lang:t('lift_menu.desc_vehdc'),
                event = "qb-mechanicjob:client:UnattachVehicle"
            },
            {
                title = Lang:t('lift_menu.header_stats'),
                icon = "fa-solid fa-square",
                description = Lang:t('lift_menu.desc_stats'),
                event = "qb-mechanicjob:client:CheckStatus",
                args = {
                    number = 1
                }
            },
            {
                title = Lang:t('lift_menu.header_parts'),
                icon = "fa-solid fa-square",
                description = Lang:t('lift_menu.desc_parts'),
                event = "qb-mechanicjob:client:PartsMenu",
                args = {
                    number = 1
                }
            }
        }
    })
    lib.showContext('open_mechanicLiftMenu')
end

local function PartsMenu()
    local plate = QBCore.Functions.GetPlate(Config.Plates[ClosestPlate].attachedVehicle)

    if VehicleStatus[plate] then
        local vehicleMenu = {}

        for k, v in pairs(Config.Parts) do
            if math.ceil(VehicleStatus[plate][k]) ~= v.maxValue then
                local percentage = math.ceil(VehicleStatus[plate][k])

                if percentage > 100 then
                    percentage = math.ceil(VehicleStatus[plate][k]) / 10
                end

                vehicleMenu[#vehicleMenu + 1] = {
                    title = v.label,
                    description = "Status: " .. percentage .. ".0% / 100.0%",
                    event = "qb-mechanicjob:client:PartMenu",
                    args = {
                        name = v.label,
                        parts = k
                    }
                }
            else
                local percentage = math.ceil(v.maxValue)

                if percentage > 100 then
                    percentage = math.ceil(v.maxValue) / 10
                end

                vehicleMenu[#vehicleMenu + 1] = {
                    title = v.label,
                    description = Lang:t('parts_menu.status') .. percentage .. ".0% / 100.0%",
                    event = "qb-mechanicjob:client:NoDamage"
                }
            end
        end

        lib.registerContext({
            id = 'open_mechanicParts',
            title = "Status",
            options = vehicleMenu
        })
        lib.showContext('open_mechanicParts')
    end
end

local function PartMenu(data)
    local part = data.parts

    lib.registerContext({
        id = 'open_mechanicPartMenu',
        title = Lang:t('parts_menu.menu_header'),
        options = {
            {
                title = data.name,
                icon = "fa-solid fa-screwdriver-wrench",
                description = Lang:t('parts_menu.repair_op') .. QBCore.Shared.Items[Config.Parts[part].repair.item].label .. " " .. Config.Parts[part].repair.cost .. "x",
                event = "qb-mechanicjob:client:RepairPart",
                args = {
                    part = part
                }
            },
            {
                title = Lang:t('parts_menu.b_menu'),
                icon = "fa-solid fa-arrow-left",
                description = Lang:t('parts_menu.d_menu'),
                event = "qb-mechanicjob:client:PartsMenu"
            }
        }
    })
    lib.showContext('open_mechanicPartMenu')
end

local function NoDamage()
    lib.registerContext({
        id = 'open_mechanicNoDamage',
        title = Lang:t('nodamage_menu.header'),
        options = {
            {
                title = Lang:t('nodamage_menu.bh_menu'),
                icon = "fa-solid fa-screwdriver-wrench",
                description = Lang:t('nodamage_menu.bd_menu'),
                event = "qb-mechanicjob:client:PartsMenu"
            }
        }
    })
    lib.showContext('open_mechanicNoDamage')
end

local function UnattachVehicle()
    DoScreenFadeOut(150)
    Wait(150)

    FreezeEntityPosition(Config.Plates[ClosestPlate].attachedVehicle, false)
    SetEntityCoords(Config.Plates[ClosestPlate].attachedVehicle, Config.Plates[ClosestPlate].zone.coords.x, Config.Plates[ClosestPlate].zone.coords.y, Config.Plates[ClosestPlate].zone.coords.z)
    SetEntityHeading(Config.Plates[ClosestPlate].attachedVehicle, Config.Plates[ClosestPlate].heading)
    TaskWarpPedIntoVehicle(cache.ped, Config.Plates[ClosestPlate].attachedVehicle, -1)

    Wait(500)
    DoScreenFadeIn(250)

    Config.Plates[ClosestPlate].attachedVehicle = nil

    TriggerServerEvent('qb-vehicletuning:server:SetAttachedVehicle', false, ClosestPlate)

    DestroyVehiclePlateZone(ClosestPlate)
    RegisterVehiclePlateZone(ClosestPlate, Config.Plates[ClosestPlate])
end

local function SpawnListVehicle(model)
    QBCore.Functions.TriggerCallback('QBCore:Server:SpawnVehicle', function(netId)
        local veh = NetToVeh(netId)

        SetVehicleNumberPlateText(veh, "MECH" .. tostring(math.random(1000, 9999)))
        SetEntityHeading(veh, Config.Locations["vehicle"].w)
        SetVehicleFuelLevel(veh, 100.0)
        TaskWarpPedIntoVehicle(cache.ped, veh, -1)

        TriggerEvent("vehiclekeys:client:SetOwner", QBCore.Functions.GetPlate(veh))

        SetVehicleEngineOn(veh, true, true)
    end, model, Config.Locations["vehicle"], true)
end

local function VehicleList()
    local vehicleMenu = {}

    for k, v in pairs(Config.Vehicles) do
        vehicleMenu[#vehicleMenu + 1] = {
            title = v,
            event = "qb-mechanicjob:client:SpawnListVehicle",
            args = {
                headername = v,
                spawnName = k
            }
        }
    end

    lib.registerContext({
        id = 'open_mechanicVehicleList',
        title = "Vehicle List",
        options = vehicleMenu
    })
    lib.showContext('open_mechanicVehicleList')
end

local function CheckStatus()
    local plate = QBCore.Functions.GetPlate(Config.Plates[ClosestPlate].attachedVehicle)

    SendStatusMessage(VehicleStatus[plate])
end

local function RepairPart(part)
    local PartData = Config.RepairCostAmount[part]
    local count = exports.ox_inventory:Search('count', PartData.item)

    if count >= PartData.costs then
        TriggerEvent('animations:client:EmoteCommandStart', {"mechanic"})

        QBCore.Functions.Progressbar("repair_part", Lang:t('labels.progress_bar') .. Config.Parts[part].label, math.random(5000, 10000), false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true
        }, {}, {}, {}, function() -- Done
            TriggerEvent('animations:client:EmoteCommandStart', {"c"})
            TriggerEvent('qb-vehicletuning:client:RepaireeePart', part)

            SetTimeout(250, function()
                PartsMenu()
            end)
        end, function()
            QBCore.Functions.Notify(Lang:t('notifications.rep_canceled'), "error")
        end)
    else
        QBCore.Functions.Notify(Lang:t('notifications.not_materials'), 'error')
    end
end

-- Events
RegisterNetEvent("qb-mechanicjob:client:UnattachVehicle", function()
    UnattachVehicle()
end)

RegisterNetEvent("qb-mechanicjob:client:PartsMenu", function()
    PartsMenu()
end)

RegisterNetEvent("qb-mechanicjob:client:PartMenu", function(data)
    PartMenu(data)
end)

RegisterNetEvent("qb-mechanicjob:client:NoDamage", function()
    NoDamage()
end)

RegisterNetEvent("qb-mechanicjob:client:CheckStatus", function()
    CheckStatus()
end)

RegisterNetEvent("qb-mechanicjob:client:SpawnListVehicle", function(data)
    local vehicleSpawnName = data.spawnName

    SpawnListVehicle(vehicleSpawnName)
end)

RegisterNetEvent("qb-mechanicjob:client:RepairPart", function(data)
    local partData = data.part

    RepairPart(partData)
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    QBCore.Functions.GetPlayerData(function(PlayerData)
        PlayerJob = PlayerData.job

        if PlayerData.job.onduty then
            if PlayerJob.type == 'mechanic' then
                TriggerServerEvent("QBCore:ToggleDuty")
            end
        end
    end)

    QBCore.Functions.TriggerCallback('qb-vehicletuning:server:GetAttachedVehicle', function(plates)
        for k, v in pairs(plates) do
            Config.Plates[k].attachedVehicle = v.attachedVehicle
        end
    end)
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerJob = JobInfo
    onDuty = PlayerJob.onduty

    DeleteTarget(dutyTargetBoxID)
    DeleteTarget(stashTargetBoxID)
    RegisterDutyTarget()

    if onDuty then
        RegisterStashTarget()
    end
end)

RegisterNetEvent('QBCore:Client:SetDuty', function(duty)
    onDuty = duty

    DeleteTarget(dutyTargetBoxID)
    DeleteTarget(stashTargetBoxID)
    RegisterDutyTarget()

    if onDuty then
        RegisterStashTarget()
    end
end)

RegisterNetEvent('qb-vehicletuning:client:SetAttachedVehicle', function(veh, key)
    if veh ~= false then
        Config.Plates[key].attachedVehicle = veh
    else
        Config.Plates[key].attachedVehicle = nil
    end
end)

RegisterNetEvent('qb-vehicletuning:client:RepaireeePart', function(part)
    local veh = Config.Plates[ClosestPlate].attachedVehicle
    local plate = QBCore.Functions.GetPlate(veh)

    if part == "engine" then
        SetVehicleEngineHealth(veh, Config.Parts[part].maxValue)
        TriggerServerEvent("vehiclemod:server:updatePart", plate, "engine", Config.Parts[part].maxValue)
    elseif part == "body" then
        local enhealth = GetVehicleEngineHealth(veh)
        local realFuel = GetVehicleFuelLevel(veh)

        SetVehicleBodyHealth(veh, Config.Parts[part].maxValue)

        TriggerServerEvent("vehiclemod:server:updatePart", plate, "body", Config.Parts[part].maxValue)

        SetVehicleFixed(veh)
        SetVehicleEngineHealth(veh, enhealth)

        if GetVehicleFuelLevel(veh) ~= realFuel then
            SetVehicleFuelLevel(veh, realFuel)
        end
    else
        TriggerServerEvent("vehiclemod:server:updatePart", plate, part, Config.Parts[part].maxValue)
    end

    QBCore.Functions.Notify(Lang:t('notifications.partrep', {
        value = Config.Parts[part].maxValue
    }))
end)

RegisterNetEvent('vehiclemod:client:setVehicleStatus', function(plate, status)
    VehicleStatus[plate] = status
end)

RegisterNetEvent('vehiclemod:client:getVehicleStatus', function()
    if not (IsPedInAnyVehicle(cache.ped, false)) then
        local veh = GetVehiclePedIsIn(cache.ped, true)

        if veh and veh ~= 0 then
            local vehpos = GetEntityCoords(veh)
            local pos = GetEntityCoords(cache.ped)

            if #(pos - vehpos) < 5.0 then
                if not IsThisModelABicycle(GetEntityModel(veh)) then
                    local plate = QBCore.Functions.GetPlate(veh)

                    if VehicleStatus[plate] then
                        SendStatusMessage(VehicleStatus[plate])
                    else
                        QBCore.Functions.Notify(Lang:t('notifications.uknown'), "error")
                    end
                else
                    QBCore.Functions.Notify(Lang:t('notifications.not_valid'), "error")
                end
            else
                QBCore.Functions.Notify(Lang:t('notifications.not_close'), "error")
            end
        else
            QBCore.Functions.Notify(Lang:t('notifications.veh_first'), "error")
        end
    else
        QBCore.Functions.Notify(Lang:t('notifications.outside'), "error")
    end
end)

RegisterNetEvent('vehiclemod:client:fixEverything', function()
    if IsPedInAnyVehicle(cache.ped, false) then
        if not IsThisModelABicycle(GetEntityModel(cache.vehicle)) and GetPedInVehicleSeat(cache.vehicle, -1) == cache.ped then
            local plate = QBCore.Functions.GetPlate(cache.vehicle)

            TriggerServerEvent("vehiclemod:server:fixEverything", plate)
        else
            QBCore.Functions.Notify(Lang:t('notifications.wrong_seat'), "error")
        end
    else
        QBCore.Functions.Notify(Lang:t('notifications.not_vehicle'), "error")
    end
end)

RegisterNetEvent('vehiclemod:client:setPartLevel', function(part, level)
    if (IsPedInAnyVehicle(cache.ped, false)) then
        local veh = GetVehiclePedIsIn(cache.ped,false)

        if not IsThisModelABicycle(GetEntityModel(veh)) and GetPedInVehicleSeat(veh, -1) == cache.ped then
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
        else
            QBCore.Functions.Notify(Lang:t('notifications.wrong_seat'), "error")
        end
    else
        QBCore.Functions.Notify(Lang:t('notifications.wrong_seat'), "error")
    end
end)

RegisterNetEvent('vehiclemod:client:repairPart', function(part, level, needAmount)
    if not IsPedInAnyVehicle(cache.ped, false) then
        local veh = GetVehiclePedIsIn(cache.ped, true)

        if veh and veh ~= 0 then
            local vehpos = GetEntityCoords(veh)
            local pos = GetEntityCoords(cache.ped)

            if #(pos - vehpos) < 5.0 then
                if not IsThisModelABicycle(GetEntityModel(veh)) then
                    local plate = QBCore.Functions.GetPlate(veh)

                    if VehicleStatus[plate] and VehicleStatus[plate][part] then
                        local lockpickTime = (1000 * level)

                        if part == "body" then
                            lockpickTime = lockpickTime / 10
                        end
                        
                        ScrapAnim(lockpickTime)

                        QBCore.Functions.Progressbar("repair_advanced", Lang:t('notifications.progress_bar'), lockpickTime, false, true, {
                            disableMovement = true,
                            disableCarMovement = true,
                            disableMouse = false,
                            disableCombat = true,
                        }, {
                            animDict = "mp_car_bomb",
                            anim = "car_bomb_mechanic",
                            flags = 16
                        }, {}, {}, function() -- Done
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
                                TriggerServerEvent("vehiclemod:server:updatePart", plate, part, GetVehicleStatus(plate, part) + level)
                                TriggerServerEvent("qb-mechanicjob:server:removePart", part, level)
                            end
                        end, function() -- Cancel
                            openingDoor = false

                            ClearPedTasks(cache.ped)

                            QBCore.Functions.Notify(Lang:t('notifications.process_canceled'), "error")
                        end)
                    else
                        QBCore.Functions.Notify(Lang:t('notifications.not_part'), "error")
                    end
                else
                    QBCore.Functions.Notify(Lang:t('notifications.not_valid'), "error")
                end
            else
                QBCore.Functions.Notify(Lang:t('notifications.not_close'), "error")
            end
        else
            QBCore.Functions.Notify(Lang:t('notifications.veh_first'), "error")
        end
    else
        QBCore.Functions.Notify(Lang:t('notifications.not_vehicle'), "error")
    end
end)

RegisterNetEvent('qb-mechanicjob:client:target:OpenStash', function()
    exports.ox_inventory:openInventory('stash', 'stash_mechanic')
end)

RegisterNetEvent('qb-mechanicjob:client:target:CloseMenu', function()
    DestroyVehiclePlateZone(ClosestPlate)
    RegisterVehiclePlateZone(ClosestPlate, Config.Plates[ClosestPlate])

    lib.hideContext()
end)

-- Threads
CreateThread(function()
    local wait = 500

    while not LocalPlayer.state.isLoggedIn do
        -- do nothing
        Wait(wait)
    end

    local Blip = AddBlipForCoord(Config.Locations["exit"].x, Config.Locations["exit"].y, Config.Locations["exit"].z)

    SetBlipSprite(Blip, 446)
    SetBlipDisplay(Blip, 4)
    SetBlipScale(Blip, 0.7)
    SetBlipAsShortRange(Blip, true)
    SetBlipColour(Blip, 0)
    SetBlipAlpha(Blip, 0.7)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(Lang:t('labels.job_blip'))
    EndTextCommandSetBlipName(Blip)

    RegisterGarageZone()
    RegisterDutyTarget()
    RegisterStashTarget()
    SetVehiclePlateZones()

    while true do
        wait = 500

        SetClosestPlate()

        if PlayerJob.type == 'mechanic' then
            if isInsideDutyZone then
                wait = 0

                if IsControlJustPressed(0, 38) then
                    TriggerServerEvent("QBCore:ToggleDuty")
                end
            end

            if onDuty then
                if isInsideStashZone then
                    wait = 0

                    if IsControlJustPressed(0, 38) then
                        TriggerEvent("qb-mechanicjob:client:target:OpenStash")
                    end
                end

                if isInsideGarageZone then
                    wait = 0

                    local inVehicle = IsPedInAnyVehicle(cache.ped)

                    if IsControlJustPressed(0, 38) then
                        if inVehicle then
                            DeleteVehicle(cache.vehicle)

                            lib.hideTextUI()
                        else
                            VehicleList()

                            lib.hideTextUI()
                        end
                    end
                end

                if isInsideVehiclePlateZone then
                    wait = 0

                    local attachedVehicle = Config.Plates[ClosestPlate].attachedVehicle
                    local coords = Config.Plates[ClosestPlate].coords

                    if attachedVehicle then
                        if IsControlJustPressed(0, 38) then
                            lib.hideTextUI()

                            OpenMenu()
                        end
                    else
                        if IsControlJustPressed(0, 38) and IsPedInAnyVehicle(cache.ped) then
                            DoScreenFadeOut(150)
                            Wait(150)

                            Config.Plates[ClosestPlate].attachedVehicle = cache.vehicle

                            SetEntityCoords(cache.vehicle, coords)
                            SetEntityHeading(cache.vehicle, coords.w)
                            FreezeEntityPosition(cache.vehicle, true)

                            Wait(500)
                            DoScreenFadeIn(150)

                            TriggerServerEvent('qb-vehicletuning:server:SetAttachedVehicle', cache.vehicle, ClosestPlate)

                            DestroyVehiclePlateZone(ClosestPlate)
                            RegisterVehiclePlateZone(ClosestPlate, Config.Plates[ClosestPlate])
                        end
                    end
                end
            end
        end

        Wait(wait)
    end
end)

CreateThread(function()
    while true do
        Wait(1000)

        if IsPedInAnyVehicle(cache.ped, false) then
            if not IsThisModelABicycle(GetEntityModel(cache.vehicle)) and GetPedInVehicleSeat(cache.vehicle, -1) == cache.ped then
                local engineHealth = GetVehicleEngineHealth(cache.vehicle)
                local bodyHealth = GetVehicleBodyHealth(cache.vehicle)
                local plate = QBCore.Functions.GetPlate(cache.vehicle)

                if not VehicleStatus[plate] then
                    TriggerServerEvent("vehiclemod:server:setupVehicleStatus", plate, engineHealth, bodyHealth)
                else
                    TriggerServerEvent("vehiclemod:server:updatePart", plate, "engine", engineHealth)
                    TriggerServerEvent("vehiclemod:server:updatePart", plate, "body", bodyHealth)

                    effectTimer = effectTimer + 1

                    if effectTimer >= math.random(10, 15) then
                        ApplyEffects(cache.vehicle)

                        effectTimer = 0
                    end
                end
            else
                effectTimer = 0

                Wait(1000)
            end
        else
            effectTimer = 0

            Wait(2000)
        end
    end
end)