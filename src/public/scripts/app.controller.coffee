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
					@_boost = true
				)
				$('#boost').on('touchend', (  ) =>
					@_boost = false
				)
				$('#fire').on('touchstart', (  ) =>
					@_fire = true
				)
				$('#fire').on('touchend', (  ) =>
					@_fire = false
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
				@_yaw = Math.round(eventData.alpha)

				orientation =
					roll: @_roll
					pitch: @_pitch
					yaw: @_yaw


				sendBoost = null
				if @_boost is not @_lastBoost
					sendBoost = @_lastBoost = @_boost

				sendFire = null
				if @_fire is not @_lastFire
					sendFire = @_lastFire = @_fire
				

				@node.getPeers()[0].emit('controller.orientation', orientation, sendBoost, sendFire)
			)


			
	window.App = new App.Controller