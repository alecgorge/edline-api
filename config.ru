require 'rubygems'
require 'sinatra'
require 'logger'

Dir.mkdir('logs') unless File.exist?('logs')

f = File.open('logs/common.log', File::APPEND)
$logger = Logger.new(f)
$logger.level = Logger::INFO

# Spit stdout and stderr to a file during production
# in case something goes wrong
$stdout.reopen("logs/output.log", "a+")
$stdout.sync = true
$stderr.reopen($stdout)

set :run, false
set :port, 5000
enable :logging

require './edline'

run Sinatra::Application