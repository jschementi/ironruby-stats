File.open(File.dirname(__FILE__) + '/data/pid', 'w'){ |f| f.print Process.pid }
a = 0
a += 1 while true
