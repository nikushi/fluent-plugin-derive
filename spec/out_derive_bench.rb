# encoding: UTF-8
require_relative 'spec_helper'

# setup
Fluent::Test.setup
config = %[
  remove_tag_prefix foo
  add_tag_prefix hoge
  key1 foooooo_baaaaaa_count *1000
  key2 hogeeee_fugaaaa_count *1500
]

time = Time.now.to_i
tag = 'foo.bar'
driver = Fluent::Test::OutputTestDriver.new(Fluent::DeriveOutput, tag).configure(config)

# bench
require 'benchmark'
message = "2013/01/13T07:02:11.124202 INFO GET /ping"
n = 100000
Benchmark.bm(7) do |x|
  x.report { driver.run { n.times do |i|
    time = time + i*60
    driver.emit({'foooooo_baaaaaa_count' => 1234, 'hogeeee_fugaaaa_count' => 5000, 'unmached_keeeeee' => "abvc" }, time)
  end
  } }
end

# key_pattern without adjustment
#              user     system      total        real
#                        2.920000   0.030000   2.950000 (  3.466375)
#
# key_pattern with adjustment
#              user     system      total        real
#                        3.000000   0.040000   3.040000 (  3.550168)
#
# key1 without adjustment and key2 without adjustment
#              user     system      total        real
#                        2.520000   0.030000   2.550000 (  3.058561)
#
# key1 with adjustment and key2 with adjustment
#              user     system      total        real
#                        2.630000   0.030000   2.660000 (  3.180860)
