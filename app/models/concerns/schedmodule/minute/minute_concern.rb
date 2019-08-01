module Concerns::Schedmodule::Minute::MinuteConcern
	extend ActiveSupport::Concern

  	included do

  		attr_accessor :update_script

  	end

  	def set_update_script(args)
		self.update_script = {
			script: {
				lang: "painless",
				inline: '''
				for(employee in ctx._source.employees){
					if(employee["employee_id"] == params.employee_id){
						if(params.booking_id == null){
							Map booking = new HashMap();
							booking.put("report_ids",params.report_ids);
							booking.put("status_id",params.status_id);
							booking.put("order_id",[params.order_id]);
				        	employee["bookings"].add(booking);
						}
						else{
							for(booking in employee.bookings){
								if(booking["booking_id"] == params.booking_id){
									booking["report_ids"].addAll(params.report_ids);
								}
							}
						}
					}
				}
				''',
				params: {
					employee_id: args[:employee_id],
					order_id: args[:order_id],
					report_ids: args[:report_ids],
					status_id: args[:status_id]
				}	
			}
		}

	end  		

  	module ClassMethods


  		## @param[Hash] bucket : aggregation bucket.
  		## @param[Hash] args : 
  		## :order => order object
  		## :status => status object.
  		## :booking_minutes_array => array of minutes.
  		## @return[Schedule::Minute] 
  		def book_minute(bucket,args)
  			#puts JSON.pretty_generate(bucket)

  			#puts "the args are:"

  			#puts JSON.pretty_generate(args)

  			current_minute = bucket["key"].to_i
  			#last_minute = args[:booking_minutes_array].last.number
  			minute = nil
  			create_booking = args[:booking_minutes_array].blank? ? true : (args[:booking_minutes_array].last.number < current_minute)
  			
  			unless create_booking.blank?
          unless bucket.employee.employee.buckets.blank?
    				employee_bucket = bucket.employee.employee.buckets[0].employee_id.buckets[0]
    				employee_id = employee_bucket["key"]
    				minute = new(number: current_minute)
    				employee = Employee.new(id: employee_id)
    				booking = Schedule::Booking.new(status_id: args[:status].id.to_s, order_id: args[:order].id.to_s)

    				unless employee_bucket.bookings.booking.buckets.blank?
    					booking_id = employee_bucket.bookings.booking.buckets.first["key"]
    					booking.id = booking_id
    				end
            booking.build_blocks(args.merge({:current_minute => current_minute, :employee_id => employee_id}))
    				employee.bookings << booking
    				minute.employees << employee
    				minute.set_update_script({
    					employee_id: employee_id,
    					order_id: args[:order].id.to_s,
    					status_id: args[:status].id.to_s,
    					report_ids: args[:report_ids]
    				})
          end
   			end
  			minute
  		end

  	end

end