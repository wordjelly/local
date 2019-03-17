require 'test_helper'
 
class OrderTest < ActiveSupport::TestCase
   
    setup do 
    	@o = Order.new(patient_id: "test_patient")
    	@o.save
   		5.times do |n|
			status = Status.new(report_id: "report#{n}", order_id: 
				@o.id.to_s, numeric_value: 100, name: "bill")
			status.save
		end

		2.times do |n|
			status = Status.new(order_id: @o.id.to_s, numeric_value: 100, name: "payment")
			status.save
		end

		Elasticsearch::Persistence.client.indices.refresh index: "pathofast-statuses"

   end

   test "account statement is generated" do 
   		o = Order.find(@o.id.to_s)
   		o.generate_account_statement
   		puts JSON.pretty_generate(o.account_statement)
   end

end