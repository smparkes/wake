require 'digest/md5'

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
    if String === args[0] || ( Array === args[0] && String === args[0][0] )
      @glob = args.shift
    else
      @glob = cls.default[:glob]
    end
  end

  def regexp args
    if Regexp === args[0] || ( Array === args[0] && Regexp === args[0][0] )
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

  def out_of_date? node, flag
    return true if !File.exists? node.path
    mtime = File.mtime node.path
    node.depends_on.nodes.values.detect { |dep| File.exists?(dep.path) and File.mtime(dep.path) > mtime }
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
          globs = Array(@glob)
          globs.each do |glob|
           Dir[glob].each { |f| set[f] = f }
          end
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
    Digest::MD5.hexdigest(string) == hash
  end

  def check_signature pair, path
    return true if !File.exists? path
    prefix = pair[0] + "WAKE HASH: "
    suffix = pair[1] + ""
    content = File.read(path).split("\n")
    if content && content.last && (
       content.last[0,prefix.length] != prefix ||
       content.last[-suffix.length,suffix.length] != suffix ||
       !verify_hash( content[0..-2].join("\n"),
                     content.last[prefix.length,content.last.length-prefix.length-suffix.length] ) )
      $stderr.puts "#{plugin_name}: #{path} missing or incorrect signature: not overwriting"
      return false
    end
    true
  end

  def sign pair, path
    return if !File.exists? path
    prefix = pair[0] + "WAKE HASH: "
    suffix = pair[1] + ""
    content = File.read(path).split("\n").join("\n")
    File.open(path,"a") do |f|
      f.print(prefix,Digest::MD5.hexdigest(content),suffix,"\n")
    end
  end

  def cmd node, string, options = {}
    if sig = options[:signature] and !check_signature sig, node.path
      return -1
    end
    if File.exists? node.path
      FileUtils.rm node.path
    end
    print string, "\n"
    system string
    status = $?.exited? ? $?.exitstatus : 255
    return status if status > 0
    sign sig, node.path if sig
    bits = File.stat(node.path).mode
    bits &= ~0222
    FileUtils.chmod bits, node.path
    return 0
  end

end

