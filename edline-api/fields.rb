
class Fields
	def self.login_fields(u,p)
		{
			'loginEvent'	=> '1',
			'un'			=> u,
			'kscf'			=> p,
			'login'			=> "Log In"
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
			'eventParms' 							=> eventParams
		}
	end

	def self.private_reports_fields
		self.event_fields('viewUserDocList', "undefined")
	end

	def self.submit_event(client, fields)
		client.post('https://www.edline.net/post/GroupHome.page',
					:body => fields,
					:header => {'Referer' => 'https://www.edline.net/pages/Brebeuf'})
	end
end