
require './edline-api/fields'
require 'nokogiri'
require 'date'

class EdlineClass
	def initialize(id, user)
		@id = id
		@cache = user.cache
		@user = user
		@client = user.client
		@url = ""

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

		# let's see if we already have the path to class cached
		cache_name = ["classes", @id, "url"]
		url = @cache.get(cache_name, nil, Cache::CLASS_URL_DURATION)

		if url == nil
			# unfortunately, cache miss so we have to make a POST and follow the redirect
			# also we will save it for later
			url = @cache.set(cache_name,
							 Fields.submit_event(@client, Fields.class_fields(@id))
							 	   .headers["Location"])
		end

		@url = url

		# fetch this class page
		@client.get(url,
					:header => {'Referer' => 'https://www.edline.net/pages/Brebeuf'})
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

		class_page = self.request_class

		dom = Nokogiri::HTML(class_page.content)

		begin # we may need to rescue
			@class_name = dom.at_css('title').content.strip[0..-11] # strip off " Home Page"

			@teacher = dom.at_css('#GroupMessageBoxContent b')
			if @teacher != nil 
				@teacher = @teacher.content.strip
			else
				@teacher = ""
			end

			# get calendar items
			raw_cal = dom.css('#CalendarBoxContent tr')

			raw_cal.each { |row|
				dates = row.css('td.edlEventDateCell')

				# there are blank tr's because of reasons (???)
				next if dates.length == 0

				date = dates[0].content.strip

				date = Date.new(("20"+date[6, 2]).to_i, # year
								date[0, 2].to_i,		# month
								date[3,2].to_i)			# day
						   .to_time
						   .utc							# make sure everything is the same timezone
						   .to_i

				link = row.css('td.edlEventContentCell a')[0]

				isFile = link['href'][0..6] == '/files/'

				title = link.content.strip

				id = isFile ? link['href'] : link['href'][76,19] # from pos 76 for 19 chars

				@calendar.push({
					'name' => title,
					'isFile' => isFile,
					'id' => id,
					'date' => date
				})
			} unless raw_cal.length == 0

			# get contents
			raw_contents = dom.css('#ContentsBoxContent div.edlBoxListItem a')

			raw_contents.each { |link|
				isFile = link['href'][0..6] == '/files/'

				title = link.content.strip

				id = isFile ? link['href'] : link['href'][22,19] # from pos 22 for 19 chars

				@contents.push({
					'name' => title,
					'isFile' => isFile,
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
		rescue
			# gen a temp file for invalid classes
			d = File.join("logs", "invalid_classes", @id)
			if !File.directory?(d)
				FileUtils.mkdir_p(d, :mode => 0777)
			end

			File.open(File.join(d, "info") << ".json", 'w') { |f|
				f.write({
					"id" => @id,
					"username" => @user.username,
					"uri" => @url,
					"headers" => class_page.headers
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