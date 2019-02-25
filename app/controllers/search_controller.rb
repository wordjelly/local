class SearchController < ApplicationController
	
	respond_to :html, :json, :js

	def build_query
		{
			size: 10,
			query:  {
				multi_match: {
					query: params[:query],
					fields: []
				}
			}
		}
	end

	def search
		response = Elasticsearch::Persistence.client.search index: "pathofast-*", body: build_query
		mash = Hashie::Mash.new response 
		@search_results = mash.hits.hits.map{|c|
			c = c["_type"].capitalize.constantize.new(c["_source"].merge(:id => c["_id"]))
			c
		}
	end

	def type_selector
		
		@type = params[:type]
		puts "autocomplete type is: #{@type}"
		response = Elasticsearch::Persistence.client.search index: "pathofast-#{@type}", body: build_query
		mash = Hashie::Mash.new response 
		@search_results = mash.hits.hits.map{|c|
			c = c["_type"].camelize.constantize.new(c["_source"].merge(:id => c["_id"]))
			c
		}
		puts @search_results.to_s
		puts @search_results.size.to_s

	end


end