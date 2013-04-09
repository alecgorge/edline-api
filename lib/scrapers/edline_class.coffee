cheerio = require 'cheerio'
Cache = require '../cache'
logger	= require 'winston'
async = require 'async'

class EdlineClass
	constructor: (@id, @user) ->
		@cache = @user.cache
		@client = @user.client

		@cache_name = ["classes", @id, "information"]

		@_data = null

	save_data: (data) ->
		@_data = data
		@cache.set @cache_name, data,(err, resp) ->
			false
		, Cache.durations.CLASS_DURATION

	request_class: (cb) ->
		_do = () =>
			c = @user.request.get
					uri: @id
					followRedirect: true
				, (err, res, body) ->
					cb res, body

		if not @user.isPrimed
			async.series [
				(next) => @user.prime_cookies(next, @user.request),
				(next) => @user.user_homepage(next, @user.request)
			], _do
		else
			_do()

	data: (cb) ->
		if @_data != null
			return cb @_data

		logger.debug "Requesting #{@cache_name.join(',')}"			
		@cache.get @cache_name, (cached) =>
			logger.debug "Class cache? #{cached}"
			if cached != null
				return cb cached

			@request_class (res, class_page) =>
				logger.info "Loaded class."
				$ = cheerio.load class_page

				@save_data {
					teacher: 'not available'
					class_name: $('title').text().trim()
					contents: $('.navList a').map (i, node) ->
						{
							name: $(node).find('.navName').text().trim()
							isFile: false
							id: $(node).attr('href')
						}
					calendar: []
				}

				cb @_data

module.exports = EdlineClass
