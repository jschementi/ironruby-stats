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
  ir.exe -X:Interpret

%table
  %thead
    %tr
      %th{:colspan => 2} Performance
  %tbody
    %tr
      %th Startup time
      %td= "#{stats[:startup]} s"
    %tr
      %th Throughput (100000 iters)
      %td= "#{stats[:throughput]} s"

  %thead
    %tr
      %th{:colspan => 2} RubySpec
  = haml :mspec, :locals => {:title => "Language", :mspec => stats[:mspec_language]}, :layout => false
  = haml :mspec, :locals => {:title => "Core", :mspec => stats[:mspec_core]}, :layout => false
  = haml :mspec, :locals => {:title => "Libraries", :mspec => stats[:mspec_libraries]}, :layout => false

  %thead
    %tr
      %th{:colspan => 2} Source Code
  %tbody
    %tr
      %th Github repository size
      %td= "#{stats[:repo]} mb"
      
  %thead
    %tr
      %th{:colspan => 2} Binaries
  %tbody
    %tr
      %th Build time
      %td= "#{stats[:build]} s"
    %tr
      %th Binary size
      %td= "#{stats[:binsize]} mb"

@@ mspec
%thead
  %tr.sub
    %th{:colspan => 2} Language
  %tbody
    - if mspec.empty? || mspec.select{|_,v| v.to_f != 0}.empty?
      %tr
        %td
          No data
    - else
      %tr
        %th time
        %td= "#{mspec[:seconds]} s"
      %tr
        %th files
        %td= mspec[:files]
      %tr 
        %th examples
        %td= mspec[:examples]
      %tr
        %th expectations
        %td= mspec[:expectations]
      %tr
        %th failures
        %td{ :class => (mspec[:failures].to_i > 0 ? 'fail' : 'pass') }
          = mspec[:failures]
      %tr
        %th errors
        %td{ :class => (mspec[:errors].to_i > 0 ? 'fail' : 'pass') }
          = mspec[:errors]

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
.fail
  :color red
.pass
  :color green
div
  :padding 5px
  :margin-left auto
  :margin-right auto
  :position relative