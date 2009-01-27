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
    FileUtils.rm "#{CD}/compile.log"
    Benchmark.measure do
      FileUtils.cd(RB) { system "rake compile > #{CD}/compile.log" }
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
  
  def mspec(type = nil)
    types = [:core, :lang, :lib]
    types.each {|t| FileUtils.rm "#{CD}/mspec_#{t}.log" if File.exist? "#{CD}/mspec_#{t}.log" }
    
    type ||= :core
    unless types.include?(type)
      puts "\"#{type}\" is not a valid mspec option"
      exit
    end
    
    results = nil
    FileUtils.cd(RB) do
      print "Running mspec:#{type} ..."
      system "rake mspec:#{type} > #{CD}/mspec_#{type}.log"
    end
    
    File.open("#{CD}/mspec_#{type}.log", "r") { |f| f.read }
  end
end

class SSS
  class << self
    include Stats
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
  
    def report_binsize
      puts "Binary size: #{mb(total_binary_size(size_of_binaries))}MB"
    end
  
    def report_repo
      puts "Github repo size: #{mb(github_size)} MB"
    end
  
    def report_startup
      puts "Startup time: #{startup_time.real.round_to(2)} seconds"
    end

    def report_throughput
      puts "Throughput: (100000 iterations) #{throughput.round_to(2)} seconds"
    end

    def report_mspec_core
      dmr pmr(mspec(:core))
    end
    
    def report_mspec_lang
      dmr pmr(mspec(:lang))
    end
    
    def report_mspec_lib
      dmr pmr(mspec(:lib))
    end

    def report_all
      reports.each {|m| send(m) if reports.include?(m)}
    end
    
    def reports
      list = methods(false).sort.select { |m| m =~ /report_(.*)/ && $1 != 'all' }
      if i = list.index('report_build')
        list[0], list[i] = list[i], list[0]
      end
      list
    end
    
  private
    # Display Parsed MSpec Results 
    def dmr(results)
      results.each do |k,v| puts "#{k}:\t#{v}" end
    end
  
    # Parse MSpec Results 
    def pmr(results)
      data = {}
      parser = /Finished in (.*? seconds)\n\n(.*? files), (.*? examples), (.*? expectations), (.*? failures), (.*? errors)/
      results.scan(parser) do |parsed|
        parsed.each do |node|
          s = node.split(' ')
          data[s.last.to_sym] = s.first
        end
      end
      data
    end
  end
  
end

#
# Run the report
#

$behavior = {
  ['--help', '-h'] => lambda { puts usage; exit },
  ['--all']        => lambda { Report.run :all },
  ['--console']    => lambda { puts 'Running in console mode' },
  ['--clean']      => lambda { clean }
}.merge(
  # generate a ['--#{name}'] => lambda { Report.run name } 
  # for each report in Report.reports
  Report.reports.inject({}) do |opts, r|
    name = r.split('report_').last
    opts[["--#{name}"]] = lambda { Report.run name.to_sym }
    opts
  end
)

def clean
  print 'removing log files ... '
  %W(compile.log mspec_core.log mspec_lang.log mspec_lib.log).each do |f|
    FileUtils.rm "#{CD}/#{f}" if File.exist? "#{CD}/#{f}"
  end
  puts 'done'
end

def usage
  o = "usage:\n  ruby #{__FILE__[2..-1]}"
  $behavior.map{|opts, _| ' [' + opts.join('|') + ']'}.each{|i| o << i}
  o
end

if ARGV.empty?
  puts usage
end

ARGV.each do |arg|
  found = false
  $behavior.each do |options, lmbd|
    if options.include?(arg)
      found = true
      lmbd.call
    end
  end
  unless found 
    puts "Unknown argument '#{arg}'"
    puts help
    exit
  end
end