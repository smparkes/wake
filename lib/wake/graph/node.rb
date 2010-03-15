require 'wake/graph'

class Wake::Graph::Node
  attr_reader :path

  class DependenceSet
    attr_reader :node
    def initialize node
      @node = node
    end
    def nodes
      @nodes ||= {}
    end
    def each &block
      nodes.values.each( &block )
    end
    def << node
      if !nodes.has_key? node
        nodes[node] = node 
        # puts "#{node.path} #{symbol} #{self.node.path}"
        node.send(symbol) << self.node
      end
    end
    def replace from, to
      # puts "delete #{from.object_id} add #{to.object_id}"
      nodes.each do |node|
        target_set = node.send(symbol).nodes
        target_set.delete from
        target_set[to] = to
      end
    end
  end

  class DependsOn < DependenceSet
    def symbol
      :depended_on_by
    end
  end

  class DependedOnBy < DependenceSet
    def symbol
      :depends_on
    end
  end

  attr_accessor :plugin

  def initialize path
    @path = Pathname(path).to_s
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

  def replace original
    if original
      original.subsume self
    else
      self
    end
  end

  def check_subsume other
    raise "hell: #{other.class} vs #{self.class}" if other.class != self.class
  end

  def subsume other
    # puts "sub #{object_id} #{other.object_id}"
    check_subsume other
    # p self.class, other.class
    other.watchers.each do |watcher|
      self << watcher
    end
    other.depends_on.replace other, self
    other.depended_on_by.replace other, self
    raise "hell" if self.plugin && other.plugin && self.plugin != other.plugin
    self.plugin ||= other.plugin
    self
  end

  def precious
    @precious
  end

  def out_of_date? flag
    plugin and plugin.out_of_date? self, flag
  end

  def changed!
    @watches and @watches.each { |watch| watch.call }
  end

  def primary_dependence
    values = depends_on.nodes.values.uniq
    raise "ambiguous primary for #{path}" if values.length > 1
    values[0]
  end

  def watch &block
    @watches ||= []
    @watches << block
  end

end
