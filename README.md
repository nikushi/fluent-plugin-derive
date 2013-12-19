# fluent-plugin-derive

Output the rate of the increasing/decreasing value between the last and the current, like RRDs derive.

## Configuration

### Example 1

    <match foo.bar.**>
      type derive
      add_tag_prefix derive
      key1 foo_count
      key2 bar_count
    </match>

Assuming following inputs are coming:

    2013-12-19 20:01:00 +0900 foo.bar: {"foo_count": 100, "bar_count": 200}
    2013-12-19 20:02:00 +0900 foo.bar: {"foo_count": 700, "bar_count": 1400}

then output becomes as below:

    2013-12-19 20:02:01 +0900 derive.foo.bar: {"foo_count": 10, "bar_count": 20}

Cacled as a per sec rate. See below how calced.

    (700/100)/(20:02:00 - 20:01:00)  => 10
    (1400/200)/(20:02:00 - 20:01:00) => 20

### Example 2

    <match foo.bar.**>
      type derive
      add_tag_prefix derive
      key1 foo_count *1000
      key2 bar_count *1000
    </match>

Assuming following inputs are coming:

    2013-12-19 20:01:00 +0900 foo.bar: {"foo_count": 100, "bar_count": 200}
    2013-12-19 20:02:00 +0900 foo.bar: {"foo_count": 700, "bar_count": 1400}

then output becomes as below:

    2013-12-19 20:02:01 +0900 derive.foo.bar: {"foo_count": 10000, "bar_count": 20000}

## Paramteres
* key[1-20] [Adjustment]

A pair of a field name of the input record, and to be calculated. key1 or key_pattern is required. `Adjustment` is optional, for compute rate.

`Adjustment` is like follow:

    key1 foo_count *3600000 => output the rate as K/h
    key1 foo_count *8       => shift unit (e.g. Bps to bps)
    key1 foo_count /1000    => shift unit (e.g. M to K)

* key_pattern [Adjustment]

A pair of a regular expression to specify field names of the input record, and to be calculated. key1 or key_pattern is required. `Adjustment` is optional.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
