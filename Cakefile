fs = require('fs')
exec = require('child_process').exec;
spawn = require('child_process').spawn

source = 'src'
target = 'lib'
keep = ['src', 'package.json', 'README.md', 'Cakefile']

# Builds all files and copies everything into root directory
task 'build', ->
	build()

# Installs all dependencies and builds all files
task 'deploy', ->
	ps = spawn('npm', ['install'])
	ps.stdout.setEncoding('utf8')
	ps.stdout.on('data', ( data ) -> console.log(data))
	build()

# Clears root directory of all built files
task 'clean', ->
	exec("ls | grep -v '#{keep.join('\\|')}' | xargs rm -r")

# Watches for file changes and compiles accordingly
task 'watch', ->
	# Watch for changes in coffee files ...
	coffeeWatcher = spawn('coffee', ['-wco', "./#{target}", "./#{source}"])
	coffeeWatcher.stdout.setEncoding('utf8')
	coffeeWatcher.stdout.on('data', ( data ) -> console.log(data))

	# ... and other files too! Let's build them first ...
	buildOthers()

	# ... and now at the watcher.
	watchTree = require('fs-watch-tree').watchTree
	watchTree source, ( event ) ->
		file = event.name
		if file.indexOf('.coffee') is -1
			destination = file.replace(source, __dirname + '/' + target)

			if event.isDelete()
				remove(destination)

			else 
				if not event.isDirectory()
					copy(file, destination)

				if event.isMkdir()
					makeDir(destination)

build = ( ) ->
	buildCoffee()
	buildOthers()

buildCoffee = ( ) ->
	exec("coffee -c -o #{__dirname}/#{target} #{source}", (stdin, stdout, stderr) -> console.log stderr, stdout)

buildOthers = ( ) ->
	walk "#{source}", (err, results) ->
		throw 'Unexpected build error' if err?
		for result in results
			path = result.split('/')
			path.shift()
			path.pop()
			path = path.join('/');
			ext = result.split('.').pop()
			name = result.split('/').pop()
			if ext isnt 'coffee'
				console.log "mkdir -p ./lib/#{path} && cp #{result} ./lib/#{path}/#{name}"
				exec("mkdir -p ./lib/#{path} && cp #{result} ./lib/#{path}/#{name}")

copy = ( file, destination ) ->
	exec("cp -f '#{file}' '#{destination}'", ->
		date = new Date()
		console.log "#{date.toLocaleTimeString()} - created #{file}"
	)

remove = ( file ) ->
	exec("rm -rf '#{file}'", ->
		date = new Date()
		console.log "#{date.toLocaleTimeString()} - removed #{file}"
	)

makeDir = ( dir ) ->
	exec("mkdir '#{dir}'", ->
		date = new Date()
		console.log "#{date.toLocaleTimeString()} - created #{dir}"
	)

walk = (dir, done) ->
	results = []
	fs.readdir(dir, (err, list) ->
		if (err)
			return done(err)
		pending = list.length
		if (!pending)
			return done(null, results)
		list.forEach((file) ->
			file = dir + '/' + file
			fs.stat(file, (err, stat) ->
				if (stat && stat.isDirectory())
					walk(file, (err, res) ->
						results = results.concat(res)
						if (!--pending)
							done(null, results)
					)
				else
					results.push(file)
					if (!--pending)
						done(null, results)
			)
		)
	)