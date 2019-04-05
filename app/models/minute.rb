require 'elasticsearch/persistence/model'
class Minute
	include Elasticsearch::Persistence::Model
	include Concerns::EsBulkIndexConcern
	
	index_name "pathofast-minutes"

	attribute :date, Date
	attribute :working, Integer, :default => 1
	attribute :number, Integer
	attribute :employees, Array[Hash]


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
		mapping do
			indexes :employees, type: 'nested', 
				properties: {
					employee_id: {
						type: "keyword"
					},
					status_ids: {
						type: "keyword"
					},
					bookings: {
						type: "nested",
						properties: {
							status_id: {
								type: 'keyword'
							},
							count: {
								type: 'integer'
							},
							priority: {
								type: 'float'
							},
							order_id: {
								type: 'keyword'
							},
							report_ids: {
								type: 'keyword'
							},
							max_delay: {
								type: 'keyword'
							}
						}
					}
				}
	    end
	end

	## so the script will check the existing bookings.
	## these we already have to have.
	## we do it one day at a time.
	## it gets assigned to multiple people.
	## do we aggregate?
	## the time can be very large
	## we want the bookings of this person
	## it could also happen for a routine.
	## we can't reassing it to everyone.
	## i mean so we iterate
	## we come to that employee
	## we take the status ids, already booked
	## or we can do it in bunches.
	## of 100 minutes
	## aggregate existing bookings of this employee
	## group by minute
	## same minute get the least occupied employee
	## and in the update script, reassoign to them.
	## both possibilities can be done.

	def self.bulk_size
		100
	end

	def self.create_test_minutes(number_of_minutes)
		status_ids = []    	
    	100.times do |status|
    		status_ids << status
    	end
		number_of_minutes.times do |minute|
			m = Minute.new(number: minute, working: 1, employees: [], id: minute.to_s)
			6.times do |employee|
				e = Employee.new(id: employee.to_s, status_ids: status_ids)
				[0,1,2,3,4].sample.times do |booking|
					b = Booking.new
					b.status_id = status_ids.sample
					b.count = 2
					b.priority = booking
					b.order_id = "o#{booking}"
					b.report_ids = ["r#{booking}"]
					b.max_delay = 10*booking
					e.bookings << b		
				end
				m.employees << e
			end
			Minute.add_bulk_item(m)
		end
		Minute.flush_bulk
	end
	
	def self.create_test_days
		status_ids = []    	
    	100.times do |status|
    		status_ids << status
    	end
    	days = []
    	minute_count = 0
    	100.times do |day|
    		d = Day.new(id: "day_" + day.to_s)
    		d.date = Time.now + day.days
    		d.working = 1
    		d.minutes = []
    		720.times do |minute|
    			m = Minute.new(number: minute_count, working: 1, employees: [], id: minute_count.to_s)
    			6.times do |employee|
    				e = Employee.new(id: employee.to_s, status_ids: status_ids, booked_status_id: -1, booked_count: 0)
    				m.employees << e
    			end
    			minute_count+=1
    			Minute.add_bulk_item(m)
    		end
    	end
    	Minute.flush_bulk
	end	

	def aggregate_employee_bookings(employee_id,minute_from,minute_to)

		Minute.search({
			query: {
				nested: {
					path: "employees",
					query: {
						bool: {
							must: [
								{
									term: {
										"employees.employee_id".to_sym => employee_id
									}
								},
								{
									exists: {
										field: "employees.bookings"
									}
								}
							]
						}
					}
				}
			},
			aggs: {
				
			}
		})

	end

	## @param[String] date : block and reallot from
	## @param[String] date : block and reallot to
	## @param[String] employee_id : the employee to be blocked
	## @param[Array] status_ids : defaults to an empty array, which means all statuses.
	def self.block_and_reallot_bookings(from,to,employee_id,status_ids=[])

		## first i have to randomly create this.


	end


	## @param[String] date : block and reallot from
	## @param[String] date : block and reallot to
	## @param[String] employee_id : the employee to be blocked
	## @param[Array] status_ids : defaults to an empty array, which means all statuses.
	def self.block_status(from,to,status_id,employee_ids=[])

	end

	## @param[Array] required_statuses: 
	## some status may be such that it can only be done at a 
	## particular time.
	## for eg: microbiology reporting -> maybe only on a certain
	## time of a day
	## or on a certain day.
	## also statuses have to have a capacity.
	## 
	def self.get_minute_slots(args)
		
		queries = args[:required_statuses].map{|c|
			query_template = {
				bool: {
					must: [
						{
							range: {
								number: {
									gte: c[:from],
									lte: c[:to]
								}
							}
						},
						{
							bool: {
								should: [
									nested: {
										path: "employees",
										query: {
											bool: {
												should: [
													{
														bool: {
															must: [
																{
																	term: {
																		"employees.status_id".to_sym => c[:status_id]
																	}
																},
																{
																	term: {
																		"employees.booked_count".to_sym => -1
																	}
																}
															]
														}
													},
													{
														bool: {
															must: {
																term: {
																	"employees.booked_status_id".to_sym => c[:status_id]
																}
															},
															must: {
																range: {
																	"employee.booked_count".to_sym => {
																		lte: c[:maximum_capacity] 
																	}
																}
															}
														}
													}
												]
											}
										}
									}
								]
							}
						}
					]
				}
			}
			query_template
		}

		## so we have a day
		## we can assign employees to certain statuses for certain slots
		## automatically or in rotation.
		## problem is what if its not there in that range
		## for any employee a particular status?
		## then you widen the range there, and redo the fucking query
		## so we have this query and aggs
		## so what has to be added ui side ?
		## better go employee and status.
		## first the status.
		## we want to allot a status
		## keep it simple for the moment.
		## which statuses can an employee do ->
		## choose the status names.
		## over which timeframe ?
		## choose the timeframe
		## or we can have a particular status divided over 
		## all employees over a timeframe.
		## that also we can do.
		## so let's make this screen on the status creation
		## that will be the best option.
		## so there i can instead choose the employee who can do that status
		## and then i can modulate it via the minutes ui, to block an employee from certain things.
		## but for eg we want one employee on the roche for 2 hours
		## and no one else.
		## so lets say you give an option -> divide equally.
		## in that case, you ahve to give a slot option.
		## what will be the slot duration.
		## otherwise, all workers can do, and then everyone is registered for every minute.
		## routines are basically sets of statuses
		## like reports
		## we can schedule routines periodically
		## in that case, the individual statuses have to also be scheduled.
		## for eg : routine weekly maintainance of roche e411
		## so lets add this module to the status.
		## so this will actually be updating minute.
		## so first minutes.
		## minute UI.
		## then status UI.
		## first atust.

		query_and_aggs = 
			{
				query: queries,
			  	aggs: {
			    	required_status: {
			      		nested: {
			        	path: "employees"
			      	},
			      	aggs: {
			        	status_id: {
				          		terms: {
				            		field: "employees.status_ids",
				            		size: 10,
				            		include: "2"
				          		},
				          		aggs: {
				            		minute: {
				              			reverse_nested: {},
				              			aggs: {
				                			minute_id: {
				                  				terms: {
				                    				field: "number",
				                    				size: 10
				                  				},
				                  				aggs: {
					                    			employees: {
						                      			nested: {
						                        			path: "employees"
						                      			},
						                      			aggs: {
						                        			emp_id: {
						                          				terms: {
						                            				field: "employees.id",
						                            				size: 10,
						                            				order: {
						                              					booked_count: "asc"
						                            				}
						                         				},
						                          				aggs: {
						                            				booked_count: {
							                              				min: {
							                                				field: "employees.booked_count"
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
	end

	#######################################################
	##
	##
	## we have a from and a to,
	## we have to convert it to an array of applicable minute
	## ids.
	## as long as that is in the open hours.
	## we go one minute at a time.
	##
	##
	#######################################################
	## we can define what is closed here.
	## for the moment it will check if hours of day of that day, are greater than 8.30 pm, or less than 8 am, then we 
	def self.is_closed?(time_obj)
		((time_obj.hour > 20) || (time_obj.hour < 8))
	end

	## @param[String] from : date
	## @param[String] to : date
	## @return[Array] minute_ids : array of strings each is basicaslly an integer, that represents the id of a minute object.
	def self.get_minutes_ids(from,to)
		minute_ids = []
		from_date = Time.new(from)
		to_date = Time.new(to)
		from_epoch = from_date.to_i
		to_epoch = to_date.to_i
		while(from_epoch < to_epoch)
			t = Time.at(from_epoch)
			unless is_closed?(t)
				minute_ids << (from_epoch/60).to_s
			end
			from_epoch+=60
		end
		minute_ids
	end

	## @param[String] id: valid id of a minute document to be updated
	## @param[Hash] params: MUST CONTAIN:
	## :employee_ids => array of valid employee ids.
	## :status_id => the id of the status that we are updating this minute with.
	## @return[Hash] : bulk update request hash. 
	def self.update_minute(id,params)

		update_request = {
			script: {
				lang: "painless",
				inline: '''
					for(employee_id in params.employee_ids){
				        def employee_found = 0;
				        for(employee in ctx._source.employees){
				            if(employee["id"] == employee_id){
				              employee_found = 1;
				              if(!employee["status_ids"].contains(params.status_id)){
				              	employee["status_ids"].add(params.status_id)
				              }
				            }
				        }
				        if(employee_found == 0){
				          Map obj = new HashMap();
				          obj.put("status_ids",[params.status_id]);
				          obj.put("id",employee_id);
				          obj.put("booked_status_id",-1);
				          obj.put("booked_count",0);
				          ctx._source.employees.add(obj);
				        }
				      }
				''',
				params: {
					employee_ids: params[:employee_ids],
					status_id: params[:status_id]
				}		
			}
		}

		{
			update: {
				_index: index_name, _type: document_type, _id: id, data: update_request
			}
		}


	end

end