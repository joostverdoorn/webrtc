requirejs.config
	shim:		
		'underscore':
			expors: '_'

		'socket.io':
			exports: 'io'

		'jquery':
			exports: '$'

		'bootstrap': [ 'jquery' ]

	# We want the following paths for 
	# code-sharing reasons. Now it doesn't 
	# matter from where we require a module.
	paths:
		'public': './'

		'underscore': 'vendor/scripts/underscore'
		'jquery': 'vendor/scripts/jquery'
		'bootstrap': 'vendor/scripts/bootstrap'
		'adapter' : 'vendor/scripts/adapter'
		'socket.io': 'socket.io/socket.io'

require [
	'./app._'
	'./models/node.master'
	], ( App, Node ) ->

	# Master app class
	#

	class App.Master extends App
		
		# This method will be called from the baseclass when it has been constructed.
		# 
		initialize: ( ) ->
			@node = new Node()
			@_benchmarks = [[]]
			@node.on('peer.channel.opened', ( slave ) =>
				elem = $('<div><hr /></div>')
				rollBar = $('<div class="progress"><div class="bar roll" style="width: 0%;"></div></div>')
				pitchBar = $('<div class="progress"><div class="bar pitch" style="width: 0%;"></div></div>')
				yawBar = $('<div class="progress"><div class="bar yaw" style="width: 0%;"></div></div>')
				elem.append(rollBar, pitchBar, yawBar)

				$('#slaves').append(elem)

				
			)
			
			@node.on('peer.benchmark', ( id, benchmark ) =>
				num = 0
				for num in [0...@node._peers.length] by 1
					if (@node._peers[num].id == id)
						node  = @node._peers[num].node
				
				time = Math.round(@.time())
				@_benchmarks.push(new Array())
				@_benchmarks[num].push(time)
				@_initTime = performance.now()
				if(@_benchmarks[num].length is 12)
					@_benchmarks[num].shift();
					average = _.reduce(@_benchmarks[num],  (memo, num) ->
						 memo + num
					, 0) / @_benchmarks[num].length;
					average = Math.round(average)
					$(".bench").html($(".bench").html() + "<div id='#{node.id}'> Slave <b>#{node.system.osName} - #{node.system.browserName}#{node.system.browserVersion}</b> has a benchmark of #{average} </div>")
			)
			###
			slave.on('peer.orientation', ( orientation ) ->
				rollBar.children('.bar').width("#{100 * ((orientation.roll + 90) / 180)}%")
				pitchBar.children('.bar').width("#{100 * ((orientation.pitch + 90) / 180)}%")
				yawBar.children('.bar').width("#{100* (orientation.yaw / 360)}%")
			)

			slave.on ('peer.custom'), (custom) ->
				$(".custom").text(custom.value)

			slave.on('peer.disconnected', ( ) =>
				elem.remove()
			)
			
			###
	window.App = new App.Master
