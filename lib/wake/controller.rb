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
      handler.listen(monitored_paths)
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
      if path == @script.path && ![ :load, :deleted, :moved ].include?(event_type)
        @script.parse!
        handler.refresh(monitored_paths)
      else
        begin
          @script.call_action_for(path, event_type)
        rescue Refresh => refresh
          handler.refresh(monitored_paths)
        end
      end
    end

    # List of paths the script is monitoring.
    #
    # Basically this means all paths below current directoly recursivelly that
    # match any of the rules' patterns, plus the script file.
    #
    # ===== Returns
    # paths<Array[Pathname]>:: List of monitored paths
    #
    def monitored_paths
      paths = Dir['**/*'].select do |path|
        watch = false
        @script.rules.reverse.each do |r|
          rule_watches = r.watch(path)
          if false
            $stderr.print "watch ", path, " ", rule_watches, "\n"
          end
          next if rule_watches.nil?
          watch = rule_watches
          break
        end
        watch
      end
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
  end
end
