local Translations = {
    labels = {
        engine = 'Motore',
        bodsy = 'Body',
        radiator = 'Radiatore',
        axle = 'Drive Shaft',
        brakes = 'Freni',
        clutch = 'Clutch',
        fuel = 'Serbatoio',
        sign_in = 'Sign In',
        sign_off = 'Sign Off',
        o_stash = '[E] Open Stash',
        h_vehicle = '[E] Parcheggia Veicolo',
        g_vehicle = '[E] Prendi Veicolo',
        o_menu = '[E] Apri Menu',
        work_v = '[E] Lavoro sul Veicolo',
        progress_bar = 'Riparando...',
        veh_status = 'Stato Veicolo:',
        job_blip = 'Autocare Mechanic',
        stash = 'Mechanic Stash',
        status = 'Status',
        vehicle_title = "Vehicle: %{value}",
        vehicle_list = 'Vehicle List',
    },

    lift_menu = {
        header_menu = 'Vehicle Options',
        header_vehdc = 'Disconnect Vehicle',
        desc_vehdc = 'Unattach Vehicle in Lift',
        header_stats = 'Check Status',
        desc_stats = 'Check Vehicle Status',
        header_parts = 'Vehicle Parts',
        desc_parts = 'Repair Vehicle Parts',
        c_menu = '⬅ Close Menu'
    },

    parts_menu = {
        status = 'Status: ',
        menu_header = 'Part Menu',
        repair_op = 'Repair:',
        b_menu = '⬅ Back Menu',
        d_menu = 'Back to parts menu',
        c_menu = '⬅ Close Menu'
    },

    nodamage_menu = {
        header = 'No Damage',
        bh_menu = 'Back Menu',
        bd_menu = 'There Is No Damage To This Part!',
        c_menu = '⬅ Close Menu'
    },

    notifications = {
        not_enough = 'You don\'t Have Enough',
        not_have = 'You don\'t have',
        not_materials = 'There are not enough materials in the safe',
        rep_canceled = 'Riparazione Annullata',
        repaired = 'è stato riparato!',
        uknown = 'Status uknown',
        not_valid = 'Not valid vehicle',
        not_close = 'You are not close enough to the vehicle',
        veh_first = 'You must be in the vehicle first',
        outside = 'You must be outside the vehicle',
        wrong_seat = 'You are not the driver or on a bicycle',
        not_vehicle = 'You are not in a vehicle',
        progress_bar = 'Repairing vehicle..',
        process_canceled = 'Proccess canceled',
        not_part = 'Not a valid part',
        partrep ='The %{value} Is Repaired!',
    }
}

if GetConvar('qb_locale', 'en') == 'it' then
    Lang = Locale:new({
        phrases = Translations,
        warnOnMissing = true,
        fallbackLang = Lang,
    })
end
