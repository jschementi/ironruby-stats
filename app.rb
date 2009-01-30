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
    if t
      t = t.to_f
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
      %th{:colspan => 3}
        Performance
    %tr.sub
      %th ir.exe
      %th default
      %th -X:Interpret
  %tbody
    %tr
      %th Startup time
      %td= time(stats[:startup][:compiled])
      %td= time(stats[:startup][:interpreted])
    %tr
      %th 100000 iters
      %td= time(stats[:throughput][:compiled])
      %td= time(stats[:throughput][:interpreted])

  %thead
    %tr
      %th{:colspan => 3} RubySpec
  = haml :mspec, :locals => {:title => "Language", :mspec => stats[:mspec_language]}, :layout => false
  = haml :mspec, :locals => {:title => "Core", :mspec => stats[:mspec_core]}, :layout => false
  = haml :mspec, :locals => {:title => "Library", :mspec => stats[:mspec_library]}, :layout => false

  %thead
    %tr
      %th{:colspan => 3} Source Code
  %tbody
    %tr
      %th Github repository size
      %td{:colspan => 2}= size stats[:repo]
      
  %thead
    %tr
      %th{:colspan => 3} Binaries
  %tbody
    %tr
      %th Build time
      %td{:colspan => 2}= time stats[:build]
    %tr
      %th Binary size
      %td{:colspan => 2}= size(total_binary_size(stats[:binsize]))

@@ mspec
%thead
  %tr.sub
    %th{:colspan => 3}= title
  %tbody
    - if mspec.empty? || mspec.select{|_,v| v.to_f != 0}.empty?
      %tr
        %td
          No data
    - else
      %tr
        %th time
        %td{:colspan => 2}= time mspec[:seconds]
      %tr
        %th files
        %td{:colspan => 2}= data mspec[:files]
      %tr 
        %th examples
        %td{:colspan => 2}= data mspec[:examples]
      %tr
        %th expectations
        %td{:colspan => 2}= data mspec[:expectations]
      %tr
        %th failures
        %td{:colspan => 2, :class => (mspec[:failures].to_i > 0 ? 'fail' : 'pass') }
          = data mspec[:failures]
      %tr
        %th errors
        %td{:colspan => 2, :class => (mspec[:errors].to_i > 0 ? 'fail' : 'pass') }
          = data mspec[:errors]

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