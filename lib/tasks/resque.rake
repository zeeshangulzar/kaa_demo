namespace :resque do
  task :restart do
    pids = []
    f = File.open('log/resque.pid') if File.exists?('log/resque.pid')
    if f
      f.each_line{|line|
        pids.push(line)
      }
    end
    pids.each{|pid|
      puts "Attempting to gracefully murder resque process: #{pid}"
      if !system("kill -3 #{pid}")
        puts "Process doesnt exist"
      end
    }
    puts "Dropping resque.pid so resque can make a new one without hassle..."
    File.delete('log/resque.pid') if File.exists?('log/resque.pid')
    puts "Firing up resque..."
    system("(cd #{Dir.pwd} && nohup nice -5 bundle exec rake environment resque:work RAILS_ENV=production HES_SECURITY_DISABLED=true QUEUE=* PIDFILE=log/resque.pid >> 'log/resque.log' 2>&1 &) && sleep 1")
    puts "Should be up."
  end
end