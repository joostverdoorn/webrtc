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

			# Display the own Peer as first row in the table
			$("#nodes tbody").append("<tr class='success' id='#{@node.id}'><td>#{@node.id}</td><td>Master</td><td>#{@node.benchmark.cpu}</td><td class='ping'>0</td><td>#{@makeSystemString(@node.system)}</td><td class='status'>self</td><td class='actions'>-</td></tr>")
			
			# refresh the table each 5 seconds
			_pingUpdatePeers =  setInterval((( ) => 	@getPeers() ), 5000)

			# The node is has opened a peer channel connection
			@node.on('peer.channel.opened', ( peer , data ) =>
				# Perform ping operations
				_pingInterval = setInterval(( ) =>
					peer.ping( ( latency ) =>
						latency = Math.round(latency)
						@_benchmarks[peer.id]["ping"] = latency
						# Update Ping in the table
						$("##{peer.id} .ping").text(latency)
					)
				, 200)

				# get benchmarks of the Peer
				@_benchmarks[peer.id] = new Object()
				peer.query("benchmark", (benchmark) =>
					@_benchmarks[peer.id]["cpu"] = benchmark["cpu"]	
				)

				# get System information of the Peer
				peer.query("system", (system) =>
						@node.system = system	
				)
				
			)

		# manually disconnect a node
		disconnect: ( id ) =>
			@node.disconnect(id)
			$("##{id} .status").text ("Disconnected")
			$("##{id} .actions").html("-")

		# manually connect to a node
		connect: ( id ) =>
			$("##{id}").remove()
			@node.connect (id)
			

		# get all available nodes peers from a server and display them
		getPeers: () =>
			# remove all other nodes
			$("tr").not(".success").not(".heading").remove()
			# get all nodes from a server
			@_allPeers = @node.server.query("nodes", (ids) =>
				for id in ids
					if id isnt @node.id
						peer  = _(@node._peers).find( ( peer ) -> peer.id is id )
						# is this  node already connected?
						if (peer? and @_benchmarks[id]?)
							systemString = @makeSystemString(@node.system)
							$("#nodes tbody").append("<tr id='#{peer.id}'><td>#{peer.id}</td><td>Master</td><td>#{@_benchmarks[peer.id]["cpu"]}</td><td class='ping'>0</td><td>#{systemString}</td><td class='status'>Connected</td><td class='actions'><a href='#'>Disconnect</a></td></tr>")
							( (id) =>
	 							$("##{peer.id} a:contains('Disconnect')").click () => @disconnect(id)
							) (id)
						# this is not a connected node	
						else
							$("#nodes tbody").append("<tr id='#{id}'><td>#{id}</td><td>Master</td><td></td><td class='ping'></td><td></td><td class='status'></td><td class='actions'><a href='#'>Connect</a></td></tr>")
							( (id) =>
	 							$("##{id} a:contains('Connect')").click () => @connect(id)
							) (id)
							
				
			)

		makeSystemString: (system) ->
			"#{system.osName} - #{system.browserName}#{system.browserVersion}"


			
	window.App = new App.Master
