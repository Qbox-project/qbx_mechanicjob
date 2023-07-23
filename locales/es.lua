local Translations = {
    labels = {
        engine = 'Motor',
        bodsy = 'Carrocería',
        radiator = 'Radiador',
        axle = 'Árbol de transmisión',
        brakes = 'Frenos',
        clutch = 'Embrague',
        fuel = 'Depósito de combustible',
        sign_in = 'Entrar en servicio',
        sign_off = 'Salir de servicio',
        o_stash = 'Abrir almacén',
        h_vehicle = '[E] Ocultar vehículo',
        g_vehicle = '[E] Obtener vehículo',
        o_menu = '[E] Abrir menú',
        work_v = '[E] Trabajar en el vehículo',
        progress_bar = 'Reparando... ',
        veh_status = 'Estado del vehículo: ',
        job_blip = 'Mecánico de LS Customs',
        stash = 'Almacén de mecánico',
        status = 'Estado',
        vehicle_title = "Vehículo: %{value}",
        vehicle_list = 'Lista de vehículos',
    },

    lift_menu = {
        header_menu = 'Opciones del vehículo',
        header_vehdc = 'Desconectar vehículo',
        desc_vehdc = 'Desvincular vehículo del elevador',
        header_stats = 'Ver estado',
        desc_stats = 'Ver estado del vehículo',
        header_parts = 'Piezas del vehículo',
        desc_parts = 'Reparar piezas del vehículo',
        c_menu = '⬅ Cerrar menú'
    },

    parts_menu = {
        status = 'Estado: ',
        menu_header = 'Menú de piezas',
        repair_op = 'Reparar: ',
        b_menu = '⬅ Volver al menú',
        d_menu = 'Volver al menú de piezas',
        c_menu = '⬅ Cerrar menú'
    },

    nodamage_menu = {
        header = 'Sin daños',
        bh_menu = 'Volver al menú',
        bd_menu = '¡No hay daños en esta parte!',
        c_menu = '⬅ Cerrar menú'
    },

    notifications = {
        not_enough = 'No tienes suficiente',
        not_have = 'No tienes',
        not_materials = 'No hay suficientes materiales en el almacén',
        rep_canceled = 'Reparación cancelada',
        repaired = '¡ha sido reparado/a!',
        uknown = 'Estado desconocido',
        not_valid = 'Vehículo no válido',
        not_close = 'No estás lo suficientemente cerca del vehículo',
        veh_first = 'Primero debes estar dentro del vehículo',
        outside = 'Debes estar fuera del vehículo',
        wrong_seat = 'No eres el conductor o estás en una bicicleta',
        not_vehicle = 'No estás en un vehículo',
        progress_bar = 'Reparando vehículo...',
        process_canceled = 'Proceso cancelado',
        not_part = 'No es una pieza válida',
        partrep ='El/la %{value} ha sido reparado/a',
    }
}

if GetConvar('qb_locale', 'en') == 'es' then
    Lang = Locale:new({
        phrases = Translations,
        warnOnMissing = true,
        fallbackLang = Lang,
    })
end
