module Concerns::OrderConcern

	extend ActiveSupport::Concern

	included do 
			
		attribute :name, String, mapping: {type: 'keyword'}

		attribute :reports, Array[Diagnostics::Report]

		attribute :patient_id, String, mapping: {type: 'keyword'}

		attribute :categories, Array[Inventory::Category] 

		attribute :payments, Array[Business::Payment]

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
			document.update_report_items
		end

	end

	def assign_id_from_name
		self.name = BSON::ObjectId.new.to_s
		self.id = self.name
	end

	## first reset all the required quantitis.
	def reset_category_quantities
		self.categories.map {|cat|
			cat.quantity = 0	
		}
	end

	def has_category?(name)
		self.categories.select{|c|
			c.name == name
		}.size > 0
	end

	## can we show all the sectors if required ?
	## we can get it from where ?
	## information will have to be created for each sector also.

	def update_requirements
		reset_category_quantities
		self.reports.map{|report|
			report.requirements.each do |req|
				options = req.categories.size
				req.categories.each do |category|
					puts "looking for category: #{category.name}"
					if !has_category?(category.name)
						category_to_add = Inventory::Category.new(quantity: category.quantity, required_for_reports: [], optional_for_reports: [], name: category.name)
						if options > 1
							category_to_add.optional_for_reports << report.id.to_s
						else
							category_to_add.required_for_reports << report.id.to_s
						end
						self.categories << category_to_add
					else
						self.categories.each do |existing_category|
							if existing_category.name == category.name
								
								existing_category.quantity += category.quantity

								if options > 1
									existing_category.optional_for_reports << report.id.to_s
								else
									existing_category.required_for_reports << report.id.to_s
								end

								existing_category.optional_for_reports.flatten!

								existing_category.required_for_reports.flatten!

							end
						end
					end
				end
			end
		}		
	end

	def update_report_items
		self.reports.map{|c|
			c.clear_all_items
		}
		self.categories.each do |category|
			category.items.each do |item|
				self.reports.each do |report|
					report.add_item(category,item)
				end
			end
		end
	end

	module ClassMethods

		def permitted_params
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