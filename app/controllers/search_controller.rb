class SearchController < ApplicationController
	
	include Concerns::BaseControllerConcern

	def build_query

		should_clauses = [
			{
				term: {
					public: Concerns::OwnersConcern::IS_PUBLIC
				}
			}
		]

		if current_user
			## it has a verified / owns or belongs to an organization
			should_clauses << {
				term: {
					owner_ids: current_user.id.to_s
				}
			}
			
			if current_user.belongs_to_organization?
				should_clauses << {
					term: {
						owner_ids: current_user.organization_id
					}
				}
			end

		end

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
		response = Elasticsearch::Persistence.client.search index: "pathofast-*", body: build_query
		mash = Hashie::Mash.new response 
		@search_results = mash.hits.hits.map{|c|
			puts "the search result is:"
			puts c["_source"]
			puts c["_type"]
			c = c["_type"].underscore.classify.constantize.new(c["_source"].merge(:id => c["_id"]))
			c
		}
	end

	def type_selector
			
		## but the current user has to be used
		## and this has to be exposed to json also
		## 
		@type = params[:type]
		puts "autocomplete type is: #{@type}"
		response = Elasticsearch::Persistence.client.search index: "pathofast-#{@type}", body: build_query
		mash = Hashie::Mash.new response 
		@search_results = mash.hits.hits.map{|c|
			c = c["_type"].underscore.classify.constantize.new(c["_source"].merge(:id => c["_id"]))
			c
		}
		puts @search_results.to_s
		puts @search_results.size.to_s

	end


end