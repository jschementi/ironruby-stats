$: << File.expand_path(File.dirname(__FILE__))

load 'config.rb'

require 'rubygems'
require 'ext'
require 'benchmark'
require 'win32ole'

RB = "#{REPO}/Merlin/Main/Languages/Ruby"
BIN = "#{REPO}/Merlin/Main/Bin/Release"
ENV['PATH'] = [MRI_BIN.to_dos, BIN.to_dos, ENV['PATH']].join(';')
CD = File.expand_path(File.dirname(__FILE__))
INTERPRET = "-X:CompilationThreshold 1000000000"
IR = "#{BIN}/ir.exe"
MRI = "#{MRI_BIN}/ruby.exe"
MSPEC = "mspec.bat run -fs"
MSPEC_OPTIONS = {:ironruby => "-Gcritical -Gunstable -Gruby", :ruby => '-Gruby'}
DATA = "#{CD}/data"
require 'fileutils'
FileUtils.mkdir DATA unless File.exist? DATA

#
# Helpers
#

module Helpers
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
 
  def to_dos(str)
    str.to_dos
  end

  def ir(file, opts = nil)
    `#{IR.to_dos} #{opts if opts} #{file.to_dos}`
  end

  def mri(file, opts = nil)
    `#{MRI.to_dos} #{opts if opts} #{file.to_dos}`
  end

  def build
    print "Building IronRuby (release mode) ... "
    result = Benchmark.measure do
      FileUtils.cd(RB) { system "msbuild Ruby.sln /p:Configuration=Release /nologo > #{DATA.to_dos}\\compile.log 2>&1" }
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

  def working_set
    working_set = 0
    begin
      t = Thread.new{ system "#{IR.to_dos} #{to_dos "#{CD}/getpid.rb"}" }
      print "Running for 5 seconds to get working set "
      count, done = 0, 4
      loop { sleep(1); print '.'; break if (count += 1) > done }
      count, timeout = 0, 19
      loop do
        break if File.exist?("#{DATA}/pid")
        raise "Timeout getting working set" if (count += 1) > timeout
        sleep(1)
        print '.'
      end
      puts ' found'
      pid = File.open("#{DATA}/pid".to_dos, 'r'){|f| f.read }.to_i
      processes = WIN32OLE.connect("winmgmts://").ExecQuery(
        "select * from win32_process where ProcessId = #{pid}")
      if processes.count == 1
        processes.each{|p| working_set = p.WorkingSetSize}
      else
        puts "*Error: found more than one process with pid==#{pid}"
      end
      Thread.kill(t)
      Process.kill(9, pid)
    ensure
      FileUtils.rm "#{DATA}/pid" if File.exist? "#{DATA}/pid"
    end
    working_set.to_i
  end

  def github_size
    get_ironruby_from_github[:size]
  end

  def startup_time
    print "Timing average startup (compiled, interpreted, and MRI) ... "
    c = i = r = 0
    iters = 10.0
    iters.to_i.times do
      c += Benchmark.measure { ir "#{CD}/empty.rb" }.real
      i += Benchmark.measure { ir "#{CD}/empty.rb", INTERPRET }.real
      r += Benchmark.measure { mri "#{CD}/empty.rb" }.real
    end
    c, i, r = [c,i,r].map{|i| i / iters}
    delta = r - (c < i ? c : i)
    puts "done"
    {:compiled => c, :interpreted => i, :ruby => r, :delta => delta}
  end
  
  def throughput
    print "Timing average throughput (compiled, interpreted, and MRI) ... "
    c = i = r = 0
    iters = 10.0
    iters.to_i.times do
      i += ir("#{CD}/loop.rb", INTERPRET).to_f
      c += ir("#{CD}/loop.rb").to_f
      r += mri("#{CD}/loop.rb").to_f
    end
    c, i, r = [c,i,r].map{|i| i / iters}
    delta = r - (c < i ? c : i)
    puts "done"
    {:compiled => c, :interpreted => i, :ruby => r, :delta => delta}
  end
  
  def mspec(type = nil, impl = nil)
    type ||= :core
    impl ||= :ironruby
    impl_bin = impl == :ironruby ? IR : MRI
    
    print "Running mspec:#{type} with #{impl} ... "

    log = "#{DATA}/mspec_#{type}_#{impl}.log"

    # since running mspec takes a while, only run if the log file is not present
    unless File.exist? log
      results = nil
      old = FileUtils.pwd
      begin
        FileUtils.cd RB
        system "#{MSPEC} #{MSPEC_OPTIONS[impl]} -B#{ "#{CD}/stats.config".to_dos } --target=#{impl_bin.to_dos} #{type} 1> #{log.to_dos} 2>&1"
      ensure
        FileUtils.cd old
      end
    end
    puts "done"
     
    pmr File.open(log, "r") { |f| f.read }
  end

  # Parse MSpec Results 
  def pmr(results)
    data = {}
    parser = /Finished in (.*? second)[s]?\n\n(.*? file)[s]?, (.*? example)[s]?, (.*? expectation)[s]?, (.*? failure)[s]?, (.*? error)[s]?/
    
    cnvrsns = {:seconds => lambda {|i| i.to_f}}
    default = lambda{|i| i.to_i}
    
    results.scan(parser) do |parsed|
      parsed.each do |node|
        s = node.split(' ')
        key = "#{s.last}s".to_sym
        cnvrsns.each do |f,l| 
          data[key] = (key == f ? l : default).call(s.first)
        end
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

  #def report_startup
  #  startup_time
  #end

  #def report_throughput
  #  throughput
  #end

  def report_working_set
    working_set
  end

  def report_mspec_language
    _mspec(:language)
  end

  def report_mspec_core
    _mspec(:core)
  end

  def report_mspec_library
    _mspec(:library)
  end
  
  def final
    date = Time.now.strftime("%Y%m%d%H%M%S")
    _save_dat(date)
    _upload_html(*_save_html(date))
  end
  
private
  def _mspec(scope)
    ir = mspec(scope)
    ru = mspec(scope, :ruby)
    delta = ir.inject({}){|r,(k,v)| r[k] = ru[k] - ir[k]; r} if !ir.nil? && !ru.nil?
    {:ironruby => ir, :ruby => ru, :delta => delta}
  end

  def _save_dat(date)
    filename = "#{DATA}/data-#{date}.dat"
    print "Writing #{filename} ... "
    File.open(filename, "wb") do |f|
      Marshal.dump(@data, f)
    end
    puts "done"
  end

  def _save_html(date)
    print "Generating http://ironruby.info homepage "
    _kill 'pid1' 
    t = Thread.new { system "#{Gem.ruby} #{(File.dirname(__FILE__) + '/app.rb').to_dos}" }
    require 'net/http'
    10.times do
      sleep 1
      begin
        url = URI.parse("http://#{Socket.gethostname}:4567")
        res = Net::HTTP.start(url.host, url.port) {|http| http.get '/' }
        raise res.code_type.exception_type unless res.kind_of? Net::HTTPOK
        html = res.body
        filename = "#{DATA}/index-#{date}.html"
        indexfile = File.dirname(filename) + '/index.html'
        File.open(filename, 'w'){|f| f.write html }
        FileUtils.rm indexfile if File.exist? indexfile
        FileUtils.cp filename, indexfile
        puts " done"
        return [filename, indexfile]
      rescue
        print '.'
      end
    end
    raise "Timeout generating HTML"
  ensure
    _kill 'pid1', t
  end

  def _kill(pidfile, t = nil)
    pidfile = "#{DATA}/#{pidfile}"
    return unless File.exist?(pidfile)
    pid = File.open(pidfile, 'r'){|f| f.read }.to_i
    Thread.kill(t) if t
    Process.kill(9, pid)
  rescue
    # noop
  ensure
    FileUtils.rm pidfile if File.exist?(pidfile)
  end

  def _upload_html(filename, indexfile)
    print "Connecting to ironruby.info ... "
    require 'net/ftp'
    ftp = Net::FTP.new("ironruby.com")
    ftp.login('ironruby', _get_pswd)
    ftp.passive = true
    ftp.chdir('info')
    puts 'done'
    print "Uploading #{filename} to http://ironruby.info/#{File.basename(filename)} ... "
    ftp.puttextfile filename
    puts 'done'
    print "Uploading #{indexfile} to http://ironruby.info/#{File.basename(indexfile)} ... "
    ftp.puttextfile indexfile
    puts 'done'
  end

  def _get_pswd
    File.open("#{File.dirname(__FILE__)}/pswd"){|f| f.read}.chomp
  end

  def _scp_data(filename)
    print "Sending file to ironruby.info ... "
    Net::SCP.start("ironruby.info", "iruby", :password => _get_pswd) do |scp|
      scp.upload! filename, "/home/iruby/ironruby.info/data/#{filename.split("/").last}"
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
  
  #def report_startup
  #  "Startup time: #{data.map{|k,v| "#{k}(#{v} s)"}.join(", ")}\n"
  #end

  #def report_throughput
  #  "Throughput: (100000 iterations): #{data.map{|k,v| "#{k}(#{v} s)"}.join(", ")}\n"
  #end
  
  def report_working_set
    "Working set: #{mb data} MB\n"
  end

  def report_mspec_language
    _mspec
  end
  
  def report_mspec_core
    _mspec
  end
  
  def report_mspec_library
    _mspec
  end
  
private
  def _mspec
    data.map{|k,v| "#{k}:\n#{dmr(v)}\n"}.join(", ")
  end

  # display parsed rubyspec results 
  def dmr(results)
    results.inject(""){ |s,(k,v)| s << "#{k}:\t#{v}\n"; s }
  end
  
  def total_binary_size(binaries)
    binaries.inject(0){|x,(_,y)| x += y }
  end

  def mb(bytes)
    bytes./(1024*1024.0).round_to(2)
  end
end

$default_reporter = DataReporter.new

if __FILE__ == $0

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

  puts "SUCCESS!"
end
