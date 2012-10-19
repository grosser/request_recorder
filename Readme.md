Record your rack/rails requests and store them for future inspection

Install
=======

    gem install request_recorder

Add to your middleware stack:

    require "request_recorder"

    require "request_recorder/cache_logger"
    use RequestRecorder::Middleware, :store => RequestRecorder::CacheLogger.new(Rails.cache)

    -- or --

    require "request_recorder/redis_logger"
    use RequestRecorder::Middleware, :store => RequestRecorder::RedisLogger.new(Redis.new)

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
