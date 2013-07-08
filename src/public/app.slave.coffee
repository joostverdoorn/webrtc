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
					@node.master.ping( ( latency ) =>
						$('.latency').html(Math.round(latency))
					)
				, 100)

				# benchmark uitvoeren
				for x in [0..11] by 1
					@.bench()
				###
				if window.DeviceOrientationEvent
					window.addEventListener('deviceorientation', (eventData) =>
						@_roll = Math.round(eventData.gamma)
						@_pitch = Math.round(eventData.beta)
						@_yaw = Math.round(eventData.alpha)

						orientation =
							roll: @_roll
							pitch: @_pitch
							yaw: @_yaw

						@node.emit('peer.orientation', orientation)

						$('.roll').html(@_roll)
						$('.pitch').html(@_pitch)
						$('.yaw').html(@_yaw)	
					)
				###
				
			)

		bench: () =>
			sha = "4C48nBiE586JGzhptoOV"
			for i in [0...56] by 1
				sha = CryptoJS.SHA3(sha).toString()
			output = value: sha
			@node.master.emit('peer.benchmark', output)

	window.App = new App.Slave
