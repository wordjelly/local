module Concerns::Schedule::OrderConcern
  	extend ActiveSupport::Concern

  	included do

  	end

  	module ClassMethods

  		def employee_agg(s)
			employee_agg = {
				employee_id: {
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
											"employees.bookings.status_id".to_sym => s[:id]
										}
									},
									aggs: {
										booking_priority: {
											terms: {
												field: "employees.bookings.priority",
												order: {"_key".to_sym => "asc"}
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

		def with_order_aggregation(aggs,status,order)
			aggs[status.id.to_s][:with_order_filter] = 
				{
					nested: {
						path: "employees"
					},
					aggs: {
						with_order_filter_bookings: {
							nested: {
								path: "employees.bookings"
							},
							aggs: {
								order_filter: {
									filter: {
										term: {
											"employees.bookings.order_id".to_sym => order.id.to_s
										}
									},
									aggs: {
										minutes: {
											reverse_nested: {},
											aggs: {
												minute: {
													terms: {
														field: "number",
														size: status.to - status.from,
														include: (status.from.to_i..status.to.to_i).to_a
													},
													aggs: {
														employees: {
															nested: {
																path: "employees"
															},
															aggs: employee_agg(statuse)
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

		def without_order_aggregation(aggs,status,order)

			aggs[status.id.to_s][:without_order_filter] = 
				{
					nested: {
						path: "employees"
					},
					aggs: {
						without_order_filter_bookings: {
							nested: {
								path: "employees.bookings"
							},
							aggs: {
								order_filter: {
									filter: {
										not: {
											filter: {
												term: {
													"employees.bookings.order_id".to_sym => order.id.to_s
												}
											}
										}
									},
									aggs: {
										minutes: {
											reverse_nested: {},
											aggs: {
												minute: {
													terms: {
														field: "number",
														size: status.to - status.from,
														include: (status.from.to_i..status.to.to_i).to_a
													},
													aggs: {
														employees: {
															nested: {
																path: "employees"
															},
															aggs: employee_agg(statuse)
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
					with_order_aggregation(aggregation,status,order)
					without_order_aggregation(aggregation,status,order)
				end
			end


			puts "the query is: "
			puts JSON.pretty_generate(query)

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
					
					puts JSON.pretty_generate(search_result.response.aggregations.send(status_id))
					
					#search_result.response.aggregations.send(status_id).buckets.each do |bucket|
						


					#end
				
				end
			end
			

			exit(1)

		end

	end
end