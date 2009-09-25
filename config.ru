require 'rubygems'
require 'sinatra'
require './app'

set :environment, :production
set :run, false

log = File.new("/home/iruby/ironruby.info/log/sinatra.log", "a+")
STDOUT.reopen(log)
STDERR.reopen(log)

run Sinatra::Application

