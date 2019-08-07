require 'elasticsearch/persistence/model'

class Version

	include Elasticsearch::Persistence::Model
	include Concerns::FormConcern
	include Concerns::MissingMethodConcern
	
	attribute :attributes_string, String
	attribute :control_doc_number, String

	## here also we have to do display nested.

	## @return[String] a control doc_number
	## composed of current_year/current_epoch.to_s
	## eg : 2015/1551093091092
	## @called_from : base_controller_concner#update,create where version is being created.
	def assign_control_doc_number
		self.control_doc_number = Time.now.strftime("%Y") + "/" + Time.now.to_i.to_s
		self.control_doc_number
	end	

	## true if the model param are different for non_tamperable_parasmeters 
	def tampering?(non_tamperable_parameters, previous_version, model_params, obj_class)
		prev_obj = obj_class.constantize.new(previous_version)
		tampering = false
		non_tamperable_parameters.each do |p|
			if prev_obj.send(p.to_sym) != model_params.send(p.to_sym)
				tampering = true
			end
		end
		tampering
	end

	## blocking this as we don't want anything to interfere here.
	def cascade_id_generation(organization_id)
		## don't do anything.		
	end	
	
end