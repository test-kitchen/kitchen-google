require "bundler/gem_tasks"
require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:test)

begin
  require "cookstyle/chefstyle"
  require "rubocop/rake_task"
  RuboCop::RakeTask.new(:style) do |task|
    task.options += ["--display-cop-names", "--no-color"]
  end
rescue LoadError
  puts "cookstyle/chefstyle is not available. (sudo) gem install cookstyle to do style checking."
end

begin
  require "yard"

  YARD::Rake::YardocTask.new(:yard) do |task|
    task.stats_options = ["--list-undoc"]
  end

  namespace :yard do
    desc "Report documentation coverage and list undocumented objects"
    task :stats do
      sh "yard stats --list-undoc"
    end

    desc "Serve the documentation locally at http://localhost:8808, reloading on change"
    task :server do
      sh "yard server --reload"
    end
  end
rescue LoadError
  puts "yard is not available. (sudo) gem install yard to generate documentation."
end

namespace :integration do
  # Deliberately not part of any default task: these create real instances and
  # real disks in a real project, and cost real money.
  desc "Run the integration suites against GCE (requires a GCP project)"
  task :test do
    Dir.chdir("integration") { sh "bundle exec kitchen test --concurrency 4" }
  end

  desc "Destroy anything the integration suites left behind"
  task :destroy do
    Dir.chdir("integration") { sh "bundle exec kitchen destroy --concurrency 4" }
  end

  desc "List the integration suites"
  task :list do
    Dir.chdir("integration") { sh "bundle exec kitchen list" }
  end
end

# Documentation is intentionally NOT part of the default task: missing YARD
# comments should never fail CI.
task default: %i{test style}
