requirejs.config
	shim:
		'underscore':
			exports: '_'
		'jquery':
			exports: '$'
		'sigma':
			exports: 'sigma'
		'forceatlas': [ 'sigma' ]

	# We want the following paths for 
	# code-sharing reasons. Now it doesn't 
	# matter from where we require a module.
	paths:
		'public': './'

		'underscore': 'vendor/scripts/underscore'
		'jquery': 'vendor/scripts/jquery'
		'sigma': 'vendor/scripts/sigma.min'
		'forceatlas': 'vendor/scripts/sigma.forceatlas2'

		
require [
	'app._'
	'jquery'
	'underscore'
	'sigma'
	'forceatlas'
	], ( App, $, _, sigma ) ->

	# NodeGraph app class
	#

	class App.NodeGraph extends App

		# This method will be called from the baseclass when it has been constructed.
		# 
		initialize: ( ) ->

			# The update URL
			@_updateURL = '/nodes'

			# The datatype for @_updateURL
			@_dataType = 'json'

			@_addedNodes = {}
			@_addedEdges = {}
			@_animating = false
			$(document).ready(( ) =>
				@_sigmaInstance = sigma.init $('#graph').get(0)
				@_sigmaInstance.drawingProperties {
						defaultLabelColor: '#fff'
						defaultLabelSize: 14
						defaultLabelBGColor: '#fff'
						defaultLabelHoverColor: '#000'
						labelThreshold: 6
						defaultEdgeType: 'line'
						edgeColor: 'asd'
						defaultEdgeColor: '#FFF'
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
			)

		# Updates the view and sets the timeout on itself again
		#
		update: ( ) ->
			$.ajax({
					url: @_updateURL
					dataType: @_dataType
				}).error(( )=>
					console.log 'ERROR!'
					console.log arguments
				).done ( data ) =>
					
					# Check if all previous nodes and edges still exist
					for node, a of @_addedNodes
						if not data[node]
							# Node was removed from the network, so remove it from the graph
							@removeNode node
						else
							# Node still exists, but do all old edges still exist?
							for edge, b of @_addedEdges[node]
								if b and $.inArray(edge, data[node]) == -1 and $.inArray(node, data[edge]) == -1		# The edge does not exist anymore, so remove it
									@removeEdge node, edge

					# Add newly added network nodes to the graph
					for node, a of data
						#if not @_addedNodes[node]		# Node does not yet exist, so create it
							@addNode node

					# All nodes exist so now it's time to add all non-existent edges
					for node, a of data
						for edge, b of data[node]
							@addEdge node, b

					@_sigmaInstance.iterNodes((n) =>
							if n.degree > 1
								n.color = '#F00'
							else if n.degree is 1
								n.color = '#0F0'
							else
								n.color = '#FF0'
						)
					setTimeout (
						() => 
							@update()
						), 1000


			
		# Generates a random RGB color as CSS3 string
		#
		randomColor: ( ) ->
			r = Math.round(Math.random() * 256)
			g = Math.round(Math.random() * 256)
			b = Math.round(Math.random() * 256)

			if (Math.abs(r-g) < 50 && Math.abs(g-b) < 50 && Math.abs(b-r) < 50)
				return @randomColor()
			else
				return "rgb(#{r},#{g},#{b})"

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

			console.log 'adding node'
			@_sigmaInstance.addNode(title, {
					x: Math.random()
					y: Math.random()
					color: '#FF0'#@randomColor()
					size: 1
				})#.draw()

		# Adds an edge between two edges
		#
		addEdge: ( node1, node2 ) ->
			#console.log 'adding'
			if not @_addedNodes[node1] or not @_addedNodes[node2] or @_addedEdges[node1][node2] or @_addedEdges[node2][node1]
				return

			console.log "adding #{node1} -> #{node2}"
			@_addedEdges[node1][node2] = true
			@_addedEdges[node2][node1] = true

			@_sigmaInstance.addEdge(node1 + '_' + node2, node1, node2)#.draw()
			

		# Removes an edge between two nodes
		#
		removeEdge: ( node1, node2 ) ->
			if not @_addedNodes[node1] or not @_addedNodes[node2] or not @_addedEdges[node1][node2] or not @_addedEdges[node2][node1]
				return

			console.log "removing #{node1} -> #{node2}"
			@_addedEdges[node1][node2] = false
			@_addedEdges[node2][node1] = false

			@_sigmaInstance.dropEdge("#{node1}_#{node2}")#.draw()
			@_sigmaInstance.dropEdge("#{node2}_#{node1}")#.draw()
			
	window.App = new App.NodeGraph
