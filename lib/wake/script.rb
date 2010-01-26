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
        ( pattern.class == String ) and ( pattern = Regexp.new pattern )
        md = pattern.match(path)
        if md
          watch = self.predicate.nil? || self.predicate.call(md)
        end
        return watch
      end

      def match path
        # $stderr.print("match #{path}\n")
        pattern = self.pattern
        ( pattern.class == String ) and ( pattern = Regexp.new pattern )
        # p path, pattern, pattern.match(path)
        ( md = pattern.match(path) ) &&
          ( self.predicate == nil || self.predicate.call(md) )
      end

    end
    
    # TODO eval context
    class API #:nodoc:
    end

    # Creates a script object for <tt>path</tt>.
    #
    # Does not parse the script.  The controller knows when to parse the script.
    #
    # ===== Parameters
    # path<Pathname>:: the path to the script
    #
    def initialize(path)
      self.class.script = self
      @path  = path
      @rules = []
      @default_action = lambda {}
    end

    # Main script API method. Builds a new rule, binding a pattern to an action.
    #
    # Whenever a file is saved that matches a rule's <tt>pattern</tt>, its
    # corresponding <tt>action</tt> is triggered.
    #
    # Patterns can be either a Regexp or a string. Because they always
    # represent paths however, it's simpler to use strings. But remember to use
    # single quotes (not double quotes), otherwise escape sequences will be
    # parsed (for example "foo/bar\.rb" #=> "foo/bar.rb", notice "\." becomes
    # "."), and won't be interpreted as the regexp you expect.
    #
    # Also note that patterns will be matched against relative paths (relative
    # from current working directory).
    #
    # Actions, the blocks passed to <tt>watch</tt>, receive a MatchData object
    # as argument. It will be populated with the whole matched string (md[0])
    # as well as individual backreferences (md[1..n]). See MatchData#[]
    # documentation for more details.
    #
    # ===== Examples
    #
    #   # in script file
    #   watch( 'test/test_.*\.rb' )  {|md| system("ruby #{md[0]}") }
    #   watch( 'lib/(.*)\.rb' )      {|md| system("ruby test/test_#{md[1]}.rb") }
    #
    # With these two rules, wake will run any test file whenever it is itself
    # changed (first rule), and will also run a corresponding test file
    # whenever a lib file is changed (second rule).
    #
    # ===== Parameters
    # pattern<~#match>:: pattern to match targetted paths
    # event_types<Symbol|Array<Symbol>>::
    #   Rule will only match events of one of these type. Accepted types are :accessed,
    #   :modified, :changed, :delete and nil (any), where the first three
    #   correspond to atime, mtime and ctime respectively. Defaults to
    #   :modified.
    # action<Block>:: action to trigger
    #
    # ===== Returns
    # rule<Rule>:: rule created by the method
    #
    def watch(pattern, event_type = DEFAULT_EVENT_TYPE, predicate = nil, options = {}, &action)
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

    # Eval content of script file.
    #--
    # TODO fix script file not found error
    def parse!
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

      instance_eval(@path.read)

    rescue Errno::ENOENT
      # TODO figure out why this is happening. still can't reproduce
      Wake.debug('script file "not found". wth')
      sleep(0.3) #enough?
      instance_eval(@path.read)
    end

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
      @rules.reverse.select do |rule| path.match(rule.pattern) end
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
  end
end
