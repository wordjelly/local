module Concerns::Schedule::TestMethodsConcern
  	extend ActiveSupport::Concern

  	included do

  	end

  	module ClassMethods
  			
	  	## creates a single minute, with 
		## creates n minutes.
		def create_single_test_minute(status,employee_count=1)
			status_ids = [status.id.to_s]
			m = Schedule::Minute.new(number: 1, working: 1, employees: [], id: 1.to_s)
			employee_count.times do |employee|
				e = Employee.new(id: employee.to_s, status_ids: status_ids, employee_id: employee.to_s, bookings_score: 0)
				m.employees << e
			end
			Schedule::Minute.add_bulk_item(m)
			Schedule::Minute.flush_bulk
		end

		def create_multiple_test_minutes(total_mins,employee_count,status_ids,start_minute = 0)
			total_mins.times do |min|
				m = Schedule::Minute.new(number: (min + start_minute), working: 1, employees: [], id: (min + start_minute).to_s)
				employee_count.times do |employee|
					e = Employee.new(id: employee.to_s, status_ids: status_ids, employee_id: employee.to_s, bookings_score: 0)
					m.employees << e
				end
				Schedule::Minute.add_bulk_item(m)
			end
			Schedule::Minute.flush_bulk
		end

		## creates a single minute, with 
		## creates n minutes.
		def create_two_test_minutes(status)
			status_ids = [status.id.to_s]
			2.times do |n| 
				m = Schedule::Minute.new(number: n, working: 1, employees: [], id: n.to_s)
				1.times do |employee|
					e = Employee.new(id: employee.to_s, status_ids: status_ids, employee_id: employee.to_s, bookings_score: 0)
					m.employees << e
				end
				Schedule::Minute.add_bulk_item(m)
			end
			Schedule::Minute.flush_bulk
		end

		def create_test_minutes(number_of_minutes=25,status_ids=["step 1","step 2","step 3"])
			number_of_minutes.times do |minute|
				m = Schedule::Minute.new(number: minute, working: 1, employees: [], id: minute.to_s)
				6.times do |employee|
					e = Employee.new(id: employee.to_s, status_ids: status_ids, employee_id: employee.to_s, bookings_score: [0,1,2,3,4,5,6,7,8,9,10].sample, number: minute, id_minute: employee.to_s + "_" + minute.to_s)
					[0,1,2,3,4].sample.times do |booking|
						b = Schedule::Booking.new
						b.status_id = status_ids.sample
						b.count = 2
						b.priority = booking
						b.order_id = "o#{booking}"
						b.report_ids = ["r#{booking}"]
						b.max_delay = 10*booking
						e.bookings << b		
					end
					m.employees << e
				end
				Schedule::Minute.add_bulk_item(m)
			end
			Schedule::Minute.flush_bulk
		end
		
		def create_test_days
			status_ids = []    	
	    	100.times do |status|
	    		status_ids << status
	    	end
	    	days = []
	    	minute_count = 0
	    	100.times do |day|
	    		d = Day.new(id: "day_" + day.to_s)
	    		d.date = Time.now + day.days
	    		d.working = 1
	    		d.minutes = []
	    		720.times do |minute|
	    			m = Schedule::Minute.new(number: minute_count, working: 1, employees: [], id: minute_count.to_s)
	    			6.times do |employee|
	    				e = Employee.new(id: employee.to_s, status_ids: status_ids, booked_status_id: -1, booked_count: 0)
	    				m.employees << e
	    			end
	    			minute_count+=1
	    			Schedule::Minute.add_bulk_item(m)
	    		end
	    	end
	    	Schedule::Minute.flush_bulk
		end	

  	end

end