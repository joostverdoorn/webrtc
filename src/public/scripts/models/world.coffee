define [
	'public/scripts/helpers/mixable'
	'public/scripts/helpers/mixin.eventbindings'

	'three'
	], ( Mixable, EventBindings, Three ) ->

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

			radius = 50
			segments = 16
			rings = 16

			material = new THREE.MeshLambertMaterial
				color: 0x339933
				shading: Three.SmoothShading

			light = new THREE.DirectionalLight( 0xefefff, 2 )
			light.position.set( -1, 0, -1 ).normalize()
			@scene.add(light)

			light = new THREE.DirectionalLight( 0xffefef, 2 )
			light.position.set( 1, 0, -1 ).normalize()
			@scene.add(light)

			light = new THREE.DirectionalLight( 0x888888, 2 )
			light.position.set( 0, 1, 1 ).normalize()
			@scene.add(light)

			@loader = new Three.JSONLoader()	
			@loader.load('/meshes/ufo.js', ( geometry, materials ) =>
				mesh = new Three.Mesh(geometry, new THREE.MeshFaceMaterial( materials ))
				mesh.scale.set(25, 25, 25)
				mesh.rotation.y = Math.PI / 3
				@scene.add(mesh)

				@player = mesh
			)


		# Updates the world.
		#
		# @param dt [Float] the time that has elapsed since last update
		#
		update: ( dt ) ->
			@player?.rotation.y += .01
