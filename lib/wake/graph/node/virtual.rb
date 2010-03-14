require 'wake/graph/node'

class Wake::Graph::Node::Virtual < Wake::Graph::Node

  def initialize node, key
    path = ::File.expand_path(node.path)
    path = path[cwd.length..-1] if path.index(cwd) == 0
    path = ::File.join( ".wake", path, key )
    super( path )
  end

  def cwd
    @cwd ||= ::File.expand_path(".")
  end

end
