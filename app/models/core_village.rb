class CoreVillage < ActiveRecord::Base
	set_table_name "village"
	set_primary_key "village_id"

	belongs_to :traditional_authority, :class_name => "CoreTraditionalAuthority"

end
