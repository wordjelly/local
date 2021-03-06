require 'elasticsearch/persistence/model'
class Diagnostics::Report

	include Elasticsearch::Persistence::Model
	include ActiveModel::Serialization
	include ActiveModel::Validations
  	include ActiveModel::Validations::Callbacks
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern
	include Concerns::FormConcern
	include Concerns::SearchOptionsConcern
	include Concerns::Diagmodule::Report::OutsourceConcern
	include Concerns::CallbacksConcern

	## ready for reporting ?
	## we can add a method.

	index_name "pathofast-diagnostics-reports"
	document_type "diagnostics/report"

	YES = 1

	NO = -1
	
	VERIFY_ALL = YES

	TOP_UP_TEMPLATE_FILE_NAME = "top_up_template.json"

	## OBJECT ARRAYS
	attribute :tests, Array[Diagnostics::Test]
	attribute :statuses, Array[Diagnostics::Status]

	attribute :requirements, Array[Inventory::Requirement]
	attribute :rates, Array[Business::Rate]
	
	## SCALARS 
	attribute :name, String, mapping: {type: 'keyword'}
	attribute :description, String, mapping: {type: 'keyword'}
	attribute :patient_id, String, mapping: {type: 'keyword'}
	attribute :tag_ids, Array, mapping: {type: "keyword"}, default: []

	## 1 -> request rerun
	## you have to enter a comment in the range
	## 
	## -1 -> (default) don't.
	attribute :request_rerun, Integer, mapping: {type: 'integer'}, default: NO
	## calculated before_save in the set_procedure_version function
	attribute :procedure_version, String, mapping: {type: "keyword"}
	attribute :start_epoch, Integer, mapping: {type: 'integer'}
	## WE SET a
	## AND THEN THE FIRST ACTION TO CHECK IS 
	## parse normal ranges.

	## doesnt need to be a permitted param, is internally assigned.
	#attribute :order_id, String, mapping: {type: 'keyword'}


	attribute :verify_all, Integer, mapping: {type: 'integer'}, default: YES

	## stat marked, means the report will be released as soon as it is ready, without waiting for other reports in the patient order.
	## it also gets priority.
	## default : -1 -> means its not stat
	## 1 -> means its stat.
	## @used_in : 
	attribute :stat, Integer, mapping: {type: 'integer'}, default: NO
	
	## this is generated before_validation.
	## it is generated from the def order_concern#generate_report_impression
	attribute :impression, String, mapping: {type: 'text'}

	####################################################
	##
	##
	## TOP UP REPORT.
	## if this option is selected
	## then it will load a json file, which contains 
	## the details for the balance report and 
	## make a template out of it.
	## let's do that first.
	## then we go for an order with that report.
	##
	###################################################
	attribute :top_up_template, Integer, mapping: {type: 'integer'}, default: NO

	attribute :outsource_score, Float, mapping: {type: 'float'}, default: 1.0

	attribute :internal_score, Float, mapping: {type: 'float'}, default: 1.0

	####################################################
	##
	##
	## SET AFTER FIND IN THE ORDER CONCERN.
	## GIVES ACCESS TO THE ORDER ORGANIZATION INSIDE THE REPORT
	## 
	##
	####################################################
	attr_accessor :order_organization

	####################################################
	##
	##
	## ACCESSORS : SET AFTER_FIND.
	##
	##
	####################################################
	attr_accessor :report_all_tests_verified
	attr_accessor :report_has_abnormal_tests
	attr_accessor :report_is_outsourced

	## could be the signatories from the primary organization, includes any additional staff signatures. Primary signatories are first filtered to see if they can sign on this report, like a microbiologist can sign on a microbilogy report.
	## set from #order_concern#group_reports_by_organization.
	attr_accessor :final_signatories

	## consider for processing
	## Set in #self.consider_for_processing
	attr_accessor :worth_processing

	## set from order_concern#verify
	attr_accessor :a_test_was_verified

	## report list
	## used from orders.js to get a list of report names that the user can add
	## from organization id -> also will have to be specified.
	## when you click -> it shows you which organization
	## your own, pathofast -> etc
	## so basically then aggregate by organization
	## that's how it should work
	## so this is a bit complicated here.
	## i want to outsource
	## i don't want to outsource
	## if you want to outsource -> shows from other organizations
	## just grouped by name and sorted alphabetically
	## what about some kind of weightage ?
	## the profiles.
	## aggregate by organizaiton.
	## and show it.
	## if he clicks outsource.
	attr_accessor :show_outsourced
	attr_accessor :show_packages
	attr_accessor :reports_list
	attr_accessor :outsourcable_organization_ids


	## @called_from : after_find in Concerns::OrderConcern#after_find
	## sets all the accessors, and these are included in the json
	## representation of this element.
	## @param[Organization] organization:  the organization that has created the order in the first place
	def set_accessors
		self.report_all_tests_verified = self.is_verified?
		self.report_has_abnormal_tests = self.has_abnormal_tests?
		self.report_is_outsourced = self.is_outsourced?
		self.tests.each do |test|
			test.order_organization = self.order_organization
			test.set_accessors
		end
	end

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
		    indexes :name, type: 'keyword', fields: {
		      	:raw => {
		      		:type => "text",
		      		:analyzer => "nGram_analyzer",
		      		:search_analyzer => "whitespace_analyzer"
		      	}
		    },
	   	 	copy_to: "search_all"
		    indexes :patient_id, type: 'keyword'
		    indexes :tag_ids, type: 'keyword'
		    indexes :statuses, type: 'nested', properties: Diagnostics::Status.index_properties
		    indexes :requirements, type: 'nested', properties: Inventory::Requirement.index_properties
		    indexes :rates, type: 'nested', properties: Business::Rate.index_properties
		    indexes :tests, type: 'nested', properties: Diagnostics::Test.index_properties
			indexes :start_epoch, type: 'integer'
			indexes :verify_all, type: 'integer'
			indexes :stat, type: 'integer'
		end
	end
		
	## if it has a created by user.
	## we are not cascading the before validation callbacks
	## why ?
	before_validation do |document|
		document.set_procedure_version
		document.generate_top_up_template if (document.top_up_template == YES)
		document.cascade_id_generation(nil) unless document.created_by_user.blank?
	end


	## lets see if this works or not.
	## 	
	def generate_top_up_template
		templates = JSON.parse(IO.read(Rails.root.join("app","models","diagnostics",TOP_UP_TEMPLATE_FILE_NAME)))
		template = templates["reports"][0].deep_symbolize_keys
		template.assign_attributes(self)
		## so how will we mark these orders.
	end


	## @called_from : #order_concern#update_reports
	def prune_test_ranges(patient)
		self.tests.each do |test|
			test.prune_ranges(patient)
		end
	end

	def fields_not_to_show_in_form_hash(root="*")
		{
			"*" => ["create unless document.created_by_user.blank?d_at","updated_at","public","currently_held_by_organization","created_by_user_id","owner_ids","procedure_version","outsourced_report_statuses","merged_statuses","search_options","pdf_url","latest_version","request_rerun","start_epoch","verify_all","stat","outsource_to_organization_id","outsource_from_status_category","outsource_from_status_id","patient_id","outsource_score"],
			"order" => ["created_at","updated_at","public","currently_held_by_organization","created_by_user_id","owner_ids","procedure_version","outsourced_report_statuses","merged_statuses","search_options","description","patient_id","start_epoch","tag_ids","pdf_url","latest_version","outsource_score","images_allowed","outsource_to_organization_id","outsource_from_status_category","outsource_from_status_id","name","request_rerun","verify_all","stat","top_up_template","internal_score","requirements","statuses"]
		}
	end
	## generates a huge concated string using the reference status version 
	## of each status in the report.
	## then converts that into a base64 string.
	def set_procedure_version
		procedure_version = ''
		self.statuses.map{|c|
			procedure_version+= c.updated_at.to_s
		}
		procedure_version = BSON::ObjectId.new.to_s if procedure_version.blank?
		self.procedure_version = Base64.encode64(procedure_version)
	end


	## called_from: #order_concern: generate_receipts
	## called_from: #order_concern : add_report_values
	## called_from: #order_concern : verify
	## a report can be considered for processing
	def consider_for_processing?(order_history_tags)
		result = true
		#if self.worth_processing.nil?
			#self.worth_processing = true
		puts "came to check worth processing."
		self.requirements.each do |req|
			puts "checking requirement: #{req.name}"
			unless req.satisfied?
				puts "its not satisfied"
				result = false
			end
		end
		self.tests.each do |test|
			unless test.history_provided?(order_history_tags)
				puts "history not provided."
				result = false
			end
		end
		self.worth_processing = result
		result
	end

	def self.permitted_params
		base = [
				:id,
				{:report => 
					[
						:id,
						:patient_id,
						:name, 
						:description,
						:start_epoch,
						:procedure_version,
						:verify_all,
						:stat,
						:request_rerun,
						:outsource_to_organization_id, 
						:outsource_from_status_category, 
						:outsource_from_status_id,
						:currently_held_by_organization,
						:top_up_template,
						:outsource_score,
						:internal_score,
						{:tag_ids => []},
						{
							:requirements => Inventory::Requirement.permitted_params
						},
				    	{
				    		:statuses => Diagnostics::Status.permitted_params
				    	},
				    	{
				    		:rates => Business::Rate.permitted_params
				    	},
				    	{
				    		:tests => Diagnostics::Test.permitted_params
				    	},
				    	:impression,
				    	:show_packages,
				    	:show_outsourced,
				    	:reports_list
					]
				}
			]
		if defined? @permitted_params
			base[1][:report] << @permitted_params
			base[1][:report].flatten!
		end
		base
	end

	def self.index_properties
		{
			:name => {
				:type => 'keyword',
				:fields => {
						:raw => {
			      		:type => "text",
			      		:analyzer => "nGram_analyzer",
			      		:search_analyzer => "whitespace_analyzer"
		      		}
				}
			},
			:patient_id => {
				:type => 'keyword'
			},
			:outsource_to_organization_id => {
				:type => 'keyword'
			},
			:tag_ids => {
				:type => 'keyword'
			},
			:requirements => {
				:type => 'nested',
				:properties => Inventory::Requirement.index_properties
			},
			:statuses => {
				:type => 'nested',
				:properties => Diagnostics::Status.index_properties
			},
			:rates => {
				:type => "nested",
				:properties => Business::Rate.index_properties
			},
			:tests => {
				:type => "nested",
				:properties => Diagnostics::Test.index_properties
			},
			:start_epoch => {
				:type => 'integer'
			},
			:verify_all => {
				:type => 'integer'
			},
			:stat => {
				:type => 'integer'
			},
			:impression => {
				:type => 'keyword'
			},
			:outsource_score => {
				:type => 'float'
			},
			:internal_score => {
				:type => 'score'
			}
		}
	end

	## after this will be the history thing
	## then we are more or less done.
	#############################################################
	##
	## STATUS GROUPING
	##
	##
	#############################################################
	## @used_in: Concerns::Schedule::OrderConcern, to make the blocks.
	## @param[statuses] Array : Diagnostics::Status Objects.
	## @return[Hash]
	## key => duration
	## value => [status_id_one, status_id_two, status_id_three]s
	def self.group_statuses_by_duration(statuses)
		search_request = search({
			query: {
				nested: {
					path: "statuses",
					query: {
						bool: {
							should: statuses.map{|c|
								{
									term: {
										"statuses.id".to_sym => c.id.to_s
									}
								}
							}
						}
					}
				}
			},
			aggs: {
				duration_agg: {
					nested: {
						path: "statuses"
					},
					aggs: {
						status_duration: {
							terms: {
								field: "statuses.duration"
							},
							aggs: {
								status_ids: {
									terms: {
										field: "statuses.id"
									}
								}
							}
						}
					}
				}
			}
		})

		duration_to_statuses = {}
		search_request.response.aggregations.duration_agg.status_duration.buckets.each do |duration_bucket|
			duration = duration_bucket["key"]
			statuses = []
			duration_bucket.status_ids.buckets.each do |status_id_bucket|
				status_id = status_id_bucket["key"]
				statuses << status_id
			end
			duration_to_statuses[duration.to_s] = statuses
		end

		duration_to_statuses

	end	

	## simple table -> Report name -> outsource to:
	## same way -> we can 
	## tubes, reports editing, and payment receipt downloading
	## simplify these three
	## and finish immuno report format checking.
	#############################################################
	##
	##
	## STATUS GROUPING ENDS.
	##
	##
	#############################################################

	## so it clears the items.
	def clear_all_items
		self.requirements.each do |req|
			req.categories.each do |cat|
				cat.items = []
			end
		end
	end

	## item has a remaining quantity.
	def add_item(category,item)
		#puts "came to add item to report: #{self.name}"
		#puts "incoming category is: #{category.name}"
		#puts "item is: #{item}"
		#puts "iterating requirements."
		self.requirements.each do |req|
			#puts "requirement name is : #{req.name}"
			req.categories.each do |cat|
				#puts "category name is: #{cat.name}"
				if cat.name == category.name
					#puts "category names match."
					#puts "checking has space."
					#puts "category quantity is: "
					#puts cat.quantity
					if item.has_space?(cat.quantity)
						#puts "it has space."
						item.deduct_space(cat.quantity)
						cat.items << item
					else
						#puts "it does not have space."
						## so we can reduce the requirement.
						## so as it does not have space, it
						## is not being added
						## that's the problem here
						## there is no error.
					end
				end
			end
		end
	end

	#####################################################
	##
	##
	## OVERRIDDEN FROM SEARCH OPTIONS CONCERN
	##
	##
	#####################################################
	def apply_current_user(current_user)
		self.search_options ||= []
		if belongs_to_user?(current_user)
			## add the search options
			##self.search_options[:]
			self.search_options << {
				:text => "Choose",
				"data_id".to_sym => self.id.to_s,
				:classes => ["choose_report"]
			}
		else
			self.search_options << {
				:text => ("Outsource to" + self.currently_held_by_organization),
				"data_id".to_sym => self.id.to_s,
				:class => ["choose_report","outsource"]
			}
		end

		#puts "the search options become:"
		#puts JSON.pretty_generate(self.search_options)

	end

	#############################################################3
	##
	##
	## OVERRIDDEN FROM NESTED FORM.
	##
	##
	#############################################################
	## this gets overriden in the different things.
	def summary_row(args={})
		'
			<tr>
				<td>' + self.name + '</td>
				<td>' + self.tests.size.to_s + '</td>
				<td>' + self.statuses.size.to_s + '</td>
				<td>' + self.requirements.size.to_s + '</td>
				<td><div class="edit_nested_object" data-id=' + self.unique_id_for_form_divs + '>Edit</div></td>
			</tr>
		'
	end

	## should return the table, and th part.
	## will return some headers.
	def summary_table_headers(args={})
		'''
			<thead>
	          <tr>
	              <th>Name</th>
	              <th>Total Tests</th>
	              <th>Total Steps</th>
	              <th>Total Requirements</th>
	              <th>Options</th>
	          </tr>
	        </thead>
		'''
	end

	## if the root is an order, we don't want the add new button.
	def add_new_object(root,collection_name,scripts,readonly)
			 
		if root =~ /order/
			''
		else
			
			script_id = BSON::ObjectId.new.to_s

			script_open = '<script id="' + script_id + '" type="text/template" class="template"><div style="padding-left: 1rem;">'
			
			scripts[script_id] = script_open

			scripts[script_id] +=  new_build_form(root + "[" + collection_name + "][]",readonly,"",scripts) + '</div></script>'
		
			element = "<a class='waves-effect waves-light btn-small add_nested_element' data-id='#{script_id}'><i class='material-icons left' >cloud</i>Add #{collection_name.singularize}</a>"

			element

		end

	end

	## has any test just been verified?
	## okay so that's why this doesnt work.
	## you cannot sit and verify tests individually.
	def a_test_was_verified?
		self.a_test_was_verified
		## so how do we do this ?
=begin
		self.tests.select{|c|
			((c.changed_attributes.include? "verification_done") && (c.verification_done == Diagnostics::Test::VERIFIED))
		}.size > 0
=end
	end

	## @return[Boolean] true/false : true if all the tests are verified.
	## @called_from : views/business/orders/report_summary
	def is_verified?
		self.tests.select{|c|
			c.verification_done == Diagnostics::Test::NOT_VERIFIED
		}.size == 0
	end

	## @return[Boolean] true/false : true if any of the tests are abnormal.
	## @called_from : views/business/orders/report_summary
	def has_abnormal_tests?
		self.tests.select{|c|
			c.is_abnormal?
		}.size > 0
	end

	## @return[Boolean] true/false : the order organization is passed in after_Find from order_concern. We compare that to the currently held by organization on the report. If they are not the same, then the report has been outsourced.
	## this is used to set the accessor :report_is_outsourced
	## and this accessor is also available in the json representation of this object.
	def is_outsourced?
		self.organization.id.to_s != self.order_organization.id.to_s
	end

	## @return[Boolean] true/false : true if the user can sign the report.
	## @called_from : order_concern#group_reports_by_organization
	def can_sign?(user)
		#puts "came to can sign ------, with user: #{user}"
		true
	end

	## @return[Array] list of user_ids who have verified the tests in this report.
	def gather_signatories
		self.final_signatories = self.tests.map{|c|
			#puts "coming from Diagnostics::Report#gather_signatories -> test: #{c.name} , verification done by: #{c.verification_done_by}"
			c.verification_done_by				
		}.uniq
	end

	###########################################################
	##
	##
	## RATE HELPERS
	##
	##
	###########################################################
	## @return[Float] the rate marked for patients
	## @called_from : Business::Payment.
	def get_patient_rate
		k = self.rates.select{|c|
			c.is_patient_rate?
		}
		unless k.blank?
			k[0].rate
		else
			0.to_f
		end
	end

	## @return[Float] the first rate which is marked for all organizations (*)
	def get_default_rate
		k = self.rates.select{|c|
			c.is_default_rate?
		}
		unless k.blank?
			k[0].rate
		else
			0.to_f
		end
	end

	## @return[Float] : either the rate for this particular organization or the default rate.
	def get_organization_rate(organization_id)
		k = self.rates.select{|c|
			c.for_organization_id == organization_id
		}
		unless k.blank?
			k[0].rate
		else
			get_default_rate
		end
	end

	## tubes
	## 
	###########################################################
	##
	## override with methods to include all the attr_accessors.
	##
	## if you call to_json on order, then and only then these additional methods are included, calling, as_json on order, does not include these methods.
	###########################################################
	def as_json(options={})
		super(:methods => [:report_has_abnormal_tests,:report_all_tests_verified, :report_is_outsourced, :worth_processing,:outsourcable_organization_ids])
	end
	##########################################################
	## @called_from : order_concern#remove_reports
	def can_be_removed?
		## can this report be removed ?
		## if someone triggers a removal.
		## currently returns true.
		true
	end

	## whether each of the requirements in has at least one
	## of its categories containing an item.
	def requirements_satisfied?
		result = true
		self.requirements.map{|c|
			result = false unless c.satisfied?
		}
		result
	end
	########################################################
	##
	##
	## USED IN SOME TESTS eg: statement_test.rb
	##
	##
	#####################################################
	def self.find_reports(args)
		organization_id = args[:organization_id]
		if !args[:organization_name].blank?
			search_request = Organization.search({
				query: {
					term: {
						name: organization_name
					}
				}
			})
			organization_id = search_request.response.hits.hits.first._id
		end

		query = {
			size: 100,
			query: {
				bool: {
					must: [
						{
							term: {
								currently_held_by_organization: organization_id
							}
						}
					]
				}
			}
		}

	
		unless args[:report_name].blank?
			query[:query][:bool][:must] << {
				term: {
					name: args[:report_name]
				}
			}
		end

		puts "the query is :"
		puts query.to_s


		search_request = search(query)

		search_request.response.hits.hits.map{|hit|
			report = Diagnostics::Report.new(hit["_source"])
			report.id = hit["_id"]
			report
		}


	end

	def self.find_reports_by_organization_name(organization_name,size=10)
		#puts "searching for organization name: #{organization_name}"
		search_request = Organization.search({
			query: {
				term: {
					name: organization_name
				}
			}
		})

		organization_id = search_request.response.hits.hits.first._id

		search_request = search({
			size: size,
			query: {
				term: {
					currently_held_by_organization: organization_id
				}
			}
		})

		search_request.response.hits.hits.map{|hit|
			report = Diagnostics::Report.new(hit["_source"])
			report.id = hit["_id"]
			report
		}

	end

	## @return[Diagnostics::Report] top_up_report : the report which is reserved for letting people make top ups.
	## @called_from : 
	def self.get_top_up_report
		search_request = search({
			query: {
				term: {
					top_up_template: YES
				}
			}
		})
		top_up_report = nil
		search_request.response.hits.hits.each do |hit|
			top_up_report = Diagnostics::Report.new(hit._source)
			top_up_report.id = hit._id
		end
		top_up_report
	end

	def self.index_controller_action(query,params,current_user)
		## SCORING CAN BE CONTROLLED BY OUTSOURCE_SCORE, AND INTERNAL_SCORE -> BOTH OF WHICH 
		return {query: query} if params[:reports_list].blank?
		aggs = {
		    report_name: {
		      	terms: {
		        	field: "name",
		        	size: 50
		      	},
		      	aggs: {
		        	report_id: {
		          		terms: {
		            		field: "_id",
		            		size: 10
		          		}
		        	},
		        	organization_id: {
		          		terms: {
		            		field: "currently_held_by_organization",
		            		size: 10
		          		}
		        	}
		      	}
		    }
		}

		if params["show_outsourced"] == true
			## ORDER AGGREGATION BY THE OUTSOURCED SCORE.
			query[:bool][:must_not] = {
				term: {
					currently_held_by_organization: current_user.organization.id.to_s
				}
			}
		else
			## SCORE BY THE INTERNAL SCORE.
		end

		puts "aggs becomes:"
		puts JSON.pretty_generate(aggs)

		{aggs: aggs, query: query, size:0}
	
	end

	def self.parse_index_controller_aggregation(response)
		reports = []
		puts response.aggregations
		return reports if response.aggregations.blank?
		return reports if response.aggregations.report_name.blank?
		response.aggregations.report_name.buckets.each do |report_name_bucket|
			report_name = report_name_bucket["key"]
			outsourcable_organization_ids = report_name_bucket.organization_id.buckets.map{|c|
				c["key"]
			}
			report_id = report_name_bucket.report_id.buckets[0]["key"]
			report = Diagnostics::Report.new(name: report_name, outsourcable_organization_ids: outsourcable_organization_ids)
			report.id = report_id
			reports << report
		end
		reports
	end

end	