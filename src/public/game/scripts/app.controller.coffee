#
# Copyright (c) 2013, TNO, J. Abbink, K. Grigorjancs, J.P. Verdoorn
# All rights reserved.
#
requirejs.config
	baseUrl: '../../'

	shim:
		'kinetic':
			exports: 'Kinetic'

		'kinetic.multitouch': [ 'kinetic', 'touchy', 'underscore' ]

	# We want the following paths for
	# code-sharing reasons. Now it doesn't
	# matter from where we require a module.
	paths:
		'library': './library'
		'game': './game'

		'underscore': 'vendor/scripts/underscore'
		'kinetic': 'vendor/scripts/kinetic.min'
		'touchy': 'vendor/scripts/touchy'
		'kinetic.multitouch': 'vendor/scripts/kinetic.multitouch'

require [
	'game/scripts/app._'
	'library/node'

	'kinetic'
	'touchy'
	'kinetic.multitouch'
	], ( App, Node, Kinetic ) ->

	# Mobile Controller Class
	#
	class App.Controller extends App

		# Initialize the mobile controller to create a new connection to the network and rendder everything
		#
		initialize: ( ) ->
			peerID = @getURLParameter('nodeID')

			@node = new Node()
			@node.server.on('connect', ( ) =>
				@peer = @node.connect(peerID, ( success ) =>
					if success then @node.server.disconnect()
				)
			)

			# Create the container and add it to the document.
			@container = document.createElement 'div'
			@container.id = 'container'
			document.body.appendChild @container

			# Get the width and height of the window.
			@width = window.innerWidth
			@height = window.innerHeight

			# Create Kinetic stage
			@stage = new Kinetic.MultiTouch.Stage
				container: 'container'
				width: @width
				height: @height
				multitouch: true

			# Add controls
			controls = new Kinetic.Layer
			@_setupOrientationControl()
			@_setupFireButton(controls)
			@_setupThrottle(controls)
			@_setupAnalogStick(controls)
			@stage.add(controls)

		# Sets up the listener for the device's orientation.
		#
		# @private
		_setupOrientationControl: ( ) ->
			window.addEventListener('deviceorientation', ( event ) =>
				roll = Math.round(event.beta)
				pitch = Math.round(event.gamma)

				if window.orientation is -90
					roll *= -1
					pitch *= -1

				if pitch < -90
					pitch = -90
				else if pitch > 0
					pitch = 0
				pitch = (pitch + 45) / 45

				if roll < -30
					roll = -30
				else if roll > 30
					roll = 30
				roll = roll / 30

				@peer?.emit('controller.orientation', roll, pitch)
			)

		# Draws the fire button and the logic behind it.
		#
		# @private
		_setupFireButton: ( layer ) ->
			button = new Kinetic.Circle
				radius: 40
				x: @width / 3
				y: @height / 2
				fill: '#bb3333'
				stroke: '#000000'
				strokeWidth: 2
				multitouch: true

			button.on(Kinetic.MultiTouch.TOUCHSTART, ( e ) =>
				@peer?.emit('controller.fire', true)
			)

			button.on(Kinetic.MultiTouch.TOUCHEND, ( e) =>
				@peer?.emit('controller.fire', false)
			)

			layer.add(button)

		# Draws the throttle control and the logic behind it.
		#
		# @private
		_setupThrottle: ( layer ) ->
			defaults =
				width: 80
				height: 40
				x: @width / 8
				y: @height * 4 / 5
				range: @height * 3 / 5

			throttle = new Kinetic.Group
				x: defaults.x
				y: defaults.y
				multitouch:
					draggable: true

			bar = new Kinetic.Rect
				width: defaults.width
				height: defaults.height
				x: -defaults.width / 2
				y: -defaults.height / 2
				fill: 'black'

			touchBar = new Kinetic.Rect
				width: defaults.width
				height: defaults.range
				x: -defaults.width / 2
				y: -defaults.range

			background = new Kinetic.Rect
				width: defaults.width
				height: defaults.range + defaults.height
				x: defaults.x - defaults.width / 2
				y: defaults.y - defaults.range - defaults.height / 2
				fill: '#555555'
				stroke: '#000000'
				strokeWidth: 2
				opacity: .5

			throttle.add(touchBar)
			throttle.add(bar)

			layer.add(background)
			layer.add(throttle)

			emitPosition = ( ) =>
				boost = -(bar.getY() + throttle.getY() - defaults.y + defaults.height / 2) / (defaults.range)
				@peer?.emit('controller.boost', boost)
				console.log 'controller.boost', boost

			throttle.on(Kinetic.MultiTouch.TOUCHSTART, ( e ) =>
				bar.setY(e.y - defaults.y - defaults.height / 2)
				layer.draw()
				emitPosition()
			)

			throttle.on(Kinetic.MultiTouch.DRAGMOVE, ( e ) =>
				throttle.setX(defaults.x)

				if throttle.getY() + bar.getY() > defaults.y - defaults.height / 2
					throttle.setY(defaults.y - bar.getY() - defaults.height / 2)

				else if throttle.getY() + bar.getY() < defaults.y - defaults.range - defaults.height / 2
					throttle.setY(defaults.y - defaults.range - bar.getY() - defaults.height / 2)

				emitPosition()
			)

			throttle.on(Kinetic.MultiTouch.DRAGEND, ( e ) =>
				bar.setY(bar.getY() + throttle.getY() - defaults.y)
				throttle.setY(defaults.y)
				emitPosition()
			)

		# Draws the analog stick and the logic behind it.
		#
		# @private
		_setupAnalogStick: ( layer ) ->
			defaults =
				x: @width * 3 / 4
				y: @height / 2
				range: Math.min(@width / 4, @height / 2) * .8

			analogStick = new Kinetic.Group
				x: defaults.x
				y: defaults.y
				multitouch:
					draggable: true

			circle = new Kinetic.Circle
				radius: 40
				x: 0
				y: 0
				fill: '#000000'

			touchCircle = new Kinetic.Circle
				radius: defaults.range
				x: 0
				y: 0

			background = new Kinetic.Circle
				radius: defaults.range
				x: defaults.x
				y: defaults.y
				fill: '#555555'
				stroke: '#000000'
				strokeWidth: 2
				opacity: .5

			analogStick.add(touchCircle)
			analogStick.add(circle)

			layer.add(background)
			layer.add(analogStick)

			emitPosition = ( ) =>
				x = (circle.getX() + analogStick.getX() - defaults.x) / defaults.range
				y = (circle.getY() + analogStick.getY() - defaults.y) / defaults.range

				@peer?.emit('controller.analog', x, y)

			analogStick.on(Kinetic.MultiTouch.DRAGSTART, ( e ) =>
				circle.setX(e.x - defaults.x)
				circle.setY(e.y - defaults.y)
				emitPosition()
			)

			analogStick.on(Kinetic.MultiTouch.DRAGMOVE, ( e ) =>
				x = analogStick.getX() - defaults.x + circle.getX()
				y = analogStick.getY() - defaults.y + circle.getY()

				if Math.sqrt(x * x + y * y) > defaults.range
					angle = Math.atan2(y, x)

					x = Math.cos(angle) * defaults.range + defaults.x - circle.getX()
					y = Math.sin(angle) * defaults.range + defaults.y - circle.getY()

					analogStick.setX(x)
					analogStick.setY(y)

				emitPosition()
			)

			analogStick.on(Kinetic.MultiTouch.DRAGEND, ( e ) =>
				analogStick.setX(defaults.x)
				analogStick.setY(defaults.y)

				circle.setX(0)
				circle.setY(0)

				emitPosition()
			)

		# Returns a parameter from the url.
		#
		# @param name [String] the parameter to return
		#
		getURLParameter: ( name ) ->
			results = new RegExp('[\\?&]' + name + '=([^&#]*)').exec(window.location.href)
			unless results?
				return null
			else
				return results[1] || 0

	window.App = new App.Controller
