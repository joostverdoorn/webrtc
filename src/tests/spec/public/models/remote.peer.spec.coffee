require.config
	paths:
		'public': '../../public'

require [
	'public/models/remote.peer'
	], ( Peer ) ->

	describe 'Remote.Peer', ->

		remote = null
		fakeController = null

		# Fake RTCPeerConnection object to prevent actually connecting with something
		fakeRTC = null

		beforeEach ->

			class FakeRTCDataChannel
				onmessage: ->
				onopen: ->
				onclose: ->
				onmessage: ->


			class FakeRTCPeerConnection
				iceConnectionState: null

				onicecandidate: ->
				oniceconnectionstatechange: ->
				ondatachannel: ->
					new FakeRTCDataChannel()

				createDataChannel: ->
					new FakeRTCDataChannel()
				createOffer: ->
				close: ->
				setLocalDescription: ->
				setRemoteDescription: ->
				createAnswer: ->
				addIceCandidate: ->

			class FakeController

				class FakeServer
					emitTo: ->
				
				constructor: ->		
					@server = new FakeServer()

				id: '1'
				query: ->
				relay: ->

			fakeController = new FakeController()

			remote = new Peer(fakeController, '1', true, FakeRTCPeerConnection)

		describe 'test', ->
			it 'test', ->