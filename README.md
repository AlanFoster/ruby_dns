# RubyDns

Simple DNS server written in Ruby to test writing a simple server with sockets and BinData.
Definitely not production ready or feature complete.

## Testing

```
bundle exec rspec
```

### Examples

Running DNS on port 53 requires the correct permissions:

```
$ sudo -E ./examples/example.rb
Starting server on 127.0.0.1:53 ...
```

Verifying with dig:

```
$ dig +time=10000 example.com @127.0.0.1

; <<>> DiG 9.10.6 <<>> +time=10000 example.com @127.0.0.1
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 13498
;; flags: qr aa; QUERY: 1, ANSWER: 2, AUTHORITY: 0, ADDITIONAL: 0

;; QUESTION SECTION:
;example.com.                   IN      A

;; ANSWER SECTION:
example.com.            400     IN      A       255.255.255.255
example.com.            400     IN      A       127.0.0.1

;; Query time: 1 msec
;; SERVER: 127.0.0.1#53(127.0.0.1)
;; WHEN: Sun Jun 28 20:02:32 BST 2020
;; MSG SIZE  rcvd: 83
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
