require "rake/testtask"

Rake::TestTask.new do |t|
  t.test_files = FileList['test/*_test.rb']
  t.verbose = true
end

desc "auto-generate README"
task :readme do
  header = "Sub\n===\n\n"
  help = `./bin/sub --help`
  if $?.exitstatus != 0
    $stderr.puts "./bin/sub --help not found!"
    exit 1
  end
  before = File.read("README")
  File.open("README", 'w+') do |f|
    f.write(header + help)
  end
  after = File.read("README")
  puts "generated README"
  puts "changed: #{before != after}"
end

desc "Install (copy files to /usr/local/bin or INSTALL_PREFIX). Use sudo if necessary."
task :install do
  require "fileutils"
  install_dir = ENV["INSTALL_PREFIX"] || "/usr/local/bin"
  unless File.directory?(install_dir)
    $stderr.puts "Directory #{install_dir} does not exist. Install failed."
    exit 1
  end
  paths = ENV["PATH"].split(":")
  unless paths.include?(install_dir)
    $stderr.puts "#{install_dir} is not in your PATH. Install failed."
  end
  bin_file = File.join(File.dirname(__FILE__), "bin", "sub")
  unless File.exist?(bin_file)
    $stderr.puts "File #{bin_file} doesn't exist. Error: install failed."
    exit 1
  end
  begin
    FileUtils.cp(bin_file, install_dir)
  rescue Errno::EACCES => e
    $stderr.puts "Failed to install"
    $stderr.puts e.message
    if `logname`.strip != 'root'
      $stderr.puts "Hint: Try using sudo before the command: sudo rake install"
    end
    exit 1
  end
  if (which = `which sub`.strip) != File.join(install_dir, 'sub')
    $stderr.puts "Warning: `which sub` returned wrong value: '#{which}'"
  end
  exit 0
end

desc "Uninstall (removes /usr/local/bin/sub or $(INSTALL_PREFIX)/sub). Use sudo if necessary."
task :uninstall do
  install_dir = ENV["INSTALL_PREFIX"] || "/usr/local/bin"
  unless File.directory?(install_dir)
    $stderr.puts "Directory #{install_dir} does not exist. Uninstall failed."
    exit 1
  end
  bin_file = File.join(install_dir, "sub")
  unless File.exist?(bin_file)
    $stderr.puts "File #{bin_file} doesn't exist."
    exit 0
  end
  begin
    FileUtils.rm(bin_file)
  rescue Errno::EACCES => e
    $stderr.puts "Failed to uninstall"
    $stderr.puts e.message
    if `logname`.strip != 'root'
      $stderr.puts "Hint: Try using sudo before the command: sudo rake uninstall"
    end
    exit 1
  end
  system("which sub")
  if $?.exitstatus == 0
    $stderr.puts "Warning: sub is still in your PATH"
  end
  exit 0
end
