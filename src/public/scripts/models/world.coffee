define [
	'public/scripts/helpers/mixable'
	'public/scripts/helpers/mixin.eventbindings'

	'public/scripts/models/entity.player'
	'public/scripts/models/collection'

	'three'
	'public/vendor/scripts/three_lambertoon_a'
	], ( Mixable, EventBindings, Player, Collection, Three ) ->

	# This class manages the game world.
	#
	# @concern EventBindings
	#
	class World extends Mixable

		@concern EventBindings

		# Constructs a new world
		#
		# @param scene [Three.Scene] the scene to draw upon
		#
		constructor: ( @scene ) ->

			@_entities = new Collection()

			light = new THREE.DirectionalLight( 0xffffff, 2 )
			light.position.set( -1, 0, -1 ).normalize()
			@scene.add(light)

			light = new THREE.DirectionalLight( 0xffffff, 2 )
			light.position.set( 1, 0, -1 ).normalize()
			@scene.add(light)

			light = new THREE.DirectionalLight( 0xffffff, 2 )
			light.position.set( 0, 1, 1 ).normalize()
			@scene.add(light)

			light = new THREE.AmbientLight( 0xffffff )
			scene.add( light )

			@player = new Player( ( ) =>
				@add(@player)
			)


		add: ( entity ) ->
			@_entities.add(entity)
			@scene.add(entity.mesh)

		remove: ( entity ) ->
			@_entities.remove(entity)
			@scene.remove(entity.mesh)


		# Updates the world.
		#
		# @param dt [Float] the time that has elapsed since last update
		#
		update: ( dt ) ->
			entity.update(dt) for entity in @_entities
			@camera
