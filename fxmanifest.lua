fx_version 'cerulean'
game 'gta5'

description 'qbx_MechanicJob'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/import.lua',
    '@qbx_core/shared/locale.lua',
    'locales/en.lua',
    'locales/*.lua',
    'config.lua',
}

client_scripts {
    '@PolyZone/client.lua',
    '@PolyZone/BoxZone.lua',
    '@PolyZone/CircleZone.lua',
    'client/damage-effects.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

modules {
    'qbx_core:playerdata',
    'qbx_core:utils',
}

provide 'qb-mechanicjob'
lua54 'yes'
use_experimental_fxv2_oal 'yes'
