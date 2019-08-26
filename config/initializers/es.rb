remote_host = {host: ENV["REMOTE_ES_HOST"] , scheme: 'https', port: 9243}
remote_host.merge!({user: ENV["REMOTE_ES_USER"], password: ENV["REMOTE_ES_PASSWORD"]})

$remote_es_client = Elasticsearch::Client.new hosts: [ remote_host], headers: {"Content-Type" => "application/json" }, request: { timeout: 45 }

#host = {host: '192.168.1.2', scheme: 'http', port: 9200}
host = {host: 'localhost', scheme: 'http', port: ENV["LOCAL_ES_PORT"]}

if Rails.env.production?
	Elasticsearch::Persistence.client = Elasticsearch::Client.new hosts: [ remote_host], headers: {"Content-Type" => "application/json" }, request: { timeout: 145 }
else
	Elasticsearch::Persistence.client = Elasticsearch::Client.new hosts: [ host], headers: {"Content-Type" => "application/json" }, request: { timeout: 145 }
end


["Employee","Inventory::Item","Inventory::ItemGroup","Inventory::ItemType","Inventory::ItemTransfer","Inventory::Transaction","Inventory::Comment","Geo::Location","Geo::Spot","Business::Order","Patient","Diagnostics::Report","Image","Schedule::Minute","Organization","Tag","Inventory::Equipment::Machine","Inventory::Equipment::MachineCertificate",
      "Inventory::Equipment::MachineComplaint"].each do |cls|
	unless Elasticsearch::Persistence.client.indices.exists? index: cls.constantize.index_name
		cls.constantize.send("create_index!",{force: true})
	end
end

## overrides method from wordjelly/mongoid-elasticsearch
## there we made a blanket document type as "type"
## link to that: https://github.com/wordjelly/mongoid-elasticsearch/blob/7a387df3b86d3d1763d18376fdccfcfa79fadce3/lib/mongoid/elasticsearch/index.rb#L19
## ill have to modify the gem.
module Mongoid
  module Elasticsearch
    class Index
        def type
            klass.model_name.collection.singularize
        end 
    end 
  end
end
=begin
class ::Hash
    def deep_merge_nil(second)
        merger = proc { |key, v1, v2| }
        compound_merger = proc {|key,v1,v2|
        	Hash === v1 && Hash === v2 ? v1.deep_merge_nil(v2, &merger) : [:undefined, nil, :nil].include?(v2) ? v1 : v2 
        	## if either is blank.
        	## then take the one which is not blank.
        	## if either is an array, then what ?
        	## if the sizes of incoming and existing are different
        	## precedence to incoming.
        	## if sizes are the same, then check ids, 
        	## so we have to custom merge logic.
        }
        self.merge(second, &merger)
    end
end
=end