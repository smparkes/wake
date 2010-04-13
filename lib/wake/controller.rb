require 'find'

module Wake

  class Refresh < Exception; end

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
    
    def initialize(script)
      @script  = script
    end

    def run
      @script.parse!
      @state = :all
      graph = self.graph true
      handler.listen(graph.paths)
    rescue Interrupt
    end

    def update path = nil, event_type = nil
      # puts "update #{path} #{event_type}"
      if !path
        execute
      elsif path == :sig_quit # ick!
        @state = :all
      else
        graph[path] and graph[path].changed!
      end
    end

    def execute
      puts "execute: #{@state}"
      fired = false
      success = true
      graph = self.graph true
      # pp graph.levelize(graph.nodes,:depends_on).map { |level| level.map { |n| n.path } }
      l = 0
      graph.levelize(graph.nodes, :depends_on, @state).each do |level|
        # pp level.map { |n| n.path }.sort
        l+=1
        level = level.select do |n|
          v = n.out_of_date? @state
          puts "odd: #{n.path} #{@state} #{v}" if false && v != nil
          v
        end
        plugin_hash = level.inject({}) do |hash,node|
          # p node.path, node.object_id, node.plugin ? node.plugin.class : "nope"
          if plugin = node.plugin
            hash[plugin] ||= []
            hash[plugin] << node
          end
          hash
        end
        plugin_hash.each do |plugin, nodes|
          fired = true
          success &&= plugin.fire_all.call nodes
        end
      end
      if !success
        @state = :changed_failing
      else
        if @state == :changed_failing
          if fired
            @state = :failed
            execute
          end
        elsif @state == :failed
          @state = :all
          execute
        else
          @state = :changed
        end
      end
      # p "<s", @state
    end

    def graph rescan = false
      if !@graph || rescan && (@script_modified_at != @script.modified_at or @script_rescan != @script.rescan)
        # puts "rescan #{@script_modified_at != @script.modified_at} #{@script_rescan != @script.rescan}"
        @script_modified_at = @script.modified_at
        @script_rescan = @script.rescan
        # paths = Dir['**/*'].select do |path|
        @graph = Graph.new
        pruners = @script.plugins.map { |pi| pi.pruner }.compact
        watchers = @script.plugins.map { |pi| pi.watcher }.compact
        Find.find(".") do |path|
          path.sub! %r{^\./}, ""
          pruners.map { |pruner| pruner.call( path ) && Find.prune }
          watchers.map { |watcher| watcher.call( path, @graph ) }
        end
        ::EM.reactor_running? and handler.refresh(@graph.paths)
      end
      # pp graph.paths
      # pp graph.levelize(graph.nodes,:depends_on).map { |level| level.map { |n| n.path } }
      # pp graph.levelize(graph.nodes(:depends_on),:depended_on_by).map { |level| level.map { |n| n.path } }
      # graph.paths.keys
      @graph
    end
  end
end
