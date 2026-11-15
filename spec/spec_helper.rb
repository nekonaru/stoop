# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'stoop'
require 'fileutils'

# Removes a temp dir, tolerating brief Windows file-lock races on SQLite
# WAL sidecars. Leaves the directory behind if removal still fails; the OS
# temp folder is reclaimed anyway.
module TempTreeHelper
  def remove_tree(path)
    3.times do
      begin
        FileUtils.remove_entry(path)
        return
      rescue Errno::EACCES, Errno::EPERM, Errno::ENOTEMPTY
        sleep 0.1
      end
    end
  end
end

RSpec.configure do |config|
  config.include TempTreeHelper

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.disable_monkey_patching!
  config.warnings = true
  config.order = :random
  Kernel.srand config.seed
end
