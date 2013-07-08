requirejs.config
	shim:		
		'underscore':
			exports: '_'

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
			$("#nodes tbody").append("<tr class='success' id='#{@node.id}'><td>#{@node.id}</td><td>Node</td><td>#{@node.benchmark.cpu}</td><td class='ping'>0</td><td>todo</td><td class='status'>self</td><td class='actions'>-</td></tr>")

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

				$("#nodes tbody").append("<tr id='#{peer.id}'><td>#{peer.id}</td><td>Node</td><td>CPU</td><td class='ping'>peer</td><td>todo</td><td class='status'>Connected</td><td class='actions'><a href='#'>Disconnect</a></td></tr>")
				$("##{peer.id} a:contains('Disconnect')").click () =>
					@disconnect(peer.id)
				
			)

			@node.on('peer.disconnected', ( peer  ) =>
				$("##{peer.id} .status").text ("Disconnected")
				$("##{peer.id} .actions").html( "<a href='#'>Connect</a>")
				$("##{peer.id} a:contains('Connect')").click () =>
					@connect(peer.id)
			)

		# disconnect 
		disconnect: ( id ) =>
			peer = _(@node._peers).find( ( peer ) -> peer.id is id ) #should use a getPeer function later
			#disconnect iets

		# manually connect to a node
		connect: ( id ) =>
			peer = _(@node._peers).find( ( peer ) -> peer.id is id ) #should use a getPeer function later
			@node.connect ("id")
			$("##{id}").remove()

		# get all available nodes peers from a server and display them
		getPeers: () =>
			# query 


			
	window.App = new App.Master
