define [
	'./node._'
	'public/models/peer.slave'
	
	'jquery'
	], ( Node, Slave, $ )->

	class Node.Master extends Node

		type: 'master'

		# This method will be called from the baseclass when it has been constructed.
		# 
		initialize: ( ) ->
			@_slaves = []

			@server.on('slave.add', ( id ) =>
				slave = new Slave(@, id)

				elem = $('<div><hr /></div>')
				rollBar = $('<div class="progress"><div class="bar roll" style="width: 0%;"></div></div>')
				pitchBar = $('<div class="progress"><div class="bar pitch" style="width: 0%;"></div></div>')
				yawBar = $('<div class="progress"><div class="bar yaw" style="width: 0%;"></div></div>')
				elem.append(rollBar, pitchBar, yawBar)

				$('#slaves').append(elem)

				slave.on('peer.orientation', ( orientation ) ->
					rollBar.children('.bar').width("#{100 * ((orientation.roll + 90) / 180)}%")
					pitchBar.children('.bar').width("#{100 * ((orientation.pitch + 90) / 180)}%")
					yawBar.children('.bar').width("#{100* (orientation.yaw / 360)}%")
				)

				slave.on ('peer.custom'), (custom) ->
					$(".custom").text(custom.value)

				slave.on('peer.disconnected', ( ) =>
					@_slaves = _(@_slaves).without slave
					elem.remove()
				)

				@_slaves.push(slave)
			)		