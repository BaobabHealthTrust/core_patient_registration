class CorePatient < ActiveRecord::Base
  set_table_name "patient"
  set_primary_key "patient_id"
  include CoreOpenmrs

  has_one :person, :class_name => "CorePerson", :foreign_key => :person_id, :conditions => {:voided => 0}
  has_many :patient_identifiers, :class_name => "CorePatientIdentifier", :foreign_key => :patient_id, :dependent => :destroy, :conditions => {:voided => 0}

  def after_void(reason = nil)
    self.person.void(reason) rescue nil
    self.patient_identifiers.each {|row| row.void(reason) }
    self.patient_programs.each {|row| row.void(reason) }
    self.orders.each {|row| row.void(reason) }
    self.encounters.each {|row| row.void(reason) }
  end

end
