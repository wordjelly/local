require 'elasticsearch/persistence/model'
class Diagnostics::Report

	include Elasticsearch::Persistence::Model
	include ActiveModel::Validations
  	include ActiveModel::Validations::Callbacks

	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern
	include Concerns::FormConcern
	include Concerns::SearchOptionsConcern
	include Concerns::PdfConcern
	include Concerns::Diagmodule::Report::OutsourceConcern


	index_name "pathofast-diagnostics-reports"
	document_type "diagnostics/report"

	VERIFY_ALL = 1

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
	attribute :request_rerun, Integer, mapping: {type: 'integer'}, default: -1
	## calculated before_save in the set_procedure_version function
	attribute :procedure_version, String, mapping: {type: "keyword"}
	attribute :start_epoch, Integer, mapping: {type: 'integer'}
	## WE SET a
	## AND THEN THE FIRST ACTION TO CHECK IS 
	## parse normal ranges.

	## doesnt need to be a permitted param, is internally assigned.
	#attribute :order_id, String, mapping: {type: 'keyword'}

	## default : -1, (means don't)
	## if set to 1 -> it will set verified as true only on those 
	## tests which (a. are not already verified, are ready for reporting, and whose picked range is not abnormal)
	attribute :verify_all, Integer, mapping: {type: 'integer'}, default: -1

	## stat marked, means the report will be released as soon as it is ready, without waiting for other reports in the patient order.
	## it also gets priority.
	## default : -1 -> means its not stat
	## 1 -> means its stat.
	## @used_in : 
	attribute :stat, Integer, mapping: {type: 'integer'}, default: -1
	
	## this is generated before_validation.
	## it is generated from the def order_concern#generate_report_impression
	attribute :impression, String, mapping: {type: 'text'}

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

	## @called_from : after_find in Concerns::OrderConcern#after_find
	## sets all the accessors, and these are included in the json
	## representation of this element.
	## @param[Organization] organization:  the organization that has created the order in the first place
	def set_accessors
		self.report_all_tests_verified = self.all_tests_verified?
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
	before_validation do |document|
		document.set_procedure_version
		document.cascade_id_generation(nil) unless document.created_by_user.blank?
	end

	

	def fields_not_to_show_in_form_hash(root="*")
		{
			"*" => ["create unless document.created_by_user.blank?d_at","updated_at","public","currently_held_by_organization","created_by_user_id","owner_ids","procedure_version","outsourced_report_statuses","merged_statuses","search_options","pdf_url","latest_version","request_rerun","start_epoch","verify_all","stat","outsource_to_organization_id","outsource_from_status_category","outsource_from_status_id","patient_id"],
			"order" => ["created_at","updated_at","public","currently_held_by_organization","created_by_user_id","owner_ids","procedure_version","outsourced_report_statuses","merged_statuses","search_options","description","patient_id","start_epoch","tag_ids","pdf_url","latest_version"]
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
				    	}
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
			}
		}
	end

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
		self.requirements.each do |req|
			req.categories.each do |cat|
				if cat.name == category.name
					if item.has_space?(cat.quantity)
						item.deduct_space(cat.quantity)
						cat.items << item
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
			## now let's see how this works.
			## now we need to know which organization this is
			## this should be done after find.
			## for the record.
			self.search_options << {
				:text => ("Outsource to" + self.organization.name),
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

	## @return[Boolean] true/false : true if all the tests are verified.
	## @called_from : views/business/orders/report_summary
	def all_tests_verified?
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
		#puts "self organization is:"
		#puts self.organization.to_s
		#puts "self order organization is:"
		#puts self.order_organization.to_s
		self.organization.id.to_s != self.order_organization.id.to_s
	end

	## @return[Boolean] true/false : true if the user can sign the report.
	## @called_from : order_concern#group_reports_by_organization
	def can_sign?(user)
		true
	end

	## @return[Array] list of user_ids who have verified the tests in this report.
	def gather_signatories
		self.tests.map{|c|
			puts "coming from Diagnostics::Report#gather_signatories -> test: #{c.name} , verification done by: #{c.verification_done_by}"
			c.verification_done_by				
		}.uniq
	end
	###########################################################
	##
	## override with methods to include all the attr_accessors.
	##
	## if you call to_json on order, then and only then these additional methods are included, calling, as_json on order, does not include these methods.
	###########################################################
	def as_json(options={})
		super(:methods => [:report_has_abnormal_tests,:report_all_tests_verified, :report_is_outsourced])
	end
	##########################################################

end	