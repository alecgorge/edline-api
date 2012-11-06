
require './edline-api/fields'
require 'nokogiri'
require 'date'

class EdlineClass
	def initialize(id, user)
		@id = id
		@cache = user.cache
		@user = user
		@client = user.client
		@url = @id # with mobile site, we get url :D

		@cache_name = ["classes", @id, "information"]

		@data = @cache.get(@cache_name, nil)

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

		c = @client.get @url

		if c.headers['Location'] != nil and c.headers['Location'].ends_with?(".page")
			@user.prime_cookies
			@user.user_homepage

			c = @client.get @url
		end

		while c.headers['Location'] != nil
			c = @client.get c.headers['Location']
		end

		return c
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
		@cache.set(@cache_name, @data, Cache::CLASS_DURATION)
	end

	def fetch_data
		if @data != nil
			self.extract_json unless @extracted == true
			return @data
		end

		class_page = self.request_class

		dom = Nokogiri::HTML(class_page.content)

		begin # we may need to rescue
			@class_name = dom.at_css('title').content.strip

			@data = {
				'teacher' => 'not available',
				'class_name' => @class_name,
				'contents' => dom.css('.navList a').map { |node|
					{
						'name' => node.at_css('.navName').content.strip,
						'isFile' => false,
						'id' => node.attr('href')
					}
				},
				'calendar' => []
			}

			self.save_json
			@extracted = true

			return @data
		rescue => e
			I.increment('errors.invalid.class')

			# gen a temp file for invalid classes
			d = File.join("logs", "invalid_classes", @id)
			if !File.directory?(d)
				FileUtils.mkdir_p(d, :mode => 0777)
			end

			File.open(File.join(d, "info") << ".json", 'w') { |f|
				f.write({
					"id" => @id,
					"username" => @user.username,
					"password" => @user.password,
					"uri" => @url,
					"headers" => class_page.headers,
					"message" => e.message,
					"backtrace" => e.backtrace[0..9]
				}.to_json())
			}

			File.open(File.join(d, "info") << ".html", 'w') { |f|
				f.write(class_page.content)
			}

			$logger.warn "[CLASS] Unhandlable class: %s" % @id

			return {
				'teacher' => 'Alec will look into this',
				'class_name' => 'Error fetching class',
				'contents' => [],
				'calendar' => []
			}
		end
	end
end