class CoreRegion < ActiveRecord::Base
  set_table_name "region"
  set_primary_key "region_id"
  
  has_many :districts, :foreign_key => :region_id, :class_name => "CoreDistrict"
end
