require 'elasticsearch/persistence/model'
class Order

	include Elasticsearch::Persistence::Model
	include Concerns::StatusConcern
	include Concerns::PdfConcern
	
	index_name "pathofast-orders"

	attr_accessor :patient_name

	attr_accessor :account_statement



	attribute :patient_id, String

	attribute :patient_test_ids, Array

	attribute :patient_report_ids, Array



	attribute :template_report_ids, Array

	attribute :tubes, Hash


	attr_accessor :patient
	attr_accessor :reports
	## adding or removing an item group.
	## if you want to ad items by means of an item group
	attr_accessor :item_group_id
	attr_accessor :item_group_action

	
		
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
		    indexes :tubes, type: 'nested', properties: {
		    	item_requirement_name: {
		    		type: 'keyword'
		    	},
		    	patient_report_ids: {
		    		type: 'keyword'
		    	},
		    	item_requirement_volumes: {
		    		type: 'float'
		    	},
		    	remaining_volume: {
		    		type: 'float'
		    	},
		    	template_report_ids: {
		    		type: 'keyword'
		    	},
		    	barcode: {
		    		type: 'keyword'
		    	}
		    }
		end

	end

	validates_presence_of :patient_id	

	
	before_save do |document|
		document.update_tubes
	end

	def existing_template_report_ids
		self.tubes ||= []
		self.tubes.map{|c|
			c[:template_report_ids]
		}.flatten.uniq
	end

	def update_tubes
		## first delete the reports that have been removed.
		(existing_template_report_ids - self.template_report_ids).each do |template_report_id_to_remove|
			self.tubes.map{|c|
				if arrind = c[:template_report_ids].index(template_report_id_to_remove)
					patient_report = Report.find(c[:patient_report_ids][arrind])
					if patient_report.can_be_cancelled?
						c[:template_report_ids].delete_at(arrind)
						c[:patient_report_ids].delete_at(arrind)
						c[:remaining_volume]+= c[:item_requirement_volumes].delete_at(arrind)
					else
						## so we add it back to the current template report ids, because that patient report can no longer be cancelled.
						self.template_report_ids << template_report_id_to_remove
					end
				end
			}
		end

		report_ids_to_add = self.template_report_ids - existing_template_report_ids

		## now we aggregate item requirements.
		ItemRequirement.search({
			query: {
				bool: {
					filter: {
						nested: {
							path: "definitions",
							query: {
								terms: {
									"definitions.report_id".to_sym => report_ids_To_add
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
					item_requirements: {
						terms: {
							field: "name",
							size: 100
						}

					}
				}
			}
		})
		## now add the newer reports.
		## for this how do we proceed.
		## now we minus from the second the first, and work on those
		## with the aggregations
		## this is pretty easy.
		## we also have to figure out a way to add the barcode, but since these are nested, that will be very simple in a tabular format.
		## same for the item group.
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

	def load_reports
		self.reports ||= []
		self.patient_report_ids.each do |patient_report_id|
			report = Report.find(patient_report_id)
			report.load_tests
			report.load_item_requirements
			self.reports << report
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