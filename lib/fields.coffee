_	= require 'underscore'
url = require 'url'

class Fields
	@login_fields: (u,p) ->
		{
			'loginEvent' 	: 1,
			'un' 			: u,
			'kscf'			: p,
			'login'			: 'Log In'
		}

	@class_fields: (id, user_id) ->
		@event_fields('myClassesResourceView',
						  "TCNK=headerComponent;targetResEntid=#{id};targetViewAsUserEntid=#{user_id}") 

	@item_fields: (id) ->
		@event_fields('contentsResourceView', "TCNK=contentsBoxComponent;targetResEntid=#{id}");

	@event_fields: (invokeEvent, eventParams) ->
		{
			'invokeEvent' 	: invokeEvent,
			'eventParms' 	: eventParams
		}

	@student_classes: (viewAsEnt) ->
		{
			'selectViewAsEvent' : '1',
			'viewAsEntid'		: viewAsEnt
		}

	@doc_fields: (id) ->
		@event_fields('docView', "TCNK=calendarBoxComponent;targetDocEntid=#{id}")

	@private_reports_fields: ->
		@event_fields('viewUserDocList', "undefined")

	@submit_event: (client, fields, toURL = 'https://www.edline.net/post/MyClasses.page', cb = null) ->
		if _.isFunction toURL
			cb = toURL
			toURL = "https://www.edline.net/post/MyClasses.page"

		client.post
			uri: toURL
			form: fields
			header:
				'Referer' : 'https://www.edline.net/MyClasses.page'
		, cb

	@rlViewItm: (client, id, cb) ->
		@submit_event(client, self.doc_fields(id), cb)

	@smart_submit_event: (client, id, cb) ->
		type = false
		if id.indexOf(',') > -1
			type = id[0]
			id = id.substring(2)
	
		return @rlViewItm(client, id, cb) if type is "r"
		return @submit_event(client, @doc_fields(id), cb) if type is "d"

		@submit_event client, @item_fields(id), cb

	@find_id: (str) ->
		m = str.match(/(?:mc|cb|fsv)ViewItm\('([0-9,]+)'/)
		return m[1] unless !m

		m = str.match(/rlViewItm\('([0-9]+)'/)
		return "r," + m[1] unless !m

		# javascript:submitEvent('docView', 'TCNK=calendarBoxComponent;targetDocEntid=573652239356711700')
		m = str.match(/targetDocEntid=([0-9]+)/)
		return "d," + m[1] unless !m

		# match direct links to things
		return "u," + str unless !url.parse(str).protocol

		throw new Exception("Unable to grok dis id: #{str}")

module.exports = Fields
