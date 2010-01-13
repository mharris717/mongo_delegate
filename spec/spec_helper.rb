$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'mongo_delegate'
require 'spec'
require 'spec/autorun'
require 'rr'

Spec::Runner.configure do |config|
  config.mock_with :rr
end
