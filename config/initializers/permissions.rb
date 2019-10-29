#permissions.rb
$permissions = JSON.parse(IO.read("#{Rails.root.join('config','initializers','permissions.json')}"))