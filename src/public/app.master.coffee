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
			$("#nodes tbody").append("<tr class='success' id='#{@node.id}'><td>#{@node.id}</td><td>Master</td><td>#{@node.benchmark.cpu}</td><td class='ping'>0</td><td>#{@makeSystemString(@node.system)}</td><td class='status'>self</td><td class='actions'>-</td></tr>")
			_pingUpdatePeers =  setInterval((( ) => 	@getPeers() ), 5000)
			@node.on('peer.channel.opened', ( peer , data ) =>
				_pingInterval = setInterval(( ) =>
					peer.ping( ( latency ) =>
						latency = Math.round(latency)
						@_benchmarks[peer.id]["ping"] = latency
						$("##{peer.id} .ping").text(latency)
					)
				, 200)

				@_benchmarks[peer.id] = new Object()
				peer.query("benchmark", (benchmark) =>
					@_benchmarks[peer.id]["cpu"] = benchmark["cpu"]
					peer.query("system", (system) =>
						@node.system = system
						systemString = @makeSystemString(@node.system)
						$("#nodes tbody").append("<tr id='#{peer.id}'><td>#{peer.id}</td><td>Master</td><td>#{@_benchmarks[peer.id]["cpu"]}</td><td class='ping'>peer</td><td>#{systemString}</td><td class='status'>Connected</td><td class='actions'><a href='#'>Disconnect</a></td></tr>")
						$("##{peer.id} a:contains('Disconnect')").click () => @disconnect(peer.id)
						
					)
				)
				

				

				
				
			)

			###@node.on('peer.disconnected', ( peer  ) =>
				$("##{peer.id} .status").text ("Disconnected")
				$("##{peer.id} .actions").html( "<a href='#'>Connect</a>")
				$("##{peer.id} a:contains('Connect')").click () =>
					@connect(peer.id)
			)###

		# disconnect 
		disconnect: ( id ) =>
			peer = _(@node._peers).find( ( peer ) -> peer.id is id ) #should use a getPeer function later
			console.log id
			#disconnect iets

		# manually connect to a node
		connect: ( id ) =>
			$("##{id}").remove()
			@node.connect (id)
			

		# get all available nodes peers from a server and display them
		getPeers: () =>
			$("tr").not(".success").remove()
			@_allPeers = @node.server.query("nodes", (ids) =>
				for id in ids
					if id isnt @node.id
						peer  = _(@node._peers).find( ( peer ) -> peer.id is id )
						if (peer?)
							systemString = @makeSystemString(@node.system)
							$("#nodes tbody").append("<tr id='#{peer.id}'><td>#{peer.id}</td><td>Master</td><td>#{@_benchmarks[peer.id]["cpu"]}</td><td class='ping'>peer</td><td>#{systemString}</td><td class='status'>Connected</td><td class='actions'><a href='#'>Disconnect</a></td></tr>")
						
						else
							$("#nodes tbody").append("<tr id='#{id}'><td>#{id}</td><td>Master</td><td></td><td class='ping'></td><td></td><td class='status'></td><td class='actions'><a href='#'>Connect</a></td></tr>")
							( (id) =>
	 							$("##{id} a:contains('Connect')").click () => @connect(id)
							) (id)
							
				
			)

		makeSystemString: (system) ->
			"#{system.osName} - #{system.browserName}#{system.browserVersion}"


			
	window.App = new App.Master
