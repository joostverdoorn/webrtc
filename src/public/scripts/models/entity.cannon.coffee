define [
	'public/scripts/models/entity._'

	'three'
	], ( Entity, Three ) ->

	# This class implements the cannon hanging from the ufo
	#
	class Entity.Cannon extends Entity

		# Is called from the baseclass' constructor. 
		#
		# @param info [Object] an object containing all info to apply to the player
		#
		initialize: ( @player, info = null ) ->
			@_cannonLoaded = false
			@_cannonBaseLoaded = false

			@mass = 10
			@angularDrag = 5

			@rotateLeft = 0
			@rotateRight = 0
			@rotateUpward = 0
			@rotateDownward = 0

			@_cannonBase = new Three.Mesh()
			
			# Load the cannon mesh.
			@_loader.load('/meshes/cannon.js', ( geometry, material ) =>
				@mesh.geometry = geometry
				@mesh.material = new Three.MeshFaceMaterial(material)
				@player.mesh.add(@mesh)

				# Set the correct rotation order.
				@rotation.order = 'YZX'

				# Hang the cannon 1.1 meters below the UFO.
				@position.y -= 1.1

				# Apply transformations
				@applyInfo(info)

				# Set the loaded state.
				@_cannonLoaded = true
				if @_cannonBaseLoaded
					@loaded = true
			)

			# Load the cannon base mesh.
			@_loader.load('/meshes/cannonBase.js', ( geometry, material ) =>
				@_cannonBase.geometry = geometry
				@_cannonBase.material = new Three.MeshFaceMaterial(material)
				@player.mesh.add(@_cannonBase)

				# Set the loaded state.
				@_cannonBaseLoaded = true
				if @_cannonLoaded
					@loaded = true
			)

		# Updates the physics state of the cannon. Calls baseclass' update after.
		#
		# @param dt [Float] the time that has elapsed since last update was called.
		#
		update: ( dt ) ->
			unless @loaded
				return

			# Add rotational forces.
			@addAngularForce(new Three.Euler(0, .4 * @rotateLeft, 0, 'YXZ'))
			@addAngularForce(new Three.Euler(0, -.4 * @rotateRight, 0, 'YXZ'))
			@addAngularForce(new Three.Euler(0, 0, .4 * @rotateUpward, 'YXZ'))
			@addAngularForce(new Three.Euler(0, 0, -.4 * @rotateDownward, 'YXZ'))

			# Update physics.
			super(dt, false, true)

			# Rotate cannon base y to cannon y
			@_cannonBase.rotation.y = @rotation.y

			# Set a maximal angles for the cannon.
			if @rotation.z > Math.PI / 4
				@rotation.z = Math.PI / 4
			else if @rotation.z < -Math.PI / 3
				@rotation.z = -Math.PI / 3

			if @rotation.y > Math.PI / 2
				@rotation.y = Math.PI / 2
			else if @rotation.y < -Math.PI / 2
				@rotation.y = -Math.PI / 2

			# X axis rotation should not be possible.
			if @rotation.x isnt 0
				@rotation.x = 0

		# Applies information given in an object to the entity.
		#
		# @param info [Object] an object that contains the transformations
		#
		applyInfo: ( info ) =>
			unless info
				return

			super(info)
			
			@rotateLeft = info.rotateLeft
			@rotateRight = info.rotateRight
			@rotateUpward = info.rotateUpward
			@rotateDownward = info.rotateDownward	
			
		# Returns the current info in an object.
		#
		# @return [Object] an object of all the info
		#
		getInfo: ( ) ->
			info = super()
			
			info.rotateLeft = @rotateLeft
			info.rotateRight = @rotateRight
			info.rotateUpward = @rotateUpward
			info.rotateDownward = @rotateDownward			

			return info