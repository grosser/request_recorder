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

Usage
=====

 - request a page with `/something?request_recorder=10-my_session_name` -> record next 10 requests from my browser
 - all the debug-level logging info from rails + activerecord gets stored
 - get log directly from the store or use the frontend

Chrome console
==============
(needs `:frontend_auth`)

 - Install [Chrome extension](https://chrome.google.com/webstore/detail/chrome-logger/noaneddfkdjfnfdakjjmocngnfkfehhd) by [Ryan Cook](https://github.com/cookrn)
 - Enable it<br/> ![Enable](http://cdn.craig.is/img/chromelogger/toggle.gif)
 - Open console<br/> ![Profit](https://dl.dropboxusercontent.com/u/2670385/Web/request_recorder_output.png)

Frontend
========
(needs `:frontend_auth`)
See the log of all requests in an entire session: `/request_recorder/my_session_name`.
This also includes requests that did not get shown in the chrome logger like redirects.

Author
======
[Michael Grosser](http://grosser.it)<br/>
michael@grosser.it<br/>
License: MIT<br/>
[![Build Status](https://travis-ci.org/grosser/request_recorder.png)](https://travis-ci.org/grosser/request_recorder)
