# fluent-tail-multiline-ex,a plugin for Fluentd

tail_multiline_ex merged the great and useful functions of tail_ex and tail_multiline.(simply copy the both code and change the symbols)

## Installation

Add this line to your application's Gemfile:

    gem 'fluent-plugin-tail-multiline-ex'

And then execute:

    $ bundle

Or, if you're using td-client, you can call td-client's gem

    $ /usr/lib64/fluent/ruby/bin/gem install fluent-plugin-tail-multiline-ex

## Basic Usage

tail-multiline_ex extends 
 [tail_ex plugin](https://github.com/yosisa/fluent-plugin-tail-ex).   
and
 [tail_multiline plugin](https://github.com/tomohisaota/fluent-plugin-tail-multiline).

## Thanks

Grateful to the authors of tail_ex, tail_multiline and Fluentd!

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
