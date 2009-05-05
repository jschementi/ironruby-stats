namespace :stats do
  desc "run the stats on an existing build"
  task :nobuild do
    exec("ruby stats.rb --skip-build --all")
  end

  desc "run the stats and upload to the server"
  task :retry do
    #pushd %~dp0\..\..\..\Main
    #tf get
    #popd
    #pushd %~dp0
    #ruby retry.rb
    #ruby stats.rb --all
    #popd
    exec("retry.bat")
  end
  
  desc "run stats" 
  task :stats do
    exec("ruby stats.rb --all")
  end

  desc "run stats without uploading"
  task :noupload => :clean do
    exec("ruby stats.rb --all --reporter=text")
  end

  desc "clean stats"
  task :clean do
    system("ruby stats.rb --clean")
  end
end

task :default => "stats:noupload"
