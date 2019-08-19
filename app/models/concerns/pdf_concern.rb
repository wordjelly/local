module Concerns::PdfConcern

	extend ActiveSupport::Concern

	included do 
		attribute :latest_version, String, mapping: {type: "keyword"}
		attribute :pdf_url, String, mapping: {type: "keyword"}
		## the cloudinary urls of files that were converted into pdfs
		attribute :pdf_urls, Array, mapping: {type: "keyword"}, default: []
		## unless blank, will not do generate_pdf.
		attr_accessor :skip_pdf_generation
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
			
		return unless self.skip_pdf_generation.blank?

		file_name = get_file_name
		file_name = "test"
	    
	    ac = ActionController::Base.new
	    
	    pdf = ac.render_to_string pdf: file_name,
            template: "#{ Auth::OmniAuth::Path.pathify(self.class.name).pluralize}/pdf/show.pdf.erb",
            locals: {:object => self},
            layout: "pdf/application.html.erb",
            header: {
            	html: {
            		template:'/layouts/pdf/header.html.erb',
            		layout: '/layouts/pdf/empty_layout.html.erb',
            		locals: {:object => self}
            	}
            },
            footer: {
           		html: {   
           			template:'/layouts/pdf/footer.html.erb',
           			layout: '/layouts/pdf/empty_layout.html.erb',
            		locals: {:object => self}
                }
            }       

        save_path = Rails.root.join('public',"#{file_name}.pdf")
		File.open(save_path, 'wb') do |file|
		  file << pdf
		end
=begin
	    Tempfile.open(file_name) do |f| 
		  f.binmode
		  f.write pdf
		  f.close 
		  #IO.write("#{Rails.root.join("public","test.pdf")}",pdf)
		  response = Cloudinary::Uploader.upload(File.open(f.path), :public_id => file_name, :upload_preset => "report_pdf_files")
		  puts "response is: #{response}"
		  self.latest_version = response['version'].to_s
		  self.pdf_url = response["url"]
		end
=end

		self.skip_pdf_generation = true
		
		#self.save		

	end


	## @return[String] file_name : consists of a bson object id and the current time.
	def get_file_name
		BSON::ObjectId.new.to_s + "_" + Time.now.strftime("%b_%-d_%Y")
	end

end