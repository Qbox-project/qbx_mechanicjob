Config = Config or {}

-- UseTarget should only be set to true when using ox_target
Config.UseTarget = GetConvar('UseTarget', 'false') == 'true'

Config.MaxStatusValues = {
    ["engine"] = 1000.0,
    ["body"] = 1000.0,
    ["radiator"] = 100,
    ["axle"] = 100,
    ["brakes"] = 100,
    ["clutch"] = 100,
    ["fuel"] = 100
}

Config.ValuesLabels = {
    ["engine"] = Lang:t('labels.engine'),
    ["body"] = Lang:t('labels.bodsy'),
    ["radiator"] = Lang:t('labels.radiator'),
    ["axle"] = Lang:t('labels.axle'),
    ["brakes"] = Lang:t('labels.brakes'),
    ["clutch"] = Lang:t('labels.clutch'),
    ["fuel"] = Lang:t('labels.fuel')
}

Config.RepairCost = {
    ["body"] = "plastic",
    ["radiator"] = "plastic",
    ["axle"] = "steel",
    ["brakes"] = "iron",
    ["clutch"] = "aluminum",
    ["fuel"] = "plastic"
}

Config.RepairCostAmount = {
    ["engine"] = {
        item = "metalscrap",
        costs = 2
    },
    ["body"] = {
        item = "plastic",
        costs = 3
    },
    ["radiator"] = {
        item = "steel",
        costs = 5
    },
    ["axle"] = {
        item = "aluminum",
        costs = 7
    },
    ["brakes"] = {
        item = "copper",
        costs = 5
    },
    ["clutch"] = {
        item = "copper",
        costs = 6
    },
    ["fuel"] = {
        item = "plastic",
        costs = 5
    }
}

Config.Plates = {
    {
        zone = {
            coords = vec3(-340.85, -128.15, 39.0),
            size = vec3(2.5, 5.5, 2.0),
            rotation = 340.0
        },
        heading = 339.3
    }
}

Config.Locations = {
    exit = vec3(-339.04, -135.53, 39),
    duty = {
        coords = vec3(-323.5, -129.0, 39.0),
        size = vec3(3, 2, 2),
        rotation = 340.0
    },
    stash = {
        coords = vec3(-319.0, -132.0, 39.0),
        size = vec3(2, 2.0, 2.0),
        rotation = 340.0
    },
    vehicle = vec4(-370.51, -107.88, 38.35, 72.56)
}

Config.Vehicles = {
    ["flatbed"] = "Flatbed",
    ["towtruck"] = "Towtruck",
    ["minivan"] = "Minivan (Rental Car)",
    ["blista"] = "Blista"
}

Config.MinimalMetersForDamage = {
    [1] = {
        min = 8000,
        max = 12000,
        multiplier = {
            min = 1,
            max = 8
        }
    },
    [2] = {
        min = 12000,
        max = 16000,
        multiplier = {
            min = 8,
            max = 16
        }
    },
    [3] = {
        min = 12000,
        max = 16000,
        multiplier = {
            min = 16,
            max = 24
        }
    }
}

Config.Damages = {
    ["radiator"] = "Radiator",
    ["axle"] = "Drive Shaft",
    ["brakes"] = "Brakes",
    ["clutch"] = "Clutch",
    ["fuel"] = "Fuel Tank"
}