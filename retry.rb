require 'win32ole'
require 'rubygems'
require 'win32/process'
require 'dbg'

puts "Cleaning ..."
system 'ruby stats.rb --clean'

$duration = 45 * 60
$retry_count = 0
$retry_times = 2

while $retry_count <= $retry_times
  retryer = Thread.new do
    puts "Waiting #{$duration} seconds for you to run"
    sleep($duration)
    puts "\n... ready or not, hear I come!"

    found = false

    wmi = WIN32OLE.connect("winmgmts://")
    wmi.ExecQuery("select * from win32_process").each do |process|
      if process.CommandLine == 'ruby stats.rb --all'
        fount = true
        puts "Found you hanging, so stop running!"
        $retry_count += 1
        `taskkill /PID #{process.ProcessId} /F`
        `taskkill /PID ir.exe /F`
        if $retry_count <= $retry_times
          puts "Running you again"
        else
          puts "You've hung too many times, you're done."
        end
        Thread.exit
      end
    end

    unless found
      puts "Never found ruby.exe, so stop retrying!"
      Thread.exit
    end
  end

  Thread.new{ system 'ruby stats.rb --all' }.join
  retryer.join
end
