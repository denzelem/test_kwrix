require_relative 'lib/kwrix'

desc 'Cleans the docker volume'
task :clean do
  Kwrix::Runner.new.clean
end

desc 'Ask OpenAI a question with docker function calling enabled'
task :run, [:prompt] do |_, args|
  Kwrix::Runner.new.run(args[:prompt])
end

task default: :run
