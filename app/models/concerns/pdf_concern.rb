module Concerns::PdfConcern

	extend ActiveSupport::Concern

	included do 
		attribute :latest_version, String, mapping: {type: "keyword"}
	end

	CLOUDINARY_RESULT_OK = "ok"
	CLOUDINARY_RESULT_NOT_FOUND = "not found"

	## this is the main method to call.
	## internally will call the generate_pdf method inside the background job.
	def queue_pdf_job
		#puts " ---------- CAME TO QUEUE PDF JOB -------------"
		PdfJob.perform_later([self.class.name, self.id.to_s])
	end

	

	## will set the pdf_uploaded_to_cloudinary_variable, to true, if the upload is successfull.
	## this is going to happen in a background job.
	def generate_pdf
		## first we try to generate the pdf.
=begin
		file_name = get_file_name
	    ac = ActionController::Base.new
	    pdf = ac.render_to_string pdf: file_name,
	               template: "#{self.class.name.underscore.pluralize}/show.pdf.erb",
	               locals: {:object => self},
	               layout: "pdf/application.html.erb"
	    Tempfile.open(file_name) do |f| 
		  f.binmode
		  f.write pdf
		  f.close 

		  response = Cloudinary::Uploader.upload(File.open(f.path), :public_id => file_name, :upload_preset => "report_pdf_files")
		  self.latest_version = response['version'].to_s

		  #puts "latest version is; #{self.latest_version}"
		end
=end
		self.save		
	end



	def get_file_name
		self.id.to_s + "_" + self.created_at.strftime("%b_%-d_%Y")
	end

end