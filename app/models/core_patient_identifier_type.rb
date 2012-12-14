class CorePatientIdentifierType < ActiveRecord::Base
  set_table_name "patient_identifier_type"
  set_primary_key "patient_identifier_type_id"
  include CoreOpenmrs

  def next_identifier(options = {})
    return nil unless options[:patient]
    case self.name
      when "National id"
        unless use_moh_national_id
          health_center_id = CoreLocation.current_location.site_id rescue "1"
          national_id_version = "1"
          national_id_prefix = "P#{national_id_version}#{health_center_id.rjust(3,"0")}"

          last_national_id = CorePatientIdentifier.find(:first,:order=>"identifier desc", 
            :conditions => ["(identifier_type = ? OR identifier_type = ?) AND left(identifier,5)= ?",
              self.patient_identifier_type_id, 
              CorePatientIdentifierType.find_by_name("Old Identification Number").id,
              national_id_prefix])
          last_national_id_number = last_national_id.identifier rescue "0"

          next_number = (last_national_id_number[5..-2].to_i+1).to_s.rjust(7,"0") 
          new_national_id_no_check_digit = "#{national_id_prefix}#{next_number}"
          check_digit = CorePatientIdentifier.calculate_checkdigit(new_national_id_no_check_digit[1..-1])
          new_national_id = "#{new_national_id_no_check_digit}#{check_digit}" 
        else
          new_national_id = NationalId.next_id(options[:patient].patient_id) 
        end
        patient_identifier = CorePatientIdentifier.new
        patient_identifier.type = self
        patient_identifier.identifier = new_national_id
        patient_identifier.patient = options[:patient]
        patient_identifier.save!
        patient_identifier
    end
  end

  private

  def use_moh_national_id
    CoreGlobalProperty.find_by_property('use.moh.national.id').property_value == "yes" rescue false
  end

end
