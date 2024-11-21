Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'cmdline-sub'
  s.version     = '0.1.1'
  s.summary     = 'Sub is a commandline substitution editor'
  s.description = <<desc
sub substitutes the matching pattern in every word in the command line with the
substitution. Only the first matched pattern in the word is substituted unless
the 'g' flag is given. There are various options that change the way substitutions
are performed or the way matches are made. Patterns can have regular expression
wildcards (special characters) in them, and the regular expression engine used is
Ruby's. Special characters are interpreted as special unless the 'L' flag is given.
desc

  s.required_ruby_version  = '>= 2.0.0'
  s.license = 'MIT'

  s.author = 'Luke Gruber'
  s.email = 'luke.gru@gmail.com'
  s.homepage = 'https://github.com/luke-gru/sub'
  s.bindir = 'bin'
  s.executables = ['sub']
  s.files = Dir['README', 'LICENSE', 'Rakefile', 'Gemfile', 'bin/sub']

  s.add_development_dependency('debug', '~> 1.9.2')
  s.add_development_dependency('minitest', '~> 5.25.1')
  s.add_development_dependency('rake', '~> 13.2.1')
end
