require 'rubygems'
require 'sinatra'

def dbg
  require 'ruby-debug'
  Debugger.start
  debugger
end

get '/' do
  stats = nil
  File.open(Dir['data/data-*.dat'].sort.last, "rb") do |f|
    stats = Marshal.load(f)
  end
  dbg
  haml :index, :locals => {:stats => stats}
end

get '/stylesheet.css' do
  content_type 'text/css', :charset => 'utf-8'
  sass :stylesheet
end

use_in_file_templates!

__END__

@@ layout
%html
  %head
    %title IronRuby Stats
    %link{:href => "stylesheet.css", :rel => "stylesheet", :type => "text/css"}
  %body
    =yield

@@ index
%h1 IronRuby Stats
%h2 Performance
.group
  %p
    %b Startup time
    = stats[:startup]
    seconds
  %p
    %b Throughput (100000 iterations)
    = stats[:throughput]
    seconds
%h2 RubySpec tests
.nest
  %h3 Language
  .group
    = haml :mspec, :locals => {:mspec => stats[:mspec_language]}, :layout => false
  %h3 Core
  .group
    = haml :mspec, :locals => {:mspec => stats[:mspec_core]}, :layout => false
  %h3 Lib
  .group
    = haml :mspec, :locals => {:mspec => stats[:mspec_libraries]}, :layout => false
%h2 Source Code
.group
  %p
    %b GitHub repository size
    = stats[:repo]
    MB
%h2 Binaries
.group
  %p
    %b Build time
    = stats[:build]
    seconds
  %p
    %b Binary size
    = stats[:binsize]
    MB
    
@@ mspec
- if mspec.empty?
  %p No data
- elsif mspec.select{|_,v| v.to_f != 0}.empty?
  %p No data
- else
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

@@ stylesheet
body
  :background-color #000
  :color #fff
  :font-family Consolas, "Lucida Console", Arial
  :font-size 14px
h1
  :border-bottom 2px solid #333
.nest
  :margin-left 20px
.group
  :background-color #222
  :padding 5px
  :margin 0 20px
p
  :border-bottom 2px solid #333
  :font-weight bold
  :font-size 18px
  :margin 5px
  :padding 0
  b
    :font-weight normal
    :color #ddd
    :font-size 14px