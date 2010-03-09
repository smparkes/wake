require 'wake/graph'

class Wake::Graph::Node
  attr_reader :path

  class DependenceSet
    attr_reader :node
    def initialize node
      @node = node
    end
    def each &block
      nodes.values.each( &block )
    end
  end

  class DependsOn < DependenceSet
    def nodes
      @nodes ||= {}
    end
    def << node
      if !nodes.has_key? node
        nodes[node] = node 
        node.depended_on_by << self.node
      end
    end
  end

  class DependedOnBy < DependenceSet
    def nodes
      @nodes ||= {}
    end
    def << node
      if !nodes.has_key? node
        nodes[node] = node 
        node.depends_on << self.node
      end
    end
  end

  def initialize path
    @path = path
  end

  def watchers
    @watchers ||= {}
  end

  def depends_on
    @depends_on ||= DependsOn.new self
  end

  def depended_on_by
    @depended_on_by ||= DependedOnBy.new self
  end

  def << watcher
    watchers.has_key?( watcher ) ? false : ( watchers[watcher] = watcher and true )
  end
end

