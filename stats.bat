set REPO=c:\dev\vsl1s_irstats
call %REPO%\Merlin\Main\Scripts\Bat\Dev.bat
pushd %MERLIN_ROOT%
tf get
tf unshelve rubytags-2010-01-22;jimmysch /noprompt
set GEM_HOME=%GEM_PATH%
set RUBY=%MERLIN_ROOT%\..\External.LCA_RESTRICTED\Languages\Ruby\ruby-1.8.6p368\bin\ruby.exe
%RUBY% %~dp0stats.rb --clean
%RUBY% %~dp0stats.rb --all
popd
