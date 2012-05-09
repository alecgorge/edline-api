require 'rubygems'
require 'sinatra'
require 'logger'

Dir.mkdir('logs') unless File.exist?('logs')

$logger = Logger.new('logs/common.log','weekly')
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