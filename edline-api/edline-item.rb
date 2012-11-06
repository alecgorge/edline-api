
require './edline-api/fields'
require 'nokogiri'
require 'date'
require 'uri'

class EdlineItem
	def initialize(id, user)
		@id = id
		@url = @id
		@user = user
		@type = "html"
		@content = {
			'title' => "Uh oh",
			'content' => "<p>This app doesn't know how to handle this. Alec is looking into this and will probably fix it. Eventually.</p>"
		}
		@client = user.client
		@cache = user.cache
		@cache_file = ["items", @id, @user.username, "payload"]
		@urls = []
		@contents = []
		@headers = []

		@fetched = false

		p = @cache.get(@cache_file, nil)

		if p != nil
			@fetched = true
			@type = p['type']
			@content = p['content']
		end
	end

	# this is here for efficency to make sure that the user is logged in
	def request_item
		if !@user.isPrimed
			@user.prime_cookies

			@user.user_homepage # no need to check if valid; it is assumed
							   # to be so if a class is being requested
		end

		c = @client.get(@url,
				:header => {'Referer' => 'https://www.edline.net/pages/Brebeuf'})

		@headers = [c.headers]
		@contents = [c.content]
		@urls = [@url]

		return c
	end

	def _data
		p = {
			'type' => @type,
			'content' => @content
		}

		if !@fetched
			@cache.set(@cache_file, p, Cache::ITEM_DURATION)
			@fetched = true
		end

		@urls = []
		@contents = []
		@headers = []

		return p
	end

	def get_host_without_www(url)
		url = "http://#{url}" if URI.parse(url).scheme.nil?
		host = URI.parse(url).host.downcase
		host.start_with?('www.') ? host[4..-1] : host
	end

	def fetch_data
		if get_host_without_www(@id) != 'edline.net'
			return {
				'type' => 'url',
				'content' => @id
			}
		end

		if @fetched
			return _data
		end

		item_page = self.request_item

		# some items are dumb and redirect to files
		# WITH MOBILE UI; ALL ARE DUMB.
		if item_page.headers['Location'] != nil
			second = @client.get item_page.headers["Location"]
			file = URI(second.headers["Location"]).path

			@type = 'file'
			@content = EdlineFile.fetch_file(@cache, file, @user)

			return _data
		end

		dom = Nokogiri::HTML(item_page.content)

		# check for iframe'd content: grades and wysiwyg
		iframe_block = dom.at_css('#docViewBodyIframe')
		if iframe_block != nil
			@type = 'iframe'
			@content = {
				'title' => dom.at_css('.mobileTitle').content.strip,
				'content' => @client.get("https://www.edline.net"+iframe_block.attr('src')).content
			}

			return _data
		end

		cal = dom.at_css '.calContainer'
		if cal != nil
			@type = 'calendar'
			@content = {}
			cal.css('.calGroup')[0...-1].each { |day|
				next if day.at_css('.calDayLabel') == nil
				title = Date.parse(day.at_css('.calDayLabel').content).strftime('%a, %b %d, %Y')
				@content[title] = day.css('.navList a').map { |node| 
					{
						'name' => node.attr('title'),
						'item_id' => node.attr('href')
					}
				}
			}

			return _data
		end

		# check for a directory listing
		dir = dom.at_css('.navList')
		if dir !=nil
			@type = 'folder'
			@content = dir.css('a').map { |node|
				{
					'name' => node.at_css('.navName').content.strip,
					'isFile' => false,
					'id' => node.attr('href')
				}
			}

			return _data
		end

		content = dom.at_css '.contentArea'
		if content != nil
			@type = 'html'
			@content = {
				'content' => content.content
			}

			return _data
		end

		# gen a temp file for invalid thingys
		d = File.join("logs", "invalid_items", @id)
		if !File.directory?(d)
			FileUtils.mkdir_p(d, :mode => 0777)
		end

		File.open(File.join(d, "info") << ".json", 'w') { |f|
			f.write({
				"id" => @id,
				"username" => @user.username,
				"password" => @user.password,
				"uri" => @urls,
				"headers" => @headers
			}.to_json())
		}

		@contents.each_with_index { |v,k|
			File.open(File.join(d, "info") << "_" << k.to_s << ".html", 'w') { |f|
				f.write(v)
			}
		}

		I.increment('errors.invalid.item')

		$logger.warn "[ITEM] Unhandlable item: %s" % @id

		@urls = []
		@contents = []
		@headers = []

		{
			'type' => @type,
			'content' => @content
		}
	end
end