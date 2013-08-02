define [
	'public/library/helpers/mixable'
	'public/library/helpers/mixin.eventbindings'
	'qrcode'
	], ( Mixable, EventBindings, QRCode ) ->
	class InfoScreen extends Mixable

		@concern EventBindings

		# Creates a InfoScreen in the DOM that can show information to the player
		#
		# @param context [jQuery DOM-object] The object to add this info view to.
		# @param forceKeyboard [Boolean] Force to use the keyboard as input without showing the selection screen
		#
		constructor: ( context, @forceKeyboard = false ) ->
			@views = {}
			$('head').append('<link rel="stylesheet" type="text/css" href="../stylesheets/infoScreen.css">');

			context.append $ '<div id="info"></div>'
			@container = $ '#info'
			do @showLoadingScreen

		# Load a view from a file, cache it and show it
		#
		# @param file [String] the filename to load
		# @param onShow [Function] function to execute after the view has been shown to the user
		# @param onHide [Function] function to execute just before the view gets replaced by a new one
		#
		_showFromFile: ( file, onShow = (->), onHide = (->) ) =>
			if @_activeScreen
				@_activeScreen()
				@_activeScreen = false

			unless @views[file]
				@container.load "views/infoScreen/#{file}", (contents) =>
					@views[file] = contents
					@_activeScreen = onHide
					onShow()
				return

			@container.html @views[file]
			@_activeScreen = onHide
			onShow()

		# Shows a loading screen to the user
		#
		showLoadingScreen: =>
			@_showFromFile 'loading.html'

		# Shows a welcome screen to the user that the user can click away to get to the controller selection
		#
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

		# Shows the controller selection screen; choices are Keyboard/Mouse and Mobile Phone
		#
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

		# Shows explanation on how to play the game
		#
		# @param controller [String] the controllertype
		#
		showInfoScreen: ( controller ) =>
			if @forceKeyboard
				@hide
				return

			@_showFromFile "info_#{controller}.html"

		# Shows the QR code to connect via mobile phone
		#
		# @param url [String] URL that after visiting connects to this user
		#
		showMobileConnectScreen: ( url ) =>
			@_showFromFile "mobile_qr.html", =>
				$('#controllerQRCodeImage').qrcode(url)
				$('#controllerQRCodeLink').html("<a href=\"#{url}\">#{url}</a>")

		# Tells the user that he died and how to respawn
		#
		showPlayerDiedScreen: ( ) =>
			@_showFromFile "player_died.html"

		# Shows the InfoView
		#
		show: =>
			@container.show()

		# Hides the InfoView
		#
		hide: =>
			@container.hide()
