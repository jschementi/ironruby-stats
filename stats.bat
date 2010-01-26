call %~dp0init.bat
echo Cleaning stats
%RUBY% %~dp0stats.rb --clean
echo Running stats
%RUBY% %~dp0stats.rb --all 1> %~dp0data\lastrun.log 2>&1
