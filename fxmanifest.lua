fx_version 'cerulean'
game 'gta5'

description 'QBX-MechanicJob'
version '1.0.0'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'locales/en.lua',
    'locales/*.lua',
    'config.lua',
    '@ox_lib/init.lua',
}

client_scripts {
    '@PolyZone/client.lua',
    '@PolyZone/BoxZone.lua',
    '@PolyZone/CircleZone.lua',
    'client/damage-effects.lua',
    'client/main.lua',
    'client/drivingdistance.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependencies {
    'ox_inventory',
}

provide 'qb-mechanicjob'
lua54 'yes'
use_experimental_fxv2_oal 'yes'
