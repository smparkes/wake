require 'find'

module Wake

  class Refresh < Exception; end

  # The controller contains the app's core logic.
  #
  # ===== Examples
  #
  #   script = Wake::Script.new(file)
  #   contrl = Wake::Controller.new(script)
  #   contrl.run
  #
  # Calling <tt>#run</tt> will enter the listening loop, and from then on every
  # file event will trigger its corresponding action defined in <tt>script</tt>
  #
  # The controller also automatically adds the script's file itself to its list
  # of monitored files and will detect any changes to it, providing on the fly
  # updates of defined rules.
  #
  class Controller

    def handler
      @handler ||= begin
                     handler = Wake.handler.new
                     handler.add_observer self
                     Wake.debug "using %s handler" % handler.class.name
                     Script.handler = handler
                     handler
                   end
      @handler
    end
    
    # Creates a controller object around given <tt>script</tt>
    #
    # ===== Parameters
    # script<Script>:: The script object
    #
    def initialize(script)
      @script  = script
    end

    # Enters listening loop.
    #
    # Will block control flow until application is explicitly stopped/killed.
    #
    def run
      @script.parse!
      graph = self.graph
      producers = @script.plugins.map { |pi| pi.producer }.compact
      pp producers
      handler.listen(graph.paths)
    rescue Interrupt
    end

    # Callback for file events.
    #
    # Called while control flow in in listening loop. It will execute the
    # file's corresponding action as defined in the script. If the file is the
    # script itself, it will refresh its state to account for potential changes.
    #
    # ===== Parameters
    # path<Pathname, String>:: path that triggered event
    # event<Symbol>:: event type (ignored for now)
    #
    def update(path, event_type = nil)
      path = Pathname(path).expand_path
      # p path, event_type
      # if path == @script.path && ![ :load, :deleted, :moved ].include?(event_type)
      if path == @script.path && event_type == :modified
        @script.parse!
        handler.refresh(monitored_paths)
      else
        refresh = false
        begin
          @script.call_action_for(path, event_type)
        rescue Refresh => refresh
          refresh = true
        end
        if refresh or ( File.directory? path and event_type == :modified )
          handler.refresh(monitored_paths)
        end
      end
    end

    def graph
      # paths = Dir['**/*'].select do |path|
      graph = Graph.new
      pruners = @script.plugins.map { |pi| pi.pruner }.compact
      watchers = @script.plugins.map { |pi| pi.watcher }.compact
      Find.find(".") do |path|
        path.sub! %r{^\./}, ""
        pruners.map { |pruner| pruner.call( path ) && Find.prune }
        watchers.map { |watcher| watcher.call( path, graph ) }


        if false
          watch = false
          @script.rules.reverse.each do |r|
            rule_watches = r.watch(path)
            if false
              $stderr.print "watch ", path, " ", rule_watches, "\n"
            end
            next if rule_watches.nil?
            watch = rule_watches
            if !watch
              Find.prune
            end
            break
          end
          paths << path if watch || File.directory?(path)
        end




      end

      if false
      while !(new_paths = graph.paths.keys - paths.keys).empty?
        pp "new", new_paths
        paths = graph.paths
        new_paths.each do |path|
          p "x", path, watchers
          watchers.map { |watcher| watcher.call( path, graph ) and paths[path] = path }
        end
        pp "a", graph.paths.keys.sort
        pp "b",paths.keys.sort
        pp "c", graph.paths.keys.sort - paths.keys.sort
      end
      end

      # pp caller(0)


      if false
      paths.each do |path|
        # $stderr.print "lookup #{path}\n"
        @script.depends_on(path).each do |dependence|
          # $stderr.print "add #{dependence} for #{path}\n"
          paths << dependence
        end
      end
      paths.push(@script.path).compact!
      paths.uniq!
      # $stderr.print "watch #{paths.map {|path| Pathname(path).expand_path }.join(' ')}\n"
      paths.map {|path| Pathname(path).expand_path }
      end

      pp graph.paths
      pp graph.levelize(graph.nodes,:depends_on).map { |level| level.map { |n| n.path } }
      pp graph.levelize(graph.nodes.reverse,:depended_on_by).map { |level| level.map { |n| n.path } }
      # graph.paths.keys
      graph
    end
  end
end
