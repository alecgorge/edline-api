express = require 'express'

Cache	= require './cache'
authMiddleware = require './middleware/auth'
EdlineUser = require './scrapers/edline_user'
EdlineItem = require './scrapers/edline_item'
EdlineFile = require './scrapers/edline_file'
request = (require './scrapers/customized_request').httpClient()

winston = require 'winston'
cache = new Cache "edline-api.alecgorge.com", 11211

winston.loggers.add 'invalid',
	file:
		filename: 'invalid.log'

winston.exitOnError = false
winston.handleExceptions new winston.transports.File filename: 'exceptions.log'

class Server
	constructor: ()->
		@date = new Date
		@uCount = 0
		@iCount = 0
		@app	= express()
#		@app.use '/cache/__files__', express.directory(__dirname + '/../cache/__files__')
		@app.use '/cache/__files__', express.static(__dirname + '/../cache/__files__')
		@app.use express.bodyParser()

		@app.post '/user2', authMiddleware(), (req, res) ->
			@uCount += 1

			winston.debug "Number #{@uCount}/#{@uCount+@iCount} since #{@date}: Got a request for #{req.body.u}"

			user = new EdlineUser req.body.u, req.body.p, cache

			user.data (json) ->
				winston.debug "Got a response for #{req.body.u}!"

				res.json json

		@app.post '/item', authMiddleware(), (req, res) ->
			@iCount += 1

			winston.debug "Number #{@iCount}/#{@uCount+@iCount} since #{@date}: Got a request for #{req.body.u} -> #{req.body.id}"

			user = new EdlineUser req.body.u, req.body.p, cache
			item = new EdlineItem req.body.id, user

			item.data (json) ->
				winston.debug "Got an item response for #{req.body.u} -> #{req.body.id}"

				res.json json

		@app.post '/file', authMiddleware(), (req, res) ->
			winston.debug "Got a file request"

			if req.body.file?
				EdlineFile.fetch_file cache, req.body.file, request, (j) =>
					res.json Messages.success j
			else
				res.json Messages.error "Missing file param"

	start: (port = 3081) ->
		@app.listen port

module.exports = "Server": Server