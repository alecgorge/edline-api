
class Fields
	def self.login_fields(u,p)
		{
			'loginEvent' 	=> 1,
			'un' 			=> u,
			'kscf'			=> p,
			'login'			=> 'Log In'
		}
	end

	def self.class_fields(id, user_id)
		self.event_fields('myClassesResourceView',
						  "TCNK=headerComponent;targetResEntid=#{id};targetViewAsUserEntid=#{user_id}") 
	end

	def self.item_fields(id)
		self.event_fields('contentsResourceView', "TCNK=contentsBoxComponent;targetResEntid=#{id}");
	end

	def self.event_fields(invokeEvent, eventParams)
		{
			'invokeEvent' 	=> invokeEvent,
			'eventParms' 	=> eventParams
		}
	end

	def self.student_classes(viewAsEnt)
		{
			'selectViewAsEvent' => '1',
			'viewAsEntid'		=> viewAsEnt
		}
	end

	def self.doc_fields(id)
		self.event_fields('docView', "TCNK=calendarBoxComponent;targetDocEntid=#{id}")
	end

	def self.private_reports_fields
		self.event_fields('viewUserDocList', "undefined")
	end

	def self.submit_event(client, fields, toURL = 'https://www.edline.net/post/MyClasses.page')
		client.post(toURL,
					:body => fields,
					:header => {'Referer' => 'https://www.edline.net/MyClasses.page'},
					:follow_redirect => false)
	end

	def self.rlViewItm(client, id)
		self.submit_event(client, self.doc_fields(id))
	end

	def self.smart_submit_event(client, id)
		type = false
		if id.index(',') != nil
			type = id[0]
			id = id[2..-1]
		end

		return self.rlViewItm(client, id) if type == "r"
		return self.submit_event(client, self.doc_fields(id)) if type == "d"

		return self.submit_event(client, self.item_fields(id))
	end

	def self.find_id(str)
		m = str.match(/(?:mc|cb|fsv)ViewItm\('([0-9,]+)'/)
		return m[1] unless m == nil

		m = str.match(/rlViewItm\('([0-9]+)'/)
		return "r," << m[1] unless m == nil

		# javascript:submitEvent('docView', 'TCNK=calendarBoxComponent;targetDocEntid=573652239356711700')
		m = str.match(/targetDocEntid=([0-9]+)/)
		return "d," << m[1] unless m == nil

		# match direct links to things
		return "u," << str unless (str =~ URI::regexp).nil?

		raise "Unable to grok dis id: %s" % str
	end
end