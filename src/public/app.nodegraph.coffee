requirejs.config
	shim:
		'jquery':
			exports: '$'
		'sigma':
			exports: 'sigma'

		'public/vendor/scripts/jquery.plugins': [ 'jquery' ]
		'forceatlas': [ 'sigma' ]

	# We want the following paths for 
	# code-sharing reasons. Now it doesn't 
	# matter from where we require a module.
	paths:
		'public': './'

		'jquery': 'vendor/scripts/jquery'
		'sigma': 'vendor/scripts/sigma.min'
		'forceatlas': 'vendor/scripts/sigma.forceatlas2'
		
require [
	'app._'
	'jquery'
	'sigma'
	'forceatlas'
	], ( App, $, sigma ) ->

	# NodeGraph app class
	#

	class App.NodeGraph extends App
		
		# The update URL
		_updateURL = '/nodes'

		# The datatype for @_updateURL
		_dataType = 'json'

		# This method will be called from the baseclass when it has been constructed.
		# 
		initialize: ( ) ->
			@_addedNodes = {}
			@_addedEdges = {}
			@_animating = false
			@_sigmaInstance = sigma.init document.getElementById 'graph'
			@_sigmaInstance.drawingProperties {
					defaultLabelColor: '#fff'
					defaultLabelSize: 14
					defaultLabelBGColor: '#fff'
					defaultLabelHoverColor: '#000'
					labelThreshold: 6
					defaultEdgeType: 'line'
				}
			@_sigmaInstance.graphProperties {
					minNodeSize: 0.5
					maxNodeSize: 5
					minEdgeSize: 1
					maxEdgeSize: 1
				}
			@_sigmaInstance.mouseProperties {
					maxRatio: 4
				}

			@_sigmaInstance.draw()
			@startAnimation()

			@update()

		# Updates the view and sets the timeout on itself again
		#
		update: ( ) ->
			$.ajax({
					url: @_updateURL
					dataType: @_dataType
				}).done ( data ) =>
					# Check if all previous nodes and edges still exist
					for node in @_addedNodes
						if not data[node]
							# Node was removed from the network, so remove it from the graph
							@removeNode node
						else
							# Node still exists, but do all old edges still exist?
							for edge in @_addedEdges[node]
								if not data[node][edge]		# The edge does not exist anymore, so remove it
									@removeEdge node, edge

					# Add newly added network nodes to the graph
					for node in data
						#if not @_addedNodes[node]		# Node does not yet exist, so create it
							@addNode node

					# All nodes exist so now it's time to add all non-existent edges
					for node in data
						for edge in data[node]
							@addEdge node, edge

					setTimeout @update, 1000


			
		# Generates a random RGB color as CSS3 string
		#
		randomColor: ( ) ->
			r = Math.round(Math.random() * 256)
			g = Math.round(Math.random() * 256)
			b = Math.round(Math.random() * 256)

			if (Math.abs(r-g) < 50 && Math.abs(g-b) < 50 && Math.abs(b-r) < 50)
				return @randomColor()
			else
				return 'rgb(' + r + ',' + g + ',' + b + ')'

		# Starts the Force Atlas 2 algorithm to draw the graph nicely
		#
		startAnimation: ( ) ->
			if @_animating
				return

			@_animating = true
			@_sigmaInstance.startForceAtlas2()

		# Stops the Force Atlas 2 algorithm to draw the graph nicely
		#
		stopAnimation: ( ) ->
			if not @_animating
				return

			@_animating = false
			@_sigmaInstance.stopForceAtlas2()

		# Removes a node and its edges
		#
		removeNode: ( node ) ->
			if not @_addedNodes[node]
				return

			# Remove all edges with this node; the library should do this but this did not always happen
			for edge in @_addedEdges[node]
				@removeEdge node, edge

			@_addedNodes[node] = false
			@_sigmaInstance.dropNode node


		# Adds a node to the sigma instance
		#
		addNode: ( title ) ->
			if @_addedNodes[title]
				return

			@_addedNodes[title] = true
			if not @_addedEdges[title]
				@_addedEdges[title] = {}
			@_sigmaInstance.addNode title, {
					x: Math.random()
					y: Math.random()
					color: @randomColor()
					size: 1
				}

		# Adds an edge between two edges
		#
		addEdge: ( node1, node2 ) ->
			if not @_addedNodes[node1] or not @_addedNodes[node2] or @_addedEdges[node1][node2] or @_addedEdges[node2][node1]
				return

			@_addedEdges[node1][node2] = true
			@_addedEdges[node2][node1] = true

			@_sigmaInstance.addEdge node1 + '_' + node2, node1, node2

		# Removes an edge between two nodes
		#
		removeEdge: ( node1, node2 ) ->
			if not @_addedNodes[node1] or not @_addedNodes[node2] or not @_addedEdges[node1][node2] or not @_addedEdges[node2][node1]
				return

			@_addedEdges[node1][node2] = false
			@_addedEdges[node2][node1] = false

			@_sigmaInstance.dropEdge [node1, node2]
			@_sigmaInstance.dropEdge [node2, node1]
			
	window.App = new App.NodeGraph
