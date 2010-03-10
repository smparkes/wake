require 'wake'
require 'tsort'

class Wake::Graph
  include TSort

  def directed_tsort direction
    old, @direction = @direction, direction
    v = tsort
    @direction = old
    v
  end

  def tsort_each_node &block
    node_hash.values.each( &block )
  end

  def tsort_each_child node, &block
    # node.depended_on_by.each( &block )
    node.send(@direction).each(&block)
  end

  def [] arg
    if Node === arg
      node_hash[arg.path]
    else
      node_hash[arg]
    end
  end

  def << node
    node_hash[node.path] = node.replace node_hash[node.path]
  end

  def nodes direction = :depended_on_by
    directed_tsort direction
  end

  def paths direction = :depended_on_by
    directed_tsort(direction).map { |n| n.path }
  end

  def levelize nodes, method
    result = []
    levels = {}
    while node = nodes.pop
      level = nil
      dependences = node.send(method).nodes.values
      if dependences.empty?
        level = levels[node] = 0
      else
        level = levels[node] = 1 +
          dependences.inject(0) { |max,n| l = levels[n]; l > max ? l : max }
      end
      # print "#{node.path} level #{level}\n"
      ( result[level] ||= [] ) << node
    end
    result
  end

  private

  def node_hash
    @node_hash ||= {}
  end

end
