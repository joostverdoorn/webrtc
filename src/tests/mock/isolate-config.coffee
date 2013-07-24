
require [ 
	'Isolate'
	], ( Isolate ) ->

	console.log Isolate 	
	Isolate.map 'public/models/remote.server',
		connect: -> true

# isolate.map 'public/models/remote.server', {}