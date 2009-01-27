require 'benchmark'

result = Benchmark.measure do
  $a = 1; 100000.times{|i| $a *= 2}	
end

print result.real