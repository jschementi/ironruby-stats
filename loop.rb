require 'benchmark'

result = Benchmark.measure do
  100000.times{|i| i + 1}	
end

print result.real
