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
