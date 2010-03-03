require 'wake/graph/node'

class Wake::Graph::Node::Virtual < Wake::Graph::Node

  def initialize node, key
    path = ::File.join( ".wake", ::File.expand_path(node.path), key )
    super( path )
  end

end
