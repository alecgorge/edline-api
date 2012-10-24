
require './edline-api/fields'
require 'httpclient'
require 'sinatra/reloader'
require 'nokogiri'
require './edline-api/messages'
require './edline-api/edline-class'
require 'digest/sha2'
require 'date'

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
		@client.agent_name = "Mozilla/5.0 (iPhone; CPU iPhone OS 6_0 like Mac OS X) AppleWebKit/536.26 (KHTML, like Gecko) Version/6.0 Mobile/10A5376e Safari/8536.25"
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
		cached = @cache.get(cache_name, nil)

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

		# new tactic. go striaght to brebeuf. it should format things correctly
		Fields.submit_event(@client, Fields.event_fields('myClasses', 'TCNK=mobileHelper'))
		homepage = @client.get "https://www.edline.net/MyClasses.page"

		begin
			# start parsing
			dom = Nokogiri::HTML(homepage.content)

			# check for child selector
			drop_down = dom.at_css 'form[name=viewAsForm]'

			students = {}

			if drop_down != nil # parent
				student_ent_ids = dom.css('select[name=viewAsEntid] option')
				student_ent_ids.shift # remove the parent him/herself

				student_ent_ids.each { |option|
					ent_id = option.attr('value')
					name = option.content.strip

					student_listing = Fields.submit_event(client, Fields.student_classes(ent_id))

					students[name] = Nokogiri::HTML(student_listing.content).at_css '.navList'
				}
			else
				students[@username] = dom.at_css '.navList'
			end

			students.each do |name, listing|
				# get all the Edline IDs for the classes
				students[name] = listing.css('a').map { |node|
					node.attr('href')
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

		@cache.set(cache_name, students, Cache::USER_DURATION)

		return Messages.success(fetch_students(students))
	end

	def private_reports2
		cached_data = @cache.get(['private_reports2', @username], nil)

		if cached_data == nil
			if !isPrimed
				prime_cookies

				user_homepage # no need to check if valid; it is assumed
							  # to be so if a class is being requested
			end

			Fields.submit_event(@client, Fields.event_fields('privateReports', 'TCNK=mobileHelper'))
			page = @client.get "https://www.edline.net/UserDocList.page"

			begin
				# start parsing
				dom = Nokogiri::HTML(page.content)

				# check for child selector
				drop_down = dom.at_css 'form[name=viewAsForm]'

				students = {}

				if drop_down != nil # parent
					student_ent_ids = dom.css('select[name=viewAsEntid] option')
					student_ent_ids.shift # remove the parent him/herself

					student_ent_ids.each { |option|
						ent_id = option.attr('value')
						name = option.content.strip

						student_listing = Fields.submit_event(client, Fields.student_classes(ent_id), "https://www.edline.net/post/UserDocList.page")

						students[name] = Nokogiri::HTML(student_listing.content).at_css '.navContainer'
					}
				else
					students[@username] = dom.at_css '.navContainer'
				end

				cached_data = {}
				students.each do |student_name, listing|
					class_names = listing.css '.navSectionBar'
					sections = listing.css '.navList'

					reports = []
					k = 0
					class_names.each do |v|
						sections[k].css('a').each do |node|
							date = Date.parse(node.at_css('.dateNum').content)
										.to_time
										.utc
										.to_i

							name = ""
							node.at_css('span').children.each do |n|
								if n.text?
									name = n.content.strip
								end
							end
							reports.push({
								'date' => date,
								'item_id' => node.attr('href'),
								'class' => v.content.strip,
								'name' => name
							})
						end
						k = k + 1
					end

					reports.sort! { |x, y|
						x['date'] <=> y['date']
					}.reverse!

					# get all the Edline IDs for the classes
					cached_data[student_name] = reports
				end
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

				return {@username => {
					'date' => Date.new.to_time.utc.to_i,
					'item_id' => '-1',
					'class' => 'None available.',
					'name' => 'Alec is fixing this. Try later.'
				}}
			end
		end

		@cache.set(['private_reports2', @username], cached_data, Cache::REPORT_DURATION)

		cached_data
	end

	def private_reports
		cached_data = @cache.get(['private_reports', @username], nil)

		if cached_data == nil
			if !isPrimed
				prime_cookies

				user_homepage # no need to check if valid; it is assumed
							  # to be so if a class is being requested
			end

			Fields.submit_event(@client, Fields.event_fields('privateReports', 'TCNK=mobileHelper'))
			page = @client.get "https://www.edline.net/UserDocList.page"

			begin
				# start parsing
				dom = Nokogiri::HTML(page.content)

				# check for child selector
				drop_down = dom.at_css 'form[name=viewAsForm]'

				students = {}

				students[@username] = dom.at_css '.navContainer'

				cached_data = []
				students.each do |student_name, listing|
					class_names = listing.css '.navSectionBar'
					sections = listing.css '.navList'

					reports = []
					k = 0
					class_names.each do |v|
						sections[k].css('a').each do |node|
							date = Date.parse(node.at_css('.dateNum').content)
										.to_time
										.utc
										.to_i

							name = ""
							node.at_css('span').children.each do |n|
								if n.text?
									name = n.content.strip
								end
							end
							reports.push({
								'date' => date,
								'item_id' => node.attr('href'),
								'class' => v.content.strip,
								'name' => name
							})
						end
						k = k + 1
					end

					reports.sort! { |x, y|
						x['date'] <=> y['date']
					}.reverse!

					# get all the Edline IDs for the classes
					cached_data = reports
				end
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

				return {" " => {
					'date' => Date.new.to_time.utc.to_i,
					'item_id' => '-1',
					'class' => 'None available.',
					'name' => 'Alec is fixing this. Try later.'
				}}
			end
		end

		@cache.set(['private_reports', @username], cached_data, Cache::REPORT_DURATION)

		cached_data
	end
end