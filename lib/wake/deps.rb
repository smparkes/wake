require 'rubygems'
# require 'fsdb'

require 'wake/script'

class Wake::Script

  remove_method :depends_on, :depended_on_by

  def depends_on path
    result = []
    begin
      result = db["file://"+Pathname(path).realpath.to_s + ".on.yml"] || []
    rescue Errno::ENOENT => e
    rescue Exception => e; $stderr.puts e + " " + __FILE__ + " " + __LINE__ + "\n"; end
    # $stderr.print "lookup #{'file://'+Pathname(path).realpath.to_s} : #{result.join(' ')}\n"
    result.map! { |f| f.sub! %r(^file://), "" }
  end

  def depended_on_by path
    result = []
    begin
      result = db["file://"+Pathname(path).realpath.to_s + ".by.yml"] || []
    rescue Errno::ENOENT => e
    rescue Exception => e; $stderr.puts e + " " + __FILE__ + " " + __LINE__ + "\n"; end
    # $stderr.print "lookup #{'file://'+Pathname(path).realpath.to_s} : #{result.join(' ')}\n"
    result.map! { |f| f.sub! %r(^file://), "" }
  end

  def db_path
    @deps ||= begin
                path = Pathname(@path)
                path = File.join( path.dirname, "." + path.basename + ".deps" )
                begin mkdir(path); rescue; end
                path
              end
    @deps
  end


  def db
    @db ||= FSDB::Database.new db_path
  end

end
