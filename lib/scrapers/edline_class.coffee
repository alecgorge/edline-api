cheerio = require 'cheerio'
Cache = require '../cache'
request = require './customized_request'

class EdlineClass
	constructor: (@id, @user) ->
		@cache = @user.cache
		@client = @user.client

		@cache_name = ["classes", @id, "information"]

		@_data = null

	save_data: (data) ->
		@_data = data
		@cache.set @cache_name, (err, resp) ->
			false
		, Cache.durations.CLASS_DURATION

	request_class: (cb) ->
		_do = () =>
			c = request.get
					uri: @id
					followRedirect: true
				, (err, res, body) ->
					cb res, body

		if not @user.isPrimed
			async.series [
				@user.prime_cookies,
				@user.user_homepage
			], _do
		else
			_do()

	data: (cb) ->
		if @_data != null
			return cb @_data

		@cache.get @cache_name, (cached) =>
			if cached
				return cb @_data

			@request_class (res, class_page) =>
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
