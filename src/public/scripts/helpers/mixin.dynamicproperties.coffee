define ->

	# Mixin for classes that allow dynamic properties
	#
	# @mixin
	#
	DynamicProperties =

		ClassMethods: {}

		InstanceMethods:

			# Defines setters from an object of properties mapped to function calls
			#
			# @param setters [Object] the object of setters
			#
			setter: ( setters ) ->
				for key, setter of setters
					@_defineProperty(key)
					@_setters[key] = setter

			# Defines getters from an object of properties mapped to function calls
			#
			# @param getters [Object] the object of getters
			#
			getter: ( getters ) ->
				for key, getter of getters
					@_defineProperty(key)
					@_getters[key] = getter

			# Defines object properties from an object of properties
			#
			# @param properties [Object] the object of properties
			#
			property: ( properties ) ->
				for key, property of properties
					Object.defineProperty(@, key, property)

			# Defines default setters and getters for key
			#
			# @param key [String] the key for which to add setters and getters
			#
			_defineProperty: ( key ) ->
				unless @_setters?
					@_setters = {}

				unless @_getters?
					@_getters = {}

				unless @_setters[key]? and @_getters[key]?
					try
						Object.defineProperty(@, key,
							set: ( value ) =>
								return @_setters[key].apply( @, [ value ] )

							get: ( ) =>
								return @_getters[key].apply( @ )
						)

						return true
					catch e # Just return false
				return false

