ActionController::Routing::Routes.draw do |map|

  map.root :controller => 'core_patient_registration', :action => 'select_fields'

  map.new_patient  '/new_patient',  :controller => 'core_patient_registration', :action => 'new'

  map.national_id_label '/national_id_label', :controller => 'core_patient_registration', :action => 'national_id_label'

  map.select  '/select',  :controller => 'core_patient_registration', :action => 'select'

  map.select  '/select_fields',  :controller => 'core_patient_registration', :action => 'select_fields'

  map.select_fields '/select_fields', :controller => 'core_patient_registration', :action => 'select_fields'

  map.search  '/search',  :controller => 'core_patient_registration', :action => 'search'

  map.select '/district', :controller => 'core_patient_registration', :action => 'district'

  map.select '/traditional_authority', :controller => 'core_patient_registration', :action => 'traditional_authority'

  map.select '/village', :controller => 'core_patient_registration', :action => 'village'

  map.scan '/scan/:id', :controller => 'core_patient_registration', :action => 'scan'

  map.scan '/change_national_id/:id', :controller => 'core_patient_registration', :action => 'change_national_id'

  map.demographics '/demographics/:id', :controller => 'core_patient_registration', :action => 'demographics'

  map.edit_demographics '/edit_demographics/:id', :controller => 'core_patient_registration', :action => 'edit_demographics'

  map.update_demographics '/update_demographics/:id', :controller => 'core_patient_registration', :action => 'update_demographics'

  map.user_login '/user_login/:id', :controller => 'core_patient_registration', :action => 'user_login'

  map.user_logout '/user_logout/:id', :controller => 'core_patient_registration', :action => 'user_logout'

  map.baby_mother_national_id_label '/baby_mother_national_id_label', :controller => 'core_patient_registration', :action => 'baby_mother_national_id_label'

  map.baby_mother_result '/baby_mother_result', :controller => 'core_patient_registration', :action => 'baby_mother_result'

  map.create_baby '/create_baby', :controller => 'core_patient_registration', :action => 'create_baby'

  map.no_user '/no_user', :controller => 'core_patient_registration', :action => 'no_user'

  map.no_patient '/no_patient', :controller => 'core_patient_registration', :action => 'no_patient'

  # The priority is based upon order of creation: first created -> highest priority.

  # Sample of regular route:
  #   map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   map.purchase 'products/:id/purchase', :controller => 'catalog', :action => 'purchase'
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   map.resources :products

  # Sample resource route with options:
  #   map.resources :products, :member => { :short => :get, :toggle => :post }, :collection => { :sold => :get }

  # Sample resource route with sub-resources:
  #   map.resources :products, :has_many => [ :comments, :sales ], :has_one => :seller
  
  # Sample resource route with more complex sub-resources
  #   map.resources :products do |products|
  #     products.resources :comments
  #     products.resources :sales, :collection => { :recent => :get }
  #   end

  # Sample resource route within a namespace:
  #   map.namespace :admin do |admin|
  #     # Directs /admin/products/* to Admin::ProductsController (app/controllers/admin/products_controller.rb)
  #     admin.resources :products
  #   end

  # You can have the root of your site routed with map.root -- just remember to delete public/index.html.
  # map.root :controller => "welcome"

  # See how all your routes lay out with "rake routes"

  # Install the default routes as the lowest priority.
  # Note: These default routes make all actions in every controller accessible via GET requests. You should
  # consider removing or commenting them out if you're using named routes and resources.
  map.connect ':controller/:action/:id'
  map.connect ':controller/:action/:id.:format'
end
