
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

	def self.private_reports_fields
		self.event_fields('viewUserDocList', "undefined")
	end

	def self.submit_event(client, fields)
		client.post('https://www.edline.net/post/GroupHome.page',
					:body => fields,
					:header => {'Referer' => 'https://www.edline.net/pages/Brebeuf'},
					:follow_redirect => false)
	end

	def self.rlViewItm(client, id)
		client.post('https://www.edline.net/post/UserDocList.page',
					:body => {
						'targetResEntid' => id,
						'resourceViewEvent' => '1'
					},
					:header => {'Referer' => 'https://www.edline.net/pages/Brebeuf'},
					:follow_redirect => false)
	end

	def self.find_id(str)
		m = str.match(/mcViewItm\('([0-9]+)'/)

		if m == nil
			m = str.match(/rlViewItm\('([0-9]+)'/)[1]
			return "r," << m
		else
			m = m[1]
			return m
		end
	end
end