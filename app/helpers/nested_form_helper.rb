module NestedFormHelper
	def build_nested_form(model)
		scripts = {}
		form_html = model.build_form(model.class.name.classify.demodulize.underscore.downcase,"no","",scripts)
		scripts.keys.each do |script_key|
			form_html += scripts[script_key]
		end
		form_html
	end	
end