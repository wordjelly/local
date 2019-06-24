require 'elasticsearch/persistence/model'
class Business::Order

	include Elasticsearch::Persistence::Model
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern

	index_name "pathofast-business-orders"
	document_type "business/order"
	include Concerns::OrderConcern
	include Concerns::PdfConcern

=begin
	
	validates_presence_of :patient_id	
		
	## if set to any value, will skip the before save callbacks
	attr_accessor :skip_before_save

	## if set to any valu, will skip the after save callbacks.
	attr_accessor :skip_after_save	

	before_save do |document|
		if document.skip_before_save.blank?
			document.update_barcodes
			document.update_tubes
		end
	end

	after_save {puts "executing code after saving"}

	after_save do |document|
		if document.skip_after_save.blank?
			ScheduleJob.perform_later([document.id.to_s,document.class.name])
		end
	end

	after_find do |document|
		#document.load_patient
		#document.load_patient_reports
		#document.generate_account_statement
		#document.generate_pdf
	end

	def load_patient_reports
		self.reports ||= []
		get_patient_report_ids.each do |pid|
			self.reports << Report.find(pid)
		end
	end

	def existing_template_report_ids
		self.tubes ||= []
		self.tubes.map{|c|
			c["template_report_ids"]
		}.flatten.uniq
	end
	
	## returns the id of the patient report.
	## won't reclone the report if its already cloned
	## only applicable intra sesssion.
	## so we clone some of the applicable reports.
	## and we added those tubes
	## but it doesn't become transactional.
	## so it may reclone, and screw up the bill.
	def clone_report(report_id)	
		self.cloned_reports ||= {}
		if self.cloned_reports[report_id].blank?
			self.cloned_reports[report_id] = 
			Report.find(report_id).clone(self.patient_id,self.id.to_s).id.to_s
		end
		self.cloned_reports[report_id]
	end

	## @param[Hash] args: Hash of the tube definition.
	## It will include the following keys.
	## :item_requirement_name
	## :template_report_ids
	## :required_space
	## @return[Hash] 
	def add_tube_requirement(args)
		last_index = self.tubes.rindex{|x|
			x["item_requirement_name"] == args["item_requirement_name"]
		}
		if last_index.blank?
			self.tubes << args
		else
			if (100 - self.tubes[last_index]["occupied_space"]) >= args["occupied_space"]
				self.tubes[last_index]["template_report_ids"]+= args["template_report_ids"]
				self.tubes[last_index]["patient_report_ids"]+= args["patient_report_ids"]
				self.tubes[last_index]["occupied_space"]+= args["occupied_space"]
			else
				self.tubes << args
			end
		end
	end

	def update_barcodes
		if(Set.new(existing_template_report_ids) == Set.new(self.template_report_ids))
			if self.item_group_id.blank?
				self.tubes.map{|tube|
					unless tube["item_group_id"].blank?
						tube["barcode"] = nil 
						tube["item_group_id"] = nil
					end
				}
			else
				item_group = ItemGroup.find(item_group_id)
				tube_indices_assigned = []
				item_group.load_associated_items

				item_group_indices = {}

				#puts "-------------- these are the items -------------"
				#item_group.items.each do |item|
				#	puts JSON.pretty_generate(item.attributes)
				#end
				#puts "-------------- items end -----------------------"


				item_group.items.each_with_index{|item,ikey|
					#self.tubes.map.each_with_index

					item_group_indices[ikey.to_s] = nil
					self.tubes.map.each_with_index{|tube,key|
						unless tube_indices_assigned.include? key
							if tube["item_requirement_name"] == item.item_type
								#self.tubes[key]["barcode"] = item.barcode
								#self.tubes[key]["item_group_id"] = item_group.id.to_s
								item_group_indices[ikey.to_s] = key
								tube_indices_assigned << key 
							end
						end
					}
				}

				item_group_indices.keys.each do |ikey|
					unless item_group_indices[ikey].blank?
						#puts " -------- setting tube data ----------- "
						self.tubes[item_group_indices[ikey]]["barcode"] = item_group.items[ikey.to_i].barcode
						self.tubes[item_group_indices[ikey]]["item_group_id"] = item_group.id.to_s
					end
				end

			end
				

			self.tubes.each do |tube|
				unless tube["barcode"].blank?
					other_order_has_barcode?(tube["barcode"])
					item_type_is_equivalent?(tube["barcode"],tube["item_requirement_name"])
					## this is done in the background job.
					## so all that has to be changed.
					## update to every minute, where these reports have been found in the bookings.
					## if its not already there.
				else
					## remove it from those reports, in every minute, wherever it has been found.
					## this part is ok.
				end
			end	
		end
	end

	def update_tubes
		
		puts "---------- CAME TO UPDATE TUBES -------------- "

		(existing_template_report_ids - self.template_report_ids).each do |template_report_id_to_remove|
			
			self.tubes.map{|c|
				if arrind = c["template_report_ids"].index(template_report_id_to_remove)
					patient_report = Report.find(c["patient_report_ids"][arrind])
					patient_report.load_statuses
					if patient_report.can_be_cancelled?
						c["template_report_ids"].delete_at(arrind)
						c["patient_report_ids"].delete_at(arrind)
						## delete it from the minutes whereever it is registered
						## also if some tube was added, nothign much can be done for that.
						ireq = ItemRequirement.search({
							query: {
								term: {
									name: c["item_requirement_name"]
								}
							}
						}).response.hits.hits.first._source
						#puts ireq.to_s
						#puts ireq.class.name
						ireq = ItemRequirement.new(ireq)
						#puts ireq.to_s
						ireq.get_amount_for_report(template_report_id_to_remove)
						#puts "-------------------------------"
						c["occupied_space"]-= ireq.get_amount_for_report(template_report_id_to_remove)
					else
						## so we add it back to the current template report ids, because that patient report can no longer be cancelled.
						self.template_report_ids << template_report_id_to_remove
					end
				end
			}
		end

		self.report_ids_to_add = self.template_report_ids - existing_template_report_ids

		puts "the report ids to add are:"
		puts self.report_ids_to_add.to_s

		self.schedule_action = "add" unless self.report_ids_to_add.blank?

		## => key : template_report_id
		## => value : patient_report_id
		## used at the end of this function to populate the patient report ids.
		template_reports_to_patient_reports_hash = {}

		required_item_amounts = ItemRequirement.search({
			query: {
				bool: {
					filter: {
						nested: {
							path: "definitions",
							query: {
								terms: {
									"definitions.report_id".to_sym => self.report_ids_to_add
								}
							}
						}
					}
				}
			},
			aggs: {
				item_types: {
					terms: {
						field: "item_type",
						size: 100
					},
					aggs: {
						item_requirements: {
							terms: {
								field: "name",
								size: 100,
								order: {"priorities>min_priority".to_sym => "asc"}
							},
							aggs: {
								priorities: {
									nested: {
										path: "definitions"
									},
									aggs: {
										min_priority: {
											min: {
												field: "definitions.priority"
											}
										}
									}
								},
								amounts: {
									nested: {
										path: "definitions"
									},
									aggs: {
										required_reports: {
											filter: {
												terms: {
													"definitions.report_id".to_sym => self.report_ids_to_add
												}
											},
											aggs: {
												sum_amount: {
													sum: {
														field: "definitions.amount"
													}
												},
												applicable_reports: {
													terms: {
														field: "definitions.report_id"
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

		required_item_amounts.response.aggregations.item_types.buckets.each do |item_type|
			item_type.item_requirements.buckets.each do |ir|
				
				tube_type = ir["key"]
				
				required_amount = ir.amounts.required_reports.sum_amount.value

				applicable_reports = ir.amounts.required_reports.applicable_reports.buckets.map{|c| c = c["key"]}
				
				patient_report_ids = applicable_reports.map{|c|
					clone_report(c)
				}
				
				applicable_reports.each_with_index {|ar,key|
					template_reports_to_patient_reports_hash[ar] = patient_report_ids[key]
				}

				add_tube_requirement({
					"item_requirement_name" => tube_type,
					"template_report_ids" => applicable_reports,
					"occupied_space" => required_amount,
					"patient_report_ids" => patient_report_ids
				})
			end
		end

		self.patient_report_ids = template_reports_to_patient_reports_hash.values

	end

	def item_type_is_equivalent?(barcode,tube_type)
		item = Item.find(barcode)
		unless item.item_type == tube_type
			self.errors.add(:tubes, "tube type for this barcode : #{barcode} , does not match : #{tube_type}")
		end
		item.item_type == tube_type
	end

	def other_order_has_barcode?(barcode)
		puts "barcode is: #{barcode}"
		## and not self.
		results = Order.search({
			query: {
				nested: {
					path: "tubes",
					query: {
						term: {
							"tubes.barcode".to_sym => barcode
						}
					}
				}
			}
		})
		self.errors.add(:tubes, "This barcode #{barcode} has already been assigned to order id #{response.results.first.id.to_s}") if results.response.hits.hits.size > 0
		return true if results.response.hits.hits.size > 0
	end

	def delete_item_group(params)
		unless self.item_group_id.blank?
			if params[:item_group_id].blank?
				## clear the self item_group_id
				## 
			end
		end
	end
	
	def load_patient
		self.patient = Patient.find(self.patient_id)
		self.patient_name = self.patient.name
	end

	def get_patient_report_ids
		self.tubes.map{|c|
			c["patient_report_ids"]
		}.flatten.uniq
	end
	

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
							},
							{
								terms: {
									report_id: get_patient_report_ids
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

	## gather those that have exactly same steps
	## as one.
	## then schedule -> 
	## then move to the next report -> using homing to schedule it
	## simple to add or remove reports.
	## but that will take time.
	## the exact scheduling.
	## status ids.
	## i can do it actually.
	## But an employee is actually a user.
	## so they have to have a user id.
	## status collation
	## order homing.
	## these two are critical.	

	###########################################################
	##
	##
	## UTILITY
	##
	##
	###########################################################
	def get_patient_report_ids_applicable_to_status(status)
		applicable_patient_report_ids = []
		puts "the status parent ids are:"
		puts status.parent_ids
		puts "the patient report ids are:"
		puts self.patient_report_ids
		puts "the self template report ids are:"
		puts self.template_report_ids.to_s
		status.parent_ids.each do |parent_id|
			if self.template_report_ids.include? parent_id
				applicable_patient_report_ids << self.patient_report_ids[self.template_report_ids.index(parent_id)]
			end
		end
		applicable_patient_report_ids.compact
	end

	###########################################################
	##
	##
	## SCHEDULE LOGS
	## each of these methods accepts an order_log object.
	## it adds that to the orders logs, and saves
	###########################################################
	def failed_to_schedule(message)
		self.order_logs ||= []
		self.order_logs << OrderLog.new(:log_time => Time.now.to_i, :description => "failed to create schedule", :message => message)
	end

	def scheduled_successfully
		self.order_logs ||= []
		self.order_logs << OrderLog.new(:log_time => Time.now.to_i, :description => "scheduled scheduled_successfully")
	end

	def changed_order_time
		self.order_logs ||= []
		self.order_logs << OrderLog.new(:log_time => Time.now.to_i, :order_start_time => self.order_start_time, :description => "changed order time")
	end

	def submitted_for_scheduling
		self.order_logs ||= []
		self.order_logs << OrderLog.new(:log_time => Time.now.to_i, :description => "submitted for scheduling")
	end

	def added_reports
		self.order_logs ||= []
		self.order_logs << OrderLog.new(:log_time => Time.now.to_i, :report_ids => self.report_ids_to_add, :description => "added reports")
	end

	def removed_reports
		self.order_logs ||= []
		self.order_logs << OrderLog.new(:log_time => Time.now.to_i, :report_ids => self.report_ids_to_remove, :description => "removed reports")
	end

	def submitted_to_update_barcodes
		self.order_logs ||= []
		self.order_logs << OrderLog.new(:log_time => Time.now.to_i, :description => "submitted to update barcodes")
	end

	def barcodes_updated_successfully
		self.order_logs ||= []
		self.order_logs << OrderLog.new(:log_time => Time.now.to_i, :description => "barcodes updated successfully")
	end

	def barcodes_update_failed
		self.order_logs ||= []
		self.order_logs << OrderLog.new(:log_time => Time.now.to_i, :description => "barcodes update failed")
	end
	###########################################################
	##
	##
	## SCHEDULE
	##
	##
	###########################################################
	def schedule
		
		#Elasticsearch::Persistence.client.indices.refresh index: "pathofast-minutes"
		## refresh the minutes index.


		## something like scheduled for reports a,b,c
		## could not schedule, with start time.
		## could not schedule, with start time.
		## so that's how it works.
		## what if its remove.
		## you can neither add nor remove, if the schedule action is there, basically you cant do anything.
		## other than changing the start time.
		## also if its add barcodes
		## you can't do anything else.


		if self.schedule_action == "add"

			#self.report_ids_to_add = []
			#puts "the report ids to add are:"
			#puts self.report_ids_to_add.to_s

			statuses_and_reports = Status.get_statuses_for_report_ids(self.report_ids_to_add)

			reports_to_statuses_hash = statuses_and_reports[:reports_to_statuses_hash]

			statuses_to_reports_hash = statuses_and_reports[:statuses_to_reports_hash]

			status_arr = []

			prev_from = nil
				
			prev_to = nil

			prev_duration = nil

			args = {:required_statuses => []}
			statuses_to_reports_hash.keys.each_with_index {|status,key|
					
				puts "prev from is: #{prev_from}"
				puts "prev to is: #{prev_to}"

				status_details = {}

				status_details[:id] = status
				status_details[:maximum_capacity] = statuses_to_reports_hash[status][:maximum_capacity]
				status_details[:duration] = statuses_to_reports_hash[status][:duration]

				## ill split that out into a concern.

				if key == 0
					status_details[:from] = (self.start_time.to_i/60)
					status_details[:to] = status_details[:from] + DEFAULT_INTERVAL
				else
					status_details[:from] = prev_from + prev_duration
					status_details[:to] = prev_to + prev_duration
				end

				puts "the status details from and to are:"
				puts "status: #{status}"
				puts status_details.to_s
				prev_from = status_details[:from]
				prev_to = status_details[:to]
				prev_duration = status_details[:duration]
				
				puts "prev from and to becomes: #{prev_from}, and #{prev_to}"

				args[:required_statuses] << status_details

				
			}

			args[:order_id] = self.id.to_s

			puts "teh required status args are:"
			puts JSON.pretty_generate(args)

			minute_slots = Minute.get_minute_slots(args)
			#puts "the minute slots are:"
			#puts JSON.pretty_generate(minute_slots)

			## the required statuses is passed to the build_minute_request to be handled thereof.
			#Minute.build_minute_update_request_for_order(minute_slots,self,args)

			## so what should happen at the end of all this.

		else


		end

	end

=end

end