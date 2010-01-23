call C:\dev\vsl1s\Merlin\Main\Scripts\Bat\Dev.bat
cd %MERLIN_ROOT%
tf get
set GEM_HOME=%GEM_PATH%
set RUBY=%MERLIN_ROOT%\..\External.LCA_RESTRICTED\Languages\Ruby\ruby-1.8.6p368\bin\ruby.exe
%RUBY% %~dp0stats.rb --clean
%RUBY% %~dp0stats.rb --all
