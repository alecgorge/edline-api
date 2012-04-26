
require './edline-api/fields'
require 'nokogiri'
require 'date'

class EdlineItem
	def initialize(id, user)
		@id = id
		@user = user
		@type = "html"
		@content = "<p>Well this is odd. I shouldn't be here.</p>"
		@client = user.client
		@cache = user.cache
		@cache_file = ["items", @id, "payload"]

		@fetched = false

		p = @cache.get(@cache_file, nil, Cache::ITEM_DURATION)

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

		# let's see if we already have the path to class cached
		cache_name = ["items", @id, "url"]
		url = @cache.get(cache_name, nil, Cache::ITEM_URL_DURATION)

		if url == nil
			# unfortunately, cache miss so we have to make a POST and follow the redirect
			# also we will save it for later
			url = @cache.set(cache_name,
							 Fields.submit_event(@client, Fields.item_fields(@id))
							 	   .headers["Location"])
		end

		c = @client.get(url,
						:header => {'Referer' => 'https://www.edline.net/pages/Brebeuf'})

		while c.headers['Location'] != nil
			c = @client.get(c.headers['Location'])
		end

		return c
	end

	def _data
		p = {
			'type' => @type,
			'content' => @content
		}

		if !@fetched
			@cache.set(@cache_file, p)
			@fetched = true
		end

		return p
	end

	def fetch_data
		if @fetched
			return _data
		end

		item_page = self.request_item

		dom = Nokogiri::HTML(item_page.content)

		# check for a HTML view
		html_block = dom.at_css('#DocViewBoxContent')
		if html_block != nil
			@type = 'html'
			@content = {
				'title' => dom.at_css('#edlDocViewBoxAreaTitleSpan').content.strip,
				'content' => html_block.content
			}

			return _data
		end

		# check for iframe'd content (usually grades)
		iframe_block = dom.at_css('#docViewBodyFrame')
		if iframe_block != nil
			@type = 'iframe'
			@content = {
				'content' => @client.get(iframe_block['src']).content
			}

			return _data
		end

		# check for a directory listing
		dir = dom.at_css('#fsvItemsTable')
		if dir != nil
			@type = 'folder'
			@content = []

			dir.css('a').each { |link|
				isFile = link['href'][0..6] == '/files/'
				title = link.content.strip
				id = isFile ?
						link['href'] :
						link['href'][22,19] # from pos 22 for 19 chars

				@content.push({
					'name' => title,
					'isFile' => isFile,
					'id' => id
				})
			}

			return _data
		end

		{
			'type' => @type,
			'content' => @content
		}
	end
end