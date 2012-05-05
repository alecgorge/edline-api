
require './edline-api/fields'
require 'nokogiri'
require 'date'

class EdlineClass
	def initialize(id, user)
		@id = id
		@cache = user.cache
		@user = user
		@client = user.client
		@url = "https://www.edline.net/pages/Brebeuf/Classes/" << id

		@cache_name = ["classes", @id, "information"]

		@data = @cache.get(@cache_name, nil,  Cache::CLASS_DURATION)

		self.extract_json

		@extracted = false

		@teacher = "tbd"
		@class_name = "tbd"
		@calendar = []
		@contents = []
	end

	# this is here for efficency to make sure that the user is logged in
	# it is this
	def request_class
		if !@user.isPrimed
			@user.prime_cookies

			@user.user_homepage # no need to check if valid; it is assumed
							   # to be so if a class is being requested
		end

		# fetch this class page
		@client.get @url
	end

	def extract_json
		if @data != nil
			@teacher = @data['teacher']
			@class_name = @data['class_name']
			@contents = @data['contents']
			@calendar = @data['calednar']
			@extracted = true
		end
	end

	def save_json		
		@cache.set(@cache_name, @data)
	end

	def fetch_data
		if @data != nil
			self.extract_json unless @extracted == true
			return @data
		end

		mobile_page = self.request_class

		dom = Nokogiri::HTML(mobile_page.content)

		@class_name = dom.at_css('.mobileTitle').content.strip
		@teacher = "" # this isn't anywhere!

		dir = dom.css('.navItem a')
		dir.each { |link|
			title = link['title']
			id = link['href'].split('/')[6..-1].join('/') # remove everything up to Brebeuf/Classes/

			@contents.push({
				'name' => title,
				'isFile' => false, # we can never tell if stuff is a file anymore
				'id' => id
			})
		}

		@data = {
			'teacher' => @teacher,
			'class_name' => @class_name,
			'contents' => @contents,
			'calendar' => @calendar
		}

		self.save_json
		@extracted = true

		return @data
	end
end