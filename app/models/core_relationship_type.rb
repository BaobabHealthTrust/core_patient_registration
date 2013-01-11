class CoreRelationshipType < ActiveRecord::Base
  set_table_name :relationship_type
  set_primary_key :relationship_type_id
  include CoreOpenmrs
  default_scope :order => 'weight DESC'
  has_many :relationships, :class_name => 'CorePerson', :conditions => {:voided => 0}
end