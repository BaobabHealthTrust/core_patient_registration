class CoreDistrict < ActiveRecord::Base
	set_table_name "district"
	set_primary_key "district_id"

	belongs_to :region, :class_name => "CoreRegion"

end
