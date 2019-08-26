class SearchController < ApplicationController
	
	include Concerns::BaseControllerConcern

	def permissions_clauses(index_name)

		should_clauses = [
			{
				term: {
					public: Concerns::OwnersConcern::IS_PUBLIC
				}
			}
		]

		if current_user
			
			if current_user.has_organization?
				## first get the users organization.
				user_organization = 
				Organization.find(current_user.organization.id.to_s)
				verified_users = user_organization.user_ids
				
				should_clauses << {
					ids: {
						values: verified_users + [current_user.id.to_s]
					}
				}

				should_clauses << {
					terms: {
						owner_ids: current_user.organization.all_organizations
					}
				}
				
			end
			
		
			should_clauses << {
				term: {
					owner_ids: current_user.id.to_s
				}
			}
			

			
		end

		should_clauses


	end

	def build_query

		should_clauses = permissions_clauses(nil)

		query = {
			size: 100,
			query:  {
				bool: {
					must: [
						{

							multi_match: {
								query: params[:query],
								fields: ["search_all"]
							}
						},
						{
							bool: {
								minimum_should_match: 1,
								should: should_clauses
							}
						}
					]
				}
			}
		}

		puts "making query"
		puts JSON.pretty_generate(query)

		query

	end

	def search

		@type = params[:type]

		## you can directly pass the name of the 
		@index_name = params[:index_name] || "pathofast-#{@type}"

		response = Elasticsearch::Persistence.client.search index: "pathofast*", body: build_query
		mash = Hashie::Mash.new response 
		@search_results = mash.hits.hits.map{|c|
			puts "the search result is:"
			puts c["_source"]
			puts c["_type"]
			c = c["_type"].underscore.classify.constantize.new(c["_source"].to_h.merge(:id => c["_id"]))
			c.run_callbacks(:find) do 
				c.apply_current_user(current_user) if c.respond_to? :apply_current_user
			end
			c
		}
		respond_to do |format|
			format.js do 
				render "search"
			end
			format.json do 
				render :json => {search_results: @search_results}
			end
		end

	end

	def type_selector
			
		 
		@type = params[:type]

		## you can directly pass the name of the 
		@index_name = params[:index_name] || "pathofast-#{@type}"
			
		## now does the user have a name.	
		## so just make sure it is there in search all
		## and you can get the users.
		## of the current organization.
		## go for user.
		## so the organization that was sent in, should be there as 
		## verified in the organizationmembers.
		
		response = Elasticsearch::Persistence.client.search index: @index_name, body: build_query
		mash = Hashie::Mash.new response 
		#puts "the total hits are:"
		#puts mash.hits.hits.size.to_s
		@search_results = mash.hits.hits.map{|c|
			c = c["_type"].underscore.classify.constantize.new(c["_source"].to_h.merge(:id => c["_id"]))
			c.run_callbacks(:find) do
				if c.respond_to? :apply_current_user 
					c.apply_current_user(current_user)
				end
			end
			c
		}
		respond_to do |format|
			format.js do 
				render "type_selector"
			end
			format.json do 
				render :json => {search_results: @search_results}
			end
		end

	end


end