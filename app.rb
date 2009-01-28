require 'rubygems'
require 'sinatra'
require 'ruby-debug'

get '/' do
  stats = nil
  File.open(Dir['data-*.dat'].sort.last, "rb") do |f|
    stats = Marshal.load(f)
  end
  debugger
  haml :index, :locals => {:stats => stats}
end

get '/stylesheet.css' do
  content_type 'text/css', :charset => 'utf-8'
  sass :stylesheet
end

__END__

@@ layout
%html
  =yield
  
@@ index
%h1 IronRuby Stats
%h2 Binaries
%p
  %b Build time
  = stats[:build]
  seconds
%p
  %b Binary size
  = stats[:binsize]
%h2 Performance
%p
  %b Startup time
  = stats[:startup]
%p
  %b Throughput (100000 iterations)
  = stats[:throughput]
%h2 RubySpec tests
%h3 Language
= haml :mspec, :locals => {:mspec => stats[:mspec_lang]}, :layout => false
%h3 Core
= haml :mspec, :locals => {:mspec => stats[:mspec_core]}, :layout => false
%h3 Core
= haml :mspec, :locals => {:mspec => stats[:mspec_lib]}, :layout => false
%h2 Source Code
%p
  %b GitHub repository size
  = stats[:repo]

@@ mspec
%p
  = mspec[:seconds]
  %b seconds
%p
  = mspec[:files]
  %b files
  ,
  = mspec[:examples]
  %b examples
  ,
  = mspec[:expectations]
  %b expectations
  ,
  = mspec[:failures]
  %b failures
  ,
  = mspec[:errors]
  %b errors
