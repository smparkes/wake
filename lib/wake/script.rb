require 'wake/target'
require 'wake/plugin'

module Wake

  class << self
    def batches
      @batches ||= {}
    end
  end

  # A script object wraps a script file, and is used by a controller.
  #
  # ===== Examples
  #
  #   path   = Pathname.new('specs.wk')
  #   script = Wake::Script.new(path)
  #
  class Script

    DEFAULT_EVENT_TYPE = :modified

    class Batch
      def initialize rule
        @timer = nil
        @rule = rule
        @events = []
      end

      def call data, event, path
        # $stderr.print "batch add #{data} #{event} #{path}\n"
        # require 'pp'
        # pp caller(0)
        if @timer
          @timer.cancel
        end
        @timer = EM::Timer.new(0.001) do
          deliver
          Wake.batches.delete self
        end
        Wake.batches[self] = self
        # p data, event, path
        @events << [ data.to_a, event, path ]
        @events.uniq!
        # p @events
      end

      def deliver
        events = @events
        @timer = nil
        @events = []
        @rule.action.call [events]
        events.each do |event|
          Script.learn event[2]
        end
      end
    end

    # Convenience type. Provides clearer and simpler access to rule properties.
    #
    # ===== Examples
    #
    #   rule = script.watch('lib/.*\.rb') { 'ohaie' }
    #   rule.pattern      #=> 'lib/.*\.rb'
    #   rule.action.call  #=> 'ohaie'
    #
    Rule = Struct.new(:pattern, :event_types, :predicate, :options, :action, :batch)

    class Rule

      def call data, event, path
        # $stderr.print "call #{data} #{event} #{path}\n"
        if options[:batch]
          self.batch ||= Batch.new self
          batch.call data, event, path
        else
          res = nil
          if action.arity == 1 
            res = action.call data
          elsif action.arity == 2
            res = action.call data, event
          else
            res = action.call data, event, path
          end
          Script.learn path
          res
        end
      end

      def watch path
        watch = nil
        pattern = self.pattern
        if Array === pattern
          if String === pattern[0]
            @set = Dir[pattern.shift]
          end
          pattern = pattern.shift || /.*/
        end
        ( pattern.class == String ) and ( pattern = Regexp.new pattern )
        if @set
          return nil if !@set.include? path
        end
        md = pattern ? pattern.match(path) : path
        if md
          watch = self.predicate.nil? || self.predicate.call(md)
        end
        return watch
      end

      def match path
        pattern = self.pattern
        if Array === pattern
          if String === pattern[0]
            @set = Dir[pattern.shift]
          end
          pattern = pattern.shift || /.*/
        end
        ( pattern.class == String ) and ( pattern = Regexp.new pattern )
        if @set
          return nil if !@set.include? path
        end
        # p path, pattern, pattern.match(path)
        md = pattern ? pattern.match(path) : path
        if md 
          ( self.predicate == nil || self.predicate.call(md) )
        end
      end

    end
    
    attr_reader :rescan

    def initialize(path)
      self.class.script = self
      @path  = path
      @rules = []
      @default_action = lambda {}
      ignore %r{(^/?|/)\..}
      directory { |n| @rescan = Time.now; Plugin.refresh }
      watch(path.to_s) { parse! }
    end

    def _watch(pattern, event_type = DEFAULT_EVENT_TYPE, predicate = nil, options = {}, &action)
      event_types = Array(event_type)
      @rules << Rule.new(pattern, event_types, predicate, options, action || @default_action)
      @rules.last
    end

    # Convenience method. Define a default action to be triggered when a rule
    # has none specified.
    #
    # ===== Examples
    #
    #   # in script file
    #
    #   default_action { system('rake --silent rdoc') }
    #
    #   watch( 'lib/.*\.rb'  )
    #   watch( 'README.rdoc' )
    #   watch( 'TODO.txt'    )
    #   watch( 'LICENSE'     )
    #
    #   # equivalent to:
    #
    #   watch( 'lib/.*\.rb'  ) { system('rake --silent rdoc') }
    #   watch( 'README.rdoc' ) { system('rake --silent rdoc') }
    #   watch( 'TODO.txt'    ) { system('rake --silent rdoc') }
    #   watch( 'LICENSE'     ) { system('rake --silent rdoc') }
    #
    def default_action(&action)
      @default_action = action
    end

    def parse!
      return if @modified_at && @modified_at >= File.mtime(@path)

      # p "parse!"
      Wake.debug('loading script file %s' % @path.to_s.inspect)

      reset

      # Some editors do delete/rename. Even when they don't some events come very fast ...
      # and editor could do a trunc/write. If you look after the trunc, before the write, well,
      # things aren't pretty.
      
      # Should probably use a watchdog timer that gets reset on every change and then only fire actions
      # after the watchdog timer fires without get reset ..

      v = nil
      (1..10).each do
        old_v = v
        v = @path.read
        break if v != "" && v == old_v
        sleep(0.3)
      end

      instance_eval(@path.read, @path)
      @modified_at = File.mtime(@path)

    rescue Errno::ENOENT
      # TODO figure out why this is happening. still can't reproduce
      Wake.debug('script file "not found". wth')
      sleep(0.3) #enough?
      instance_eval(@path.read, @path)
      @modified_at = File.mtime(@path)
    end

    attr_reader :modified_at

    class << self
      attr_accessor :script, :handler
      def learn path
        script.depends_on(path).each do |p|
          # $stderr.print "#{path} depends on #{p}\n"
          handler.add Pathname(p)
        end
      end
    end

    def depends_on path
      []
    end

    def depended_on_by path
      []
    end

    # Find an action corresponding to a path and event type. The returned
    # action is actually a wrapper around the rule's action, with the
    # match_data prepopulated.
    #
    # ===== Params
    # path<Pathnane,String>:: Find action that correspond to this path.
    # event_type<Symbol>:: Find action only if rule's event if of this type.
    #
    # ===== Examples
    #
    #   script.watch( 'test/test_.*\.rb' ) {|md| "ruby #{md[0]}" }
    #   script.action_for('test/test_wake.rb').call #=> "ruby test/test_wake.rb"
    #
    def call_action_for(path, event_type = DEFAULT_EVENT_TYPE)
      # $stderr.print "caf #{path} #{event_type}\n";
      pathname = path
      path = rel_path(path).to_s
      # $stderr.print "dob #{path} #{depended_on_by(path).join(' ')}\n"
      string = nil
      begin
        string = Pathname(pathname).realpath.to_s
      rescue Errno::ENOENT; end
      string && depended_on_by(string).each do |dependence|
        # $stderr.print "for caf #{Pathname(pathname).realpath.to_s}\n";
        call_action_for(dependence, event_type)
      end
      rules_for(path).each do |rule|
        # begin
        types = rule.event_types
        !types.empty? or types = [ nil ]
        types.each do |rule_event_type|
          # $stderr.print "#{rule.inspect} #{rule_event_type.inspect} #{event_type.inspect} #{path} #{rule_event_type == event_type}\n"
          if ( rule_event_type.nil? && ( event_type != :load ) ) || ( rule_event_type == event_type )
            data = path.match(rule.pattern)
            # $stderr.print "data #{data}\n"
            return rule.call(data, event_type, pathname)
          end
        end
        # rescue Exception => e; $stderr.print "oops #{e}\n"; raise; end
      end
      # $stderr.print "no path for #{path}\n"
      nil
    end

    # Collection of all patterns defined in script.
    #
    # ===== Returns
    # patterns<String, Regexp>:: all patterns
    #
    def patterns
      #@rules.every.pattern
      @rules.map {|r| r.pattern }
    end

    def rules
      @rules
    end

    # Path to the script file
    #
    # ===== Returns
    # path<Pathname>:: path to script file
    #
    def path
      Pathname(@path.respond_to?(:to_path) ? @path.to_path : @path.to_s).expand_path
    end

    def method_missing *args, &block
      method = args.shift.to_s
      begin
        require method.gsub(%r{_},"")
      rescue LoadError => le
        # p le
      end

      filename = File.join(method, method +".wk").gsub(%r{_},"")

      # p filename
 
      file = $:.map { |dir| File.join dir, filename }.detect { |f| File.exists? f }

      # p file

      raise "no plugin '#{method}' found (might be a typo or other error)" if !file

      instance_eval(File.read(file), file)
      
      raise "invalid plugin '#{method}'" if !respond_to? method

      send method.to_sym, *args, &block
    end

    def plugins
      @plugins ||= []
    end

    private

    # Rules corresponding to a given path, in reversed order of precedence
    # (latest one is most inportant).
    #
    # ===== Parameters
    # path<Pathname, String>:: path to look up rule for
    #
    # ===== Returns
    # rules<Array(Rule)>:: rules corresponding to <tt>path</tt>
    #
    def rules_for(path)
      # @rules.reverse.select do |rule| path.match(rule.pattern) end
      @rules.reverse.select { |rule| rule.match(path) }
    end

    # Make a path relative to current working directory.
    #
    # ===== Parameters
    # path<Pathname, String>:: absolute or relative path
    #
    # ===== Returns
    # path<Pathname>:: relative path, from current working directory.
    #
    def rel_path(path)
      Pathname(path).expand_path.relative_path_from(Pathname(Dir.pwd))
    end

    # Reset script state
    def reset
      @default_action = lambda {}
      @rules.clear
    end

    def process_args cls, args, &block
      if args.length === 1 && Hash === args.first
        cls.default :options => args.pop
      else
        plugins << cls.new( self, *args, &block )
      end
    end

  end
end
