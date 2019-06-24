module Concerns::Schedule::OrderConcern
  	extend ActiveSupport::Concern

  	included do

  	end

  	module ClassMethods

  		
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

		def add_status_to_aggregation(aggs,status,order)
				aggs[status.id.to_s] = {
					terms: {
						field: "number",
						size: status.to - status.from,
						include: (status.from.to_i..status.to.to_i).to_a
					},
					aggs: {
						with_order_filter: {
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
												employees: {
													reverse_nested: {
														path: "employees"
													},
													aggs: employee_agg(status)
												}
											}
										}
									}
								}
							}
						},
						without_order_filter: {
							nested: {
								path: "employees"
							},
							aggs: employee_agg(status)
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
					add_status_to_aggregation(aggregation,status,order)
				end
			end


			puts "the query is: "
			puts JSON.pretty_generate(query)

			puts "the aggregation is"
			puts JSON.pretty_generate(aggregation)

		end

	end
end