fx_version 'cerulean'
game 'gta5'

description 'Qbx-radialmenu'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/import.lua',
    '@qbx_core/shared/locale.lua',
    'locales/en.lua',
    'locales/*.lua',
    'config.lua'
}

modules {
    'qbx_core:playerdata',
    'qbx_core:utils'
}

client_scripts {
    'client/*.lua',
}

server_scripts {
    'server/*.lua',
}

provide 'qb-radialmenu'
lua54 'yes'
use_experimental_fxv2_oal 'yes'
