Record your rack/rails requests and store them for future inspection

Install
=======

    gem install request_recorder

Usage
=====

 - Add it to the bottom of you middleware stack
 - request a page with __request_recording=10 -> record next 10 requests from my browser
 - RequestRecorded::Requests gets a new entry with all the logging info from rails + activerecord
 - go to the database or build a nice frontend for RequestRecorded::Requests

Author
======
[Michael Grosser](http://grosser.it)<br/>
michael@grosser.it<br/>
License: MIT<br/>
[![Build Status](https://secure.travis-ci.org/grosser/request_recorder.png)](http://travis-ci.org/grosser/request_recorder)
