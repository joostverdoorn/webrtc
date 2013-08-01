define [
	'public/library/helpers/mixable'
	'public/library/helpers/mixin.eventbindings'
	], ( Mixable, EventBindings ) ->
	class WelcomeScreen extends Mixable

		@concern EventBindings

		constructor: ( context, @forceKeyboard = false ) ->
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

		showWelcomeScreen: ( ) =>
			if @forceKeyboard
				@trigger 'controllerType', 'keyboard'
				return

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
					@_clickHandlerKeyboard = _clickHandler 'mouse'
					@_clickHandlerMobile = _clickHandler 'mobile'

					$('#keyboard').click @_clickHandlerKeyboard
					$('#mobile').click @_clickHandlerMobile
				, =>
					$('#keyboard').unbind 'click', @_clickHandlerKeyboard
					$('#mobile').unbind 'click', @_clickHandlerMobile
					@_clickHandlerKeyboard = null
					@_clickHandlerMobile = null

		showInfoScreen: ( controller ) =>
			if @forceKeyboard
				@hide
				return

			@_showFromFile "info_#{controller}.html"

		showMobileConnectScreen: ( callback ) =>
			@_showFromFile "mobile_qr.html",
				callback

		showPlayerDiedScreen: ( ) =>
			@_showFromFile "player_died.html"

		show: =>
			@container.show()

		hide: =>
			@container.hide()
