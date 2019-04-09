class ScheduleJob < ActiveJob::Base
  
  queue_as :default
  self.queue_adapter = :inline

  ##we currently log all exceptions to redis.
  rescue_from(StandardError) do |exception|
  	puts exception.message
   	puts exception.backtrace.join("\n")
  end
 
  ## expected array of arguments is: 
  ## this job is for creation of orders
  ## reallotments
  ## status blocking
  ## if it is for creating orders, the best options would be 
  ## to give the order id, and call a method on it, that does the 
  ## heavy lifting.
  ## on the order, the action will be schedule.
  ## an order could get cancelled,
  ## in that case the background job would have to unschedule it.
  ## if its a routine, then that also has an action attribute
  ## there is also reallotment.
  ## that will be called on employee.
  ## 0 => object_id
  ## 1 => object_class
  ## the object calls the schedule method on itself.
  def perform(args)
    obj = args[1].constantize.find(args[0])
    obj.schedule
    Minute.flush_bulk
  end

end