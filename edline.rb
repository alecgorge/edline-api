#!/usr/bin/env ruby

# requires sinatra json sinatra-contrib nokogiri httpclient thin
# also need libxml2-dev

development = false

require 'sinatra'
require './messages'
require 'json'
require './user'
require './edline-item'
require './cache'
require 'sinatra/reloader' if development
require 'digest/md5'
require 'uri'

cache = Cache.new('cache', 60 * 60)

module Sinatra

  module BeforeOnlyFilter
    def before_only(routes, &block)
      before do
        routes.map!{|x| x = x.gsub(/\*/, '\w+')}
        routes_regex = routes.map{|x| x = x.gsub(/\//, '\/')}
        instance_eval(&block) if routes_regex.any? {|route| (request.path =~ /^#{route}$/) != nil}
      end
    end
  end

  register BeforeOnlyFilter
end

before_only(['/user', '/user2', '/item', '/file', '/private-reports']) do
	headers "Server" => ""

	if(!params.has_key?("u") || !params.has_key?("p"))
		halt 401, Messages.json, Messages.no_auth_vars.to_json
	else
		@username = params['u']
		@password = params['p']
	end

	content_type :json
end

post '/user' do
	Messages.error("Old version. Please update the app.").to_json
end

post '/user2' do
	user = User.new(@username, @password, cache)

	Messages.success(user.data).to_json
end

post '/item' do
	if params.has_key?("id")
		item = EdlineItem.new(params['id'], User.new(@username, @password, cache))

		return Messages.success(item.fetch_data).to_json
	end
end

post '/private-reports' do
	user = User.new(@username, @password, cache)
	Messages.success(user.private_reports).to_json
end

post '/file' do
	if params.has_key?("file")
		uri = URI::parse(params['file'])
		name = params['file'][7..-1]
		cache_name = ['cache', '__files__'] + name.split('/')
		q = File.join(*cache_name)

		if !File.exists?(q)
			FileUtils.mkdir_p(File.join(cache_name[0..-2]), :mode => 0777)

			user = User.new(@username, @password, cache)
			if !user.isPrimed
				user.prime_cookies

				user.user_homepage # no need to check if valid; it is assumed
								   # to be so if a class is being requested
			end

			file = user.client.get('https://www.edline.net' + params['file'])

			File.open(q, "w+") { |f|
				f.write(file.content)
			}
		end

		return Messages.success({
			'file' => cache_name.join('/')
		}).to_json
	end
end

get '/cache/__files__/*' do
	send_file File.join('cache', '__files__', params[:splat])
end

post '*' do
	Messages.error("Invalid Method").to_json
end

