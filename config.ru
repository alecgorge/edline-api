require 'rubygems'
require 'sinatra'

set :env, :production
set :run, false
set :port, 5000

require './edline'

run Sinatra::Application