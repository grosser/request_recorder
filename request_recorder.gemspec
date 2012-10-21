$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
name = "request_recorder"
require "#{name}/version"

Gem::Specification.new name, RequestRecorder::VERSION do |s|
  s.summary = "Record your rack/rails requests and store them for future inspection"
  s.authors = ["Michael Grosser"]
  s.email = "michael@grosser.it"
  s.homepage = "http://github.com/grosser/#{name}"
  s.files = `git ls-files`.split("\n")
  s.license = "MIT"
  s.add_runtime_dependency "rack"
  s.add_runtime_dependency "activerecord"
end
