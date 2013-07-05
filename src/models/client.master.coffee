define [
	'./client._'
	], ( Client ) ->

	# This class is a server side representation of a master client
	#

	class Client.Master extends Client

		# This method will be called from the baseclass when it has been constructed.
		#
		initialize: ( ) ->