
require './fields'
require 'httpclient'
require 'sinatra/reloader'
require 'nokogiri'
require './edline-class'
require 'digest/sha2'

class User
	attr_accessor :isPrimed
	attr_accessor :client
	attr_accessor :cache
	attr_accessor :username
	attr_accessor :password

	def initialize(u, p, c)
		@username = u
		@password = p

		@cache = c
		@client = HTTPClient.new
		@client.follow_redirect_count = 10

		@isPrimed = false # if loaded from cache, but a class needs a reload
	end

	def cookie_name
		@cache.path("cookies", @username)
	end

	def prime_cookies
		@client.get("https://www.edline.net/Index.page")
		@isPrimed = true
	end

	def user_homepage
		@client.post('https://www.edline.net/post/Index.page',
					 :body => Fields.login_fields(@username, @password),
					 :header => {'Referer' => 'https://www.edline.net/Index.page'},
					 :follow_redirect => false)
	end

	def fetch_students(students)
		s = {}
		students.each do |name, ids|
			s[name] = {}
			ids.each do |id|
				cl = EdlineClass.new(id, self)
				d = cl.fetch_data

				s[name][d['class_name']] = d
			end
		end

		return s
	end

	def data
		# check if there is a cache of the classes list
		h = Digest::SHA2.new << @username << ":::" << @password

		cache_name = ["users", h.to_s, "classes"]
		cached = @cache.get(cache_name, nil, Cache::USER_DURATION)

		if cached != nil
			students = cached

			return fetch_students(students)
		end

		# we need to load the homepage to make sure the cookies are behaving correctly
		self.prime_cookies

		# now actually login and look for classes
		page = self.user_homepage
		location = page.headers["Location"]

		# invalid logins get redirected to a notification page
		if location == "http://www.edline.net/Notification.page"
			@isPrimed = false
			return Messages.error "Invalid Login";
		end

		# valid logins go to the school page. we better fetch that.
		homepage = @client.get location

		# start parsing
		dom = Nokogiri::HTML(homepage.content)

		# looking in the header menu because it is the only place where all the necessary
		# content exists
		shortcuts = dom.at_css '#myShortcutsItem'

		all_people = shortcuts.css('div[type=menu]')

		# holds all the student information
		students = {}

		# detect if parent
		if all_people[0] != nil && all_people[0]['id'].index('userShortcuts') != nil
			# remove the parent, they don't have classes
			all_people.shift

			all_people.each { |child|
				child_classes = child.children.css('div[type=item]')

				separator_position = child_classes.index(child_classes.css('#Separator1')[0]) - 1

				students[child['title']] = child_classes[0..separator_position]
			}
		else
			# get the name
			name = dom.at_css('#userShortcuts0 a').content

			child_classes = shortcuts.css('div[type=item]')

			separator_position = child_classes.index(child_classes.css('#Separator1')[0]) - 1

			students[name] = child_classes[0..separator_position]
		end

		students.each do |name, student| # student is a NodeSet
			# get all the Edline IDs for the classes
			students[name] = student.map { |node|
				node.attr('action').match(/code:mcViewItm\('([0-9]+)'/)[1]
			}
		end

		@cache.set(cache_name, students)

		return fetch_students(students)
	end

	def private_reports
		cached_data = @cache.get(['private_reports', @username], nil, Cache::REPORT_DURATION)

		if cached_data == nil
			if !isPrimed
				prime_cookies

				user_homepage # no need to check if valid; it is assumed
							  # to be so if a class is being requested
			end

			page = Fields.submit_event(@client, Fields.private_reports_fields())

			while page.headers["Location"] != nil
				page = @client.get(page.headers['Location'])
			end

			dom = Nokogiri::HTML(page.content)

			cached_data = []

			dom.css('.ed-formTable tr')[2..-1].each { |row|
				tds = row.css('td')
				name = tds[5].content.strip

				if ['Demographics',
					'Line Schedules',
					'Grid Schedules'].include? name
					next
				end

				date = tds[2].content.strip
				date = Date.new(("20"+date[6, 2]).to_i, # year
							date[0, 2].to_i,			# month
							date[3,2].to_i)				# day
					   .to_time
					   .utc								# make sure everything is the same timezone
					   .to_i

				cached_data.push({
					'date' => date,
					'item_id' => tds[3].at_css('a')['href'][22..-4],
					'class' => tds[4].at_css('a').content.strip,
					'name' => name
				})
			}
		end

		@cache.set(['private_reports', @username], cached_data)

		cached_data
	end
end