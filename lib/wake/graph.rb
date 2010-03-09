require 'wake'
require 'tsort'

class Wake::Graph
  include TSort

  def tsort_each_node &block
    node_hash.values.each( &block )
  end

  def tsort_each_child node, &block
    node.depended_on_by.each( &block )
  end

  def [] arg
    if Node === arg
      node_hash[arg.path]
    else
      node_hash[arg]
    end
  end

  def << node
    raise "hell" if !(Node === node)
    raise "hell" if node_hash[node.path] && node_hash[node.path].class != node.class
    node_hash[node.path] ||= node
  end

  def nodes
    tsort
  end

  def paths
    tsort.map { |n| n.path }
  end

  def levelize nodes, method
    result = []
    levels = {}
    while node = nodes.pop
      level = nil
      dependences = node.send(method).nodes.values
      if dependences.empty?
        # print node.path, 0, "\n"
        level = levels[node] = 0
      else
        level = levels[node] = 1 +
          dependences.inject(0) { |max,n| l = levels[n]; l > max ? l : max }
        # print node.path, level, "\n"
      end
      ( result[level] ||= [] ) << node
    end
    result
  end

  private

  def node_hash
    @node_hash ||= {}
  end

end
