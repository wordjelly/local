require 'test_helper'
 

class DayTest < ActiveSupport::TestCase
   
    setup do
		#Minute.create_index! force: true    	
		#Minute.create_test_minutes(25)
		#Elasticsearch::Persistence.client.indices.refresh index: "pathofast-*"
    end


=begin
    test "test adds new employee to minute" do 
    	new_employee_ids = ["101","221","321"]

		update_hash = Minute.update_minute("1",{
    		employee_ids: new_employee_ids,
    		status_id: "1"
    	})		
    	Minute.add_bulk_item(update_hash)
    	Minute.flush_bulk
    	Elasticsearch::Persistence.client.indices.refresh index: "pathofast-minutes"

    	minute = Minute.find("1")
    	selected_minutes = minute.employees.select{|c|
    		new_employee_ids.include? c["id"]
    	}
    	assert_equal 3, selected_minutes.size
    end

    test "adds status id to existing employee" do 
    	new_employee_ids = ["101","221","321"]

		update_hash = Minute.update_minute("2",{
    		employee_ids: new_employee_ids,
    		status_id: "1"
    	})		
    	Minute.add_bulk_item(update_hash)
    	Minute.flush_bulk
    	Elasticsearch::Persistence.client.indices.refresh index: "pathofast-minutes"

    	## now we update the same employees in this minute, with another status id.
    	new_employee_ids = ["101","221","321"]

		update_hash = Minute.update_minute("2",{
    		employee_ids: new_employee_ids,
    		status_id: "1000"
    	})		
    	Minute.add_bulk_item(update_hash)
    	Minute.flush_bulk
    	Elasticsearch::Persistence.client.indices.refresh index: "pathofast-minutes"

    	## now this minute, should have employees with both these status ids.

    	m = Minute.find("2")
    	selected_employees = m.employees.select{|c|
    		new_employee_ids.include? c["id"]
    	}

    	assert_equal 3, selected_employees.size

    	selected_employees.each do |employee|
    		assert_equal ["1","1000"], employee["status_ids"]
    	end

    end
=end

=begin
    test "aggregates the bookings of the employee to be blocked" do 
    	Minute.aggregate_employee_bookings("1","","")
    end
=end
	
	test " - gets all minutes as slots for this status - " do 

		required_statuses = [
			{
				:from => 0,
				:to => 10,
				:id => "1",
				:maximum_capacity => 10
			}
		]

		Minute.get_minute_slots({:required_statuses => required_statuses})

	end

=begin
    test "blocks employee given start time and end time" do

    end

    test "reallots job to other employee if primary employee is to be blocked" do 

    end
=end

end