require.config
	paths:
		'public': '../../public'

require [
	'public/models/node'
	], ( Node ) ->

		describe 'Node', ->
			
			# beforeEach ->

			# 	node = new Node()
			# 	console.log Node, node

			# describe 'when created', ->

			# 	it 'should not be a supernode', ->
			# 		expect(node.isSuperNode).toBe(false)

			# 	# it 'should be a not supernode', ->
			# 	# 	expect(node.isSuperNode).not.toBe(true)