return {
    useTarget = false,
    debugPoly = false,
    targets = {},
    partLabels = {
        engine = locale('labels.engine'),
        body = locale('labels.body'),
        radiator = locale('labels.radiator'),
        axle = locale('labels.axle'),
        brakes = locale('labels.brakes'),
        clutch = locale('labels.clutch'),
        fuel = locale('labels.fuel'),
    },
    vehicles = {
        flatbed = 'Flatbed',
        towtruck = 'Towtruck',
        minivan = 'Minivan (Rental Car)',
        blista = 'Blista',
    },
    minimalMetersForDamage = {
        {
            min = 8000,
            max = 12000,
            multiplier = {
                min = 1,
                max = 8,
            }
        },
        {
            min = 12000,
            max = 16000,
            multiplier = {
                min = 8,
                max = 16,
            }
        },
        {
            min = 12000,
            max = 16000,
            multiplier = {
                min = 16,
                max = 24,
            }
        },
    },
    damageableParts = {
        'radiator',
        'axle',
        'brakes',
        'clutch',
        'fuel',
    }
}