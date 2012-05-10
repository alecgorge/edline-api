
class Fields
	def self.login_fields(u,p)
		{
			'submitEvent' 		=> 1,
			'TCNK' 				=> 'authenticationEntryComponent',
			'guestLoginEvent' 	=> '',
			'enterClicked' 		=> true,
			'bscf' 				=> '',
			'bscv' 				=> '',
			'targetEntid' 		=> '',
			'ajaxSupported' 	=> 'yes',
			'screenName' 		=> u,
			'kclq' 				=> p
		}
	end

	def self.class_fields(id)
		self.event_fields('myClassesResourceView',
						  "TCNK=headerComponent;targetResEntid=#{id};targetViewAsUserEntid=undefined") 
	end

	def self.item_fields(id)
		self.event_fields('contentsResourceView', "TCNK=contentsBoxComponent;targetResEntid=#{id}");
	end

	def self.event_fields(invokeEvent, eventParams)
		{
			'invokeEvent' 							=> invokeEvent,
			'eventParms' 							=> eventParams,
			'sessionRenewalEnabled' 				=> 'yes',
			'sessionRenewalIntervalSeconds' 		=> '300',
			'sessionRenewalMaxNumberOfRenewals' 	=> '25',
			'sessionIgnoreInitialActivitySeconds' 	=> '90',
			'sessionHardTimeoutSeconds' 			=> '1200',
			'ajaxRequestKeySuffix' 					=> '0'
		}
	end

	def self.doc_fields(id)
		self.event_fields('docView', "TCNK=calendarBoxComponent;targetDocEntid=#{id}")
	end

	def self.private_reports_fields
		self.event_fields('viewUserDocList', "undefined")
	end

	def self.submit_event(client, fields, toURL = 'https://www.edline.net/post/GroupHome.page')
		client.post(toURL,
					:body => fields,
					:header => {'Referer' => 'https://www.edline.net/pages/Brebeuf'},
					:follow_redirect => false)
	end

	def self.rlViewItm(client, id)
		self.submit_event(client, {
			'targetResEntid' => id,
			'resourceViewEvent' => '1'
		}, 'https://www.edline.net/post/UserDocList.page')
	end

	def self.smart_submit_event(client, id)
		type = false
		if id.index(',') != nil
			type = id[0]
			id = id[2..-1]
		end

		if type != false
			if type == "r"
				return self.rlViewItm(client, id)
			elsif type == "d"
				return self.submit_event(client, self.doc_fields(id))
			end
		else
			return self.submit_event(client, self.item_fields(id))
		end
	end

	def self.find_id(str)
		m = str.match(/(?:mc|cb)ViewItm\('([0-9]+)'/)
		return m[1] unless m == nil

		m = str.match(/rlViewItm\('([0-9]+)'/)
		return "r," << m[1] unless m == nil

		# javascript:submitEvent('docView', 'TCNK=calendarBoxComponent;targetDocEntid=573652239356711700')
		m = str.match(/targetDocEntid=([0-9]+)/)
		return "d," << m[1] unless m == nil		

		raise "Unable to grok dis id: %s" % str
	end
end