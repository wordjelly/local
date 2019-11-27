module TagHelper

	## @return[Tag]
    def create_history_pregnancy_tag	
    	tag = Tag.new
   		tag.tag_type = Tag::HISTORY_TAG
   		tag.name = "Pregnancy"
   		tag.history_options = [
   			"Not Pregnant",
   			"Week 1",
   			"Week 2",
   			"Week 3",
   			"Week 4",
   			"Week 5",
   			"Week 6"
   		] 	
    end

end