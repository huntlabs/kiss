[![Build Status](https://travis-ci.org/huntlabs/kiss.svg?branch=master)](https://travis-ci.org/huntlabs/kiss)

# Kiss library
A refined core library for D programming language.

## Modules
 * event ( kqueue / epoll / iocp )
 * net ( TcpListener / TcpStream )
 * serialize
 * radix-tree
 * timer
 * container
 * memory
 * buffer
 * configration
 * logger

## Platforms
 * FreeBSD
 * Windows
 * OSX
 * Linux
 * NetBSD
 * OpenBSD

## Libraries
 * [collie](https://github.com/huntlabs/collie) – An asynchronous event-driven network framework written in D.

## Frameworks
 * [hunt](https://github.com/huntlabs/hunt) – Hunt is a high-level D Programming Language Web framework that encourages rapid development and clean, pragmatic design. It lets you build high-performance Web applications quickly and easily.

## Benchmarks
![Benchmark](docs/images/benchmark-2.png)

For details, see [here](docs/benchmark.md).

## TODO
- [x] Publish v0.4
- [x] Clean up all the deprecated code
- [ ] Performance improvement
- [ ] Stablize APIs
- [ ] More friendly APIs
- [ ] More examples
- [x] Use kiss.logger for inner debugging
- [x] Benchmark test
- [x] Improving supports on Mac OS
