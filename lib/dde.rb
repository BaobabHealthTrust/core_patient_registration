module DDE
 
    def self.search_and_or_create(json)
    
      raise "Argument expected to be a JSON Object" if (JSON.parse(json) rescue nil).nil?

      person = JSON.parse(json) rescue {}
      
      birthdate_year = person["birthdate"].to_date.year rescue "Unknown"
      birthdate_month = person["birthdate"].to_date.month rescue nil
      birthdate_day = person["birthdate"].to_date.day rescue nil
      gender = person["gender"] == "F" ? "Female" : "Male"

      passed = {
         "person"=>{"occupation"=>(person["person_attributes"]["occupation"] rescue nil),
         "age_estimate"=> (person["birthdate_estimated"] rescue nil),
         "cell_phone_number"=>(person["person_attributes"]["cell_phone_number"] rescue nil),
         "birth_month"=> birthdate_month ,
         "addresses"=>{"address1"=>(person["addresses"]["current_residence"] rescue nil),
              "address2"=>(person["addresses"]["home_district"] rescue nil),
              "city_village"=>(person["addresses"]["current_village"] rescue nil),
              "state_province"=>(person["addresses"]["current_district"] rescue nil),
              "neighborhood_cell"=>(person["addresses"]["home_village"] rescue nil),
              "township_division"=>(person["addresses"]["current_ta"] rescue nil),
              "county_district"=>(person["addresses"]["home_ta"] rescue nil)},
         "gender"=> gender ,
         "patient"=>{"identifiers"=>{"National id" => ((person["national_id"] || person["_id"]) || person["_id"])}},
         "birth_day"=>birthdate_day,
         "home_phone_number"=>(person["person_attributes"]["home_phone_number"] rescue nil),
         "names"=>{"family_name"=>(person["names"]["family_name"] rescue nil),
         "given_name"=>(person["names"]["given_name"] rescue nil),
         "middle_name"=>""},
         "birth_year"=>birthdate_year},
         "filter_district"=>"",
         "filter"=>{"region"=>"",
         "t_a"=>""},
         "relation"=>""
        }
        
      # Check if this patient exists locally
      result = CorePatientIdentifier.find_by_identifier((person["national_id"] || person["_id"]))
         
      if result.blank?
        # if patient does not exist locally, first verify if the patient is similar
        # to an existing one by national_id so you can update else create one
        
        (person["patient"]["identifiers"] rescue []).each do |identifier|
          
          result = CorePatientIdentifier.find_by_identifier(identifier[identifier.keys[0]],
              :conditions => ["identifier_type = ?", 
              CorePatientIdentifierType.find_by_name("National id").id]) rescue nil
          
          break if !result.blank?
          
        end
        
        if !result.blank?
        
        # raise (person["national_id"] || person["_id"]).inspect
      
          current_national_id = self.get_full_identifier("National id", result.patient_id)        
          self.set_identifier("National id", (person["national_id"] || person["_id"]), result.patient_id)
          self.set_identifier("Old Identification Number", current_national_id.identifier, result.patient_id)
          current_national_id.void("National ID version change")
        
        elsif person["patient_id"].blank?     
        
          self.create_from_form(passed["person"])
          
          result = CorePatientIdentifier.find_by_identifier((person["national_id"] || person["_id"]))
          
        else
        
          result = CorePatient.find(person["patient_id"]) rescue nil
          
        end
        
      else
      
        patient = result.patient 
      
        address = patient.person.addresses.last rescue nil
        
        local = {
            "gender"=>(patient.person.gender rescue nil), 
            "birthdate_estimated"=>(patient.person.birthdate_estimated rescue nil), 
            "patient_id"=>(patient.patient_id rescue nil), 
            "national_id"=>(patient.patient_identifiers.find_by_identifier_type(PatientIdentifierType.find_by_name("National id").id).identifier rescue nil), 
            "addresses"=>{
              "current_residence" => (address.address1 rescue nil),
              "current_village" => (address.city_village rescue nil),
              "current_ta" => (address.township_division rescue nil),
              "current_district" => (address.state_province rescue nil),
              "home_village" => (address.neighborhood_cell rescue nil),
              "home_ta" => (address.county_district rescue nil),
              "home_district" => (address.address2 rescue nil)
            }, 
            "person_attributes"=>{
              "occupation" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Occupation").id).value rescue nil),
              "cell_phone_number" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Cell Phone Number").id).value rescue nil),
              "home_phone_number" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Home Phone Number").id).value rescue nil),
              "race" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Race").id).value rescue nil),
              "citizenship" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Citizenship").id).value rescue nil)
            }, 
            "patient"=>{
              "identifiers"=>(patient.patient_identifiers.collect{|id| {id.type.name => id.identifier} if id.type.name.downcase != "national id"}.delete_if{|x| x.nil?} rescue [])
            }, 
            "birthdate"=>(patient.person.birthdate.strftime("%Y-%m-%d") rescue nil), 
            "names"=>{
              "given_name"=>(patient.person.names.first.given_name rescue nil), 
              "family_name"=>(patient.person.names.first.family_name rescue nil)
            }
          }
      
        if (local["gender"].downcase.strip != person["gender"].downcase.strip) or 
              (local["birthdate"].strip != person["birthdate"].strip) or 
              (local["birthdate_estimated"] != person["birthdate_estimated"])
              
          patient.person.update_attributes(
              "gender" => person["gender"], 
              "birthdate" => person["birthdate"], 
              "birthdate_estimated" => person["birthdate_estimated"]
            ) 
            
        end
        
        if (local["names"]["given_name"].downcase.strip != person["names"]["given_name"].downcase.strip) or 
              (local["names"]["family_name"].downcase.strip != person["names"]["family_name"].downcase.strip)
        
          patient.person.names.first.update_attributes(
              "given_name" => person["names"]["given_name"], 
              "family_name" => person["names"]["family_name"]
            ) 
          
        end
      
        defidtype = CorePatientIdentifierType.find_by_name("Unknown ID").id rescue nil
        
        (person["patient"]["identifiers"] rescue []).each do |identifier|
        
          if !local["patient"]["identifiers"].include?(identifier)
          
            idtype = CorePatientIdentifierType.find_by_name(identifier.keys[0]).id rescue nil
            
            if !defidtype.blank?
            
              uuid = CorePatientIdentifier.find_by_sql("SELECT UUID() uuid")
              
              CorePatientIdentifier.create(
                  "patient_id" => patient.id, 
                  "identifier" => identifier[identifier.keys[0]], 
                  "identifier_type" => (idtype || defidtype), 
                  "uuid" => uuid                
                )
            
            end
          
          end
        
        end
      
        fields = [
          {"occupation" => "Occupation"},
          {"cell_phone_number" => "Cell Phone Number"},
          {"home_phone_number" => "Home Phone Number"},
          {"race" => "Race"},
          {"citizenship" => "Citizenship"}
        ]
      
        fields.each do |field|
        
          if (local["person_attributes"][field.keys[0]] rescue nil).to_s.strip.downcase != (person["person_attributes"][field.keys[0]] rescue nil).to_s.strip.downcase
            pattribute = CorePersonAttribute.find_by_person_attribute_type_id(CorePersonAttributeType.find_by_name(field[field.keys[0]]).id) rescue nil
            
            if !pattribute.blank?
            
              pattribute.update_attributes("value" => (person["person_attributes"][field.keys[0]] rescue nil))
            
            else
            
             CorePersonAttribute.create(
                  "person_id" => patient.person.person_id, 
                  "value" => (person["person_attributes"][field.keys[0]] rescue nil),
                  "person_attribute_type_id" => CorePersonAttributeType.find_by_name(field[field.keys[0]]).id,
                  "uuid" => (CorersonAttribute.find_by_sql("SELECT UUID() uuid").first.uuid)
                )
            
            end
            
          end
          
        end
         
        if (local["addresses"]["current_residence"] rescue nil).to_s.strip.downcase != (person["addresses"]["current_residence"] rescue nil).to_s.strip.downcase or
            (local["addresses"]["current_village"] rescue nil).to_s.strip.downcase != (person["addresses"]["current_village"] rescue nil).to_s.strip.downcase or
            (local["addresses"]["current_ta"] rescue nil).to_s.strip.downcase != (person["addresses"]["current_ta"] rescue nil).to_s.strip.downcase or 
            (local["addresses"]["current_district"] rescue nil).to_s.strip.downcase != (person["addresses"]["current_district"] rescue nil).to_s.strip.downcase or
            (local["addresses"]["home_village"] rescue nil).to_s.strip.downcase != (person["addresses"]["home_village"] rescue nil).to_s.strip.downcase or
            (local["addresses"]["home_ta"] rescue nil).to_s.strip.downcase != (person["addresses"]["home_ta"] rescue nil).to_s.strip.downcase or 
            (local["addresses"]["home_district"] rescue nil).to_s.strip.downcase != (person["addresses"]["home_district"] rescue nil).to_s.strip.downcase
            
          address = patient.person.addresses.last # rescue nil
          
          if !address.blank?
          
            address.update_attributes(
                "address1" => (person["addresses"]["current_residence"] rescue nil),
                "address2" => (person["addresses"]["home_district"] rescue nil),
                "city_village" => (person["addresses"]["current_village"] rescue nil),
                "state_province" => (person["addresses"]["current_district"] rescue nil),
                "county_district" => (person["addresses"]["home_ta"] rescue nil),
                "neighborhood_cell" => (person["addresses"]["home_village"] rescue nil),
                "township_division" => (person["addresses"]["current_ta"] rescue nil)
              )
          
          else 
          
            CorePersonAddress.create(
                "person_id" => patient.person.id,
                "address1" => (person["addresses"]["current_residence"] rescue nil),
                "address2" => (person["addresses"]["home_district"] rescue nil),
                "city_village" => (person["addresses"]["current_village"] rescue nil),
                "state_province" => (person["addresses"]["current_district"] rescue nil),
                "county_district" => (person["addresses"]["home_ta"] rescue nil),
                "neighborhood_cell" => (person["addresses"]["home_village"] rescue nil),
                "township_division" => (person["addresses"]["current_ta"] rescue nil),
                "uuid" => (CorePersonAddress.find_by_sql("SELECT UUID() uuid").first.uuid)
              )
          
          end
            
        end 
        
        # raise local.inspect
      
      end
       
      return result.patient_id rescue nil
        
    end
    
    def self.get_full_identifier(identifier, patient_id)
      CorePatientIdentifier.find(:first,:conditions =>["voided = 0 AND identifier_type = ? AND patient_id = ?",
          CorePatientIdentifierType.find_by_name(identifier).id, patient_id]) rescue nil
    end

    def self.set_identifier(identifier, value, patient_id)
      CorePatientIdentifier.create(:patient_id => patient_id, :identifier => value,
        :identifier_type => (CorePatientIdentifierType.find_by_name(identifier).id))
    end

	  def self.create_from_form(params)

		  address_params = params["addresses"]
		  names_params = params["names"]
		  patient_params = params["patient"]
		  params_to_process = params.reject{|key,value| key.match(/addresses|patient|names|relation|cell_phone_number|home_phone_number|office_phone_number|agrees_to_be_visited_for_TB_therapy|agrees_phone_text_for_TB_therapy/) }
		  birthday_params = params_to_process.reject{|key,value| key.match(/gender/) }
		  person_params = params_to_process.reject{|key,value| key.match(/birth_|age_estimate|occupation|identifiers|attributes/) }

		  if person_params["gender"].to_s == "Female"
        person_params["gender"] = 'F'
		  elsif person_params["gender"].to_s == "Male"
        person_params["gender"] = 'M'
		  end

		  person = CorePerson.create(person_params)

		  unless birthday_params.empty?
		    if birthday_params["birth_year"] == "Unknown"
          self.set_birthdate_by_age(person, birthday_params["age_estimate"], person.session_datetime || Date.today)
		    else
          self.set_birthdate(person, birthday_params["birth_year"], birthday_params["birth_month"], birthday_params["birth_day"])
		    end
		  end
		  person.save

		  person.names.create(names_params)
		  person.addresses.create(address_params) unless address_params.empty? rescue nil

		  person.person_attributes.create(
		    :person_attribute_type_id => CorePersonAttributeType.find_by_name("Occupation").person_attribute_type_id,
		    :value => params["occupation"]) unless params["occupation"].blank? rescue nil

		  person.person_attributes.create(
		    :person_attribute_type_id => CorePersonAttributeType.find_by_name("Cell Phone Number").person_attribute_type_id,
		    :value => params["cell_phone_number"]) unless params["cell_phone_number"].blank? rescue nil

		  person.person_attributes.create(
		    :person_attribute_type_id => CorePersonAttributeType.find_by_name("Office Phone Number").person_attribute_type_id,
		    :value => params["office_phone_number"]) unless params["office_phone_number"].blank? rescue nil

		  person.person_attributes.create(
		    :person_attribute_type_id => CorePersonAttributeType.find_by_name("Home Phone Number").person_attribute_type_id,
		    :value => params["home_phone_number"]) unless params["home_phone_number"].blank? rescue nil

      # TODO handle the birthplace attribute

		  if (!patient_params.nil?)
		    patient = person.create_patient

		    patient_params["identifiers"].each{|identifier_type_name, identifier|
          next if identifier.blank?
          identifier_type = CorePatientIdentifierType.find_by_name(identifier_type_name) || CorePatientIdentifierType.find_by_name("Unknown id")
          patient.patient_identifiers.create("identifier" => identifier, "identifier_type" => identifier_type.patient_identifier_type_id)
		    } if patient_params["identifiers"]

		    # This might actually be a national id, but currently we wouldn't know
		    #patient.patient_identifiers.create("identifier" => patient_params["identifier"], "identifier_type" => PatientIdentifierType.find_by_name("Unknown id")) unless params["identifier"].blank?
		  end

		  return person
	  end

    def self.set_birthdate_by_age(person, age, today = Date.today)
      person.birthdate = Date.new(today.year - age.to_i, 7, 1)
      person.birthdate_estimated = 1
    end

    def self.set_birthdate(person, year = nil, month = nil, day = nil)
      raise "No year passed for estimated birthdate" if year.nil?

      # Handle months by name or number (split this out to a date method)
      month_i = (month || 0).to_i
      month_i = Date::MONTHNAMES.index(month) if month_i == 0 || month_i.blank?
      month_i = Date::ABBR_MONTHNAMES.index(month) if month_i == 0 || month_i.blank?

      if month_i == 0 || month == "Unknown"
        person.birthdate = Date.new(year.to_i,7,1)
        person.birthdate_estimated = 1
      elsif day.blank? || day == "Unknown" || day == 0
        person.birthdate = Date.new(year.to_i,month_i,15)
        person.birthdate_estimated = 1
      else
        person.birthdate = Date.new(year.to_i,month_i,day.to_i)
        person.birthdate_estimated = 0
      end
    end

    def self.compare_people(personA,personB )

      single_attributes = ['birthdate', 'gender']
      addresses = ['current_residence','current_village','current_ta','current_district','home_village','home_ta','home_district',]
      attributes = ['citizenship', 'race', 'occupation','home_phone_number', 'cell_phone_number']

      single_attributes.each do |metric|
        if ((personA[metric].gsub(/\-/,"").gsub(/\//, "") rescue "") || "").strip.downcase != ((personB[metric].gsub(/\-/,"").gsub(/\//, "") rescue "") || "").strip.downcase
          return false
        end
      end

      addresses.each do |metric|
        if ((personA['addresses'][metric] rescue "") || "").strip.downcase != ((personB['addresses'][metric] rescue "") || "").strip.downcase
          return false
        end
      end

      return true

    end
    
end
