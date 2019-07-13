module Concerns::OrderConcern

	extend ActiveSupport::Concern

	included do 
			
		attribute :name, String, mapping: {type: 'keyword'}

		attribute :reports, Array[Diagnostics::Report]

		attribute :patient_id, String, mapping: {type: 'keyword'}

		attribute :categories, Array[Inventory::Category] 

		attribute :payments, Array[Business::Payment]

		attribute :local_item_group_id

		attribute :procedure_versions_hash, Hash

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
			    
		    	indexes :name, type: 'keyword', fields: {
			      	:raw => {
			      		:type => "text",
			      		:analyzer => "nGram_analyzer",
			      		:search_analyzer => "whitespace_analyzer"
			      	}
			    }

			   	indexes :categories, type: 'nested', properties: Inventory::Category.index_properties
			   	indexes :reports, type: 'nested', properties: Diagnostics::Report.index_properties

			end

		end


		before_save do |document|
			document.update_requirements
			document.update_report_items
		end

		after_save do |document|
			document.schedule
		end

	end

	def get_schedule
  		search_request = Schedule::Minute.search({
  			size: 0,
  			query: {
  				bool: {
  					must: [
  						{
  							nested: {
  								path: "employees",
  								query: {
  									nested: {
  										path: "employees.bookings",
  										query: {
  											term: {
  												"employees.bookings.order_id".to_sym => self.id.to_s
  											}
  										}
  									}
  								}
  							}
  						}
  					]
  				}
  			},
  			aggs: {
  				minute: {
  					terms: {
  						field: "number",
  						order: {
  							"_key".to_sym => "asc"
  						}
  					},
  					aggs: {
  						employees: {
  							nested: {
  								path: "employees"
  							},
  							aggs: {
  							 	employees: {
  							 		filter: {
  							 			nested: {
  							 				path: "employees.bookings",
  							 				query: {
  							 					term: {
  							 						"employees.bookings.order_id".to_sym => self.id.to_s
  							 					}
  							 				}
  							 			}
  							 		},
  							 		aggs: {
  							 			employees: {
  							 				terms: {
  							 					field: "employees.employee_id"
  							 				},
  							 				aggs: {
  							 					bookings: {
  							 						nested: {
  							 							path: "employees.bookings"
  							 						},
  							 						aggs: {
  							 							bookings_filtered: {
  							 								filter: {
  							 									term: {
  							 										"employees.bookings.order_id".to_sym => self.id.to_s
  							 									}
  							 								},
  							 								aggs: {
  							 									status_ids: {
		  							 								terms: {
		  							 									field: "employees.bookings.status_id"
		  							 								},
		  							 								aggs: {
		  							 									report_ids: {
		  							 										terms: {
		  							 											field: "employees.bookings.report_ids"
		  							 										}
		  							 									}
		  							 								}
		  							 							}
  							 								}
  							 							}
  							 							
  							 						}
  							 					}
  							 				}
  							 			}
  							 		}
  							 	}
  							}
  						}
  					}
  				}
  			}
  		})
  		search_request.response.aggregations
  	end

	def assign_id_from_name
		self.name = BSON::ObjectId.new.to_s
		self.id = self.name
	end

	## first reset all the required quantitis.
	def reset_category_quantities
		self.categories.map {|cat|
			cat.quantity = 0	
		}
	end

	def has_category?(name)
		self.categories.select{|c|
			c.name == name
		}.size > 0
	end


	## will build the categories array using the requirements defined in the reports.
	## before starting will clear all the quantites from existing elements of hte categories array.
	## and then will add a category if it doesn't exist, and if it exists, will increment its quantity.
	def update_requirements
		reset_category_quantities
		self.reports.map{|report|
			report.requirements.each do |req|
				options = req.categories.size
				req.categories.each do |category|
					#puts "looking for category: #{category.name}"
					if !has_category?(category.name)
						category_to_add = Inventory::Category.new(quantity: category.quantity, required_for_reports: [], optional_for_reports: [], name: category.name)
						if options > 1
							category_to_add.optional_for_reports << report.id.to_s
						else
							category_to_add.required_for_reports << report.id.to_s
						end
						self.categories << category_to_add
					else
						self.categories.each do |existing_category|
							if existing_category.name == category.name
								
								existing_category.quantity += category.quantity

								if options > 1
									existing_category.optional_for_reports << report.id.to_s
								else
									existing_category.required_for_reports << report.id.to_s
								end

								existing_category.optional_for_reports.flatten!

								existing_category.required_for_reports.flatten!

							end
						end
					end
				end
			end
		}		
	end

	## whatever items the user has added to the categories will be updated to the reports.
	def update_report_items
		self.reports.map{|c|
			c.clear_all_items
		}
		self.categories.each do |category|
			category.items.each do |item|
				self.reports.each do |report|
					report.add_item(category,item)
				end
			end
		end
	end



	## collates reports if they share the exact same statuses.
	## to do this, it will check the checksum of the report statuses.
	## if it is the same, then it will collate.
	## it also adds relevant tubes to those  statuses ?
	## no it does not.
	## just go with status ids ?
	## or how to add statuses exactly ?
	## will it have its own id
	## does it have to be unique ?
	## if you copy a status, and you change the earlier one.
	## then does that propagate ?
	## reference status id.
	## it can be done.
	## like that.
	## so it will be collated based on what ?
	## reference status id ?
	## so we give it a reference status version, and id.
	## let the status ids be unique.
	## on changing it its version will change.
	## collate by similarity of version+refid.
	## so lets say there are ten statuses -> so we make a base64 out of it ?
	## no we maintain that for the report.
	## and use it here directly.
	## call it procedure code or some shit.
	def schedule
		procedure_versions_hash = {}
		## we append the start epoch to it.
		## so that we don't fuck that up.
		## next step will be the mapping.
		## 
		self.reports.each do |report|
			## we consider the desired start time and the procedure, as a parameter for commonality.
			effective_version = report.procedure_version + "_" + report.start_epoch.to_s
			if procedure_versions_hash[effective_version].blank?
				procedure_versions_hash[effective_version] =
				{
					statuses: report.statuses,
					reports: [report.id.to_s],
					start_time: report.start_epoch
				} 
			else
				procedure_versions_hash[effective_version][:reports] << report.id.to_s
			end
		end

		## give the statuses the :from and :to timings.
		procedure_versions_hash.keys.each do |proc|
			start_time = procedure_versions_hash[proc][:start_time]
			prev_start = nil
			procedure_versions_hash[proc][:statuses].map{|c|
				c.from = prev_start.blank? ? (start_time) : (prev_start + c.duration) 
				c.to = c.from + Diagnostics::Status::MAX_DELAY
				prev_start = c.to
			}
		end

		self.procedure_versions_hash = procedure_versions_hash
		## so we can just pass the whole order.
		#puts "came to schedule order"

		#puts "procedure versions hash is:"

		#puts JSON.pretty_generate(self.procedure_versions_hash)

		Schedule::Minute.schedule_order(self)
	
				
	end

	###########################################################
	##
	##
	## PRE SCHEDULE FUNCTIONS.
	##
	##
	###########################################################
	## STEP ONE
	def get_reports_to_schedule
	end

	## STEP TWO
	def group_reports_by_start_epoch
	end

	## STEP THREE
	def group_reports_by_procedure_version
	end


	
	## SO THEY CAN ENTER THE ID OF THE OUTSOURCING ORGANIZATION
	## THEN THEY HAVE TO ANSWER FUSION QUESTIONS.
	## FOR EACH STEP IN THE OUTSOURCER SOP, IT WILL 
	## ASK IF YOU ARE GOING TO DO THIS, IF YOU HAVE AN EQUI
	## VALENT 

	## fire grouped queries.
	## so lets say you will do that yourself.
	## or you don't have any equivalent status.
	## we will do a certain status.
	## do the equivalent status
	## or do that status itself.
	## that can also be offered.
	## status is marked as required
	## so and it has a category
	## all the required statuses either have an equivalence or they
	## are out.so we we give a merge report for outsourcing.
	## so we call merge on outsourced reports
	## they have a report
	## they have sent that organizations report
	## this part comes later on.
	## so is the outsourcing issue resolved or not ?
	## he marks it as outsource
	## we searched his organizations reports
	## he has said perform by someone else.
	## so now we cannot schedule till then.
	## we get that report and present the combined statuses
	## he chooses that status.
	## how to schedule based on the start epochs.
	###########################################################
	##
	##
	## 
	##
	##
	###########################################################

	module ClassMethods

		def permitted_params
			base = [
					:id,
					{:order => 
						[
							:patient_id,
							:local_item_group_id,
							:start_epoch,
							{
								:categories => Inventory::Category.permitted_params
							},
					    	{
					    		:payments => Business::Payment.permitted_params
					    	},
					    	{
					    		:reports => Diagnostics::Report.permitted_params[1][:report]
					    	}
						]
					}
				]
			if defined? @permitted_params
				base[1][:order] << @permitted_params
				base[1][:order].flatten!
			end
			base
		end

	end

end