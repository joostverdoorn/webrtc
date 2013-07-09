requirejs.config
	shim:		
		'underscore':
			exports: '_'

		'socket.io':
			exports: 'io'

		'jquery':
			exports: '$'

		'bootstrap': [ 'jquery' ]
		'public/vendor/scripts/jquery.plugins': [ 'jquery' ]

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
	'app._'
	'models/node'
	], ( App, Node ) ->

	# Master app class
	#

	class App.Master extends App
		
		# This method will be called from the baseclass when it has been constructed.
		# 
		initialize: ( ) ->
			@node = new Node()

			@_updateNodesInterval = setInterval(@displayNodes, 5000)

			$("#nodes tbody").append(@generateNodeRow(@node.id, @node.benchmark, @node.server.latency, @node.system, false, true))

			@node.on('peer.added', ( peer ) =>
				$("#node-#{peer.id}").replaceWith(@generateNodeRow(peer.id, null, 0, null, true))
			)

			@node.on('peer.removed', ( peer ) => 
				$("#node-#{peer.id}").replaceWith(@generateNodeRow(peer.id))
			)
			
		# Displays all available nodes.
		#
		displayNodes: () =>
			$('.node-row').remove()

			@node.server.query('nodes', ( ids ) =>
				for id in ids
					unless id is @node.id
						peer = @node.getPeer(id)
					
						if peer
							row = @generateNodeRow(id, peer.benchmark, peer.latency, peer.system, true)
						else
							row = @generateNodeRow(id)

						$("#nodes tbody").append(row)
			)

		# Generate and returns a jQuery object of a table row containing all information
		# of a node, neatly formatted.
		#
		# @param id [String] the id of the node
		# @param benchmark [Object] the benchmark object of the node
		# @param ping [Integer] the latency to the node
		# @param system [Object] the system object of the node
		# @param connected [Boolean] wether or not we are currently connected to this node
		# @param self [Boolean] wether or not this row should represent ourself
		# @return [jQuery] a jQuery object of a table row
		#
		generateNodeRow: ( id, benchmark = null, ping = 0, system = null, connected = false, self = false ) ->
			if system?
				systemString = "#{system.osName} - #{system.browserName}#{system.browserVersion}"
			else
				systemString = "-"

			if benchmark?
				benchmarkString = "#{benchmark['cpu']}"
			else
				benchmarkString = "-"

			if self
				row = $("<tr class='self-row success' id='node-#{id}'></tr>")
			else
				row = $("<tr class='node-row' id='node-#{id}'></tr>")
			
			row.append("<td>#{id}</td>")
			row.append("<td>Node</td>")

			if connected
				row.append("<td>#{benchmarkString}</td>")
				row.append("<td>#{ping}</td>")
				row.append("<td>#{systemString}</td>")
				row.append("<td>Connected</td>")
				
				elem = $("<td><a href='#'>Disconnect</a></td>")
				elem.click( ( ) => 
					@node.disconnect(id)
					elem.replaceWith("<td>Disconnecting...</td>")
				)
				row.append(elem)

			else if not self
				row.append("<td></td>")
				row.append("<td></td>")
				row.append("<td></td>")
				row.append("<td></td>")
				
				elem = $("<td><a href='#'>Connect</a></td>")
				elem.click( ( ) => 
					@node.connect(id) 
					elem.replaceWith("<td>Connecting...</td>")
				)
				row.append(elem)

			else 
				row.append("<td>#{benchmarkString}</td>")
				row.append("<td class='ping'>#{ping}</td>")
				row.append("<td>#{systemString}</td>")
				row.append("<td>self</td>")
				row.append("<td></td>")

			return row
			
	window.App = new App.Master
