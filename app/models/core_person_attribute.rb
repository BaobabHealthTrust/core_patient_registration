class CorePersonAttribute < ActiveRecord::Base
  set_table_name "person_attribute"
  set_primary_key "person_attribute_id"
  include CoreOpenmrs

  belongs_to :type, :class_name => "PersonAttributeType", :foreign_key => :person_attribute_type_id, :conditions => {:retired => 0}
  belongs_to :person, :class_name => "CorePerson", :foreign_key => :person_id, :conditions => {:voided => 0}
end
