module NestedFormHelper
	def build_nested_form(model)
		model.build_form(model.class.name.classify.demodulize.underscore.downcase)
	end	
end