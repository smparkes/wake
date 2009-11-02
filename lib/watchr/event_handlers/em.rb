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

        def init first_time
          # p "w", path, first_time,(first_time ? :load : :created)
          update_reference_times
          SingleFileWatcher.handler.notify(path, (first_time ? :load : :created) )
        end

        # File's path as a Pathname
        def pathname
          @pathname ||= Pathname(path)
        end

        def file_modified
          SingleFileWatcher.handler.notify(path, type)
          update_reference_times
        end

        def file_moved
          stop_watching
          SingleFileWatcher.handler.notify(path, type)
        end

        def file_deleted
          SingleFileWatcher.handler.notify(path, type)
        end

        private

        def update_reference_times
          @reference_atime = pathname.atime
          @reference_mtime = pathname.mtime
          @reference_ctime = pathname.ctime
        end

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
        @first_time = true
        @watchers = {}
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
        @monitored_paths = monitored_paths
        attach
      end

      private

      # Binds all <tt>monitored_paths</tt> to the listening loop.
      def attach
        @monitored_paths = @monitored_paths.uniq 
        new_paths = @monitored_paths - @old_paths
        remove_paths = @old_paths - @monitored_paths
        # p "want", @monitored_paths
        # p "old", @old_paths
        # p "new", new_paths
        raise "hell" if @monitored_paths.length == 1
        new_paths.each do |path|
          ::EM.watch_file path.to_s, SingleFileWatcher do |watcher|
            watcher.init @first_time
            raise "hell" if @watchers[path]
            @watchers[path] = watcher
          end
        end
        remove_paths.each do |path|
          watcher = @watchers[path]
          raise "hell" if !watcher
          watcher.stop
        end
        @old_paths = @monitored_paths
        @first_time = false
      end

      # Unbinds all paths currently attached to listening loop.
      def detach
        @loop.watchers.each {|watcher| watcher.detach }
      end
    end
  end
end
