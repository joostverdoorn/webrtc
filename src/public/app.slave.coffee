require [
	'./app._'
	'./models/peer.master'
	], ( App, Master ) =>

	# Slave app class
	#

	class App.Slave extends App

		type: 'slave'

		# This method will be called from the baseclass when it has been constructed.
		# 
		initialize: ( ) ->
			@server.on('master.add', ( id ) =>
				@_master = new Master(id)

				@_master.on('peer.channel.opened', ( ) =>
					_pingInterval = setInterval(( ) =>
						@_master.ping( ( latency ) =>
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

							@_master.emit('peer.orientation', orientation)

							$('.roll').html(@_roll)
							$('.pitch').html(@_pitch)
							$('.yaw').html(@_yaw)	
						)


					$(".custom").keyup =>
						@_custom = $(".custom").val()
						customValue = value: @_custom
						@_master.emit('peer.custom', customValue)

				)
			)

	window.App = new App.Slave
