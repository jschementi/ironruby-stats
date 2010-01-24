IronRuby-stats
==============

A script for capturing interesting statistics about IronRuby

Pre-requisites
--------------
1. Ruby (MRI)
2. An IronRuby repository

    git clone git://github.com/ironruby/ironruby.git

Configuration
-------------
Update config.rb with the path to your IronRuby repository (from step 1 above).

For example, if you ran the "git clone" command in c:/dev, then this would be
your REPO value:

REPO = 'c:/dev/ironruby'

Also, update "MRI_BIN" with the path to your ruby.exe:

MRI_BIN = 'c:\ruby\bin'

Example
-------

> ruby stats.rb --all

Runs all reports, writes results to a .dat file, generates a HTML file, and
attemps to upload both the html file and the dat file to ironruby.info.
"ruby stats.rb --reporter=data --all" will do the same thing.

> ruby stats.rb --reporter=text --all

Runs all reports, and outputs the results to the screen.

> ruby stats.rb --mspec_lang

Only run the 'mspec_lang' report

> ruby stats.rb --skip-build --all

Run all reports, except for 'build'

Usage
-----

ruby stats.rb [--help|-h] [--clean] [--reporter=(text|data)] [--skip-#{name}] [--#{name}|--all]

  #{name} can be any of the following:
  - mspec_core : RubySpec Core tests
  - mspec_lang : RubySpec Language tests 
  - mspec_lib  : RubySpec Library tests
  - build      : Builds IronRuby
  - binsize    : Size of IronRuby binaries
  - repo       : Size of IronRuby source code repository
  - startup    : Time to start ir.exe
  - throughput : Time to do 100,000 iterations of (i *= 2)
