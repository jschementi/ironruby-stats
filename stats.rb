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
    
    puts "done"
    
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
    print "Timing startup ... "
    results = nil
    FileUtils.cd(BIN) do
      results = Benchmark.measure do
        `ir #{CD}/empty.rb`
      end
    end
    puts "done"
    results
  end
  
  def throughput
    print "Timing throughput ... "
    results = nil
    FileUtils.cd(BIN) do
      results = `ir #{CD}/loop.rb`
    end
    puts "done"
    results.to_f
  end
  
  def mspec(type = nil)
    type ||= :core
    
    # since running mspec takes a while, only run if the log file is not present
    print "Running mspec:#{type} ... "
    unless File.exist? "#{CD}/mspec_#{type}.log"
      unless [:core, :lang, :lib].include?(type)
        puts "\"#{type}\" is not a valid mspec option"
        exit
      end
      
      results = nil
      FileUtils.cd(RB) do
        system "rake mspec:#{type} > #{CD}/mspec_#{type}.log"
      end
    end
    puts "done"
     
    pmr File.open("#{CD}/mspec_#{type}.log", "r") { |f| f.read }
  end

  # Parse MSpec Results 
  def pmr(results)
    data = {}
    parser = /Finished in (.*? second)[s]?\n\n(.*? file)[s]?, (.*? example)[s]?, (.*? expectation)[s]?, (.*? failure)[s]?, (.*? error)[s]?/
    
    #cnvrsns = {:seconds => lambda {|i| i.to_f}}
    
    results.scan(parser) do |parsed|
      parsed.each do |node|
        s = node.split(' ')
        data["#{s.last}s".to_sym] = s.first
        
        #cnvrsns.each{|f,l| data[f] = l.call(data[f]) if data.has_key?(f)}
      end
    end
    
    data
  end
end

#
# Reporting
#

class BaseReporter
  include Stats
  include Helpers

  def initialize
    @skip = []
  end

  def skip(type)
    @skip << type
  end

  def run(type = :all)
    return nil if @skip.include?(type)
    
    if type == :all
      reports.each {|m| run(m)}
      final
    else
      send("report_#{type}")
    end
  end

  def reports
    list = methods.sort.select{|m| m =~ /report_(.*)/}.map{|m| m.split("report_").last.to_sym }
    
    # push build to the first task
    if i = list.index(:build)
      list[0], list[i] = list[i], list[0]
    end
    
    list
  end
  
  def final
    # Override this to do something at the end of the run
  end
end

class DataReporter < BaseReporter
  def initialize
    @data = {}
    super
  end

  def run(type)
    data = super
    
    if data && type != :all
      @data.merge!( data.kind_of?(Hash) ? data : {type.to_sym => data} )
      data
    else 
      @data
    end
  end

  def report_build
    build.real.round_to(2)
  end

  def report_binsize
    mb(total_binary_size(size_of_binaries))
  end

  def report_repo
    mb(github_size)
  end

  def report_startup
    startup_time.real.round_to(2)
  end

  def report_throughput
    throughput.round_to(2)
  end

  def report_mspec_core
    mspec(:core)
  end

  def report_mspec_lang
    mspec(:lang)
  end

  def report_mspec_lib
    mspec(:lib)
  end
  
  def final
    filename = "#{CD}/data-#{Time.now.strftime("%Y%m%d%H%M%S")}.dat"
    print "Writing #{filename} ... "
    File.open(filename, "wb") do |f|
      Marshal.dump(@data, f)
    end
    puts "done"
  end
end

class TextReporter < BaseReporter
  def initialize
    @dr = DataReporter.new
    @text = ""
    super
  end

  def run(type)
    @type = type
    text = super
    
    if text && type != :all
      @data = nil
      @text << text
      puts text
    end
  end
  
  def data
    @data ||= @dr.run(@type)
  end
  
  def report_build
    "Build time: #{data} seconds\n"
  end
  
  def report_binsize
    "Binary size: #{data}MB\n"
  end
  
  def report_repo
    "Github repo size: #{data} MB\n"
  end
  
  def report_startup
    "Startup time: #{data} seconds\n"
  end

  def report_throughput
    "Throughput: (100000 iterations) #{data} seconds\n"
  end

  def report_mspec_core
    dmr(data)
  end
  
  def report_mspec_lang
    dmr(data)
  end
  
  def report_mspec_lib
    dmr(data)
  end
  
private
  # Display Parsed MSpec Results 
  def dmr(results)
    results.inject("") { |s,(k,v)| s << "#{k}:\t#{v}\n"; s }
  end
end

$default_reporter = DataReporter.new

#
# Run the report
#

$behavior = {
  ['--help', '-h']     => lambda { puts usage; exit },
  ['--all']            => lambda { $default_reporter.run :all },
  ['--clean']          => lambda { clean_log; clean_data },
  ['--clean-log']      => lambda { clean_log },
  ['--clean-data']     => lambda { clean_data },
  [/--reporter=(.*)/]  => lambda do |r|
      $default_reporter = eval(r[1].capitalize + "Reporter").new
    end,
}.merge(
  # generate a '--#{name}' and '--skip-#{name}' option for each report
  $default_reporter.reports.inject({}) do |opts, name|
    opts[["--#{name}"]]      = lambda { $default_reporter.run name.to_sym }
    opts[["--skip-#{name}"]] = lambda { $default_reporter.skip name.to_sym }
    opts
  end
)

def clean_data
  print 'removing data files ... '
  Dir["#{CD}/data-*.dat"].each do |f|
    FileUtils.rm f
  end
  puts 'done'
end

def clean_log
  print 'removing log files ... '
  Dir["#{CD}/*.log"].each do |f|
    FileUtils.rm f
  end
  puts 'done'
end

def usage
  o = "usage:\n  ruby #{__FILE__}"
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
    elsif options.select{|o| o.kind_of?(Regexp) && arg =~ o}.size == 1
      found = true
      lmbd.call($~)
    end
  end
  
  unless found
    puts "Unknown argument '#{arg}'"
    puts help
    exit
  end
end
