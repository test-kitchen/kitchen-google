# frozen_string_literal: true

#
# Author:: Chef Partner Engineering (<partnereng@chef.io>)
# Copyright:: Copyright (c) Chef Software, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Test Kitchen's top-level namespace.
module Kitchen
  # Namespace for Test Kitchen driver plugins.
  module Driver
    # Version of the kitchen-google gem.
    #
    # Maintained by release-please, which rewrites the literal below on each
    # release. Keep it on one line.
    #
    # @return [String] the gem version
    GCE_VERSION = "2.7.0"
  end
end
