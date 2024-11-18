require "rake/testtask"

Rake::TestTask.new do |t|
  t.test_files = FileList['test/*_test.rb']
  t.verbose = true
end

task :generate_readme do
  header = "Sub\n===\n\n"
  help = `./bin/sub --help`
  File.open("README", 'w+') do |f|
    f.write(header + help)
  end
end
