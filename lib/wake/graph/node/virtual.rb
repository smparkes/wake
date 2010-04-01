require 'fileutils'
require 'wake/graph/node'

class Wake::Graph::Node::Virtual < Wake::Graph::Node

  attr_accessor :succeeded, :deps

  def initialize graph, node, key
    path = ::File.expand_path(node.path)
    path = path[cwd.length..-1] if path.index(cwd) == 0
    path = ::File.join( ".wake", path, key )
    super( path )
    if ::File.exist? path
      ::File.open(path) do |f|
        json = f.read
        hash = JSON.parse(json)
        # require 'pp'
        # pp path, hash
        self.succeeded = hash["succeeded"] if hash.has_key? "succeeded"
        hash["deps"] and hash["deps"].each do |dep|
          graph.create Wake::Graph::Node::Weak.new( dep ), :to => self
        end
      end
    end
  end

  def save!
    FileUtils.mkdir_p Pathname(@path).dirname
    open(@path,"w") do |f|
      f.truncate 0
      hash = {}
      hash["succeeded"] = self.succeeded if !self.succeeded.nil?
      hash["deps"] = self.deps if !self.deps.nil?
      json = hash.to_json
      # puts "#{@path} #{json}"
      f.write(json)
    end
  end

  def cwd
    @cwd ||= ::File.expand_path(".")
  end

end
