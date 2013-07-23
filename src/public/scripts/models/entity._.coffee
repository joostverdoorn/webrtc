define [ 
	'public/scripts/helpers/mixable'
	'public/scripts/helpers/mixin.eventbindings'

	'three'
	], ( Mixable, EventBindings, Three ) ->



	# Baseclass for all physics entities
	#
	class Entity extends Mixable
		@concern EventBindings

		# Constructs a new basic physics entity. Baseclass for other entities.
		# Will call initialize on the subclass.
		#
		# @param args... [Any] any params to pass onto the subclass
		# @param callback [Function] the function to call when the entity is loaded
		#
		constructor: ( @scene, args... ) ->
			@_loader = new Three.JSONLoader()

			@mass = 1
			@drag = .5
			@angularDrag = 1

			@velocity = new Three.Vector3(0, 0, 0)
			@angularVelocity = new Three.Vector3(0, 0, 0)
			
			@forces = []
			@angularForces = []

			@mesh = new Three.Mesh()
			@position = @mesh.position
			@rotation = @mesh.rotation

			@initialize?.apply(@, args)

		# Removes the mesh from the scene.
		#
		die: ( ) ->
			@scene.remove(@mesh)

		# Adds a force to the forces stack. Forces will be applied next update.
		#
		# @param vector [Three.Vector3] the vector force to add
		#
		addForce: ( vector ) ->
			@forces.push(vector)

		# Adds an angular force to the forces stack. Forces will be applied next update.
		#
		# @param vector [Three.Vector3] the vector force to add
		#
		addAngularForce: ( vector ) ->
			@angularForces.push(vector)

		# Updates the entity by applying forces, calculating the resulting velocity
		# and setting the entity's position and rotation.
		#
		# @param dt [Float] the time that has elapsed since last update
		#
		update: ( dt, updatePosition = true, updateRotation = true ) ->			
			# Apply forces ...
			if updatePosition				
				while force = @forces.pop()
					acceleration = force.clone().multiplyScalar(force.length() / @mass)
					@velocity.add(acceleration)

				# Calculate the drag force. We assume a fluid density of 1.2 (air at 20 degrees C)
				# and a cross-sectional area of 10
				dragForce = @velocity.clone().normalize().negate().multiplyScalar(.5 * 1.2 * @drag * Math.pow(@velocity.length() / @mass, 2) * 10)
				@velocity.add(dragForce)

				@position.x += @velocity.x * dt
				@position.y += @velocity.y * dt
				@position.z += @velocity.z * dt

			# ... and rotational forces.
			if updateRotation
				while force = @angularForces.pop()
					console.log force
					acceleration = force.clone().multiplyScalar(force.length() / @mass)
					@angularVelocity.add(acceleration)

				@angularVelocity.multiplyScalar(1 - @angularDrag * dt)
				@rotation.x = (@rotation.x + @angularVelocity.x * dt) % (Math.PI * 2)
				@rotation.y = (@rotation.y + @angularVelocity.y * dt) % (Math.PI * 2)
				@rotation.z = (@rotation.z + @angularVelocity.z * dt) % (Math.PI * 2)

		# Applies transformation information given in an object to the entity.
		#
		# @param transformations [Object] an object that contains the transformations
		#
		applyTransformations: ( transformations ) ->
			unless transformations?
				return

			if transformations.velocity?
				@velocity.fromArray(transformations.velocity)

			if transformations.angularVelocity?
				@angularVelocity.fromArray(transformations.angularVelocity)
			
			if transformations.position?
				@position.fromArray(transformations.position)
			
			if transformations.rotation?
				@rotation.fromArray(transformations.rotation)

		# Returns the current transformation information in an object.
		#
		# @return [Object] an object of all the transformations
		#
		getTransformations: ( ) ->
			transformations = 
				velocity: @velocity.toArray()
				angularVelocity: @angularVelocity.toArray()
				position: @position.toArray()
				rotation: @rotation.toArray()

			return transformations