module Concerns::Schedule::OrderConcern
  	extend ActiveSupport::Concern

  	included do

  	end

  	module ClassMethods

  		def employee_agg(s,order,aggregation)
  			aggregation[s.id.to_s] = 
			{
				nested: {
					path: "employees"
				},
				aggs: {
					employee_agg: {
						##########
						terms: {
							field: "employees.employee_id",
							size: 1,
							order: {workload: "asc"}
						},
						aggs: {
							workload: {
								min: {
									field: "employees.bookings_score"
								}
							},
							status_bookings: {
								nested: {
									path: "employees.bookings"
								},
								aggs: {
									this_status: {
										filter: {
											term: {
												"employees.bookings.status_id".to_sym => s.id.to_s
											}
										},
										aggs: {
											booking_priority: {
												filter: {
													range: {
														"employees.bookings.count".to_sym => {
															"lte" => s.maximum_capacity 
														}
													}
												},
												aggs: {
													with_order: {
														filters: {
															other_bucket_key: "other_orders", 
															filters: {
																this_order: {
																	term: {
																		"employees.bookings.order_id".to_sym => order.id.to_s
																	}
																}
															}
														},
														aggs: {
															## add an aggregation to 
															## go back to the minute
															## and then inside the minute
															## the booking id is what we need.
															## and inside that the order id.
															## then sort the employee, by 
															## the min of the minutes term agg.
															## using seperator and dot.
														}
													}
												}
											}
										}
									}
								}
							}
						}

						##########
					}
				}
			}
		end
  		
		def add_status_to_query(query,status)
			query[:bool][:should] << 
				{
					bool: {
						must: [
							{
								range: {
									number: {
										gte: (status.from - 480),
										lte: (status.to + 480)
									}
								}
							},
							{
								bool: {
									must: [
										nested: {
											path: "employees",
											query: {
												bool: {
													must: [
														{range: {"employees.bookings_score".to_sym => {lte: 10}}},
														{
															term: {
																"employees.status_ids".to_sym => status.id.to_s
															}
														},
														{
															bool: {
																minimum_should_match: 1,
																should: [
																	{
																		bool: {must_not: {exists: {field: "employees.bookings"}}}
																	},
																	{   
																		nested: {
																		path: "employees.bookings",
																		query: {
																			bool: {
																				minimum_should_match: 1,
																				should: [

																					{
																						bool: {
																							must: [
																								{
																									range: {
																										"employees.bookings.count".to_sym => 
																										{
																											lte: status.maximum_capacity
																										}
																									}
																								},
																								{
																									term: {
																										"employees.bookings.status_id".to_sym => status.id.to_s
																									}
																								}
																							]
																						}
																					},
																					{
																						bool: {
																							must_not: [
																								{
																									term: {
																										"employees.bookings.status_id".to_sym => status.id.to_s
																									}
																								}
																							]
																						}
																					}
																				]
																			}
																		}
																		}
																	}
																]
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
		end

		def schedule_order(order)

			query = {
				bool: {
					should: [
					]
				}
			}

			aggregation = {
				
			}

			order.procedure_versions_hash.keys.each do |pr|
				order.procedure_versions_hash[pr][:statuses].each do |status|
					add_status_to_query(query,status)
					aggregation[status.id.to_s] = {}
					employee_agg(status,order,aggregation)
					#with_order_aggregation(aggregation,status,order)
				end
			end

			#puts "the query is: "
			#puts JSON.pretty_generate(query)

			puts "the aggregation is"
			puts JSON.pretty_generate(aggregation)

			search_result = Schedule::Minute.search({
				query: query,
				aggs:  aggregation
			})

			#puts search_result.response.aggregations.to_s

			order.procedure_versions_hash.keys.each do |pr|
				order.procedure_versions_hash[pr][:statuses].each do |status|
					
					status_id = status.id.to_s
						
					## the status id is: 

					## what do we want ?
					## is there anything in the order filter ?
					## if yes, take that, if not then take the rest
					## we can have one where it is missing.
					## one where.
					puts "status id is: #{status_id}"
					status_aggs = search_result.response.aggregations.send(status_id)
					puts JSON.pretty_generate(status_aggs)
					#this_order = status_aggs[:with_order_filter_bookings]
					#puts JSON.pretty_generate(this_order)
					#other_orders = status_aggs[:other_order_filter_bookings]
					#puts JSON.pretty_generate(other_orders)
					#no_bookings = status_aggs[:no_bookings]
					#puts JSON.pretty_generate(no_bookings)
					exit(1)
					## get minute and employee
					## in minute get employee
					## in employee get the booking
					## we want the indexes of all this ?
					## get minute id, get employee id, get bookoing id.
				end
			end
		end
	end
end