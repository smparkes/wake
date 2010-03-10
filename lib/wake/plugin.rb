require 'wake/graph/node/virtual'
require 'wake/graph/node/file'

class Wake::Plugin

  Node = Wake::Graph::Node

  module Class

    def plugin_name cls = self
      names = cls.to_s.split("::").map { |n| n.downcase }
      begin
        method = names.pop
      end while [ "wake", "plugin" ].include? method and !names.empty?
      method
    end
  
    module_function :plugin_name
    public :plugin_name

    def default hash = {}
      options = { :virtual => plugin_name }

      @default ||= { :glob => "**/*", :regexp => %r{.*}, :options => options }
      
      @merger = proc do |key,v1,v2|
        Hash === v1 && Hash === v2 ? v1.merge(v2, &@merger) : v2
      end

      @default = @default.merge hash, &@merger
    end

  end

  class << self
    def inherited subclass
      if false
      # TODO: factor (see above)
      names = subclass.to_s.split("::").map { |n| n.downcase }
      begin
        method = names.pop
      end while [ "wake", "plugin" ].include? method and !names.empty?
      end
      Wake::Script.send :define_method, Class.plugin_name(subclass) do |*args|
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

  def plugin_name
    self.class.plugin_name
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
  def fire_one; nil; end

  def fire_all
    if fire_one
      lambda do |nodes|
        nodes.each do |node|
          fire_one.call node
        end
      end
    else
      nil
    end
  end

  def watcher
    lambda do |path, graph|
      match? path and
        ((node = graph << Node::File.new(path) ) << self) and
        node
    end
  end

  def match? path
    matches = true
    matches &&= glob_contains path
    matches &&= regexp_matches path
    matches
  end

  private

  def create graph, node, options = {}
    node = graph << node
    node.plugin = options[:plugin] if options[:plugin]
    graph[node].depends_on << options[:from] if options[:from] 
    graph[node].depended_on_by << options[:to] if options[:to] 
    node
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

  def verify_hash string, hash
    p "Huh?"
    p string, hash
  end

  def check_signature pair, path
    return true if !File.exists? path
    pair[0] += "WAKE HASH: "
    content = File.read(path).split("\n")
    p content.last[0,pair[0].length], pair[0], content.last[0,pair[0].length] != pair[0]
    if content.last[0,pair[0].length] != pair[0] ||
       content.last[-pair[1].length,pair[1].length] != pair[1] ||
       !verify_hash( content[0..-2].join("\n"),
                     content.last[pair[0].length,content.last.length-pair[0].length-pair[1].length] )
      $stderr.puts "#{plugin_name}: #{path} does not have signature: not overwriting"
    end
  end

  def cmd node, string, options = {}
    if sig = options[:signature] and !check_signature sig, node.path
      return -1
    end
    print string, "\n"
    system string
    print $?,"\n"
  end

end

