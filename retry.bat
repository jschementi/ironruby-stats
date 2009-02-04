pushd %~dp0\..\..\..\Main
tf get
popd
pushd %~dp0
ruby retry.rb
popd
