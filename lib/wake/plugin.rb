require 'wake/graph/node/virtual'
require 'wake/graph/node/file'

class Wake::Plugin

  Node = Wake::Graph::Node

  module Class

    def default hash = {}
      @default ||= { :glob => "**/*", :regexp => %r{.*}, :options => {} }
      
      @merger = proc do |key,v1,v2|
        Hash === v1 && Hash === v2 ? v1.merge(v2, &@merger) : v2
      end

      @default = @default.merge hash, &@merger
    end

  end

  class << self
    def inherited subclass
      names = subclass.to_s.split("::").map { |n| n.downcase }
      begin
        method = names.pop
      end while [ "wake", "plugin" ].include? method and !names.empty?
      Wake::Script.send :define_method, method do |*args|
        process_args subclass, args
      end
    end
  end

  def initialize wake, *args
    @wake = wake
    glob args
    regexp args
    options args
  end

  def glob args
    if String === args[0] 
      @glob = args.shift
    else
      @glob = cls.default[:glob]
    end
  end

  def regexp args
    if Regexp === args[0] 
      @regexp = args.shift
    else
      @regexp = cls.default[:regexp]
    end
  end

  def options args
    @options = cls.default[:options]
    if arg = args.shift
      @options.merge! arg
    end
  end

  def pruner; nil; end
  def producer; nil; end

  def watcher
    lambda { |path, graph| match? path and graph << ( node = Node::File.new(path) ) << self and node }
  end

  def match? path
    matches = true
    matches &&= glob_contains path
    matches &&= regexp_matches path
    matches
  end

  private

  def create graph, node, options = {}
    graph << node
    graph[node].depends_on << options[:from] if options[:from] 
  end

  def cls
    @cls ||= self.class
  end

  def glob_contents
    @glob_contents ||=
      begin
        if @glob
          set = {}
          Dir[@glob].each { |f| set[f] = f }
          set
        else
          {}
        end
      end
  end

  def glob_contains path
    @glob == "**/*" ? true : glob_contents.has_key?( path )
  end

  def regexp_matches path
    @regexp == %r{\.*} ? true : @regexp.match( path )
  end

end
