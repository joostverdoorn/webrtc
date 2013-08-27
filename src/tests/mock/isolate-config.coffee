#
# Copyright (c) 2013, TNO, J. Abbink, K. Grigorjancs, J.P. Verdoorn
# All rights reserved.
#

require [
	'Isolate'
	], ( Isolate ) ->

	console.log Isolate
	Isolate.map 'public/models/remote.server',
		connect: -> true

# isolate.map 'public/models/remote.server', {}
