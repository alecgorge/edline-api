Cache 	= require '../cache'
EdlineClass = require './edline_class'

request = require './customized_request'
logger	= require 'winston'
Messages= require '../messages'
Fields 	= require '../fields'
async	= require 'async'
cheerio = require 'cheerio'
_ 		= require 'underscore'

EdlineItem = require './edline_item'

class EdlineUser
	constructor: (@username, @password, @cache) ->
		@isPrimed = false

	prime_cookies: (next, req = request) =>
		that = @

		logger.debug "Priming cookies..."
		req.get "https://www.edline.net/Index.page", (err, x, y) ->
			logger.debug "...done priming cookies!"

			that.isPrimed = true unless err
			next(err, x, y)

	user_homepage: (next, req = request) ->
		logger.debug "Requesting homepage..."
		req.post
			uri: "https://www.edline.net/post/Index.page"
			form: Fields.login_fields(@username, @password)
			followRedirect: false
			headers:
				"Referer": "https://www.edline.net/Index.page"
		, (err, x, y) ->
			logger.debug "...done requesting homepage!"
			next(err, x, y)

	fetch_students: (students, cb) ->
		s = {}

		async.eachLimit _.keys(students), 2, (name, done) =>
			logger.debug "Fetching all classes for #{name}, max 3 at a time..."
			async.eachLimit students[name], 3, (id, innerDone) =>
				logger.debug "Fetching class (id: #{id})..."

				cl = new EdlineClass id, @
				cl.data (data) ->
					logger.debug "#{id} fetched!"

					s[name] = {} unless s[name]?
					s[name][data['class_name']] unless s[name][data['class_name']]?

					s[name][data['class_name']] = data

					innerDone()
			, () ->
				logger.debug "Done with all classes for #{name}"

				done()
		, () ->
			logger.debug "Done fetching all students!"

			cb(s)


	process_students: ($, students, cb) ->
		logger.debug "Processing #{students.length} students for the edline IDs..."

		# get all the edline IDs
		_.each students, ($listing, name) ->
			students[name] = $listing.find('a').map (v) -> $(this).attr('href')

		logger.debug "Done! #{JSON.stringify(students)}."
		@cache.set ["users", @username, @password, "classes"], students, Cache.durations.USER_DURATION

		logger.debug "Fetching students..."
		@fetch_students students, (total_data) ->
			cb Messages.success total_data

	handle_data: (body, cb) ->
		logger.debug "Got MyClasses.page! Loading cheerio..."
		$ = cheerio.load body

		drop_down = $('form[name=viewAsForm')

		students = {}

		if drop_down # parent. multiple students. ick.
			student_ent_ids = $('select[name=viewAsEntid] option')

			# remove the parent him/herself
			student_ent_ids = student_ent_ids.toArray()
			student_ent_ids.splice(0, 1)
			student_ent_ids = $(student_ent_ids)

			logger.debug "Found a parent with #{student_ent_ids.length} student(s)."

			async.each student_ent_ids, (option, done) ->
				option = $ option

				ent_id = option.attr('value')
				name = option.text().trim()

				logger.debug "Finding classes for #{name}..."
				Fields.submit_event request, Fields.student_classes(ent_id), (err, res, body) ->
					logger.debug "Got #{name}'s classes!"

					$$ = cheerio.load(body)
					students[name] = $$('.navList')
					done()
			, =>
				logger.debug "Done fetching all #{student_ent_ids.length} student(s)' classes."

				@process_students $, students, cb
		else
			logger.debug "Found a student!"

			students[@username] = $('.navList')
			@process_students $, students, cb

	data: (cb) ->
		cache_name = ["users", @username, @password, "classes"]

		_out = @

		logger.debug "Requesting #{cache_name} from cache..."
		@cache.get cache_name, (cached) =>
			if cached
				logger.debug "Cache hit!"
				_out.fetch_students cached, (total_data) ->
					cb Message.success total_data

				return

			logger.debug "Cache miss! Priming cookies..."
			_out.prime_cookies (err, res, body) ->
				_out.isPrimed = true

				logger.debug "Cookies primed! Requesting homepage..."
				_out.user_homepage (err, page, body) ->
					logger.debug "Got homepage! Location header: #{page.headers["location"]}"

					if page.headers["location"] and (page.headers["location"] is "http://www.edline.net/Notification.page" or page.headers["location"].indexOf("error.html") > -1)
						logger.debug "Invalid login! Sending error message."

						_out.isPrimed = false

						return cb Messages.error "Invalid login."

					logger.debug "Valid login! Submitting classes event form..."
					Fields.submit_event request, Fields.event_fields("myClasses", "TCNK=mobileHelper"), (err, page, body) ->
						logger.debug "Submitted! Requesting MyClasses.page..."

						request.get "https://www.edline.net/MyClasses.page", (err, page, body) ->
							_out.handle_data body, cb

module.exports = EdlineUser
