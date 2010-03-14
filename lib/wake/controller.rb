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
      graph = self.graph
      @all = true
      handler.listen(graph.paths)
    rescue Interrupt
    end

    def update path = nil, event_type = nil
      if !path
        execute
      elsif path == :sig_quit
        @all = true
      else
        graph[path].changed!
      end
    end

    def execute
      graph = self.graph
      # pp graph.levelize(graph.nodes,:depends_on).map { |level| level.map { |n| n.path } }
      l = 0
      graph.levelize(graph.nodes, :depends_on, @all).each do |level|
        l+=1
        level = level.select { |n| n.out_of_date? @all }
        plugin_hash = level.inject({}) do |hash,node|
          # p node.path, node.object_id, node.plugin ? node.plugin.class : "nope"
          if plugin = node.plugin
            hash[plugin] ||= []
            hash[plugin] << node
          end
          hash
        end
        plugin_hash.each do |plugin, nodes|
          plugin.fire_all.call nodes
        end
      end
      @all = false
    end

    def _update(path, event_type = nil)
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
      if @script_modified_at != @script.modified_at
        @script_modified_at = @script.modified_at
        # paths = Dir['**/*'].select do |path|
        @graph = Graph.new
        pruners = @script.plugins.map { |pi| pi.pruner }.compact
        watchers = @script.plugins.map { |pi| pi.watcher }.compact
        Find.find(".") do |path|
          path.sub! %r{^\./}, ""
          pruners.map { |pruner| pruner.call( path ) && Find.prune }
          watchers.map { |watcher| watcher.call( path, @graph ) }
        end
      end

      # pp graph.paths
      # pp graph.levelize(graph.nodes,:depends_on).map { |level| level.map { |n| n.path } }
      # pp graph.levelize(graph.nodes(:depends_on),:depended_on_by).map { |level| level.map { |n| n.path } }
      # graph.paths.keys
      @graph
    end
  end
end
