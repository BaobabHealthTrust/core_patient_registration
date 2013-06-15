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

  def name
    "#{self.person.names.first.given_name} #{self.person.names.first.family_name}"
  end

  def national_id(force = true)
    id = self.patient_identifiers.find_by_identifier_type(CorePatientIdentifierType.find_by_name("National id").id).identifier rescue nil
    return id unless force
    id ||= CorePatientIdentifierType.find_by_name("National id").next_identifier(:patient => self).identifier
    id
  end

  def address
    "#{self.person.addresses.first.city_village}" rescue nil
  end

  def age(today = Date.today)
    return nil if self.person.birthdate.nil?

    # This code which better accounts for leap years
    patient_age = (today.year - self.person.birthdate.year) + ((today.month -
          self.person.birthdate.month) + ((today.day - self.person.birthdate.day) < 0 ? -1 : 0) < 0 ? -1 : 0)

    # If the birthdate was estimated this year, we round up the age, that way if
    # it is March and the patient says they are 25, they stay 25 (not become 24)
    birth_date=self.person.birthdate
    estimate=self.person.birthdate_estimated==1
    patient_age += (estimate && birth_date.month == 7 && birth_date.day == 1  &&
        today.month < birth_date.month && self.person.date_created.year == today.year) ? 1 : 0
  end

  def gender
    self.person.gender rescue nil
  end

  def national_id_with_dashes
    id = national_id
    length = id.length
    case length
    when 13
      id[0..4] + "-" + id[5..8] + "-" + id[9..-1] rescue id
    when 9
      id[0..2] + "-" + id[3..6] + "-" + id[7..-1] rescue id
    when 6
      id[0..2] + "-" + id[3..-1] rescue id
    else
      id
    end
  end

  def age_in_months(today = Date.today)
    years = (today.year - self.person.birthdate.year)
    months = (today.month - self.person.birthdate.month)
    (years * 12) + months
  end

  def birthdate_formatted
    if self.person.birthdate_estimated==1
      if self.person.birthdate.day == 1 and self.person.birthdate.month == 7
        self.person.birthdate.strftime("??/???/%Y")
      elsif self.person.birthdate.day == 15
        self.person.birthdate.strftime("??/%b/%Y")
      elsif self.person.birthdate.day == 1 and self.person.birthdate.month == 1
        self.person.birthdate.strftime("??/???/%Y")
      end
    else
      self.person.birthdate.strftime("%d/%b/%Y")
    end
  end

  def get_attribute(attribute)
    CorePersonAttribute.find(:first,:conditions =>["voided = 0 AND person_attribute_type_id = ? AND person_id = ?",
        CorePersonAttributeType.find_by_name(attribute).id, self.person.id]).value rescue nil
  end

end
