
require './edline-api/fields'
require 'httpclient'
require 'sinatra/reloader'
require 'nokogiri'
require './edline-api/messages'
require './edline-api/edline-class'
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
		@client.agent_name = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_3) AppleWebKit/535.19 (KHTML, like Gecko) Chrome/18.0.1025.168 Safari/535.19"
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

	def _find_end_pos(child_classes)
		r_val = child_classes.length - 1

		child_classes.each_with_index { |cl, k|
			if  cl['title'] == 'More Classes...' ||
				cl['title'] == '-'
				r_val = k - 1
				break
			end
		}

		return r_val
	end

	def data
		# check if there is a cache of the classes list
		h = Digest::SHA2.new << @username << ":::" << @password

		cache_name = ["users", h.to_s, "classes"]
		cached = @cache.get(cache_name, nil, Cache::USER_DURATION)

		if cached != nil
			students = cached

			return Messages.success(fetch_students(students))
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

		$logger.info "[CLASS][ORIGINAL] %s" % location

		# valid logins go to the school page. we better fetch that.
		homepage = @client.get location
		
		q = false
		while homepage.headers["Location"] != nil
			location = homepage.headers["Location"]
			homepage = @client.get location
			q = true
		end

		$logger.info "[CLASS][FINAL] %s" % location if q

		begin
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
					students[child['title']] = child_classes[0.._find_end_pos(child_classes)]
				}
			else
				# get the name
				name = dom.at_css('#userShortcuts0 a').content

				child_classes = shortcuts.css('div[type=item]')

				students[name] = child_classes[0.._find_end_pos(child_classes)]
			end

			students.each do |name, student| # student is a NodeSet
				# get all the Edline IDs for the classes
				students[name] = student.map { |node|
					Fields.find_id(node.attr('action'))
				}
			end
		rescue => e
			# gen a temp file for invalid classes
			d = File.join("logs", "invalid_users", @username)
			if !File.directory?(d)
				FileUtils.mkdir_p(d, :mode => 0777)
			end

			File.open(File.join(d, "info") << ".json", 'w') { |f|
				f.write({
					"username" => @username,
					"headers" => homepage.headers,
					"message" => e.message,
					"backtrace" => e.backtrace[0..9]
				}.to_json())
			}

			File.open(File.join(d, "info") << ".html", 'w') { |f|
				f.write(homepage.content)
			}

			$logger.warn "[PRIVATE] Unhandlable user: %s" % @username
 
			return Messages.success({
				@username => [{
					'teacher' => 'Alec will look into this',
					'class_name' => 'Error fetching classes',
					'contents' => [],
					'calendar' => []
				}]
			})
		end

		@cache.set(cache_name, students)

		return Messages.success(fetch_students(students))
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

			begin
				dom = Nokogiri::HTML(page.content)

				if dom.at_css('title').content.strip == 'Please note:'
					return [{
						'date' => Date.new.to_time.utc.to_i,
						'item_id' => '-1',
						'class' => 'No private reports',
						'name' => 'School denied permission'
					}]
				end

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
						'item_id' => Fields.find_id(tds[3].at_css('a')['href']),
						'class' => tds[4].at_css('a').content.strip,
						'name' => name
					})
				}
			rescue => e
				# gen a temp file for invalid classes
				d = File.join("logs", "invalid_private_reports", @username)
				if !File.directory?(d)
					FileUtils.mkdir_p(d, :mode => 0777)
				end

				File.open(File.join(d, "info") << ".json", 'w') { |f|
					f.write({
						"username" => @username,
						"headers" => page.headers,
						"message" => e.message,
						"backtrace" => e.backtrace[0..9]
					}.to_json())
				}

				File.open(File.join(d, "info") << ".html", 'w') { |f|
					f.write(page.content)
				}

				$logger.warn "[PRIVATE] Unhandlable private reports: %s" % @username

				return [{
					'date' => Date.new.to_time.utc.to_i,
					'item_id' => '-1',
					'class' => 'None available.',
					'name' => 'Alec is fixing this. Try later.'
				}]
			end
		end

		@cache.set(['private_reports', @username], cached_data)

		cached_data
	end
end