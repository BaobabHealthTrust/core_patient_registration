class CorePersonAttributeType < ActiveRecord::Base
  set_table_name :person_attribute_type
  set_primary_key :person_attribute_type_id
  include CoreOpenmrs
  has_many :person_attributes, :class_name => "CorePersonAttribute", :conditions => {:voided => 0}
end