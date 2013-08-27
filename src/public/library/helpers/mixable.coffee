#
# Copyright (c) 2013, TNO, J. Abbink, K. Grigorjancs, J.P. Verdoorn
# All rights reserved.
#
define ->

	# Mixable class. Will aid in multiple inheritance by applying mixins.
	# Based on code originally written by Derk-Jan Karrenbeld. Licensed MIT.
	class Mixable

		@ModuleKeyWords : [ 'extended', 'included' ]

		# Extends a class by adding the properties of the mixins to the class
		#
		# @param classmixins [Object*] the mixins to add
		#
		@extend: ( classmixins... ) ->
			for mixin in classmixins
				for key, value of mixin when key not in Mixable.ModuleKeyWords
					@[ key ] = value

				mixin.extended?.apply( @ )

			return @

		# Includes mixins to a class by adding the properties to the Prototype
		#
		# @param  instancemixins [Object*] the mixins to add
		#
		@include: ( instancemixins... ) ->
			for mixin in instancemixins
				for key, value of mixin when key not in Mixable.ModuleKeyWords
					@::[ key ] = value

				mixin.included?.apply( @ )

			return @

		# Concerns automagically include and extend a class
		#
		# @param  concerns [Object*] the mixins to add
		#
		@concern: ( concerns... ) ->
			for concern in concerns
				@include concern.InstanceMethods
				@extend concern.ClassMethods

			return @
