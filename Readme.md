Record your rack/rails requests and store them for future inspection

Install
=======

    gem install request_recorder

Add to your middleware stack:

    require "request_recorder"
    use RequestRecorder::Middleware, :store => RequestRecorder::RedisLogger.new(Redis.new)

### No Redis, No problem
If you do not have redis, you can write your own logger, you only need a .write method,
see [RedisLogger](https://github.com/grosser/request_recorder/blob/master/lib/request_recorder/redis_logger.rb)

Usage
=====

 - request a page with `/something?__request_recording=10` -> record next 10 requests from my browser
 - redis 'request_recorder' gets a new entry with all the logging info from rails + activerecord
 - go to redis or build a nice frontend

Author
======
[Michael Grosser](http://grosser.it)<br/>
michael@grosser.it<br/>
License: MIT<br/>
[![Build Status](https://travis-ci.org/grosser/request_recorder.png)](https://travis-ci.org/grosser/request_recorder)
