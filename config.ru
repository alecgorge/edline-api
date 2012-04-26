require 'rubygems'
require 'sinatra'

set :env, :production
set :run, false
set :port, 4567

require './edline'

run Sinatra::Application