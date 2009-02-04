pushd %~dp0\..\..\..\Main
tf get
popd
pushd %~dp0
git pull
ruby retry.rb
popd
