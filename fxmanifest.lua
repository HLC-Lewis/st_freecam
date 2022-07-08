-- CFX Decl
fx_version 'adamant'
games { 'rdr3', 'gta5' }
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

-- Resource Decl
version '1.0.0'
author 'Stealthee <https://github.com/HLC-Lewis>'
description 'A simple freecam script for the community to use.'

server_scripts {
	'server/**/*.lua',
}

client_scripts {
	'client/**/*.lua',
}

shared_scripts {}
files {}
dependencies {}