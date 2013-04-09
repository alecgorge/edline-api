memcache = require 'memcache'
logger	 = require 'winston'
crypto	 = require 'crypto'
_		 = require 'underscore'

md5 = (txt) ->
	return crypto.createHash('md5').update(txt).digest("hex")

class Cache
	@durations:
		USER_DURATION 		: 60 * 60 * 24 * 7 * 2 	# 2 weeks
		CLASS_DURATION 		: 60 * 60 * 8 			# 8 hours
		CLASS_URL_DURATION 	: 60 * 60 * 24 * 7 * 2 	# 2 weeks
		ITEM_URL_DURATION 	: 60 * 60 * 24 * 7 * 2 	# 2 weeks
		ITEM_DURATION 		: 60 * 60 * 2			# 2 hours
		REPORT_DURATION		: 60 * 60 * 2			# 2 hours

	constructor: (host, port, defaultDuration) ->
		@duration = Cache.durations.ITEM_DURATION
		@shouldCache = true
		@shouldFlatten = true

		@setupClient new memcache.Client(port, host)

	setupClient: (client) ->
		@client = client

		return if not @shouldCache

		client.on 'connect', () ->
			logger.info "Connected to the memcache server on #{client.host}:#{client.port}"

		client.on 'close', () ->
			logger.warn "Closed connection to the memcache server on #{client.host}:#{client.port}"

		client.on 'timeout', () ->
			logger.error "Socket timeout error to the memcache server on #{client.host}:#{client.port}"

		client.on 'error', (e) ->
			logger.error "Error with the memcache server on #{client.host}:#{client.port}:"
			logger.error e

		logger.info 'Attempting to connect to memcache server...'
		client.connect()

	key: (parts) ->
		parts = parts.join('.') if parts.join?

		return md5 parts

	get: (name, _default = null, cb = null) ->
		key = @key name

		if _.isFunction _default
			cb = _default
			_default = null

		return cb(_default) if not @shouldCache

		@client.get key, (err, res) ->
			logger.error(e) if err

			res = JSON.parse(res) if res
			res = _default if not res

			cb res

	set: (name, value, length = @duration, cb = false) ->
		# logger.debug "Setting #{name} to #{JSON.stringify(value)}"

		key = @key name

		if _.isFunction length
			cb = length
			length = @duration

		if not @shouldCache
			cb(null, true) if _.isFunction cb
			return

		if not _.isString value
			value = JSON.stringify value

		cb(null, value) if _.isFunction cb
		@client.set key, value, (err, res) ->
			logger.error(e) if err
		, length
		return

module.exports = Cache