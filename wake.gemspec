
Gem::Specification.new do |s|
  s.name              = 'wake'
  s.version           = '0.1.0'
  s.summary           = "continious building"
  s.description       = "continious building"
  s.author            = "Steven Parkes"
  s.email             = 'smparkes@smparkes.net'
  s.homepage          = 'http://github.com/smparkes/wake'
  s.has_rdoc          = true
  s.rdoc_options      = %w( --main README.rdoc )
  s.extra_rdoc_files  = %w( README.rdoc )
  s.require_path      = "lib"
  s.bindir            = "bin"
  s.executables       = "wake"
  s.files = %w[
    .gitignore
    LICENSE
    Manifest
    README.rdoc
    Rakefile
    bin/wake
    docs.wk
    gem.wk
    lib/wake.rb
    lib/wake/controller.rb
    lib/wake/event_handlers/base.rb
    lib/wake/event_handlers/portable.rb
    lib/wake/event_handlers/unix.rb
    lib/wake/event_handlers/em.rb
    lib/wake/event_handlers/rev.rb
    lib/wake/script.rb
    manifest.wk
    specs.wk
    test/README
    test/event_handlers/test_base.rb
    test/event_handlers/test_portable.rb
    test/event_handlers/test_em.rb
    test/event_handlers/test_rev.rb
    test/test_controller.rb
    test/test_helper.rb
    test/test_script.rb
    test/test_wake.rb
    wake.gemspec
  ]
  s.test_files = %w[
    test/test_helper.rb
    test/test_wake.rb
    test/test_script.rb
    test/test_controller.rb
    test/event_handlers/test_base.rb
    test/event_handlers/test_em.rb
    test/event_handlers/test_rev.rb
    test/event_handlers/test_portable.rb
  ]
  s.add_development_dependency 'mocha'
  s.add_development_dependency 'jeremymcanally-matchy'
  s.add_development_dependency 'jeremymcanally-pending'
  s.add_development_dependency 'mynyml-every'
  s.add_development_dependency 'mynyml-redgreen'
end
