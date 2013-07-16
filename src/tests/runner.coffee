jasmine = require 'jasmine-node'

jasmine.executeSpecsInFolder 
	specFolders: [__dirname + '/spec']
	isVerbose: true
	showColors: true
	useRequireJs: true
	done: ( runner, log ) ->
		if runner.results().failedCount == 0
			process.exit 0
		else
			process.exit 1
