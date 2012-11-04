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

 - request a page with `/something?request_recorder=10|my-session-name` -> record next 10 requests from my browser
 - redis 'request_recorder' gets a new entry with all the logging info from rails + activerecord
 - go to redis or build a nice frontend

Frontend
========

  Add :frontend_auth and find out if the current user is authorized

    use RequestRecorder::Middleware, :frontent_auth => lambda{|env| env.warden.user.is_admin? }

Go to `/request_recorder/<key>` and see the recorded log.

Author
======
[Michael Grosser](http://grosser.it)<br/>
michael@grosser.it<br/>
License: MIT<br/>
[![Build Status](https://travis-ci.org/grosser/request_recorder.png)](https://travis-ci.org/grosser/request_recorder)
