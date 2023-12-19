return {
    useTarget = GetConvar('UseTarget', 'false') == 'true',
    debugPoly = false,
    targets = {},
    partLabels = {
        engine = Lang:t('labels.engine'),
        body = Lang:t('labels.bodsy'),
        radiator = Lang:t('labels.radiator'),
        axle = Lang:t('labels.axle'),
        brakes = Lang:t('labels.brakes'),
        clutch = Lang:t('labels.clutch'),
        fuel = Lang:t('labels.fuel'),
    },
    vehicles = {
        ['flatbed'] = 'Flatbed',
        ['towtruck'] = 'Towtruck',
        ['minivan'] = 'Minivan (Rental Car)',
        ['blista'] = 'Blista',
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