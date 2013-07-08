requirejs.config
	shim:		
		'underscore':
			expors: '_'

		'socket.io':
			exports: 'io'

		'jquery':
			exports: '$'

		'bootstrap': [ 'jquery' ]

	# We want the following paths for 
	# code-sharing reasons. Now it doesn't 
	# matter from where we require a module.
	paths:
		'public': './'

		'underscore': 'vendor/scripts/underscore'
		'jquery': 'vendor/scripts/jquery'
		'bootstrap': 'vendor/scripts/bootstrap'
		'adapter' : 'vendor/scripts/adapter'
		'socket.io': 'socket.io/socket.io'

require [
	'./app._'
	'./models/node.master'
	], ( App, Node ) ->

	# Master app class
	#

	class App.Master extends App
		
		# This method will be called from the baseclass when it has been constructed.
		# 
		initialize: ( ) ->
			@node = new Node()
			@_benchmarks = new Object()
			@node.on('peer.channel.opened', ( peer , data ) =>
				_pingInterval = setInterval(( ) =>
					peer.ping( ( latency ) =>
						latency = Math.round(latency)
						@_benchmarks[peer.id]["ping"] = latency
						$("##{peer.id} .ping").text(latency)
					)
				, 200)

				@_benchmarks[peer.id] = new Object()
				#@_benchmarks[peer.id]["cpu"] = 

				$("#nodes tr:last").after("<tr id='#{peer.id}'><td>#{peer.id}</td><td>Node</td><td>CPU</td><td class='ping'>peer</td><td>todo</td></tr>")
				
			)

			@node.on('peer.disconnected', ( peer  ) =>
				$("##{peer.id}").remove()
			)

			
	window.App = new App.Master
