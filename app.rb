require 'rubygems'
require 'sinatra'

require 'mymath'

require 'activesupport'

def dbg
  require 'ruby-debug'
  Debugger.start
  debugger
end

helpers do
  def time(t)
    t = t.to_f
    if t > 0
      t < 60 ? "#{t.round_to(2)} s" : "#{(t / 60).round_to(2)} m"
    else
      "No data"
    end
  end
  
  def size(s)
    s ? "#{mb(s)} mb" : "No data"
  end
  
  def data(d)
    d ? d.to_s : "No data"
  end
  
  def total_binary_size(binaries)
    binaries.inject(0){|x,(_,y)| x += y }
  end

  def mb(bytes)
    bytes./(1_000_000.0).round_to(2)
  end
end

get '/' do
  stats = nil
  File.open(Dir['data/data-*.dat'].sort.last, "rb") do |f|
    stats = Marshal.load(f)
  end
  
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

%div
  %a{:href => 'http://github.com/jschementi/ironruby-stats'} generated
  daily from
  %a{:href => 'http://github.com/ironruby/ironruby'} IronRuby

%table
  %thead
    %tr
      %th{:colspan => 4}
        Performance
    %tr.sub
      %th
      %th ir.exe
      %th -X:Interpret
      %th ruby.exe
  %tbody
    %tr
      %th Startup time
      %td= time(stats[:startup][:compiled])
      %td= time(stats[:startup][:interpreted])
      %td= time(stats[:startup][:ruby])
    %tr
      %th 100000 iters
      %td= time(stats[:throughput][:compiled])
      %td= time(stats[:throughput][:interpreted])
      %td= time(stats[:throughput][:ruby])

  %thead
    %tr
      %th{:colspan => 4} RubySpec
    %tr.sub
      %th{:colspan => 1}
      %th{:colspan => 2, :style => 'text-align: right'} ir.exe
      %th ruby.exe
  = haml :mspec, :locals => {:title => "Language", :mspec => stats[:mspec_language]}, :layout => false
  = haml :mspec, :locals => {:title => "Core", :mspec => stats[:mspec_core]}, :layout => false
  = haml :mspec, :locals => {:title => "Library", :mspec => stats[:mspec_library]}, :layout => false

  %thead
    %tr
      %th{:colspan => 4} Source Code
  %tbody
    %tr
      %th Github repository size
      %td{:colspan => 4}= size stats[:repo]
      
  %thead
    %tr
      %th{:colspan => 4} Binaries
  %tbody
    %tr
      %th Build time
      %td{:colspan => 3}= time stats[:build]
    %tr
      %th Binary size
      %td{:colspan => 3}= size(total_binary_size(stats[:binsize]))

@@ mspec
%thead
  %tr.sub
    %th{:colspan => 4}= title
  %tbody
    - if mspec.nil? || mspec.empty?
      %tr
        %td
          No data
    - else
      %tr
        %th time
        %td{:colspan => 2}= time mspec[:ironruby][:seconds]
        %td{:colspan => 1}= time mspec[:ruby][:seconds]
      %tr
        %th files
        %td{:colspan => 2}= data mspec[:ironruby][:files]
        %td{:colspan => 1}= data mspec[:ruby][:files]
      %tr 
        %th examples
        %td{:colspan => 2}= data mspec[:ironruby][:examples]
        %td{:colspan => 1}= data mspec[:ruby][:examples]
      %tr
        %th expectations
        %td{:colspan => 2}= data mspec[:ironruby][:expectations]
        %td{:colspan => 1}= data mspec[:ruby][:expectations]
      %tr
        %th failures
        %td{:colspan => 2, :class => (mspec[:ironruby][:failures].to_i > 0 ? 'fail' : 'pass') }
          = data mspec[:ironruby][:failures]
        %td{:colspan => 1, :class => (mspec[:ruby][:failures].to_i > 0 ? 'fail' : 'pass') }
          = data mspec[:ruby][:failures]
      %tr
        %th errors
        %td{:colspan => 2, :class => (mspec[:ironruby][:errors].to_i > 0 ? 'fail' : 'pass') }
          = data mspec[:ironruby][:errors]
        %td{:colspan => 1, :class => (mspec[:ruby][:errors].to_i > 0 ? 'fail' : 'pass') }
          = data mspec[:ruby][:errors]

@@ stylesheet
body
  :background-color #000
  :color #fff
  :font-family Consolas, "Lucida Console", Arial
  :font-size 14px
  :text-align center
h1
  :border-bottom 2px solid #333
table
  :margin-left auto
  :margin-right auto
  :text-align left
  thead
    tr
      th
        :font-size 18px
        :border-bottom 2px solid #333
        :padding 5px
        :padding-top 30px
      &.sub th
        :padding 5px
        :font-size 16px
        :border-bottom 0
        :background-color #222
  tbody
    th
      :background-color #111
      :text-align left
      
    th, td
      :padding 5px
    td
      :text-align right
.fail
  :color red
.pass
  :color green
div
  :padding 5px
  :margin-left auto
  :margin-right auto
  :position relative
a
  :color white
  :padding 3px
  :text-decoration none
  &:link, &:visited
    :background-color #222
  &:hover
    :background-color #555