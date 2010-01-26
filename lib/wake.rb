require 'pathname'
require 'rbconfig'

# Agile development tool that monitors a directory recursively, and triggers a
# user defined action whenever an observed file is modified. Its most typical
# use is continuous testing.
#
# Usage:
#
#   # on command line, from project's root dir
#   $ wake path/to/script
#   # default script if none is given is Wakefile.
#
# See README for more details
#
module Wake
  VERSION = '0.1.0'

  autoload :Script,     'wake/script'
  autoload :Controller, 'wake/controller'

  module EventHandler
    autoload :Base,     'wake/event_handlers/base'
    autoload :Unix,     'wake/event_handlers/unix'
    autoload :Portable, 'wake/event_handlers/portable'
  end

  class << self
    # backwards compatibility
    def version #:nodoc:
      Wake::VERSION
    end

    # Options proxy.
    #
    # Currently supported options:
    # * debug<Boolean> Debugging state. More verbose.
    #
    # ===== Examples
    #
    #   Wake.options.debug #=> false
    #   Wake.options.debug = true
    #
    # ===== Returns
    # options<Struct>:: options proxy.
    #
    #--
    # On first use, initialize the options struct and default option values.
    def options
      @options ||= Struct.new(:debug,:once, :wakefile).new
      @options.debug ||= false
      @options.once.nil? and @options.once = false
      @options
    end

    def options= arg
      @options = arg
    end

    # Outputs formatted debug statement to stdout, only if ::options.debug is true
    #
    # ===== Examples
    #
    #   Wake.options.debug = true
    #   Wake.debug('im in ur codes, notifayinin u')
    #
    # outputs: "[wake debug] im in ur codes, notifayinin u"
    #
    def debug(str)
      puts "[wake debug] #{str}" if options.debug
    end

    # Detect current OS and return appropriate handler.
    #
    # ===== Examples
    #
    #   Config::CONFIG['host_os'] #=> 'linux-gnu'
    #   Wake.handler #=> Wake::EventHandler::Unix
    #
    #   Config::CONFIG['host_os'] #=> 'cygwin'
    #   Wake.handler #=> Wake::EventHandler::Portable
    #
    #   ENV['HANDLER'] #=> 'unix'
    #   Wake.handler #=> Wake::EventHandler::Unix
    #
    #   ENV['HANDLER'] #=> 'portable'
    #   Wake.handler #=> Wake::EventHandler::Portable
    #
    # ===== Returns
    # handler<Class>:: handler class for current architecture
    #
    def handler
      @handler ||=
        case ENV['HANDLER'] || Config::CONFIG['host_os']
          when /mswin|windows|cygwin/i
            Wake::EventHandler::Portable
          when /sunos|solaris|darwin|mach|osx|bsd|linux/i, 'unix'
            Wake::EventHandler::Unix.default
          else
            Wake::EventHandler::Portable
        end
    end
    
    def handler= arg
      @handler = arg
    end

  end
end
