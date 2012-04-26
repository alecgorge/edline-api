require 'rubygems'
require 'sinatra'

set :env, :production
set :run, false

require './edline'

run Sinatra::Application