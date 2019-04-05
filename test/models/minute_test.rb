require 'test_helper'
 

class DayTest < ActiveSupport::TestCase
   
    setup do
		Minute.create_index! force: true    	
		Minute.create_test_minutes(5)
    end

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

    test "aggregates the bookings of the employee to be blocked" do 

    	
    	
    end

    test "blocks employee given start time and end time" do

    	## what is a block basically?
    	## you find all minutes
    	## then you aggregate by id.
    	## you iterate, each employee till you get it.
    	## there you set the status either as empty
    	## or for whichever status you want to block.
    	## suppose no other employee is available, what happens?
    	## who gets assigned to it
    	## so the aggregation will reveal who to reassign it to.
    	## and we filter these 
    	## while iterating, we can check ?
    	## or it goes into a floating pool?
    	## it gets alloted to every other person on that minute
    	## we will see how to reallot it later.
    	## that's what happens
    	## so booked statuses, will also be nested.
    	## 
    	## before blocking, should assign the assigned task to another employee if he/she is available.
    	## 

    end

    test "reallots job to other employee if primary employee is to be blocked" do 

    end
    
end