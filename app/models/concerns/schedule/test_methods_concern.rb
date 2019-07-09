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

		def create_test_minutes(number_of_minutes=1000,status_ids=["step 1","step 2","step 3","step 4","step 5","step 6","step 7","step 8","step 9","step 10","step 11","step 12","step 13","step 14","step 15","step 16","step 17","step 18","step 19","step 20","step 21"])
			
			status_durations_to_ids = {
				"10" => ["step 1","step 2","step 3","step 4"],
				"20" => ["step 5","step 6","step 7","step 8"],
				"30" => ["step 9","step 10","step 11","step 12"],
				"40" => ["step 13","step 14","step 15","step 16"],
				"60" => ["step 17","step 18","step 19","step 20"],
				"90" => ["step 21","step 22","step 23","step 24"],
				"120" => ["step 25","step 26","step 27","step 28"]
			}

			number_of_minutes.times do |minute|
				m = Schedule::Minute.new(number: minute, working: 1, employees: [], id: minute.to_s)
				6.times do |employee|
					e = Employee.new(id: employee.to_s, status_ids: status_ids.sample(10), employee_id: employee.to_s, bookings_score: [0,1,2,3,4,5,6,7,8,9,10].sample, number: minute, id_minute: employee.to_s + "_" + minute.to_s)
					[0,1,2,3,4].sample.times do |booking|
						b = Schedule::Booking.new
						b.status_id = status_ids.sample
						b.count = 2
						b.priority = booking
						b.order_id = "o#{booking}"
						b.report_ids = ["r#{booking}"]
						b.max_delay = 10*booking
						#status_durations_to_ids.keys.each do |duration|
						#	block = Schedule::Block.new
						#	block.status_ids = status_durations_to_ids[duration]
						#	block.minutes = Array((minute.to_i - duration.to_i)..minute.to_i)
						#	block.remaining_capacity = -1
						#	Schedule::Block.add_bulk_item(block)
							#b.blocks << block
						#end
						e.bookings << b		
					end
					m.employees << e
				end

				Schedule::Minute.add_bulk_item(m)
			end
			Schedule::Minute.flush_bulk
			#Schedule::Block.flush_bulk
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