REPO = "c:/dev/dlr"
RB = "#{REPO}/Merlin/Main/Languages/Ruby"
BIN = "#{REPO}/Merlin/Main/Bin/debug"

require 'fileutils'
require 'mymath'
require 'benchmark'
require 'pp'

#
# Stat gathering
#

def build
  puts "Building IronRuby"
  Benchmark.measure do
    FileUtils.cd(RB) { system 'rake compile > nul' }
  end
end

def size_of_binaries
  build unless File.exists? BIN
  Dir["#{BIN}/*.{exe,dll,config}"].
    delete_if { |f|    f =~ /ClassInitGenerator|Tests/ }.
    inject({}){ |s, f| s[f] = File.size(f); s          }
end

def github_size
  get_ironruby_from_github[:size]
end

#
# Helpers
#
require 'net/http'
require 'uri'

def fetch(uri_str, limit = 10)
  raise ArgumentError, 'HTTP redirect too deep' if limit == 0

  response = Net::HTTP.get_response(URI.parse(uri_str))
  case response
  when Net::HTTPSuccess     then response
  when Net::HTTPRedirection then fetch(response['location'], limit - 1)
  else
    response.error!
  end
end

def get_ironruby_from_github
  puts "Getting IronRuby from GitHub"
  FileUtils.rm 'ironruby.zip' if File.exist?("ironruby.zip")
  resp = fetch("http://github.com/ironruby/ironruby/zipball/master")
  size = 0
  open('ironruby.zip', 'wb') do |file|
    size = file.write(resp.body)
    yield 'ironruby.zip' if block_given?
  end
  {:size => size, :filename => 'ironruby.zip'}
end

def total_binary_size(binaries)
  binaries.inject(0){|x,(_,y)| x += y }
end

def mb(bytes)
  bytes./(1_000_000.0).round_to(2)
end

#
# Reporting
#

def report(type)
  send("report_#{type}")
end

def report_build
  puts "Build time: #{build.real.round_to(2)} seconds"
end

def report_size_of_binaries
  puts "Binary size: #{mb(total_binary_size(size_of_binaries))}MB"
end

def report_github_size
  puts "Github repo size: #{mb(github_size)} MB"
end

#
# Run the report
#

report :build
report :size_of_binaries
report :github_size