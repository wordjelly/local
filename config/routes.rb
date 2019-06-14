Rails.application.routes.draw do

  mount_routes Auth.configuration.auth_resources

  resources :reports  
  resources :patients
  resources :orders
  resources :employees
  resources :statuses
  resources :images
  resources :tags
  resources :organizations
  resources :packages
  resources :barcodes
  
  namespace :geo do 
    resources :locations
    resources :spots
  end


  ## now after create add that there.
  ## not from item_type
  ## you have to order it first
  ## and only from a trasaction can you create it.
  namespace :inventory do 
    resources :item_types
    resources :item_transfers
    resources :comments
    resources :transactions
    resources :item_groups
    resources :items
    namespace :equipment do 
      resources :machines
      resources :machine_complaints
      resources :solutions
      resources :machine_certificates
    end
  end
  


  #get 'users/sign_in_options' => "users#sign_in_options", as: "sign_in_options"

  get 'app_search' => 'search#search'
  get 'app_search/type_selector' => 'search#type_selector'
  get 'make_payment' => 'statuses#make_payment'

  root 'home#index'
  # Example resource route with options:
  #   resources :products dos
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
