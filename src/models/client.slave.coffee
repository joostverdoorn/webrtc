Client = require('./client._')

# This class is a server side representation of a slave client
#

class Client.Slave extends Client

	# This method will be called from the baseclass when it has been constructed.
	#
	initialize: ( ) ->
		console.log 'new slave'

module.exports = Client.Slave