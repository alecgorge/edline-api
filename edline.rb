#!/usr/bin/env ruby

# requires sinatra json sinatra-contrib nokogiri httpclient thin
# also need libxml2-dev

development = false

require 'sinatra'
require './edline-api/messages'
require 'json'
require './edline-api/user'
require './edline-api/edline-item'
require './edline-api/edline-file'
require './edline-api/cache'
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

	content_type 'application/json' # charset breaks android
end

post '/user' do
	Messages.error("Old version. Please update the app.").to_json
end

post '/user2' do
	user = User.new(@username, @password, cache)

	user.data.to_json
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
		return Messages.success(EdlineFile.fetch_file(cache, params['file'], User.new(@username, @password, cache))).to_json
	end
end

get '/cache/__files__/*' do
	send_file File.join('cache', '__files__', params[:splat])
end

post '*' do
	Messages.error("Invalid Method").to_json
end

