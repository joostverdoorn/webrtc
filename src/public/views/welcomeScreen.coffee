define [
	'public/library/helpers/mixable'
	'public/library/helpers/mixin.eventbindings'
	], ( Mixable, EventBindings ) ->
	class WelcomeScreen extends Mixable

		@concern EventBindings

		constructor: ( context ) ->
			@views = {}
			$('head').append('<link rel="stylesheet" type="text/css" href="../stylesheets/welcomeScreen.css">');

			context.append $ '<div id="welcome"></div>'
			@container = $ '#welcome'
			do @showLoadingScreen

		_showFromFile: ( file, onShow = (->), onHide = (->) ) =>
			if @_activeScreen
				@_activeScreen()
				@_activeScreen = false

			unless @views[file]
				@container.load "views/welcomeScreen/#{file}", (contents) =>
					@views[file] = contents
					@_activeScreen = onHide
					onShow()
				return

			@container.html @views[file]
			@_activeScreen = onHide
			onShow()

		showLoadingScreen: =>
			@_showFromFile 'loading.html'

		showWelcomeScreen: =>
			@_showFromFile 'welcome.html', =>
					@_clickHandler = =>
						@showControllerSelection()
					@container.click @_clickHandler
				, =>
					@container.unbind 'click', @_clickHandler
					@_clickHandler = null

		showControllerSelection: =>
			@_showFromFile 'controller.html', =>
					_clickHandler = ( controller ) =>
						=>
							@trigger 'controllerType', controller
					@_clickHandlerKeyboard = _clickHandler 'keyboard'
					@_clickHandlerMobile = _clickHandler 'mobile'

					$('#keyboard').click @_clickHandlerKeyboard
					$('#mobile').click @_clickHandlerMobile
				, =>
					$('#keyboard').unbind 'click', @_clickHandlerKeyboard
					$('#mobile').unbind 'click', @_clickHandlerMobile
					@_clickHandlerKeyboard = null
					@_clickHandlerMobile = null

		showInfoScreen: ( controller ) =>
			@container.hide()
