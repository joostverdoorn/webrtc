define [
	'library/helpers/mixable'
	'library/helpers/mixin.eventbindings'

	'jquery'
	'qrcode'
	], ( Mixable, EventBindings, $, QRCode ) ->
	# Informational overlays for over the game
	class Overlay extends Mixable

		@concern EventBindings

		# Creates a InfoScreen in the DOM that can show information to the player
		#
		# @param context [jQuery DOM-object] The object to add this info view to.
		# @param forceKeyboard [Boolean] Force to use the keyboard as input without showing the selection screen
		#
		constructor: ( ) ->
			@stats = {}
			@_statsVisible = false

			$('head').append('<link rel="stylesheet" type="text/css" href="/game/stylesheets/overlay.css">')

			@container = $('<div id="overlay"></div>')
			$('body').append(@container)
			@showLoadingScreen()

		# Load a view from a file, cache it and show it
		#
		# @param name [String] the filename to load
		# @param onShow [Function] function to execute after the view has been shown to the user
		# @param onHide [Function] function to execute just before the view gets replaced by a new one
		#
		display: ( name, onShow = null, onHide = null ) =>
			previousView = $('.view:visible')
			previousView.trigger('hide')
			previousView.hide()

			if $("#view-#{name}").length is 0
				view = $('<div class="view"></div>')
				view.attr('id', "view-#{name}")
				view.on('hide', onHide) if onHide?
				view.load("/game/views/#{name}.html", => onShow?())
				@container.append(view)

			else
				view = $("#view-#{name}")
				view.on('hide', onHide) if onHide?
				view.show()
				onShow?()

			@show()

		# Shows a loading screen to the user
		#
		showLoadingScreen: ->
			@display('loading')

		# Shows a welcome screen to the user that the user can click away to get to the controller selection
		#
		showWelcomeScreen: ( ) ->
			clickHandler = ( ) => @showControllerSelectionScreen()
			onShow = ( ) => @container.click(clickHandler)
			onHide = ( ) => @container.unbind('click', clickHandler)

			@display('welcome', onShow, onHide)

		# Shows the controller selection screen; choices are Keyboard/Mouse and Mobile Phone
		#
		showControllerSelectionScreen: =>
			clickHandlerDesktop = ( ) =>
				@trigger('controller.select', 'desktop')

			clickHandlerMobile = ( ) =>
				@trigger('controller.select', 'mobile')

			onShow = ( ) =>
				@container.find('#select-desktop').click(clickHandlerDesktop)
				@container.find('#select-mobile').click(clickHandlerMobile)

			onHide = ( ) =>
				@container.find('#select-desktop').unbind('click', clickHandlerDesktop)
				@container.find('#select-mobile').unbind('click', clickHandlerMobile)

			@display('controller_selection', onShow, onHide)

		# Shows explanation on how to play the game
		#
		# @param controller [String] the controllertype
		#
		showInfoScreen: ( controller ) =>
			@display("info_#{controller}")

		# Shows the QR code to connect via mobile phone
		#
		# @param url [String] URL that after visiting connects to this user
		#
		showMobileConnectScreen: ( id ) =>
			onShow = ( ) =>
				url = window.location.origin + '/controller/' + id
				$('#controllerQRCode').empty().qrcode(url)
				$('#controllerLink').html("<a href=\"#{url}\">#{url}</a>")

			@display('mobile_connect', onShow)

		# Tells the user that he died and how to respawn
		#
		showPlayerDiedScreen: ( ) =>
			@display('player_died')

		# Sorts all stats by kill/death ratio
		#
		# @param stats [Object] Stats from game
		# @return [Array<Object>] Sorted stats
		# @private
		_sortStats: ( stats ) ->
			sortedStats = []

			for id, stat of stats
				if stat.deaths is 0
					kdr = stat.kills
				else
					kdr = Math.round(stat.kills / stat.deaths * 100) / 100

				sortedStats.push([id, stat.kills, stat.deaths, kdr])

			sortedStats.sort(( a, b ) ->
				b[3] - a[3]
			)

			return sortedStats

		# Update the contents of the stats table on the overlay
		#
		# @param sortedStats [Array<Object>] sorted stats from _sortStats
		# @private
		_updateStatTable: ( sortedStats ) ->
			statRows = $('#statRows')
			statRows.empty()
			rank = 1
			for stat in sortedStats
				statRows.append("<tr><td>#{rank++}</td><td>#{stat[0]}</td><td>#{stat[1]}</td><td>#{stat[2]}</td><td>#{stat[3]}</td></tr>")

		# Display stats to the user
		showStats: ( stats = @stats ) ->
			@_statsVisible = true

			sortedStats = @_sortStats(stats)

			@display('stats', ( ) =>
				@_updateStatTable(sortedStats)
			, ( ) =>
				@_statsVisible = false
			)

		# Set the stats to be shown on the next update
		setStats: ( @stats ) =>
			if @_statsVisible
				sortedStats = @_sortStats(@stats)
				@_updateStatTable(sortedStats)

		# Shows the InfoView
		#
		show: ->
			@container.show()

		# Hides the InfoView
		#
		hide: ->
			previousView = $('.view:visible')
			previousView.trigger('hide')
			previousView.hide()
			@container.hide()
