load 'config.rb'

RB = "#{REPO}/Merlin/Main/Languages/Ruby"
BIN = "#{REPO}/Merlin/Main/Bin/debug"
CD = File.expand_path(File.dirname(__FILE__))
DATA = "#{CD}/data"
INTERPRET = "-X:Interpret"
IR = "#{BIN}/ir.exe"
MSPEC = "mspec.bat run -fs -Gcritical"

require 'fileutils'
require 'mymath'
require 'benchmark'

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
    
    filename = "#{DATA}/ironruby.zip"
    FileUtils.rm filename if File.exist?(filename)
    resp = fetch("http://github.com/ironruby/ironruby/zipball/master")
    size = 0
    
    open(filename, 'wb') do |file|
      size = file.write(resp.body)
      yield filename if block_given?
    end
    
    puts "done"
    
    {:size => size, :filename => filename}
  end
end

#
# Stat gathering
#

module Stats
  include Helpers
  
  def build
    print "Building IronRuby ... "
    result = Benchmark.measure do
      FileUtils.cd(RB) { system "rake compile > #{DATA}/compile.log 2>&1" }
    end
    puts "done"
    result.real
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
    print "Timing average startup (compiled and interpreted) ... "
    c = i = 0
    10.times do
      c += Benchmark.measure do
        `#{IR} #{CD}/empty.rb`
      end.real
      i += Benchmark.measure do
        `#{IR} #{INTERPRET} #{CD}/empty.rb`
      end.real
    end
    puts "done"
    {:compiled => c / 10.0, :interpreted => i / 10.0}
  end
  
  def throughput
    print "Timing average throughput (compiled and interpreted) ... "
    c = i = 0
    10.times do
      i += `#{IR} #{INTERPRET} #{CD}/loop.rb`.to_f
      c += `#{IR} #{CD}/loop.rb`.to_f
    end
    puts "done"
    {:compiled => c / 10.0, :interpreted => i / 10.0}
  end
  
  def mspec(type = nil, impl = nil)
    type ||= :core
    
    # since running mspec takes a while, only run if the log file is not present
    print "Running mspec:#{type} with #{impl || 'ironruby'} ... "

    log = "#{DATA}/mspec_#{type}#{"_#{impl}" if impl}.log"
    unless File.exist? log
      results = nil
      FileUtils.cd(RB) do
        # To run interpreter: -T'#{INTERPRET}'
        system "#{MSPEC} #{"--target #{impl}" if impl} #{type} > #{log} 2>&1"
      end
    end
    puts "done"
     
    pmr File.open(log, "r") { |f| f.read }
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
    list = methods.sort.select{|m| m =~ /report_(.*)/}.
      map{|m| m.split("report_").last.to_sym }
    
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
      @data.merge!({type.to_sym => data})
      data
    else 
      @data
    end
  end

  def report_build
    build
  end

  def report_binsize
    size_of_binaries
  end

  def report_repo
    github_size
  end

  def report_startup
    startup_time
  end

  def report_throughput
    throughput
  end

  def report_mspec_language
    {:ironruby => mspec(:language), :ruby => mspec(:language, :ruby)}
  end

  def report_mspec_core
    {:ironruby => mspec(:core), :ruby => mspec(:core, :ruby)}
  end

  def report_mspec_library
    {:ironruby => mspec(:library), :ruby => mspec(:library, :ruby)}
  end
  
  def final
    filename = "#{DATA}/data-#{Time.now.strftime("%Y%m%d%H%M%S")}.dat"
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
    "Binary size: #{mb(total_binary_size(data))} MB\n"
  end
  
  def report_repo
    "Github repo size: #{mb(data)} MB\n"
  end
  
  def report_startup
    "Startup time: compiled(#{data[:compiled]} s), interpreted(#{data[:interpreted]} s)\n"
  end

  def report_throughput
    "Throughput: (100000 iterations): compiled(#{data[:compiled]} s), interpreted(#{data[:interpreted]} s)\n"
  end
  
  def report_mspec_language
    "IronRuby: \n#{dmr(data[:ironruby])}\n Ruby: \n#{dmr(data[:ruby])}\n"
  end
  
  def report_mspec_core
    "IronRuby: \n#{dmr(data[:ironruby])}\n Ruby: \n#{dmr(data[:ruby])}\n"
  end
  
  def report_mspec_library
    "IronRuby: \n#{dmr(data[:ironruby])}\n Ruby: \n#{dmr(data[:ruby])}\n"
  end
  
private
  # display parsed rubyspec results 
  def dmr(results)
    results.inject(""){ |s,(k,v)| s << "#{k}:\t#{v}\n"; s }
  end
  
  def total_binary_size(binaries)
    binaries.inject(0){|x,(_,y)| x += y }
  end

  def mb(bytes)
    bytes./(1_000_000.0).round_to(2)
  end
end

$default_reporter = DataReporter.new

#
# Run the report
#

$behavior = {
  ['--help', '-h']     => lambda { puts usage; exit },
  ['--all']            => lambda { $default_reporter.run :all },
  ['--clean']          => lambda { clean },
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

def clean
  remove_all = lambda{ |path| Dir[path].each{ |f| FileUtils.rm f } }

  print 'removing log files ... '
  remove_all.call "#{DATA}/*.log"
  puts 'done'

  print 'removing zip files ... '
  remove_all.call "#{DATA}/*.zip"
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
    puts usage
    exit
  end
end
