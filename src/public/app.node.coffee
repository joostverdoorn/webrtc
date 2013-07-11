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

			@_updateNodesInterval = setInterval(@update, 5000)

			

			@node.on('peer.added', ( peer ) =>
				$("#node-#{peer.id}").replaceWith(@generateNodeRow( peer ))
			)

			@node.on('peer.removed', ( peer ) => 
				$("#node-#{peer.id}").replaceWith(@generateNodeRow(peer))
			)

			@node.server.on('connect', ( ) =>
				$("#nodes tbody").append(@generateNodeRow(@node))
			)

			@node.on('setSuperNode', ( isSuperNode ) =>
				$(".self-row .superNode").text(isSuperNode)
			)








			
		# Displays all available nodes.
		#
		update: () =>		
			@node.server.query('nodes', ( nodes ) =>
				@displayNodes(nodes)
			)


		displayNodes: (nodes) =>
			$('.node-row').remove()
			for node in nodes
				unless node.id is @node.id
					peer = @node.getPeer(node.id)
					if peer
						row = @generateNodeRow(peer)
					else
						row = @generateNodeRow(node)

				$("#nodes tbody").append(row)

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
		generateNodeRow: ( node ) ->

			self = @node.id is node.id
			if node.system?
				systemString = "#{node.system.osName} - #{node.system.browserName}#{node.system.browserVersion}"
			else
				systemString = "-"

			if node.benchmark?
				benchmarkString = "#{node.benchmark['cpu']}"
			else
				benchmarkString = "-"

			if self
				row = $("<tr class='self-row success' id='node-#{node.id}'></tr>")
			else
				row = $("<tr class='node-row' id='node-#{node.id}'></tr>")
			
			row.append("<td>#{node.id}</td>")
			row.append("<td class='superNode'>#{node.isSuperNode}</td>")

			if self
				row.append("<td>#{benchmarkString}</td>")
				row.append("<td class='ping'>-</td>")
				row.append("<td>#{systemString}</td>")
				row.append("<td>self</td>")
				row.append("<td></td>")

			else if node.latency?
				row.append("<td>#{benchmarkString}</td>")
				row.append("<td>#{node.latency}</td>")
				row.append("<td>#{systemString}</td>")
				row.append("<td>Connected</td>")
				
				elem = $("<td><a href='#'>Disconnect</a></td>")
				elem.click( ( ) => 
					@node.disconnect(node.id)
					elem.replaceWith("<td>Disconnecting...</td>")
				)
				row.append(elem)

			else 
				row.append("<td>#{benchmarkString}</td>")
				row.append("<td>-</td>")
				row.append("<td>#{systemString}</td>")
				row.append("<td></td>")
				
				elem = $("<td><a href='#'>Connect</a></td>")
				elem.click( ( ) => 
					@node.connect(node.id) 
					elem.replaceWith("<td>Connecting...</td>")
				)
				row.append(elem)



			return row
			
	window.App = new App.Master
