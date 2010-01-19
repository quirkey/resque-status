require 'resque/job_with_status' # in rails you would probably do this in an initializer

# sleeps for _length_ seconds updating the status every second

class SleepJob < Resque::JobWithStatus
  
  def perform
    total = options['length'].to_i || 1000
    num = 0
    while num < total
      at(num, total, "At #{num} of #{total}")
      sleep(1)
      num += 1
    end
    completed
  end
  
end


if __FILE__ == $0
  # Make sure you have a worker running
  # rake -rexamples/sleep_job.rb resque:work QUEUE=statused
  
  # running the job
  puts "Creating the SleepJob"
  job_id = SleepJob.create :length => 100
  puts "Got back #{job_id}"
  
  # check the status until its complete
  while status = Resque::Status.get(job_id) and !status.completed? && !status.failed?
    sleep 1
    puts status.inspect
  end
end