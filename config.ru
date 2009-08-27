begin
  require 'rubygems'
rescue LoadError
  require 'rubygems'
end

begin
  gem 'sinatra'
  require 'sinatra'
rescue LoadError
  gem 'sinatra'
  require 'sinatra'
end

set :env, :production
disable :run

log = File.new("log/sinatra.log", "a")
STDOUT.reopen(log)
STDERR.reopen(log)

require 'app'

run Sinatra.application
