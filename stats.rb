load 'config.rb'
RB = "#{REPO}/Merlin/Main/Languages/Ruby"
BIN = "#{REPO}/Merlin/Main/Bin/debug"
CD = File.expand_path(File.dirname(__FILE__))

require 'fileutils'
require 'mymath'
require 'benchmark'
require 'pp'

#
# Helpers
#
require 'net/http'
require 'uri'

module Helpers
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
    print "Downloading IronRuby from GitHub ... "
    FileUtils.rm 'ironruby.zip' if File.exist?("ironruby.zip")
    resp = fetch("http://github.com/ironruby/ironruby/zipball/master")
    size = 0
    open('ironruby.zip', 'wb') do |file|
      size = file.write(resp.body)
      yield 'ironruby.zip' if block_given?
    end
    FileUtils.rm 'ironruby.zip'
    {:size => size, :filename => 'ironruby.zip'}
  end

  def total_binary_size(binaries)
    binaries.inject(0){|x,(_,y)| x += y }
  end

  def mb(bytes)
    bytes./(1_000_000.0).round_to(2)
  end
end

#
# Stat gathering
#

module Stats
  include Helpers
  
  def build
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

  def startup_time
    results = nil
    FileUtils.cd(BIN) do
      results = Benchmark.measure do
        `ir #{CD}/empty.rb`
      end
    end
    results
  end
  
  def throughput
    results = nil
    FileUtils.cd(BIN) do
      results = `ir #{CD}/loop.rb`
    end
    results.to_f
  end
end

#
# Reporting
#

class Report
  class << self 
    include Stats
    include Helpers
  
    def run(type)
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
  
    def report_startup
      puts "Startup time: #{startup_time.real.round_to(2)} seconds"
    end

    def report_throughput
      puts "Throughput: (100000 iterations) #{throughput.round_to(2)} seconds"
    end

    def report_all
      methods.sort.each do |m|
        if m =~ /report_(.*)/ && $1 != 'all'
          send(m)
        end
      end
    end
  end
  
end

#
# Run the report
#

def help
  <<-EOS
usage:
  ruby stats.rb [--all] [--build] [--binary] [--repo] [--startup] [--throughput] [-h|--help]
EOS
end

if ARGV.empty?
  puts help
end

ARGV.each do |arg|
  case arg
  when /--help/, /-h/: 
    puts help
    exit
  when /--all/      : Report.run :all
  when /--build/    : Report.run :build
  when /--binary/   : Report.run :size_of_binary
  when /--repo/     : Report.run :github_size
  when /--startup/  : Report.run :startup
  when /--throughput/  : Report.run :throughput
  else
    puts "Unknown argument '#{arg}'"
    puts help
    exit
  end
end