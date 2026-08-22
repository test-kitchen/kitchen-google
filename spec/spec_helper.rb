# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "kitchen/driver/gce"
require "kitchen/transport/dummy"

Dir[File.expand_path("support/**/*.rb", __dir__)].sort.each { |file| require file }

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
    expectations.syntax = :expect
  end

  config.mock_with :rspec do |mocks|
    mocks.syntax = :expect

    # Doubles standing in for a real class reject messages that class does not
    # respond to, and check arity. This is what keeps the specs honest about
    # the Google API surface.
    mocks.verify_partial_doubles = true
  end

  # No `should`, no globally-exposed DSL: everything is namespaced under RSpec.
  config.disable_monkey_patching!

  # A deprecation is a bug we have not noticed yet.
  config.raise_errors_for_deprecations!

  # One example may report several independent failures instead of stopping at
  # the first, which matters when asserting over a built API payload.
  config.define_derived_metadata { |meta| meta[:aggregate_failures] = true }

  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.warnings = false

  config.default_formatter = "doc" if config.files_to_run.one?

  # Surface order dependencies; reproduce a failure with `--seed`.
  config.order = :random
  Kernel.srand config.seed
end
