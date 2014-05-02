# fluent-tail-multiline-ex, a plugin for [Fluentd](http://fluentd.org)

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
 [tail_ex plugin](https://github.com/yosisa/fluent-plugin-tail-ex). and [tail_multiline plugin](https://github.com/tomohisaota/fluent-plugin-tail-multiline).

## Example
### Tomcat7 catalina.%Y-%m-%d.log
####input
```
May 02, 2014 3:42:48 PM org.apache.catalina.core.StandardServer await
SEVERE: StandardServer.await: create[localhost:8005]: 
java.net.BindException: Address already in use
	at java.net.PlainSocketImpl.socketBind(Native Method)
	at java.net.AbstractPlainSocketImpl.bind(AbstractPlainSocketImpl.java:376)
	at java.net.ServerSocket.bind(ServerSocket.java:376)
	at java.net.ServerSocket.<init>(ServerSocket.java:237)
	at org.apache.catalina.core.StandardServer.await(StandardServer.java:426)
	at org.apache.catalina.startup.Catalina.await(Catalina.java:777)
	at org.apache.catalina.startup.Catalina.start(Catalina.java:723)
	at sun.reflect.NativeMethodAccessorImpl.invoke0(Native Method)
	at sun.reflect.NativeMethodAccessorImpl.invoke(NativeMethodAccessorImpl.java:57)
	at sun.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)
	at java.lang.reflect.Method.invoke(Method.java:606)
	at org.apache.catalina.startup.Bootstrap.start(Bootstrap.java:321)
	at org.apache.catalina.startup.Bootstrap.main(Bootstrap.java:455)

May 02, 2014 3:42:48 PM org.apache.coyote.AbstractProtocol pause
INFO: Pausing ProtocolHandler ["http-bio-8080"]
```
####configuration
```
<source>
 type tail_multiline_ex
 format_firstline  /^(?<time>[^ ]* [^ ]*, [^ ]* [^ ]* [^ ]*)/
 format  /^(?<time>[^ ]* [^ ]*, [^ ]* [^ ]* [^ ]*) (?<class>[^ ]+) (?<method>.[^ ]*)\n(?<level>[^ ]+): (?<messages>.*)/
 time_format %b %d, %Y %l:%M:%S %p
 path  /opt/tomcat/logs/catalina.%Y-%m-%d.log
 pos_file /var/log/td-agent/position/tomcat.pos
 tag tomcat.catalina.log
 refresh_interval 5
</source>
```
####output
```
2014-05-02 15:42:48	tomcat.catalina.log	{"class":"org.apache.catalina.core.StandardServer","method":"await","level":"SEVERE","messages":"StandardServer.await: create[localhost:8005]: \njava.net.BindException: Address already in use\n\tat java.net.PlainSocketImpl.socketBind(Native Method)\n\tat java.net.AbstractPlainSocketImpl.bind(AbstractPlainSocketImpl.java:376)\n\tat java.net.ServerSocket.bind(ServerSocket.java:376)\n\tat java.net.ServerSocket.<init>(ServerSocket.java:237)\n\tat org.apache.catalina.core.StandardServer.await(StandardServer.java:426)\n\tat org.apache.catalina.startup.Catalina.await(Catalina.java:777)\n\tat org.apache.catalina.startup.Catalina.start(Catalina.java:723)\n\tat sun.reflect.NativeMethodAccessorImpl.invoke0(Native Method)\n\tat sun.reflect.NativeMethodAccessorImpl.invoke(NativeMethodAccessorImpl.java:57)\n\tat sun.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)\n\tat java.lang.reflect.Method.invoke(Me
thod.java:606)\n\tat org.apache.catalina.startup.Bootstrap.start(Bootstrap.java:321)\n\tat org.apache.catalina.startup.Bootstrap.main(Bootstrap.java:455)\n"}
2014-05-02 15:42:48	dhcp-177-129.tomcat.catalina.log	{"class":"org.apache.coyote.AbstractProtocol","method":"pause","level":"INFO","messages":"Pausing ProtocolHandler [\"http-bio-8080\"]"}
```



## Thanks

Grateful to the authors of tail_ex, tail_multiline and Fluentd!

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request


