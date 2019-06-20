module Concerns::OrderConcern

	extend ActiveSupport::Concern

	included do 
			
		attribute :name, String, mapping: {type: 'keyword'}

		attribute :reports, Array[Hash]

		attribute :patient_id, String, mapping: {type: 'keyword'}

		attribute :categories, Array[Hash] 

		attribute :payments, Array[Hash]

		attribute :local_item_group_id

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
			    
		    	indexes :name, type: 'keyword', fields: {
			      	:raw => {
			      		:type => "text",
			      		:analyzer => "nGram_analyzer",
			      		:search_analyzer => "whitespace_analyzer"
			      	}
			    }

			   	indexes :categories, type: 'nested', properties: Inventory::Category.index_properties
			   	indexes :reports, type: 'nested', properties: Diagnostics::Report.index_properties

			end

		end


		before_save do |document|
			document.update_requirements
		end

	end

	def assign_id_from_name
		self.name = BSON::ObjectId.new.to_s
		self.id = self.name
	end

	## first reset all the required quantitis.
	def reset_category_quantities
		self.categories_hash.keys.each do |cat|
			self.categories_hash[cat].quantity = 0
		end
	end

	def update_requirements
		reset_category_quantities
		self.reports.map{|report|
			report.requirements.each do |req|
				options = req.categories.size
				req.categories.each do |category|
					if self.categories_hash[category.name].blank?

						category_to_add = Inventory::Category.new(quantity: category.quantity, required_for_reports: [], optional_for_reports: [])
						if options.size > 1
							optional_for_reports << report.id.to_s
						else
							required_for_reports << report.id.to_s
						end

						self.categories_hash[category.name] = category_to_add
					else

						self.categories_hash[category.name].quantity+= category.quantity

						if options.size > 1
							optional_for_reports << report.id.to_s
						else
							required_for_reports << report.id.to_s
						end					 
						
					end
				end
			end
		}
		
	end

	module ClassMethods

		def self.permitted_params
			base = [
					:id,
					{:order => 
						[
							:patient_id,
							:local_item_group_id,
							{
								:categories => Inventory::Category.permitted_params
							},
					    	{
					    		:payments => Business::Payment.permitted_params
					    	},
					    	{
					    		:reports => Diagnostics::Report.permitted_params[1][:report]
					    	}
						]
					}
				]
			if defined? @permitted_params
				base[1][:order] << @permitted_params
				base[1][:order].flatten!
			end
			base
		end
		
	end

end