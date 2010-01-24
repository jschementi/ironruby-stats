File.open(File.dirname(__FILE__) + '/data/pid1', 'w'){ |f| f.print Process.pid }

require 'rubygems'
require 'sinatra'
require 'haml'
require 'ext'
require 'active_support'

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
    if one/two > 0
      return 0.0 if two == 0.0
      -1 * (one/two)
    else
      return 0.0 if one == 0.0
      two/one
    end.round_to(2)
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
end

get '/' do
  stats = nil
  File.open(Dir['data/data-*.dat'].sort.last, "rb") do |f|
    @modification_time = f.mtime
    stats = Marshal.load(f)
  end

  # FIXME Offset the library ruby expection number by 2300, since
  # we're not taking into account ruby_bug guards in our numbers,
  # and that's how many expectations IronRuby runs more that MRI
  stats[:mspec_library][:ruby][:expectations] += 2300
  stats[:mspec_library][:delta][:expectations] += 2300

  haml :index, :locals => {:stats => stats}
end

get '/stylesheet.css' do
  content_type 'text/css', :charset => 'utf-8'
  sass :stylesheet
end
