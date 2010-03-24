require 'wake/graph/node'

class Wake::Graph::Node::Weak < Wake::Graph::Node

  def initialize path
    super( path )
  end

  def check_subsume other
  end

  def succeeded
    true
  end

end
