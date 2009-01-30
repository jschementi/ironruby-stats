require 'rubygems'
require 'sinatra'

set :env, :production
disable :run

log = File.new("log/sinatra.log", "a")
STDOUT.reopen(log)
STDERR.reopen(log)

require 'app'

run Sinatra.application