require 'wake/graph/node'

class Wake::Graph::Node::File < Wake::Graph::Node

  # not 100% sure of this ... used by simple plugins, e.g., haml, sass
  def succeeded
    true
  end

end
