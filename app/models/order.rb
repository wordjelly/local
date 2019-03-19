require 'elasticsearch/persistence/model'
class Order

	include Elasticsearch::Persistence::Model
	include Concerns::StatusConcern
	include Concerns::PdfConcern
	
	index_name "pathofast-orders"

	attr_accessor :patient_name

	attr_accessor :account_statement

	attribute :patient_id, String

	## these are the template reports.
	## we need the ids.
	attribute :template_report_ids, Array

	## items are the tubes that got assigned.
	attribute :item_ids, Array

	attribute :report_name, String

	attribute :patient_test_ids, Array

	attribute :patient_report_ids, Array

	## so item requirements is going to be like what exactly ?
	## the item id will point to that.
	## it will carry th test ids.

	attribute :item_requirements, Hash


	attr_accessor :patient
	attr_accessor :reports
	attr_accessor :items

	## adding or removing an item group.
	## if you want to ad items by means of an item group
	attr_accessor :item_group_id
	attr_accessor :item_group_action

	## if you want to add individual items.
	## array of objects.
	attr_accessor :item_type
	attr_accessor :item_type_index
	attr_accessor :item_id
	attr_accessor :item_id_action

	attr_accessor :item_types
		
=begin

=end

	settings index: { 
	    number_of_shards: 1, 
	    number_of_replicas: 0,
	    analysis: {
		      	filter: {
			      	nGram_filter:  {
		                type: "nGram",
		                min_gram: 2,
		                max_gram: 20,
		               	token_chars: [
		                   "letter",
		                   "digit",
		                   "punctuation",
		                   "symbol"
		                ]
			        }
		      	},
	            analyzer:  {
	                nGram_analyzer:  {
	                    type: "custom",
	                    tokenizer:  "whitespace",
	                    filter: [
	                        "lowercase",
	                        "asciifolding",
	                        "nGram_filter"
	                    ]
	                },
	                whitespace_analyzer: {
	                    type: "custom",
	                    tokenizer: "whitespace",
	                    filter: [
	                        "lowercase",
	                        "asciifolding"
	                    ]
	                }
	            }
	    	}
	  	} do
	    mappings dynamic: 'true' do
		    indexes :item_requirements, type: 'object'
		end

	end

	validates_presence_of :patient_id	
	## takes the template report ids, and creates reports from that, as well as cloning all tests associated with those reports.
	#before_save do |document|
	#	puts "came to create patient reports"
	#	document.create_patient_reports
	#end

	after_save do |document|
		## adds the reports to the items themselves.
		## or removes them thereof.
	end

	def add_report(report_id)

	end

=begin
	def create_patient_reports
		self.reports ||= []
		self.template_report_ids.each do |report_id|
			report = Report.fhttps://guides.rubyonrails.org/testing.html#functional-tests-for-your-controllersind(report_id)
			self.patient_report_ids << report.clone(self.patient_id).id.to_s
			self.patient_test_ids << report.test_ids
			self.patient_test_ids.flatten!

			## these reports are the cloned reports.
			self.reports << report
			set_item_requirements
		end
	end
=end

	def barcoded_tube_has_space?(filled_amount, already_required, additional_requirement)
		return (filled_amount - already_required) >= additional_requirement
	end

	## adds a new tube for a particular report.
	def add_new_tube(item_requirement,report)
		

		self.item_requirements[item_requirement.item_type] ||= []
		self.item_requirements[item_requirement.item_type] << 
		{required_amount: item_requirement.amount, optional: item_requirement.optional, barcode: nil, filled_amount: 0, report_ids: [report.id.to_s]}
		
		#puts self.item_requirements[item_requirement.item_type]

	end

	## @param[ItemRequirement] ir
	## @param[Integer] key 
	## @param[String] report_id
	def add_report_id_to_item_requirement(ir,key,report)
		self.item_requirements[ir.item_type][key]["report_ids"] ||= []
		self.item_requirements[ir.item_type][key]["template_report_ids"] ||= []
		self.item_requirements[ir.item_type][key]["report_ids"] << report.id.to_s
		self.item_requirements[ir.item_type][key]["template_report_ids"] << template_report.id.to_s
	end

	## @param[String] report_id : the report id that you want to accomodate in this order.
	## @return[Hash] true/false :true if the existing item_requirements can accomodate it and 
	def accomodate(report)
		
		report.item_requirements.each do |ir|
			
			if self.item_requirements[ir.item_type].blank?
				
				add_new_tube(ir,report)
				
			else
				requirement_accomodated = false

				self.item_requirements[ir.item_type].each_with_index{|item_requirement,key|

					unless item_requirement["barcode"].blank?
						if barcoded_tube_has_space?(item_requirement["filled_amount"],item_requirement["required_amount"],ir.amount)
							
							self.item_requirements[ir.item_type][key]["required_amount"] += ir.amount
							
							add_report_id_to_item_requirement(ir,key,report.id.to_s)

							requirement_accomodated = true
							
						end
					else
						#puts "ir is:"
						#puts ir.to_s
						#puts "item requirement is:"
						#puts item_requirement.to_s
						unless (ir.amount + item_requirement["required_amount"] > 100)

							self.item_requirements[ir.item_type][key]["required_amount"]+=ir.amount

							add_report_id_to_item_requirement(ir,key,report.id.to_s)

							requirement_accomodated = true

						end
					end
				}
				if requirement_accomodated == false
					add_new_tube(ir,report)
				end
			end
		end	
	end

	def exists?(report_id)
		self.template_report_ids.include? report_id
	end

	def delete_template_report_id(template_report_id)
		self.template_report_ids.delete(template_report_id)
	end

	def delete_patient_report_id(patient_report)
		self.patient_report_ids.delete(patient_report.id.to_s)
		patient_report.test_ids.each do |tid|
			delete_patient_test_id(tid)
		end
	end


	def delete_patient_test_id(patient_test_id)
		self.patient_test_ids.delete(patient_test_id)
	end

	## @param[String] template_report_id
	## removes 
	## this should be called on each template report.
	def remove_report(template_report_id,params)
		puts "Came to check remove report "
		template_report_ids = params[:template_report_ids] || []
		puts "the params template report ids are:"
		puts template_report_ids.to_s

		unless template_report_ids.include? template_report_id
			puts "The params dont include this report id: #{template_report_id}"
			puts "the self reports are:"
			puts self.reports.to_s

			self.reports.each do |report|
				if report.template_report_id == template_report_id
					self.item_requirements.keys.each do |type|
						self.item_requirements[type].each_with_index {|tube,key|
							if tube["report_ids"].include? report.id.to_s
								self.item_requirements[type][key]["report_ids"].delete(report.id.to_s)
								if report.item_requirements_grouped_by_type[type][key]
									self.item_requirements[type][key]["required_amount"]-= report.item_requirements_grouped_by_type[type][key]["amount"]
									if self.item_requirements[type][key]["required_amount"] <= 0
										self.item_requirements[type].delete_at(key)
									end
								end
							end
						}
						## clears the item requirements if they have nothing left .
						self.item_requirements.delete(type) if self.item_requirements[type].blank?
					end
					delete_patient_report_id(report)
				end
			end
			delete_template_report_id(template_report_id)
		end
	end

	## so now we removed reports
	## now what is the next step.
	## we can add or remove reports.
	## suppose a barcode is not given.
	## someone wants to use a barcode that 
	## they want to just run it from some labelled
	## tube.
	## if they click i don't use these tubes
	## next step is status updates
	## and payments and report formats.
	## suppose i delete an item group.
	## i mean we had added an item group
	## now we want to delete it.
	## so from the ui side, if no item group is sent, then what happens ?
	## if no item group comes into the 
	## what if an item group is added subsequently ?
	## also for item_requirements.
	## we want to change the barcode on an individual tube later on.
	## can we do it?
	## we want to remove a mistaken item_group
	## can we do it?
	## 

	## so now begins extensive testing of removing reports
	## part 2.
	## 
	## so now if it says cannot accomodate, then tubes have to be added.
	## in that case, if the order status is past collection, it should decide.
	# remove report from item_requirement
	# if its too much or too little.
	# so suppose i remove a report
	# i have to also reduce the required amount from the item requirement where it has been added.
	# if that amount becomes zero, i have to remove that item requirement, provided that no other report is registered on it.
	# so we have to check all the current template report ids, against incoming.
	# if a template report id is not there, call remove on it.
	# we do this after adding.
	def add_remove_reports(params)
		#puts "params are:"
		#puts params.to_s
		self.template_report_ids ||= []
		self.reports ||= []
		unless params[:template_report_ids].blank?
			params[:template_report_ids].each do |report_id|
				#puts "doing report id: #{report_id}"
				unless exists?(report_id)
					#puts "does not exist."
					self.template_report_ids << report_id
					report = Report.find(report_id)
					self.patient_report_ids << report.clone(self.patient_id,self.id.to_s).id.to_s
					self.patient_test_ids << report.test_ids
					self.patient_test_ids.flatten!
					self.reports << report
					report.load_item_requirements
					accomodate(report)
				else
					puts "this report already exists."
				end
			end
		else
			puts "no template report ids in params."
		end
		self.template_report_ids.each do |rid|
			puts "iterating self template report id: #{rid}"
			remove_report(rid,params)
		end
	end

	
	def other_order_has_barcode?(barcode)
		response = Order.search({
			query: {
				term: {
					item_ids: barcode
				}
			}
		})
		self.errors.add(:item_ids, "This barcode #{barcode} has already been assigned to order id #{response.results.first.id.to_s}") if response.results.size > 0
		return true if response.results.size > 0
		
	end

	def group_param_item_requirements_by_type(params)
		item_requirements = params["item_requirements"]
		results = {}
		unless item_requirements.blank?
			item_requirements.keys.each do |id|
				type = item_requirements[id]["type"]
					
				index = item_requirements[id]["index"]
					
				barcode = item_requirements[id]["barcode"]
					
				filled_amount = item_requirements[id]["filled_amount"]
				results[type] = [] if results[type].nil?
				results[type] << item_requirements[id]
			end
		end
		results
	end

	def delete_item_group(params)
		unless self.item_group_id.blank?
			if params[:item_group_id].blank?
				## clear the self item_group_id
				## 
			end
		end
	end

	def add_barcodes(params)

		item_requirements = group_param_item_requirements_by_type(params)

		item_group_id = params["item_group_id"]
		unless item_group_id.blank?
			ig = ItemGroup.find(item_group_id)
			self.item_group_id = ig.id.to_s
			item_group_item_requirements = ig.prepare_items_to_add_to_order


			item_group_item_requirements.keys.each do |igk|
				if item_requirements[igk]
					item_group_item_requirements[igk].each_with_index {|el,key|
					
						if item_requirements[igk][key]
							item_requirements[igk][key]["barcode"] = item_group_item_requirements[igk][key]["barcode"] if item_requirements[igk][key]["barcode"].blank?
						end
					}
				end
			end


			
		end
		

		unless item_requirements.blank?
			item_requirements.keys.each do |id|
				item_requirements[id].each do |ireq|
					type = ireq["type"]
					
					index = ireq["index"]
					
					barcode = ireq["barcode"]
					
					filled_amount = ireq["filled_amount"]
					
					unless barcode.blank?
						
						unless self.item_requirements[type].blank?
							self.item_requirements[type][index.to_i]["barcode"] = barcode unless other_order_has_barcode?(barcode)
							self.item_ids ||= []
							self.item_ids << barcode
							self.item_requirements[type][index.to_i]["filled_amount"] = filled_amount unless filled_amount.blank?
						else
							puts "this type does not exist in the self item requirements."
						end

					end

				end

			end
		end
	end
	
	def load_patient
		self.patient = Patient.find(self.patient_id)
		self.patient_name = self.patient.name
	end

	def load_reports
		self.reports ||= []
		self.patient_report_ids.each do |patient_report_id|
			report = Report.find(patient_report_id)
			report.load_tests
			report.load_item_requirements
			self.reports << report
		end	
	end

	def load_items
		self.items ||= []
		self.item_ids.each do |item_id|
			self.items << Item.find(item_id)
		end
	end	

	## we want to aggregate, all payments
	## query for either "bill" or "payment"
	## aggregate by bills -> summate the numeric values
	## aggregate by payments -> summate the numeric values
	## and display sorted by date.
	## so i can test this.
	## but if we want to make a payment.
	## it should just show the pending amount.
	## this is done before, show and populates the make payment thereof, and also shows it in the options.
	## it also is used for making the receipt.
	## if he makes a payment, then, it should give a receipt option, while showing the status ?
	## just gives the whole statement.
	## this should show up in the order show view.
	## as a seperate partial.
	## we also need an endpoint for this for the receipt.
	def generate_account_statement
		results = Status.search({
			sort: {
				created_at: {
					order: "asc"
				}
			},
			query: {
				bool: {
					must: [
							{
								bool: {
									should: [
										{
											term: {
												name: {
													value: "bill"
												}
											}
										},
										{
											term: {
												name: {
													value: "payment"
												}
											}
										}
									]
								}
							},
							{
								term: {
									order_id: {
										value: self.id.to_s
									}
								}
							}
					]
				}
			},
			aggs: {
				bills_and_payments: {
					terms: {
						field: "name",
						size: 100
					},
					aggs: {
				        by_id: {
					        terms: {
					            field: "_id",
					            size: 100
					        },
					        aggs: {
					        	amount: {
					        		terms: {
					        			field: "numeric_value",
					        			size: 1
					        		}
					        	},
					        	dates: {
					        		date_histogram: {
					        			field: "created_at",
					        			interval: "day"
					        		}
					        	},
					        	text_value: {
					        		terms: {
					        			field: "text_value",
					        			size: 1
					        		}
					        	}
					        }
				        },
				        total: {
				          	sum: {
				            	field: "numeric_value"
				          	}
				        }
				    }
				}
			}
		})

		self.account_statement = {bill: [], payment: [], pending: nil}

		total_bills = 0
		total_payments = 0

		results.response.aggregations.bills_and_payments.buckets.each do |bucket|
			curr_key = bucket["key"]
			unless bucket.by_id.buckets.blank?
				bucket.by_id.buckets.each do |status|
					unless status.amount.buckets.blank?
						id = status["key"]
						amount = status.amount.buckets.first["key"]
						date = status.dates.buckets.first["key_as_string"]
						text_value = status.text_value.buckets.first["key"]
						self.account_statement[curr_key.to_s.to_sym] << {id: id, amount: amount, date: date, text_value: text_value}
					end
				end
				if curr_key == "bill"
					total_bills = bucket["total"]["value"]
				elsif curr_key == "payment"
					total_payments = bucket["total"]["value"]
				end
			end
		end

		self.account_statement[:pending] = total_bills - total_payments

		puts "the account statement is:"
		puts JSON.pretty_generate(self.account_statement)

	end
	
end