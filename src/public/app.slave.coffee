requirejs.config
	shim:		
		'underscore':
			expors: '_'

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
	'./models/node.slave'
	], ( App, Node ) =>

	# Slave app class
	#

	class App.Slave extends App

		# This method will be called from the baseclass when it has been constructed.
		# 
		initialize: ( ) ->
			@node = new Node()
			@node.on('peer.channel.opened', (master) => 
				console.log 'opened'
				_pingInterval = setInterval(( ) =>
					master.ping( ( latency ) =>
						$('.latency').html(Math.round(latency))
					)
				, 100)

				if window.DeviceOrientationEvent
					window.addEventListener('deviceorientation', (eventData) =>
						@_roll = Math.round(eventData.gamma)
						@_pitch = Math.round(eventData.beta)
						@_yaw = Math.round(eventData.alpha)

						orientation =
							roll: @_roll
							pitch: @_pitch
							yaw: @_yaw

						master.emit('peer.orientation', orientation)

						$('.roll').html(@_roll)
						$('.pitch').html(@_pitch)
						$('.yaw').html(@_yaw)	
					)

				$(".custom").keyup =>
					@_custom = $(".custom").val()
					customValue = value: @_custom
					master.emit('peer.custom', customValue)
			)

	window.App = new App.Slave
