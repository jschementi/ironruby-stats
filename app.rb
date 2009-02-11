require 'rubygems'
require 'sinatra'

require 'mymath'
require 'dbg'

require 'activesupport'

helpers do
  def time(t)
    t = t.to_f
    if t != 0
      (t < 60 && t > -60) ? "#{t.round_to(2)} s" : "#{(t / 60).round_to(2)} m"
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
  
  def magnitude(*d)
    green_or_red(times(d), "x")
  end
  
  def times(data)
    one, two = data[0].to_f, data[1].to_f
    (one/two > 0 ? -1 * (one/two) : two/one).round_to(2)
  end
  
  def green_or_red(data, append = "")
    color = if data >= 0 then 'green' elsif data < 0 then 'red' end
    "<span style='color: #{color}'>#{data}#{append}</span>"
  end
  
  def total_pass_rate(comp, ref)
    ((comp[:expectations].to_i - comp[:failures].to_i - comp[:errors].to_i).to_f / ref[:expectations].to_i).round_to(4)
  end
  
  def grand_total_pass_rate(stats, comp = :ironruby)
    totals = {
      comp => {},
      :ruby => {}
    }
    types = [:expectations, :failures, :errors]
    specs = [:library, :core, :language]

    totals.each do |lang,_|
      types.each do |type|
        specs.each do |spec|
          totals[lang] ||= {}
          totals[lang][type] ||= 0
          totals[lang][type] += stats[:"mspec_#{spec}"][lang][type].to_i
        end
      end
    end

    total_pass_rate(totals[comp], totals[:ruby])
  end
  
  def total_binary_size(binaries)
    binaries.inject(0){|x,(_,y)| x += y }
  end

  def mb(bytes)
    bytes./(1024*1024.0).round_to(2)
  end

  def fetch_data(scope = :all)
    files = Dir['data/data-*.dat'].sort
    (scope == :last ? files.last : files).inject({}) do |stats, file|
      File.open(file) do |f|
        stats[f.mtime] = Marshal.load(f)
      end
      stats
    end
  end
end

get '/' do
  stats = fetch_data(:last)
  @modification_time = stats.keys.sort.last
  haml :index, :locals => {:stats => stats[@modification_time]}
end

get '/performance/:key' do
  require 'google_chart'
  impl = {:compiled => 'cc4444', :interpreted => 'bb7777', :ruby => 'ff0000', '' => '000000'}

  # fetch all historical data
  stats = fetch_data

  # group the historical data by each implementation
  trends = impl.keys.inject({}) do |trends, l|
    trends[l] = stats.keys.sort.map do |t|
      s = stats[t][params[:key].to_sym]
      s[l] || 0
    end
    trends
  end

  # compute the averages of each implementations historical data
  avg = trends.inject({}){|h, (k,v)| h[k] = v.inject(0){|sum, x| sum + x}; h }
  avgs = avg.map{|_,i| i}

  # order the implementations by averages (high to low)
  impl_order = avg.map{|k,v| [k, v]}.sort{|x,y| y.last <=> x.last}.map{|x| x.first}


  haml :performance, :locals => {:graphs => [
    GoogleChart::LineChart.new('600x500') do |lc|
      lc.show_legend = true

      lc.fill :background, :solid, :color => '000000'

      lc.axis :y, :range => [avgs.min, avgs.max], :color => 'dddddd'
      lc.axis :x, :labels => stats.keys.sort.map{|t| t.strftime("%m/%d/%y")}, :color => 'dddddd'

      impl_order.each do |i|
        lc.data i, trends[i], impl[i]
      end

      impl_order[0..-2].each_with_index do |o, i|
        lc.fill_area impl[o], i, i + 1
      end
    end
  ]}
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
    %title ironruby.info
    %link{:href => "/stylesheet.css", :rel => "stylesheet", :type => "text/css"}
  %body
    =yield


@@ index
%h1 ironruby.info

%div
  %a{:href => 'http://github.com/jschementi/ironruby-stats'} generated
  = @modification_time.strftime("%Y-%m-%d")
  from
  %a{:href => 'http://github.com/ironruby/ironruby'} IronRuby
%br
%div
  %a{:href => 'http://blog.jimmy.schementi.com/2009/02/ironrubyinfo.html'}
    What is this page all about?

%table
  %thead
    %tr
      %th{:colspan => 5}
        Performance
    %tr.sub.right
      %th
      %th ir.exe
      %th -X:Interpret
      %th ruby.exe
      %th diff
  %tbody
    = haml :benchmark,:locals => {:b => stats[:startup],:title => "Startup time",:to_diff => :interpreted,:key => :startup}
    = haml :benchmark,:locals => {:b => stats[:throughput],:title => "100,000 iterations",:to_diff => :compiled,:key => :throughput}
  %thead
    %tr
      %th{:colspan => 5} RubySpec
    %tr.sub.right
      %th{:colspan => 1}
      %th{:colspan => 2} ir.exe
      %th ruby.exe
      %th diff
  = haml :mspec,:locals => {:title => "Language",:mspec => stats[:mspec_language]},:layout => false
  = haml :mspec,:locals => {:title => "Core",:mspec => stats[:mspec_core]},:layout => false
  = haml :mspec,:locals => {:title => "Library",:mspec => stats[:mspec_library]},:layout => false
  %thead
    %tr.sub.right
      %th all specs pass rate
      %th{:colspan => 2}= "#{gtir = grand_total_pass_rate(stats) * 100}%"
      %th= "#{gtrb = grand_total_pass_rate(stats, :ruby) * 100}%"
      %th= green_or_red(gtir - gtrb, "%")
  

  %thead
    %tr
      %th{:colspan => 5} Fun facts
  %tbody
    %tr
      %th Build time
      %td{:colspan => 4}= time stats[:build]
    %tr
      %th Binary size
      %td{:colspan => 4}= size(total_binary_size(stats[:binsize]))
    %tr
      %th Working set
      %td{:colspan => 4}= size stats[:working_set]
    %tr
      %th Github repository size
      %td{:colspan => 4}= size stats[:repo]


@@ benchmark
%tr
  %th
    %a{:href => "/performance/#{key}"}= title
  %td= time(b[:compiled])
  %td= time(b[:interpreted])
  %td= time(b[:ruby])
  %td= magnitude(b[to_diff], b[:ruby])

@@ performance
%h1 ironruby.info

%div
  %a{:href => '/'}
    &laquo; Back

%h2
  = params[:key].capitalize

- graphs.each do |graph|
  %img{:src => graph.to_url}

@@ mspec
%thead
  %tr.sub
    %th{:colspan => 5}= title
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
      %td= magnitude mspec[:ironruby][:seconds], mspec[:ruby][:seconds]
    %tr
      %th files
      %td{:colspan => 2}= data mspec[:ironruby][:files]
      %td{:colspan => 1}= data mspec[:ruby][:files]
      %td= green_or_red -1 * mspec[:delta][:files]
    %tr 
      %th examples
      %td{:colspan => 2}= data mspec[:ironruby][:examples]
      %td{:colspan => 1}= data mspec[:ruby][:examples]
      %td= green_or_red -1 * mspec[:delta][:examples]
    %tr
      %th expectations
      %td{:colspan => 2}= data mspec[:ironruby][:expectations]
      %td{:colspan => 1}= data mspec[:ruby][:expectations]
      %td= green_or_red -1 * mspec[:delta][:expectations]
    %tr
      %th failures
      %td{:colspan => 2}= mspec[:ironruby][:failures]
      %td= mspec[:ruby][:failures]
      %td= green_or_red mspec[:delta][:failures]
    %tr
      %th errors
      %td{:colspan => 2}= mspec[:ironruby][:errors]
      %td= mspec[:ruby][:errors]
      %td= green_or_red mspec[:delta][:errors]
    %tr
      %th total pass rate
      %td{:colspan => 2}= "#{tir = total_pass_rate(mspec[:ironruby], mspec[:ruby]) * 100}%"
      %td= "#{trb = total_pass_rate(mspec[:ruby], mspec[:ruby]) * 100}%"
      %td= green_or_red(tir - trb, "%")

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
      &.right 
        th, td
          :text-align right
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
