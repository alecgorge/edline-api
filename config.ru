ENV['RACK_ENV'] = "development"
development = true

require 'rubygems'
require 'sinatra'

if development
	set :server, %w[webrick mongrel thin]
	set :port, 4568
	set :env, :development
else
	set :env, :production
	set :run, false
	set :port, 5000
end

require './edline'

run Sinatra::Application