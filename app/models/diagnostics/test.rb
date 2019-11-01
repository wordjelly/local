require 'elasticsearch/persistence/model'
class Diagnostics::Test	
		


	include Elasticsearch::Persistence::Model
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	include Concerns::OwnersConcern
	include Concerns::EsBulkIndexConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern
	include Concerns::FormConcern
	include Concerns::CallbacksConcern

			
	TEXTUAL_RESULT = "text"
	NUMERIC_RESULT = "numeric"
	DEFAULT_RESULT = "-"
	DEFAULT_UNITS = "-"
	VERIFIED = 1
	NOT_VERIFIED = -1
	YES = 1
	NO = 0

	index_name "pathofast-tests"

	## mapped in block
	attribute :name, String

	## mapped in block
	attribute :lis_code, String, default: BSON::ObjectId.new.to_s

	## mapped in block
	attribute :description, String, default: "test"

	## references
	attribute :references, Array, mapping: {type: 'keyword'}, default: []

	## whether to display all the normal ranges in the report.
	attribute :print_all_ranges_in_report, Integer, mapping: {type: 'integer'}, default: NO

	## whether ranges, should be interpreted, if set to no, it will not assign any normal ranges, in the order, just will show all the ranges.
	attribute :interpret_ranges, Integer, mapping: {type: 'integer'}, default: YES

	## so we can show the range, which has been selected
	## in the summary, otherwise the number of ranges, 
	## and a view for that as well.
	attribute :ranges, Array[Diagnostics::Range], mapping: {type: Diagnostics::Range.index_properties}

	
	attribute :template_tag_ids, Array, mapping: {type: 'keyword'}
	## so these are the tags.
	## and they will be validated in case of order only.
	## they need to be filled in, inside the relevant tests
	## the problem is that, can it be edited by the referring party inside an outsourced report. that is also importants.
	## so this is not so bad.
	## actually just tags, no need for super nesting.
	attribute :tags, Array[Tag], mapping: {type: Tag.index_properties}

	## -1 is not ready for reporting
	## 1  is ready for reporting.
	## is calculated on each save
	## for eg: if the request rerun is false
	## and the reportable status is passed
	## and the value is there
	## then we can report. 
	attribute :ready_for_reporting, Integer, mapping: {type: 'integer'}, default: -1

	## -1 is not yet verification_done.
	attribute :verification_done, Integer, mapping: {type: 'integer'}, default: -1

	## template tags.
	## verification done by is an array
	## user ids of those who verified this report.
	## this has a validation to check if they are permitted.
	## this again has to be done from the order
	## so here before_validation, they will simply uniq the 
	## user ids.
	## incase added more than once.
	## then these peoples signatures, have to be got.
	## that is not a big problem.
	## again that is called from report.
	attribute :verification_done_by, Array, mapping: {type: 'keyword'}

	## result types have to be defined.
	## whether it is numerical or textual
	## and both values are defined.
	## so an add value function has to be definsed.
	attribute :result_type, String, mapping: {type: 'keyword'}, default: TEXTUAL_RESULT
	
	attribute :result_text, String, mapping: {type: 'keyword'}

	attribute :result_numeric, Float, mapping: {type: 'float'}

	attribute :result_raw, String, mapping: {type: 'keyword'}, default: DEFAULT_RESULT

	attribute :units, String, mapping: {type: 'keyword'}, default: DEFAULT_UNITS

	# so it will be included in the report only if abnormal
	# otherwise we have include by default.
	# all are included.
	# this is to be in the report if it is abnormal,
	# otherwise don't include it.
	attribute :only_include_in_report_if_abnormal, Integer, mapping: {type: 'integer'}, default: YES 


	# for the report function #all_tests_verified?
	# to return true, this test must have a value.
	# and must be verified
	attribute :test_must_have_value, Integer, mapping: {type: 'integer'}, default: YES


	attribute :test_only_applicable_to_genders, Array, mapping: {type: 'keyword'}, default: Diagnostics::Range::GENDERS

	attr_accessor :display_result
	attr_accessor :display_normal_biological_interval
	attr_accessor :display_count_or_grade
	attr_accessor :display_comments_or_inference
	attr_accessor :test_is_abnormal
	attr_accessor :test_is_ready_for_reporting
	attr_accessor :test_is_verified

	## used and initialized in range_validation
	## Self#validation#all_ages_and_genders_covered_in_ranges_and_no_overlaps
	#attr_accessor :male_ranges_hash_normal
	#attr_accessor :female_ranges_hash_normal
	#attr_accessor :male_ranges_hash_abnormal
	#attr_accessor :female_ranges_hash_abnormal
	#attr_accessor :all_ranges_min_max_values

	## structure
	## key -> min_age_max_age_gender
	## value -> {normal_range: Range, abnormal_range: Range}
	## sorted by the min_age
	attr_accessor :ranges_hash

	## @set_from : models/concerns/order_concern#update_results_to_lis 	
	attr_accessor :successfully_updated_by_lis

	####################################################
	##
	##
	## SET FROM SET_ACCESSORS IN REPORT.
	## GIVES ACCESS TO THE ORDER ORGANIZATION INSIDE THE REPORT
	## 
	##
	####################################################
	attr_accessor :order_organization


	####################################################
	##
	##
	## BEFORE VALIDATION
	##
	##
	####################################################
	def remove_tags
		self.tags.delete_if{|c|
			!self.template_tag_ids.include? c.id.to_s
		}
	end

	def add_tags
		self.template_tag_ids.each do |ttid|
			self.tags << Tag.find(ttid) unless self.tags.select{|c| c.id.to_s == ttid}.size == 1
		end
	end

	def update_tags
		remove_tags
		add_tags
	end

	before_validation do |document|
		## okay so this is done.
		## we only give the template tag ids as editable.
		document.update_tags
	end
	##########################################################
	##
	##
	## VALIDATION AND ITS INTERNAL HELPERS
	##
	##
	##########################################################
	## what about special attributes ?
	## so the patient has to be passed in?
	## do we add anything special about the patient.
	## a report that contains any test that has special ranges.
	## will not be added, unless that information is defined on the patient.

	validate :all_ages_and_genders_covered_in_ranges_and_no_overlaps


	def all_ages_and_genders_covered_in_ranges_and_no_overlaps

		self.ranges_hash = {}
		
		self.ranges.each do |range|
			range_key = range.min_age.to_s + "_" + range.max_age.to_s + "_" + range.sex
			if self.ranges_hash[range_key].blank?
				self.ranges_hash[range_key] = {}		
			end 
			self.ranges_hash[range_key][(range.is_abnormal_range? ? :abnormal : :normal)] = range
		end
		
		self.ranges_hash.keys.each do |rk|
			self.errors.add(:ranges,"no normal range defined for this age group and gender, only an abnormal range, test: #{self.name}, range key: #{rk}") if self.ranges_hash[rk][:normal].blank?
		end

		return unless self.errors.blank?

		self.ranges_hash = Hash[self.ranges_hash.sort_by { |k,v| v[:normal].min_age }]
		
		self.ranges_hash.keys.each do |range_key|
			if self.ranges_hash[range_key].keys.size == 1 && self.ranges_hash[range_key].keys[0] == :abnormal
				self.errors.add(:ranges,"no normal range was defined for this age category, #{range_key}, only an abnormal range has been defined, make sure you define a normal range as well.")
			elsif self.ranges_hash[range_key].keys.size == 2
				if self.ranges_hash[range_key][:normal].min_value.between?(self.ranges_hash[range_key][:abnormal].min_value,self.ranges_hash[range_key][:abnormal].max_value)
					self.errors.add(:ranges,"there is an overlap between the min and max values of the normal and abnormal ranges")
				elsif self.ranges_hash[range_key][:normal].max_value.between?(self.ranges_hash[range_key][:abnormal].min_value,self.ranges_hash[range_key][:abnormal].max_value)
					self.errors.add(:ranges,"there is an overlap between the min and max values of the normal and abnormal ranges")
				end
			end
			
			next_range_start_age = self.ranges_hash[range_key][:normal].max_age

			next_range_gender = self.ranges_hash[range_key][:normal].sex
			
			unless next_range_start_age == Diagnostics::Range::MAXIMUM_POSSIBLE_AGE_IN_HOURS

				self.errors.add(:ranges,"contiguous ranges absent") if self.ranges_hash.keys.select{|c|
					c =~ /#{next_range_start_age}_(\d+)_#{next_range_gender}/
				}.size == 0

			end

		end

	
		## first select both
		## if its size is equal, to required, then it should be for the same range.
		minimum_selected = self.ranges_hash.keys.select{|c|
			c.to_s =~ /#{Diagnostics::Range::MINIMUM_POSSIBLE_AGE_IN_HOURS}_\d+_(male|female)/i
		}

		maximum_selected = self.ranges_hash.keys.select{|c|
			c.to_s =~ /\d+_#{Diagnostics::Range::MAXIMUM_POSSIBLE_AGE_IN_HOURS}_(male|female)/i
		}

		#puts "minimum selected size is: #{minimum_selected.size}"
		#puts "maximum selected size is: #{maximum_selected.size}"
		#puts "test applicable only to : #{self.test_only_applicable_to_genders}"

		## applicable to male
		## so should have male

		
		## applicable to both
		## should have both



		self.errors.add(:ranges,"the first range for either male or female does not start at 0 years") unless  minimum_selected.size == self.test_only_applicable_to_genders.size

		self.errors.add(:ranges,"the last range for either male or female does not start at 120 years") unless  maximum_selected.size == self.test_only_applicable_to_genders.size

		self.test_only_applicable_to_genders.each do |gd|
		
			self.errors.add(:ranges, "selected gender minimum age missing") if minimum_selected.select{|c|
				c =~ /#{gd}/i
			}.size == 0

			self.errors.add(:ranges, "selected gender maximum age missing") if maximum_selected.select{|c|
				c =~ /#{gd}/i
			}.size == 0
		
		end

	end

	##########################################################
	##
	##
	## VALIDATION AND ITS INTERNAL HELPERS
	##
	##
	##########################################################
	
	## @called_from : after_find in Concerns::OrderConcern#after_find
	## sets all the accessors, and these are included in the json
	## representation of this element.
	def set_accessors
		# display result
		if self.result_type == TEXTUAL_RESULT
			self.display_result = self.result_text
		elsif self.result_type == NUMERIC_RESULT
			self.display_result = self.result_numeric
		end

		# normal interval
		if normal_range = get_applicable_normal_range
			if normal_range.text_value == Diagnostics::Range::DEFAULT_TEXT_VALUE
				## show the min to max values.
				self.display_normal_biological_interval = normal_range.min_value.to_s + "-" + normal_range.max_value.to_s
			else
				## show the text value.
				self.display_normal_biological_interval = normal_range.text_value
			end		 
		end

		## okay now check that it gets abnormal correctly.
		## and why the tube is not being registered on the report
		## what options does the organization have to have.
		## so who should sign?
		## do we have each
		## report on new page



		# count/grade
		# comments
		if applicable_range = get_applicable_range
			self.display_count_or_grade = (applicable_range.grade || applicable_range.count || "-")
			self.display_comments_or_inference = applicable_range.inference
		end

		# is abnormal
		self.test_is_abnormal = self.is_abnormal?

		# test is ready for reporting
		self.test_is_ready_for_reporting = self.is_ready_for_reporting?
		
		# test is verified.
		self.test_is_verified = self.is_verification_done?

		# test units.


	end



	## @return[Boolean] true/false : true if there is an applicable range and it is abnormal.
	## false otherwise
	## @called_from : order_concern.rb#has_abnormal_reports , which is in turn called from views/business/orders/report_summary, which is in turn called from views/business/orders/show.pdf.erb
	## the idea is to check if any of the tests are abnormal, so that we can show them in the summary.
	def is_abnormal?
		if range = self.get_applicable_range
			range.is_abnormal == Diagnostics::Range::ABNORMAL
		else
			return false
		end
	end

	def is_ready_for_reporting?
		## for this to be set, we need to have the reportable status
		## to have been set as completed.
		## so i can set this manually for the moment.
		self.ready_for_reporting == -1 ? "No" : "Yes"
	end

	def is_verification_done?
		self.verification_done == -1 ? "Pending Verification"  : "Verified"
	end

	## so it will have to have a selected option
	## otherwise its useless.
	## that makes inputs easier to deal with.

	def self.permitted_params
		[
			:id,
			:name,
			:lis_code,
			:description,
			{:references => []},
			:machine,
			:kit,
			{
				:ranges => Diagnostics::Range.permitted_params
			},
			{
				:tags => Tag.permitted_params
			},
			{
				:template_tag_ids => []
			},
			:verification_done,
			:ready_for_reporting,
			:result_type,
			:result_text,
			:result_numeric,
			:result_raw,
			:units,
			:only_include_in_report_if_abnormal,
			:test_must_have_value,
			{ 
				:test_only_applicable_to_genders => []
			},
			:interpret_ranges,
			:print_all_ranges_in_report
		]
	end

	def self.index_properties
		{
	    	name: {
	    		type: 'keyword',
	    		fields: {
	    			:raw => {
	    				:type => "text",
			      		:analyzer => "nGram_analyzer",
			      		:search_analyzer => "whitespace_analyzer"
	    			}
		    		}
	    	},
	    	lis_code: {
	    		type: 'keyword'
	    	},
	    	description: {
	    		type: 'keyword',
	    		fields: {
	    			:raw => {
	    				:type => "text"
	    			}
	    		}
	    	},
	    	references: {
	    		type: 'keyword'
	    	},
	    	machine: {
	    		type: 'keyword'
	    	},
	    	kit: {
	    		type: 'keyword'
	    	},
	    	ranges: {
	    		type: 'nested',
	    		properties: Diagnostics::Range.index_properties
	    	},
	    	tags: {
	    		type: 'nested',
	    		properties: Tag.index_properties
	    	},
	    	verification_done: {
	    		type: 'integer'
	    	},
	    	ready_for_reporting: {
	    		type: 'integer'
	    	},
	    	result_type: {
	    		type: 'keyword'
	    	},
	    	result_text: {
	    		type: 'text'
	    	},
	    	result_numeric: {
	    		type: 'float'
	    	},
	    	result_raw: {
	    		type: 'keyword'
	    	},
	    	units: {
	    		type: 'keyword'
	    	},
	    	only_include_in_report_if_abnormal: {
	    		type: 'integer'
	    	},
			test_must_have_value: {
				type: 'integer'
			},
			test_only_applicable_to_genders: {
				type: 'keyword'
			},
			interpret_ranges: {
				type: 'integer'
			},
			print_all_ranges_in_report: {
				type: 'integer'
			},
			template_tag_ids: {
				type: 'keyword'
			}
	    }	
	end

	def fields_not_to_show_in_form_hash(root="*")
		{
			"*" => ["created_at","updated_at","public","currently_held_by_organization","created_by_user_id","owner_ids","procedure_version","outsourced_report_statuses","merged_statuses","search_options","ready_for_reporting","verification_done","result_text","result_numeric","result_raw"],
			"order" => ["created_at","updated_at","public","currently_held_by_organization","created_by_user_id","owner_ids","procedure_version","outsourced_report_statuses","merged_statuses","search_options","lis_code","description","verification_done","result_text","result_raw","result_numeric","result_type","references","units"]
		}
	end

	## filter the incoming results
	## keep away things like NAN, undefined, blanks, dots.
	## we do this not before save, but from the order
	## before_save.
	## and trigger it from there.
	#before_save do |document|
	#	document.add_result
	#end
	## should be done from the report ?
	## or else how will we get the reference to the organization id ?
	def result_filters
		["undefined","nan","null","infinity",DEFAULT_RESULT,".","!"]
	end

	## call from order.
	def add_result(patient)
		#puts "Called add result with patient data"
		#puts "the result raw is:"
		#puts self.result_raw.to_s
		#puts "result text is:"
		#puts self.result_text.to_s
		unless (self.result_raw.blank? || self.result_raw == DEFAULT_RESULT)
			
			#puts "result is not raw and not the default result."
			
			incorrect_result_format = false
			
			if self.result_text.blank?
				if self.result_numeric.blank?
					unless self.result_raw.strip.blank?
						result_filters.each do |filter|
							#puts "filter is :#{filter}"
							#puts "result raw strip is"
							if result_raw.strip.to_s =~ /#{Regexp.escape(filter)}/i
								#puts "got a match filter #{filter}"
							end
						end
					end
				end
			end
			
			#puts "incorrect result format is:"
			#puts incorrect_result_format.to_s

			if incorrect_result_format.blank?
				if self.requires_numeric_result?
					#begin
						self.result_numeric = self.result_raw.gsub(/[a-zA-Z[[:punct]]]/,'').to_f
						self.result_text = self.result_raw
						self.assign_range(patient)
					#rescue => e

					#end
				else
					self.result_text = self.result_raw
					self.assign_range(patient)
				end
			end

		end

	end

	def requires_numeric_result?
		self.result_type == NUMERIC_RESULT
	end

	def requires_text_result?
		self.result_type == TEXTUAL_RESULT
	end

	
	## so this way it picks both the normal and abnormal range
	## while both may be the same.
	def assign_range(patient)
		normal_range_index = nil
		puts "came to assign range"
		self.ranges.each_with_index.map{|c,i|
			if patient.meets_range_requirements?(c)
				puts "the patient meets the requirements."
				if c.is_normal_range?
					puts "it is a normal range"
					normal_range_index = i if normal_range_index.blank?
				end
				if self.requires_numeric_result?
					puts "it requires a numeric result"
					if ((self.result_numeric >= c.min_value) && (self.result_numeric <= c.max_value))
						puts "picks the range for the numeric result"
						c.pick_range	
					end
				elsif self.requires_text_result?
					puts "it requires a text result"
					if self.result_text == c.text_value
						puts "picks the text range"
						c.pick_range
					end
				end
			end
		}
		
		self.ranges[normal_range_index].pick_normal_range unless normal_range_index.blank?
		
	end

	
	## @return[Diagnostics::Range] applicable range, or nil , if none has been picked yet.
	## convenience method, used in summary_row, to get the applicable range and show its sex, and age.
	## it may be normal/abnormal.
	def get_applicable_range
		res = self.ranges.select{|c|
			c.picked == 1
		}
		if res.blank?
			nil
		else
			res[0]
		end
	end

	## gets the first range,
	## returns the applicable normal range for this patient. 
	def get_applicable_normal_range
		
		res = self.ranges.select{|c|
			c.normal_picked = 1
		}

		if res.blank?
			nil	
		else
			res[0]
		end

	end

	## and then after verified => dispatch report.
	## this can be done at the level of the report only =>


	###########################################################
	##
	## override with methods to include all the attr_accessors.
	##
	###########################################################
	def as_json(options={})
		super(:methods => [:display_result,:display_normal_biological_interval,:display_count_or_grade,:display_comments_or_inference,:test_is_abnormal,:test_is_ready_for_reporting,:test_is_verified, :successfully_updated_by_lis])
	end
	## okay so these are included.
	###########################################################
	##
	##
	## OVERRIDDEN FROM FORM CONCERN.
	##
	##
	###########################################################
	def summary_row(args={})

		if args["root"] =~ /order/
			
			inference = "-"
			
			range_name = "-"
			
			abnormal = "-"

			if applicable_range = get_applicable_range
				inference = applicable_range.inference
				range_name = applicable_range.get_display_name 
				abnormal = applicable_range.is_abnormal
			end

			'
				<thead>
		          <tr>
		              <th>' + self.name + '</th>
		              <th>' + (self.result_raw || DEFAULT_RESULT) + '</th>
		              <th>' + (self.units || DEFAULT_UNITS) + '</th>
		              <th>' + range_name + '</th>
		              <th>' + inference + '</th>
		              <th>' + self.is_ready_for_reporting? + '</th>
		              <th>' + self.is_verification_done? + '</th>
		              <th><div class="add_result_manually edit_nested_object" data-id=' + self.unique_id_for_form_divs + '>Add Result Manually</div>
		              	  <div class="verify edit_nested_object" data-id=' + self.unique_id_for_form_divs + '>Verify</div>
		              </th>
		          </tr>
		        </thead>
			'
		else
			'
				<tr>
					<td>' + self.name + '</td>
					<td>' + self.lis_code + '</td>
					<td>' + self.description + '</td>
					<td>' + self.ranges.size.to_s + '</td>
					<td><div class="edit_nested_object" data-id=' + self.unique_id_for_form_divs + '>Edit</div></td>
				</tr>
			'
		end
	end

	## okay now first do the order side validations for all this
	## shit
	## first the ranges, then get all the other tests to pass.
	## then these tests, and then the ui,
	## then the range interpretation and selection tests.
	## and the finalize order
	## and the signature vector ?
	## should i do that first ?
	## and the order prescription image ?
	## i could those two.
	## then the order j
	## or range selection.
	## missing range error.
	## interpretation using selected option.

	## should return the table, and th part.
	## will return some headers.
	def summary_table_headers(args={})
=begin
 <th>' + self.name + '</th>
 <th>' + self.result_raw + '</th>
 <th>' + self.units + '</th>
 <th>' + range_name + '</th>
 <th>' + inference + '</th>
 <th>' + self.ready_for_reporting + '</th>
 <th>' + self.verification_done + '</th>
 <th><div class="add_result_manually edit_nested_object" data-id=' + self.unique_id_for_form_divs + '>Add Result Manually</div>
  	  <div class="verify edit_nested_object" data-id=' + self.unique_id_for_form_divs + '>Verify</div>
 </th>
=end
		if args["root"] =~ /order/
			'
				<thead>
		          <tr>
		              <th>Name</th>
		              <th>Result</th>
		              <th>Units</th>
		              <th>Range Name</th>
		              <th>Inference</th>
		              <th>Ready For Reporting</th>
		              <th>Verified</th>
		              <th>Options</th>
		          </tr>
		        </thead>
			'
		else
			'
				<thead>
		          <tr>
		              <th>Name</th>
		              <th>LIS CODE</th>
		              <th>Description</th>
		              <th>Total Ranges</th>
		              <th>Options</th>
		          </tr>
		        </thead>
			'
		end
	end



	## @called_from : Business::Order#verify, before_validations
	## verifies the test if report verify_all is true.
	## will verify the test only if the picked_range is not abnormal.
	def verify_if_normal(created_by_user)
		unless get_applicable_range.blank?
			if get_applicable_range.is_abnormal == -1
				self.verification_done = 1 if self.is_ready_for_reporting?
				
			end
		end 	
	end	

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

	## @param[Hash] lis_test_result : a hash which contains the result of the test as sent by the lis.
	## the structure is as follows: 
	## {organization_id => result}
	## so we compare this organization id to the test's organization id, and if same then return true.
	## this is done to prevent an lis updating a test belonging to another organization in the same order, (one report may be outsourced to one organization, and another to a second, and they may have the same lis codes for a given test)
	## @return[Boolean] true/false : whether the test can be updated from the lis or not.
	## @called_from : app/models/concerns/order_concern.rb
	## when the lis wants to add a result for this test, you can use this method to decide if it should be allowed or not.
	def can_be_updated_by_lis?(lis_test_result,parent_report)
		if lis_test_result.keys[0] == parent_report.currently_held_by_organization
			(!self.is_verification_done? && self.is_ready_for_reporting?)
		else
			false
		end
	end

	## @called_from : order_concern#validation#order_can_be_finalized
	def history_provided?
		history_provided = true
		self.tags.each do |tag|
			history_provided = false unless tag.history_provided?
		end
		history_provided
	end

end