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
	'library/node'
	'jquery'
	], ( App, Node, $ ) ->

	# Mobile Controller Class
	#

	class App.Controller extends App
		
		# This method will be called from the baseclass when it has been constructed.
		# 
		initialize: ( ) ->
			@node = new Node()
			@_boost = false
			@_lastBoost = false
			@_fire = false
			@_lastFire = false

			nodeId =  @getURLParameter("nodeId")
			@node.server.on('connect', ( ) =>
				@node.connect(nodeId)
			)
			@node._peers.on('channel.opened', ( ) =>

				@node.server.disconnect()
				@node.server = null

				if window.DeviceOrientationEvent
					setTimeout( @sendDeviceOrientation, 100)

				$('#boost').on('touchstart', (  ) =>
					@sendBoostEvent(true)
				)
				$('#boost').on('touchend', (  ) =>
					@sendBoostEvent(false)
				)
				$('#fire').on('touchstart', (  ) =>
					@sendFireEvent(true)
				)
				$('#fire').on('touchend', (  ) =>
					@sendFireEvent(false)
				)

				$('#poke').on('touchmove', ( event ) =>
					touch = event.originalEvent.touches[0]
					console.log touch.pageY
				)



			)

			


		getURLParameter: (name) ->
			results = new RegExp('[\\?&]' + name + '=([^&#]*)').exec(window.location.href)
			unless results?
				return null
			else
				return results[1] || 0

		sendDeviceOrientation: ( ) =>
			window.addEventListener('deviceorientation', (eventData) =>
				@_roll = Math.round(eventData.gamma)
				@_pitch = Math.round(eventData.beta)

				orientation =
					roll: @_roll
					pitch: @_pitch

				@node.getPeers()[0].emit('controller.orientation', orientation)
			)

		sendBoostEvent: ( boost ) ->
			if boost is not @_lastBoost
				@_lastBoost = boost
				@node.getPeers()[0].emit('controller.boost', boost)

		sendFireEvent: ( fire ) ->
			if fire is not @_lastFire
				@_lastFire = fire
				@node.getPeers()[0].emit('controller.fire', fire)


	window.App = new App.Controller