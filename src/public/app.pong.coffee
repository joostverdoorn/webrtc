require [
	'app._'
	'models/peer.master'
	], ( App, Masterpong ) =>

	# Pong  app class
	#

	class App.Pong extends App

		type: 'slave'

		# This method will be called from the baseclass when it has been constructed.
		# 
		initialize: ( ) ->
			@server.on('master.add', ( id ) =>
				@_master = new Masterpong(id)

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


						)

				# manage controls on mobile
					$("#play").click =>
						$("#play").toggleClass("icon-pause icon-play")
						status = $("#play").attr("class").indexOf("play");
						button = if status is -1 then "play" else "pause"
						@_master.emit('peer.button',button)


					$("#stop").click =>
						@_master.emit('peer.button', "stop")
					)

					
	

			)

	window.App = new App.Pong
