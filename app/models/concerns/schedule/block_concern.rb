module Concerns::Schedule::BlockConcern

	extend ActiveSupport::Concern

  	included do

  	end

  	module ClassMethods

      ## so build blocks will build these two blocks
      ## and then they have to be committed.
      ## @param[]
  		def prospective_blocks(args)
  			#status,current_minute,employee_id
  			status = args[:status]
        current_minute = args[:current_minute]
        employee_id = args[:employee_id]

        blocks = []
  			## for any employee, but this status.
  			blocks << new(sample_capacity: -1*status.lot_size, minutes: Array(current_minute..(current_minute + status.duration)), status_ids: [status.id.to_s])
  			
  			## for any status but this employee

  			blocks << new(employee_capacity: -1, minutes: Array(current_minute..(current_minute + status.duration)), status_ids: ["*"], employee_id: employee_id)

        blocks

  		end

  		def retrospective_blocks(status_durations,current_minute,status)
        
        status_durations = args[:status_durations]
        
        current_minute = args[:current_minute]
        
        status = args[:status]

        blocks = []
  			
        status_durations.keys.each do |duration|
          d = duration.to_i
          minutes = Array((current_minute - duration)..(current_minute))
          status_ids = status_durations[duration]
          employee_capacity = -1
          blocks << new(employee_capacity: -1, status_ids: status_ids, minutes: minutes)
        end

        blocks << new(sample_capacity: -1, status_id: current_status.id.to_s, minutes: Array(current_minute - duration)..(current_minute))

        blocks
  			
  		end

	end

end