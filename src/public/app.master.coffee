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
	'./models/node.master'
	], ( App, Node ) ->

	# Master app class
	#

	class App.Master extends App
		
		# This method will be called from the baseclass when it has been constructed.
		# 
		initialize: ( ) ->
			@node = new Node()
			@node.on('slave.add', ( slave ) =>
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
					elem.remove()
				)
			)

	window.App = new App.Master
