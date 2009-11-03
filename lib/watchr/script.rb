module Watchr

  # A script object wraps a script file, and is used by a controller.
  #
  # ===== Examples
  #
  #   path   = Pathname.new('specs.watchr')
  #   script = Watchr::Script.new(path)
  #
  class Script
    DEFAULT_EVENT_TYPE = :modified

    # Convenience type. Provides clearer and simpler access to rule properties.
    #
    # ===== Examples
    #
    #   rule = script.watch('lib/.*\.rb') { 'ohaie' }
    #   rule.pattern      #=> 'lib/.*\.rb'
    #   rule.action.call  #=> 'ohaie'
    #
    Rule = Struct.new(:pattern, :event_types, :predicate, :action)

    class Rule
      def match path
        pattern = self.pattern
        ( pattern.class == String ) and ( pattern = Regexp.new pattern )
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
    # With these two rules, watchr will run any test file whenever it is itself
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
    def watch(pattern, event_type = DEFAULT_EVENT_TYPE, predicate  = nil, &action)
      event_types = Array(event_type)
      @rules << Rule.new(pattern, event_types, predicate, action || @default_action)
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
      Watchr.debug('loading script file %s' % @path.to_s.inspect)

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
        break if v && v == old_v
        sleep(0.2)
      end

      instance_eval(@path.read)

    rescue Errno::ENOENT
      # TODO figure out why this is happening. still can't reproduce
      Watchr.debug('script file "not found". wth')
      sleep(0.3) #enough?
      instance_eval(@path.read)
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
    #   script.action_for('test/test_watchr.rb').call #=> "ruby test/test_watchr.rb"
    #
    def call_action_for(path, event_type = DEFAULT_EVENT_TYPE)
      path = rel_path(path).to_s
      # p path
      rules_for(path).each do |rule|
        # p rule
        types = rule.event_types
        !types.empty? or types = [ nil ]
        types.each do |rule_event_type|
          if ( rule_event_type.nil? && ( event_type != :load ) ) || ( rule_event_type == event_type )
            data = path.match(rule.pattern)
            return rule.action.call(data)
          end
        end
      end
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
      @rules.reverse.select {|rule| path.match(rule.pattern) }
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
