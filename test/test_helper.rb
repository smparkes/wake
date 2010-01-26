require 'pathname'
require 'tempfile'
require 'test/unit'

require 'matchy'
require 'mocha'
require 'every'
require 'pending'
begin
  require 'redgreen'
  require 'phocus'
  require 'ruby-debug'
rescue LoadError, RuntimeError
end

root = Pathname(__FILE__).dirname.parent.expand_path
$:.unshift(root.join('lib').to_s).uniq!

require 'wake'

class Test::Unit::TestCase
  class << self
    def test(name, &block)
      name = :"test_#{name.gsub(/\s/,'_')}"
      define_method(name, &block)
    end
    alias :should :test

    # noop
    def xtest(*args) end
  end
end

# taken from minitest/unit.rb
# (with modifications)
def capture_io
  require 'stringio'

  orig_stdout, orig_stderr         = $stdout, $stderr
  captured_stdout, captured_stderr = StringIO.new, StringIO.new
  $stdout, $stderr                 = captured_stdout, captured_stderr

  yield

  return Struct.new(:stdout, :stderr).new(
    captured_stdout.string,
    captured_stderr.string
  )
ensure
  $stdout = orig_stdout
  $stderr = orig_stderr
end

begin
  require "wake/event_handlers/rev"
  HAVE_REV = true
rescue LoadError
  HAVE_REV = false
end

