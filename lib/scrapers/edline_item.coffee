request = require './customized_request'
Cache 	= require '../cache'
async	= require 'async'
cheerio = require 'cheerio'
url 	= require 'url'
logger	= require 'winston'
Messages= require '../messages'


invalid_logger = (require('winston')).loggers.get('invalid')

EdlineFile = require './edline_file'

class EdlineItem
	constructor: (@id, @user) ->
		@type = "html"
		@content =
			title: "Uh oh"
			content: "This app doesn't know how to handle this. Alec is looking into this and will probably fix it. Eventually."
		@cache = @user.cache
		@cache_file = ["items", @id, @user.username, "payload"]
		@urls = []
		@contents = []
		@headers = []

		@_data = null

	is_edline: (_url) ->
		u = url.parse _url
		if u.hostname
			parts = u.hostname.split('.')
			return true if parts.length > 1 and parts[0] is 'www' and parts[1] is 'edline'
			return true if parts[0] is 'edline'

		return false

	request_item: (cb) ->
		_do = () =>
			logger.debug "User prime state: #{@user.isPrimed}"
			c = request.get
					uri: @id
					header:
						'Referer': 'https://www.edline.net/pages/Brebeuf'
				, (err, res, body) ->
					cb res, body

		if not @user.isPrimed
			logger.debug "User is not primed! Priming..."
			async.series [
				(next) => @user.prime_cookies(next, request),
				(next) => @user.user_homepage(next, request)
			], _do
		else
			_do()

	save_data: (type, content) ->
		@_data = 'type': type, 'content': content

		@user.cache.set @cache_file, @_data, (err, res) ->
			throw err if err
		, Cache.ITEM_DURATION

	data: (cb) ->
		logger.debug "Checking if #{@id} is on edline.net..."
		if not @is_edline(@id)
			logger.debug "It is not!"

			return cb Messages.success type: 'url', content: @id

		if @_data != null
			return cb Messages.success @_data

		@cache.get @cache_file, (cached) =>
			if cached
				return cb Messages.success cached

			logger.debug "Requesting item..."
			@request_item (res, item_page) =>
				logger.debug "...done."

				# some items are dumb and redirect to files
				# WITH MOBILE UI; ALL ARE DUMB.
				if res.headers["location"]?
					logger.debug "Found redirect #{res.headers.location}"
					request res.headers.location, (file_err, file_res, file_data) =>
						file = url.parse(file_res.headers.location).path

						logger.debug "Found file: #{file}"

						EdlineFile.fetch_file @cache, file, request, (json) =>
							@save_data "file", json
							cb Messages.success @_data

					return

				$ = cheerio.load item_page

				$iframe_block = $('#docViewBodyIframe')
				if $iframe_block.length > 0
					logger.debug "Found an iframe: https://www.edline.net#{$iframe_block.attr('src')}"

					request "https://www.edline.net" + $iframe_block.attr('src'), (err, res, iframe_body) =>
						logger.debug "Loaded the iframe!"
						@save_data "iframe", title: $('.mobileTitle').text().trim(), content: iframe_body

						cb Messages.success @_data

					return

				$cal = $('.calContainer')
				if $cal.length > 0
					type = 'calendar'
					content = {}

					$grp = $cal.find('.calGroup').toArray()
					$grp.splice(-1, 1)
					$grp = $($grp).each (i, day) ->
						day = $ day

						return if day.find('.calDateLabel').length == 0

						title = (new Date(day.find('.calDateLabel').text())).toDateString('%a, %b %d, %Y')
						content[title] = day.find('a[href]').map (i, node) ->
							return {
								name: $(node).attr('title')
								item_id: $(node).attr('href')
							}

					@save_data type, content
					cb Messages.success @_data

					return

				$dir = $('.navList')
				if $dir.length > 0
					type = 'folder'
					content = $dir.find('a').map (i, node) ->
						return {
							name: $(node).find('.navName').text().trim()
							isFile: false
							id: $(node).attr('href')
						}

					@save_data type, content
					cb Messages.success @_data

					return

				$content = $('.contentArea')
				if $content.length > 0
					@save_data 'html', content: $content.html()
					cb @_data

					return

				invalid_logger.error(JSON.stringify({
					id: @cache_file,
					username: @user.username
				}))


				cb @content

module.exports = EdlineItem
