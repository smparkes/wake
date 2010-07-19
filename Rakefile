require 'rubygems'

gem 'hoe', '>= 2.5'
require 'hoe'

Hoe.plugin :debugging, :doofus, :git
Hoe.plugins.delete :rubyforge

Hoe.spec "wake" do

  developer 'Steven Parkes', 'smparkes@smparkes.net'

  self.readme_file              = 'README.rdoc'
  self.extra_rdoc_files         = Dir['*.rdoc']
  self.history_file             = "CHANGELOG.rdoc"
  self.readme_file              = "README.rdoc"

  self.extra_deps = [
    ['eventmachine', '>= 0.12.11']
  ]

  self.extra_dev_deps = [
  ]

end

task :test do
  cmd = "wake --once"
  puts cmd
  system cmd
end

# Local Variables:
# mode:ruby
# End:
