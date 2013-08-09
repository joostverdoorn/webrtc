# Browser-based multiplayer gaming using WebRTC

# Notes for SIG
Wij ontwikkelen een library die het mogelijk maakt om meerdere gebruikers dmv. WebRTC met elkaar te verbinden.
Daarnaast ontwikkelen wij als demo-implementatie een spel die deze library gebruikt. Dit spel bevat een aantal classes die (bijna) exact hetzelfde zijn dan in de library. Dit is, omdat wij het spel niet afhankelijk willen maken van code uit de library en de library alleen en vaste interface heeft die andere programma's aan mogen roepen. Daarom wordt deze code niet direct gedeeld.

Verder zijn de twee bestanden app.inspector.coffee en app.map.coffee voor interne testdoeleindenen (visualisatie van de netwerktopologie en visualisatie van alle spelers in de spelwereld) die in het finale product niet aanwezig zullen zijn.

# Build
## Requirements
* NodeJS 0.10.x
* CoffeeScript 1.6.3

##Initial Build
`cake deploy`

##Subsequent builds
`cake build`

##Cleaning
`cake clean`

##Watch for changes
To automatically build the project when a file is changed `cake watch` can be used. This is useful when actively developing to prevent the constant execution of `cake build`.

##Running
`cake run`

This starts a listenserver on `localhost:8080` which responds to `index.html` for the game, `node.html` for a node that connects to other nodes and `inspector.html` for a visualization of the networktopology.

##Tests
`cake test`

This executes all tests and shows the output in the console. For the test-coverage a listenserver on `localhost:8081` is launched which visualizes the covered codelines.
