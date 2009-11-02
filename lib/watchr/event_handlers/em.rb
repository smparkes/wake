require "eventmachine"

require 'watchr/event_handlers/unix'

module Watchr
  module EventHandler
    class EM

      Watchr::EventHandler::Unix.defaults << self
      
      ::EM.kqueue = true if ::EM.kqueue?
      
      ::EM.error_handler do |e|
        puts "EM recevied: #{e.message}"
        puts e.backtrace
        exit
      end

      include Base

      module SingleFileWatcher #:nodoc:
        class << self
          # Stores a reference back to handler so we can call its #nofity
          # method with file event info
          attr_accessor :handler
        end

        # File's path as a Pathname
        def pathname
          @pathname ||= Pathname(path)
        end

        def file_modified
          SingleFileWatcher.handler.notify(path, type)
        end

        def file_moved
p "need to reparse"
        end

        def file_deleted
          SingleFileWatcher.handler.remove(path)
        end

        # Callback. Called on file change event
        # Delegates to Controller#update, passing in path and event type
        def on_change
          self.class.handler.notify(path, type)
          update_reference_times unless type == :deleted
        end

        def update_reference_times
          @reference_atime = pathname.atime
          @reference_mtime = pathname.mtime
          @reference_ctime = pathname.ctime
        end

        private

        # Type of latest event.
        #
        # A single type is determined, even though more than one stat times may
        # have changed on the file. The type is the first to match in the
        # following hierarchy:
        #
        #   :deleted, :modified (mtime), :accessed (atime), :changed (ctime)
        #
        # ===== Returns
        # type<Symbol>:: latest event's type
        #
        def type
          return :deleted   if !pathname.exist?
          return :modified  if  pathname.mtime > @reference_mtime
          return :accessed  if  pathname.atime > @reference_atime
          return :changed   if  pathname.ctime > @reference_ctime
        end
      end

      def initialize
        SingleFileWatcher.handler = self
        @old_paths = []
      end

      # Enters listening loop.
      #
      # Will block control flow until application is explicitly stopped/killed.
      #
      def listen(monitored_paths)
        @monitored_paths = monitored_paths
        ::EM.run do
          attach
        end
      end

      # Rebuilds file bindings.
      #
      # will detach all current bindings, and reattach the <tt>monitored_paths</tt>
      #
      def refresh(monitored_paths)
        attach
      end

      private

      # Binds all <tt>monitored_paths</tt> to the listening loop.
      def attach
        new_paths = @monitored_paths.uniq - @old_paths
        new_paths.each do |path|
          ::EM.watch_file path.to_s, SingleFileWatcher do |watcher|
            p path.to_s
            watcher.update_reference_times
          end
        end
        @old_paths = @monitored_paths
      end

      # Unbinds all paths currently attached to listening loop.
      def detach
        @loop.watchers.each {|watcher| watcher.detach }
      end
    end
  end
end
