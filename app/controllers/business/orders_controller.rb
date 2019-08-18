class Business::OrdersController < ApplicationController
	include Concerns::BaseControllerConcern
	def add_authorization_clause(query)
		#so if you own any report you are clear to continue.
		#now what about the payments.
		#payments are not allowed.
		#
		#puts "is there a current user?"
		#puts current_user.to_s
		#puts "the query currently is:"
		#puts JSON.pretty_generate(query)
		if current_user
			## check if the current user's id has been mntioned in the owner_ids of the resource.
			query[:bool][:must][1][:bool][:should] <<
			{		
				term: {
					owner_ids: current_user.id.to_s
				}	
			}

			## if he owns any of the reports.
			query[:bool][:must][1][:bool][:should] << {
				nested: {
					path: "reports",
					query: {
						term: {
							owner_ids: current_user.id.to_s
						}
					}
				}
			}


			unless current_user.organization.blank?
				#if current_user.verified_as_belonging_to_organization.blank?
				#	puts "user is not verified as belonging to the given organization, so we cannot use its organization id to check for ownership"
					##not_found("user has not been verified as belonging to his claimed organization id , and this needs authorization #{controller_name}##{action_name}")
				#else
				query[:bool][:must][1][:bool][:should] << {terms: {owner_ids: current_user.organization.all_organizations }}
				#end 
				query[:bool][:must][1][:bool][:should] << {
					nested: {
						path: "reports",
						query: {
							terms: {
								owner_ids: current_user.organization.all_organizations
							}
						}
					}
				}

			else
				puts "the user does not have an organization id, so we cannot check for ownership using it."
				#not_found("user does not have an organization_id, and authorization is necessary for this #{controller_name}##{action_name}")
			end
		else
			not_found("no current user, authorization is necessary for this #{controller_name}##{action_name}")
		end

		query
	end
end
