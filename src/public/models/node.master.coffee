define [
	'./node._'
	'public/models/remote.peer'
	
	'jquery'
	], ( Node, Peer, $ ) ->

	# Master node class
	#

	class Node.Master extends Node

		type: 'master'

		# This method will be called from the baseclass when it has been constructed.
		# For now it does nothing.
		# 
		initialize: ( ) ->
			