requirejs.config
	baseUrl: '../'

	shim:
		'jquery':
			exports: '$'

		'bootstrap': [ 'jquery' ]
		'jquery.plugins': [ 'jquery' ]

	# We want the following paths for 
	# code-sharing reasons. Now it doesn't 
	# matter from where we require a module.
	paths:
		'public': './'

		'jquery': 'vendor/scripts/jquery'
		'bootstrap': 'vendor/scripts/bootstrap'
		
require [
	'scripts/app._'
	'library/node.structured'
	'jquery'
	], ( App, Node, $ ) ->

	# Master app class
	#

	class App.Master extends App
		
		# This method will be called from the baseclass when it has been constructed.
		# 
		initialize: ( ) ->
			@node = new Node()

			@_updateNodesInterval = setInterval(@displayNodes, 2000)
			
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
		displayNodes: () =>
			@node.server.query('nodes', 'node.structured', ( nodes ) =>
				$('.node-row').remove()

				for node in nodes
					unless node.id is @node.id
						peer = @node.getPeer(node.id)
						# peer might be empty/unset so render the node instead
						row = @generateNodeRow(peer || node)

					$("#nodes tbody").append(row)
			)

		# Generate and returns a jQuery object of a table row containing all information
		# of a node, neatly formatted.
		#
		# @param node [Node] Accepts a Node or a Peer object
		# @return [jQuery] a jQuery object of a table row
		#
		generateNodeRow: ( node ) ->

			self = @node.id is node.id


			if self
				row = $("<tr class='self-row success' id='node-#{node.id}'></tr>")
			else
				row = $("<tr class='node-row' id='node-#{node.id}'></tr>")
			
			row.append("<td>#{node.id}</td>")

			if self				
				row.append("<td class='ping'>-</td>")
				row.append("<td class='superNode'>false</td>")
				row.append("<td>-</td>")
				row.append("<td>-</td>")
				row.append("<td></td>")

			else if node.latency?
				row.append("<td>#{Math.round(node.latency)}</td>")
				row.append("<td class='superNode'>#{node.isSuperNode}</td>")
				row.append("<td>#{node.role}</td>")
				row.append("<td>Connected</td>")
				
				elem = $("<td><a href='#'>Disconnect</a></td>")
				elem.click( ( ) => 
					@node.disconnect(node.id)
					elem.replaceWith("<td>Disconnecting...</td>")
				)
				row.append(elem)

			else 
				row.append("<td>-</td>")
				row.append("<td class='superNode'>#{node.isSuperNode}</td>")
				row.append("<td>-</td>")
				row.append("<td></td>")
				
				elem = $("<td><a href='#'>Connect</a></td>")
				elem.click( ( ) => 
					@node.connect(node.id) 
					elem.replaceWith("<td>Connecting...</td>")
				)
				row.append(elem)

			return row
			
	window.App = new App.Master
