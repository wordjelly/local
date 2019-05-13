remote_host = {host: ENV["REMOTE_ES_HOST"] , scheme: 'https', port: 9243}
remote_host.merge!({user: ENV["REMOTE_ES_USER"], password: ENV["REMOTE_ES_PASSWORD"]})

$remote_es_client = Elasticsearch::Client.new hosts: [ remote_host], headers: {"Content-Type" => "application/json" }, request: { timeout: 45 }

#host = {host: '192.168.1.2', scheme: 'http', port: 9200}
host = {host: 'localhost', scheme: 'http', port: 9200}

if Rails.env.production?
	Elasticsearch::Persistence.client = Elasticsearch::Client.new hosts: [ remote_host], headers: {"Content-Type" => "application/json" }, request: { timeout: 145 }
else
	Elasticsearch::Persistence.client = Elasticsearch::Client.new hosts: [ host], headers: {"Content-Type" => "application/json" }, request: { timeout: 145 }
end

## create all the indices if they don't exist.


["Employee","Item","ItemGroup","ItemRequirement","Inventory::ItemType","Inventory::ItemTransfer","Inventory::Transaction","Inventory::Comment","Location","NormalRange","Order","Patient","Report","Status","Test","Image","Minute","Organization"].each do |cls|
	unless Elasticsearch::Persistence.client.indices.exists? index: cls.constantize.index_name
		cls.constantize.send("create_index!",{force: true})
	end
end