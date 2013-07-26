define [], ( ) ->
	class WelcomeScreen
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

		showControllerSelection: =>
			@_showFromFile 'controller.html'