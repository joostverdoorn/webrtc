#
# Copyright (c) 2013, TNO, J. Abbink, K. Grigorjancs, J.P. Verdoorn
# All rights reserved.
#
requirejs = require('requirejs')

requirejs.config
	# Pass the top-level main.js/index.js require
	# function to requirejs so that node modules
	# are loaded relative to the top-level JS file.
	nodeRequire: require

	shim:
		'underscore':
			exports: '_'

	paths:
		'library': './public/library'

requirejs [
	'server'
	], ( Server ) ->

		global.Server = new Server(__dirname)
