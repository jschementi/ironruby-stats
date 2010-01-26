set REPO=c:\dev\vsl1s_irstats
call %REPO%\Merlin\Main\Scripts\Bat\Dev.bat
pushd %MERLIN_ROOT%
pushd ..
echo Cleaning repo
tf undo . /recursive /noprompt
tfpt uu /recursive .
tfpt treeclean . /noprompt /recursive
msbuild %MERLIN_ROOT%\Languages\Ruby\Ruby.sln /t:Clean
echo Getting latest sources
tf get
tf unshelve rubytags-2010-01-22;jimmysch /noprompt
popd
set GEM_HOME=%GEM_PATH%
set PATH=%MERLIN_ROOT%\..\External.LCA_RESTRICTED\Languages\Ruby\ruby-1.8.6p368\bin;%PATH%
set RUBY=%MERLIN_ROOT%\..\External.LCA_RESTRICTED\Languages\Ruby\ruby-1.8.6p368\bin\ruby.exe
%RUBY% -S gem install sinatra --no-ri --no-rdoc
