module NestedFormHelper
	def build_nested_form(model)
		scripts = {}
		#form_html = model.build_form(model.class.name.classify.demodulize.underscore.downcase,"no","",scripts)
		#t = Time.now
		form_html = model.new_build_form(model.class.name.classify.demodulize.underscore.downcase,"no","",scripts)
		#t2 = Time.now
		#puts "total time taken to build form:#{(t2-t).in_milliseconds}"
		#puts "total scripts are: #{scripts.keys.size}"

		scripts.keys.each do |script_key|
			form_html += scripts[script_key]
		end

		## so what all is needed
		## reports list
		## categories -> quantity and items
		## additional recipients
		## 

		#form_html = "some html"
		form_html
	end	
end