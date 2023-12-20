return {
    maxStatusValues = {
        engine = 1000.0,
        body = 1000.0,
        radiator = 100,
        axle = 100,
        brakes = 100,
        clutch = 100,
        fuel = 100,
    },
    repairCost = {
        body = 'plastic',
        radiator = 'plastic',
        axle = 'steel',
        brakes = 'iron',
        clutch = 'aluminum',
        fuel = 'plastic',
    },
    repairCostAmount = {
        engine = {
            item = 'metalscrap',
            costs = 2,
        },
        body = {
            item = 'plastic',
            costs = 3,
        },
        radiator = {
            item = 'steel',
            costs = 5,
        },
        axle = {
            item = 'aluminum',
            costs = 7,
        },
        brakes = {
            item = 'copper',
            costs = 5,
        },
        clutch = {
            item = 'copper',
            costs = 6,
        },
        fuel = {
            item = 'plastic',
            costs = 5,
        },
    },
    plates = {
        {
            coords = vec4(-340.95, -128.24, 39, 160.0),
            boxData = {
                heading = 340,
                length = 5,
                width = 2.5,
                debugPoly = false
            },
            AttachedVehicle = nil,
        },
        {
            coords = vec4(-327.91, -144.34, 38.86, 70.34),
            boxData = {
                heading = 249,
                length = 6.5,
                width = 5,
                debugPoly = false
            },
            AttachedVehicle = nil,
        },
    },
    locations = {
        exit = vec3(-339.04, -135.53, 39.00),
        duty = vec3(-323.30, -128.79, 39.02),
        stash = vec3(-319.19, -131.90, 37.98),
        vehicle = vec4(-370.51, -107.88, 38.35, 72.56),
    }
}