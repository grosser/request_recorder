Record your rack/rails requests and store them for future inspection + see them in your chrome console.

Install
=======

    gem install request_recorder

Add to your middleware stack:

    require "request_recorder"

    require "request_recorder/cache_logger"
    use RequestRecorder::Middleware,
      :store => RequestRecorder::CacheLogger.new(Rails.cache),
      :frontend_auth => lambda { |env| Rails.env.development? } # TODO use something like `env.warden.user.is_admin?` in production
      # if you get 502's because of too large headers, you can reduce them: everything in :remove will be removed when above :max
      # :headers => {:max => 10_000, :remove => [/Identity Map/, /Cache local read/, /Cache read/, /SELECT count(\*)/, /SELECT \* FROM/] }

Usage
=====

 - request a page with `/something?request_recorder=10-my_session_name` -> record next 10 requests from my browser
 - all the debug-level logging info from rails + activerecord gets stored
 - get log directly from the store or use the frontend

Chrome console
==============
(needs `:frontend_auth`)

 - Install [Chrome extension](https://chrome.google.com/webstore/detail/chrome-logger/noaneddfkdjfnfdakjjmocngnfkfehhd) by [Craig Campbell](http://craig.is)
 - Enable it<br/> ![Enable](http://cdn.craig.is/img/chromelogger/toggle.gif)
 - Open console<br/> ![Profit](https://dl.dropboxusercontent.com/u/2670385/Web/request_recorder_output.png)

Web-frontend
========
(needs `:frontend_auth`)

![Frontend](https://dl.dropboxusercontent.com/u/2670385/Web/request_recorder_frontend.png)

See the log of **all** requests in the session: `/request_recorder/my_session_name`.
This also includes requests that did not get shown in the chrome logger like redirects.

Author
======
[Michael Grosser](http://grosser.it)<br/>
michael@grosser.it<br/>
License: MIT<br/>
[![Build Status](https://travis-ci.org/grosser/request_recorder.png)](https://travis-ci.org/grosser/request_recorder)
