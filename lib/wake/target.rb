class Wake::Target

  def initialize wake
    @wake = wake
  end

  def glob args, default = "**/*"
    if String === args[0] 
      @glob = args.shift
    else
      @glob = default
    end
  end

  def regexp args, default = %r{.*}
    if Regexp === args[0] 
      @regexp = args.shift
    else
      @regexp = default
    end
  end

  def options global, args, default = {}
    @options = global.dup
    if arg = args.shift
      @options.merge! arg
    else
      @options.merge! default
    end
  end

end
