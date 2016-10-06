# fluent-plugin-derive, a plugin for [Fluentd](http://fluentd.org)

Calculate per second value for the increasing/decreasing value between the last and the current, like derive in RRDTool.

For example, imagine interface counter values that are inputted by SNMP polling, What we want to know is essentially the bps not the raw value. By this plug-in, the last inputted values of the specific keys and time are cached, and the per second rate for each key are culculated and re-emitted when the next record is inputted.

Note that Fluentd does not guarantee the order of arrival of messages, it may not be able to calculate accurately if the messages which are tagged with same name are inputted at short intervals. So DO NOT USE this plugin in that case.

I am using the derive plugin in combination with [fluent-plugin-snmp](https://github.com/iij/fluent-plugin-snmp).

## Configuration

### Example 1

    <match foo.bar.**>
      type derive
      add_tag_prefix derive
      key1 foo_count
      key2 bar_count
    </match>

Assuming following inputs are coming:

    2013-12-19 20:01:00 +0900 foo.bar: {"foo_count":  100, "bar_count":  200}
    2013-12-19 20:02:00 +0900 foo.bar: {"foo_count":  700, "bar_count": 1400}
    2013-12-19 20:03:10 +0900 foo.bar: {"foo_count":  700, "bar_count": 1470}
    2013-12-19 20:04:10 +0900 foo.bar: {"foo_count": 1300, "bar_count":  870}

then output becomes as below:

    2013-12-19 20:01:00 +0900 derive.foo.bar: {"foo_count": nil, "bar_count": nil}
    2013-12-19 20:02:00 +0900 derive.foo.bar: {"foo_count":  10, "bar_count":  20}
    2013-12-19 20:03:10 +0900 derive.foo.bar: {"foo_count":   0, "bar_count":   1}
    2013-12-19 20:04:10 +0900 derive.foo.bar: {"foo_count":  10, "bar_count": -10}

Cacled as a per sec rate. See below how calced.

    (700/100)/(20:02:00 - 20:01:00)  => 10

### Example 2

    <match foo.bar.**>
      type derive
      add_tag_prefix derive
      key1 foo_count *1000
      key2 bar_count *1000
    </match>

Assuming following inputs are coming:

    2013-12-19 20:01:00 +0900 foo.bar: {"foo_count":  100, "bar_count":  200}
    2013-12-19 20:02:00 +0900 foo.bar: {"foo_count":  700, "bar_count": 1400}
    2013-12-19 20:03:10 +0900 foo.bar: {"foo_count":  700, "bar_count": 1470}
    2013-12-19 20:04:10 +0900 foo.bar: {"foo_count": 1300, "bar_count":  870}

then output becomes as below:

    2013-12-19 20:01:00 +0900 derive.foo.bar: {"foo_count":   nil, "bar_count":    nil}
    2013-12-19 20:02:00 +0900 derive.foo.bar: {"foo_count": 10000, "bar_count":  20000}
    2013-12-19 20:03:10 +0900 derive.foo.bar: {"foo_count":     0, "bar_count":   1000}
    2013-12-19 20:04:10 +0900 derive.foo.bar: {"foo_count": 10000, "bar_count": -10000}

## Paramteres
* key[1-20] [Adjustment]

A pair of a field name of the input record, and to be calculated. key1 or key_pattern is required. `Adjustment` is optional.

Use `Adjustment` like follow:

    key1 foo_count *3600000 => output the rate as K/h
    key1 foo_count *8       => shift unit (e.g. Byteps to bps)
    key1 foo_count /1000    => shift unit (e.g. M to K)

* key_pattern [Adjustment]

A pair of a regular expression to specify field names of the input record, and to be calculated. key1 or key_pattern is required. `Adjustment` is optional.

* tag

The output tag name

* add_tag_prefix

Add tag prefix for output message

* remove_tag_prefix

Remove tag prefix for output message

* min

Define the expected range value. If min and/or max are specified any value outside the defined range will be truncated.

* max

Define the expected range value. If min and/or max are specified any value outside the defined range will be truncated.

* time_unit_division

Optional. Divide the incleased value by interval time before output. The default is `true`. Set `false` for disable dividing.

* counter_mode

Optional. Use RRD's counter mode. The default is `false`. Set `true` for use RRD's counter.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
