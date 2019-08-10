require 'elasticsearch/persistence/model'
class Diagnostics::Test	
	
	include Elasticsearch::Persistence::Model
	include Concerns::NameIdConcern
	include Concerns::ImageLoadConcern
	#include Concerns::OwnersConcern
	include Concerns::AlertConcern
	include Concerns::MissingMethodConcern
	include Concerns::FormConcern
			
	TEXTUAL_RESULT = "text"
	NUMERIC_RESULT = "numeric"
	DEFAULT_RESULT = "-"
	DEFAULT_UNITS = "-"

	index_name "pathofast-tests"

	## mapped in block
	attribute :name, String

	## mapped in block
	attribute :lis_code, String, default: BSON::ObjectId.new.to_s

	## mapped in block
	attribute :description, String, default: "test"

	## references
	attribute :references, Array, mapping: {type: 'keyword'}, default: []

	## so we can show the range, which has been selected
	## in the summary, otherwise the number of ranges, 
	## and a view for that as well.
	attribute :ranges, Array[Diagnostics::Range], mapping: {type: 'keyword'}

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

	## result types have to be defined.
	## whether it is numerical or textual
	## and both values are defined.
	## so an add value function has to be defined.
	attribute :result_type, String, mapping: {type: 'keyword'}, default: TEXTUAL_RESULT
	
	attribute :result_text, String, mapping: {type: 'keyword'}

	attribute :result_numeric, Float, mapping: {type: 'float'}

	attribute :result_raw, String, mapping: {type: 'keyword'}, default: DEFAULT_RESULT

	attribute :units, String, mapping: {type: 'keyword'}, default: DEFAULT_UNITS


	def self.permitted_params
		[
			:name,
			:lis_code,
			:description,
			{:references => []},
			:machine,
			:kit,
			{
				:ranges => Diagnostics::Range.permitted_params
			},
			:verification_done,
			:ready_for_reporting,
			:result_type,
			:result_raw,
			:units
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
	    	}
	    }	
	end

	def fields_not_to_show_in_form_hash(root="*")
		{
			"*" => ["created_at","updated_at","public","currently_held_by_organization","created_by_user_id","owner_ids","procedure_version","outsourced_report_statuses","merged_statuses","search_options"],
			"order" => ["created_at","updated_at","public","currently_held_by_organization","created_by_user_id","owner_ids","procedure_version","outsourced_report_statuses","merged_statuses","search_options","lis_code","description","ready_for_reporting","verification_done","result_text","result_raw","result_numeric","result_type","references","units"]
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
		["undefined","nan","null","infinity","-",".","!"]
	end

	## call from order.
	def add_result(patient)

		unless (self.result_raw.blank? || self.result_raw == DEFAULT_RESULT)

			incorrect_result_format = false
			
			if self.result_text.blank?
				if self.result_numeric.blank?
					unless self.result_raw.strip.blank?
						result_filters.each do |filter|
							incorrect_result_format = (self.result_raw.strip.to_s =~ /#{filter}/i) if incorrect_result_format.blank?
						end
					end
				end
			end
			if incorrect_result_format.blank?
				if self.requires_numeric_result?
					begin
						self.result_numeric = self.result_raw.gsub(/[a-zA-Z[[:punct]]]/,'').to_f
						self.result_text = self.result_raw
						self.assign_range(patient)
					rescue

					end
				else
					self.result_text = self.result_raw
					self.assign_range(patient)
				end
			end

		end

	end

	def requires_numeric_result?
		self.result_type == TEXTUAL_RESULT
	end

	def requires_text_result?
		self.result_type == NUMERIC_RESULT
	end

	def assign_range(patient)
		self.ranges.map{|c|
			if patient.meets_range_requirements?(c)
				if self.requires_numeric_result?
					if ((self.result_numeric >= c.min_value) && (self.result_numeric <= c.max_value))
						c.pick_range
					end
				elsif self.requires_text_result?
					if self.result_text == c.text_value
						c.pick_range
					end
				end
				break
			end
		}
	end

	## @return[Diagnostics::Range] applicable range, or nil , if none has been picked yet.
	## convenience method, used in summary_row, to get the applicable range and show its sex, and age.
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


	def is_ready_for_reporting?
		self.ready_for_reporting == -1 ? "Yes" : "No"
	end

	def is_verification_done?
		self.verification_done == -1 ? "Verified"  : "Pending Verification"
	end

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

end