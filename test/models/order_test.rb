require 'test_helper'
 
class OrderTest < ActiveSupport::TestCase
   
    setup do 

      ["Test","Employee","Item","ItemGroup","ItemRequirement","ItemType","Location","NormalRange","Order","Patient","Report","Status","Test","Image"].each do |cls|
        cls.constantize.send("create_index!",{force: true})
      end

      t = Test.new(name: "MCV", lis_code: "MCV", price: 100)
      t.save

      t2 = Test.new(name: "MCH", lis_code: "MCH", price: 100)
      t2.save

      patient = Patient.new(first_name: "Bhargav", last_name: "Raut")
      patient.save

      item_type_one = ItemType.new(name: "Serum Tube")
      item_type_one.save

      item_type_two = ItemType.new(name: "Plasma Tube")
      item_type_two.save

      item_type_three = ItemType.new(name: "Plain Tube")
      item_type_three.save

      item_type_four = ItemType.new(name: "Plasma Tube")
      item_type_four.save

      item_requirement = ItemRequirement.new(name: "Golden Top Tube", item_type: item_type_one.name)
      item_requirement.save

      item_requirement_two = ItemRequirement.new(name: "RS Tube", item_type: item_type_one.name)
      item_requirement_two.save

      item_requirement_three = ItemRequirement.new(name: "Plain Tube", item_type: item_type_one.name)
      item_requirement_three.save

      item_requirement_four = ItemRequirement.new(name: "Plasma Tube", item_type: item_type_two.name)
      item_requirement_four.save

      ## add this item to that report.
      ## i can do that manually
      r1 = Report.new(name: "Creatinine", price: 300)
      r1.test_ids = [t.id.to_s,t2.id.to_s]
      r1.item_requirement_ids = [item_requirement.id.to_s, item_requirement_two.id.to_s, item_requirement_three.id.to_s,item_requirement_four.id.to_s]
      r1.save
      @r1_id = r1.id.to_s

      r2 = Report.new(name: "Urea", price: 300)
      r2.test_ids = [t.id.to_s,t2.id.to_s]
      r2.item_requirement_ids = [item_requirement.id.to_s, item_requirement_two.id.to_s, item_requirement_three.id.to_s,item_requirement_four.id.to_s]
      r2.save
      @r2_id = r2.id.to_s

      r3 = Report.new(name: "HDL", price: 300)
      r3.test_ids = [t.id.to_s,t2.id.to_s]
      r3.item_requirement_ids = [item_requirement.id.to_s, item_requirement_two.id.to_s, item_requirement_three.id.to_s,item_requirement_four.id.to_s]
      r3.save
      @r3_id = r3.id.to_s

      r4 = Report.new(name: "LDL", price: 300)
      r4.test_ids = [t.id.to_s,t2.id.to_s]
      r4.item_requirement_ids = [item_requirement.id.to_s, item_requirement_two.id.to_s, item_requirement_three.id.to_s,item_requirement_four.id.to_s]
      r4.save
      @r4_id = r4.id.to_s

      r5 = Report.new(name: "GGT", price: 300)
      r5.test_ids = [t.id.to_s,t2.id.to_s]
      r5.item_requirement_ids = [item_requirement.id.to_s, item_requirement_two.id.to_s, item_requirement_three.id.to_s,item_requirement_four.id.to_s]
      r5.save
      @r5_id = r5.id.to_s

      [item_requirement,item_requirement_two,item_requirement_three].each_with_index {|ir,key|
        item_requirement = ItemRequirement.find(ir.id.to_s)
        item_requirement.definitions = [
          {
            report_id: r1.id.to_s,
            report_name: r1.name.to_s,
            amount: 10,
            priority: key
          },
          {
            report_id: r2.id.to_s,
            report_name: r2.name.to_s,
            amount: 10,
            priority: key
          },
          {
            report_id: r3.id.to_s,
            report_name: r3.name.to_s,
            amount: 10,
            priority: key
          },
          {
            report_id: r4.id.to_s,
            report_name: r4.name.to_s,
            amount: 10,
            priority: key
          },
          {
            report_id: r5.id.to_s,
            report_name: r5.name.to_s,
            amount: 80,
            priority: key
          }
        ]
        item_requirement.save
      }


      item_one = Item.new(item_type: item_type_one.name, barcode: "GOLDEN_TOP_TUBE", expiry_date: (Time.now + 10.days).to_s)
      item_one.save

      item_two = Item.new(item_type: item_type_two.name, barcode: "RS_TUBE", expiry_date: (Time.now.to_s).to_s)
      item_two.save

      item_three = Item.new(item_type: item_type_three.name, barcode: "PLAIN_TUBE", expiry_date: (Time.now.to_s).to_s)
      item_three.save

      item_four = Item.new(item_type: item_type_four.name, barcode: "PLASMA_TUBE", expiry_date: (Time.now.to_s).to_s)
      item_four.save

      ## so now we have saved the items, and the optional item requirements.
      ## these are for the individual requiremetns.
      ## now the first thing is to check why the tube assignment is not working.
      ## and the second thing is to check about item_requirement_amounts.

      status_zero = Status.new(name: "At Collection Site", priority: 0)
      status_zero.save

      status_one = Status.new(name: "On Conveyor Belt", priority: 0)
      status_one.save

      status_two = Status.new(name: "In Centrifuge", priority: 1)
      status_two.save

      status_three = Status.new(name: "Waiting For Analyzer", priority: 2)
      status_three.save

      status_four = Status.new(name: "Inside Analyzer", priority: 3)
      status_two.save

      status_five = Status.new(name: "Result Pending Verification", priority: 4)
      status_five.save

      status_six = Status.new(name: "Verified, Waiting for Print", priority: 5)
      status_six.save   

      status_seven = Status.new(name: "Pending Aliquoting for Deep Freeze Storage", priority: 6)
      status_seven.save

      status_eight = Status.new(name: "Aliquoted", priority: 6)
      status_eight.save

      5.times do |n|
        status = Status.new(report_id: "report#{n}", order_id: "order1", numeric_value: 100, name: "bill", priority: 0)
        status.save
      end

      2.times do |n|
        status = Status.new(order_id: "order1", numeric_value: 100, name: "payment", priority: 0)
        status.save
      end

  		Elasticsearch::Persistence.client.indices.refresh index: "pathofast-statuses"

    end

=begin
    test "account statement is generated" do 
   		o = Order.find(@o.id.to_s)
   		o.generate_account_statement
   		o.generate_pdf
      puts JSON.pretty_generate(o.account_statement)
    end
=end

=begin
    test "3 new tubes are added" do 
      o = Order.new
      o.patient_id = "test_patient"
      o.template_report_ids = [@r1_id,@r2_id,@r3_id]
      o.save
      assert_equal 3, o.tubes.size
      ["Golden Top Tube","RS Tube","Plain Tube"].each do |tube|
        assert o.tubes.select{|c| c["item_requirement_name"] == tube}.size == 1
      end
      o.tubes.each do |tube|
        [@r1_id,@r2_id,@r3_id].each do |rid|
          assert tube["template_report_ids"].include? rid
        end
        assert_equal tube["occupied_space"],30.0
      end
    end

    test "report is added to 3 existing tubes" do 
      o = Order.new
      o.patient_id = "test_patient"
      o.template_report_ids = [@r1_id,@r2_id,@r3_id]
      o.save
      o = Order.find(o.id.to_s)
      o.template_report_ids << @r4_id
      o.save
      assert_equal 3, o.tubes.size
      o.tubes.each do |tube|
        [@r1_id,@r2_id,@r3_id,@r4_id].each do |rid|
          assert tube["template_report_ids"].include? rid
        end
        assert_equal tube["occupied_space"],40.0
      end
    end

    test "adds new tube of same type if existing tube does not have enough space" do 
      o = Order.new
      o.patient_id = "test_patient"
      o.template_report_ids = [@r1_id,@r2_id,@r3_id]
      o.save
      o = Order.find(o.id.to_s)
      o.template_report_ids << @r5_id
      o.save
      assert_equal 6, o.tubes.size
    end

    test "reports are removed, tube is also removed, and new tube of the same type is added for another report" do 

      o = Order.new
      o.patient_id = "test_patient"
      o.template_report_ids = [@r1_id,@r2_id,@r3_id]
      o.save
      o = Order.find(o.id.to_s)
      o.template_report_ids = [@r1_id,@r2_id]
      o.save
      assert_equal 3, o.tubes.size
      ["Golden Top Tube","RS Tube","Plain Tube"].each do |tube|
        assert o.tubes.select{|c| c["item_requirement_name"] == tube}.size == 1
      end
      o.tubes.each do |tube|
        [@r1_id,@r2_id].each do |rid|
          assert tube["template_report_ids"].include? rid
        end
        assert_equal tube["occupied_space"],20.0
        assert_equal 2, tube["template_report_ids"].size
      end       
    end
=end


    test "only r2 is removed, not r3, because r3 has crossed the point of cancellation" do 

      o = Order.new
      o.patient_id = "test_patient"
      o.template_report_ids = [@r1_id,@r2_id,@r3_id]
      o.save
      # so clone is not working properly.
     
      Elasticsearch::Persistence.client.indices.refresh index: "pathofast-reports"      

      puts "r3 id is: #{@r3_id}"


      results = Report.search({
        size: 1,
        query: {
          bool: {
            must: [
              {
                term: {
                  patient_id: "test_patient"
                }
              },
              {
                term: {
                  template_report_id: @r3_id
                }
              } 
            ]
          }
        }
      })

      puts "r3 id is: #{@r3_id}"

      patient_report = nil
      results.response.hits.hits.each do |hit|
        patient_report = Report.new(hit["_source"])
        patient_report.id = hit["_id"]
      end

      puts "the patient report is:"
      puts patient_report.attributes.to_s

      s = Status.new
      s.parent_ids = [patient_report.id.to_s]
      s.text_value = Status::COLLECTION_COMPLETED
      s.priority = 1
      s.save

      Elasticsearch::Persistence.client.indices.refresh index: "pathofast-statuses"    

      o.template_report_ids = [@r1_id]
      o.save
      ## only r2 will be removed.
      ## not r3.
      assert_equal 3, o.tubes.size
      ["Golden Top Tube","RS Tube","Plain Tube"].each do |tube|
        assert o.tubes.select{|c| c["item_requirement_name"] == tube}.size == 1
      end
      o.tubes.each do |tube|
        puts "this is the tube"
        puts JSON.pretty_generate(tube)
        [@r1_id,@r3_id].each do |rid|
          assert tube["template_report_ids"].include? rid
        end
       #assert ((tube["template_report_ids"].include? @r2_id) == false)
        assert_equal tube["occupied_space"],20.0
        assert_equal 2, tube["template_report_ids"].size
      end     

    end

=begin

    test "barcodes can be added to individual tubes" do 

    end


    test "group item id, on being added is assigned to the relevant tubes" do 

    end

=end

 
end