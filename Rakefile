require "bundler/setup"
require "bundler/gem_tasks"
require "bump/tasks"
require "appraisal"

task :spec do
  sh "rspec spec/"
end

task :default do
  sh "rake appraisal:install && rake appraisal spec"
end
