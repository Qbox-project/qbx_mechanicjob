Config = Config or {}

-- UseTarget should only be set to true when using ox_target
Config.UseTarget = GetConvar('UseTarget', 'false') == 'true'

Config.Parts = {
    ["engine"] = {
        label = 'Motor',
        maxValue = 1000.0,
        canDamage = false,
        repair = {
            item = "metalscrap",
            cost = 2
        }
    },
    ["body"] = {
        label = 'Body',
        maxValue = 1000.0,
        canDamage = false,
        repair = {
            item = "plastic",
            cost = 3
        }
    },
    ["radiator"] = {
        label = 'Radiator',
        maxValue = 100.0,
        canDamage = true,
        repair = {
            item = "steel",
            cost = 5
        }
    },
    ["axle"] = {
        label = 'Drive Shaft',
        maxValue = 100.0,
        canDamage = true,
        repair = {
            item = "aluminum",
            cost = 7
        }
    },
    ["brakes"] = {
        label = 'Brakes',
        maxValue = 100.0,
        canDamage = true,
        repair = {
            item = "copper",
            cost = 5
        }
    },
    ["clutch"] = {
        label = 'Clutch',
        maxValue = 100.0,
        canDamage = true,
        repair = {
            item = "copper",
            cost = 6
        }
    },
    ["fuel"] = {
        label = 'Fuel tank',
        maxValue = 100.0,
        canDamage = true,
        repair = {
            item = "plastic",
            cost = 5
        }
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