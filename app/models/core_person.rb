class CorePerson < ActiveRecord::Base
  require "bean"
  set_table_name "person"
  set_primary_key "person_id"
  include CoreOpenmrs

  cattr_accessor :session_datetime
  cattr_accessor :migrated_datetime
  cattr_accessor :migrated_creator
  cattr_accessor :migrated_location

  has_one :patient, :class_name => "CorePatient", :foreign_key => :patient_id, :dependent => :destroy, :conditions => {:voided => 0}
  has_many :names, :class_name => 'CorePersonName', :foreign_key => :person_id, :dependent => :destroy, :order => 'person_name.preferred DESC', :conditions => {:voided => 0}
  has_many :addresses, :class_name => 'CorePersonAddress', :foreign_key => :person_id, :dependent => :destroy, :order => 'person_address.preferred DESC', :conditions => {:voided => 0}
  has_many :person_attributes, :class_name => 'CorePersonAttribute', :foreign_key => :person_id, :conditions => {:voided => 0}

  def after_void(reason = nil)
    self.patient.void(reason) rescue nil
    self.names.each{|row| row.void(reason) }
    self.addresses.each{|row| row.void(reason) }
    # self.relationships.each{|row| row.void(reason) }
    self.person_attributes.each{|row| row.void(reason) }
    # We are going to rely on patient => encounter => obs to void those
  end

  def self.create_patient_from_dde(params, dont_recreate_local=false)
    
	  address_params = params["person"]["addresses"]
		names_params = params["person"]["names"]
		patient_params = params["person"]["patient"]
    birthday_params = params["person"]
		params_to_process = params.reject{|key,value|
      key.match(/identifiers|addresses|patient|names|relation|cell_phone_number|home_phone_number|office_phone_number|agrees_to_be_visited_for_TB_therapy|agrees_phone_text_for_TB_therapy/)
    }
		birthday_params = params_to_process["person"].reject{|key,value| key.match(/gender/) }
		person_params = params_to_process["person"].reject{|key,value| key.match(/birth_|age_estimate|occupation/) }


		if person_params["gender"].to_s == "Female"
      person_params["gender"] = 'F'
		elsif person_params["gender"].to_s == "Male"
      person_params["gender"] = 'M'
		end

		unless birthday_params.empty?
		  if birthday_params["birth_year"] == "Unknown"
			  birthdate = Date.new(Date.today.year - birthday_params["age_estimate"].to_i, 7, 1)
        birthdate_estimated = 1
		  else
			  year = birthday_params["birth_year"]
        month = birthday_params["birth_month"]
        day = birthday_params["birth_day"]

        month_i = (month || 0).to_i
        month_i = Date::MONTHNAMES.index(month) if month_i == 0 || month_i.blank?
        month_i = Date::ABBR_MONTHNAMES.index(month) if month_i == 0 || month_i.blank?

        if month_i == 0 || month == "Unknown"
          birthdate = Date.new(year.to_i,7,1)
          birthdate_estimated = 1
        elsif day.blank? || day == "Unknown" || day == 0
          birthdate = Date.new(year.to_i,month_i,15)
          birthdate_estimated = 1
        else
          birthdate = Date.new(year.to_i,month_i,day.to_i)
          birthdate_estimated = 0
        end
		  end
    else
      birthdate_estimated = 0
		end

    passed_params = {"person"=>
        {"data" =>
          {"addresses"=>
            {"address1"=> (address_params["address1"] rescue ""),
            "address2"=> (address_params["address2"] rescue ""),
            "state_province"=> (address_params["state_province"] rescue ""),
            "county_district"=> (address_params["county_district"] rescue ""),
            "neighborhood_cell"=> (address_params["neighborhood_cell"] rescue ""),
            "city_village"=> (address_params["city_village"] rescue "")
          },
          "attributes"=>
            {"occupation"=> (params["person"]["occupation"] rescue ""),
            "cell_phone_number" => (params["person"]["cell_phone_number"] rescue ""),
            "home_phone_number" => (params["person"]["home_phone_number"] rescue ""),
            "office_phone_number" => (params["person"]["office_phone_number"] rescue ""),
            "citizenship" => (params["person"]["citizenship"] rescue ""),
            "race" => (params["person"]["race"] rescue "")
          },
          "patient"=>
            {"identifiers"=>
              {
              "diabetes_number"=>""
            }
          },
          "gender"=> person_params["gender"],
          "birthdate"=> birthdate,
          "birthdate_estimated"=> birthdate_estimated ,
          "names"=>{
            "family_name"=> names_params["family_name"],
            "given_name"=> names_params["given_name"],
            "family_name2"=> names_params["family_name2"],
            "middle_name"=> names_params["middle_name"]
          }
        }
      }
    }

    if !params["remote"]

      @dde_server = self.get_global_property_value("dde_server_ip") rescue "" # CoreGlobalProperty.find_by_property("dde_server_ip").property_value rescue ""

      @dde_server_username = self.get_global_property_value("dde_server_username") rescue "" # CoreGlobalProperty.find_by_property("dde_server_username").property_value rescue ""

      @dde_server_password = self.get_global_property_value("dde_server_password") rescue "" # CoreGlobalProperty.find_by_property("dde_server_password").property_value rescue ""

      uri = "http://#{@dde_server_username}:#{@dde_server_password}@#{@dde_server}/people.json/"

      recieved_params = RestClient.post(uri, passed_params)

      national_id = JSON.parse(recieved_params)["npid"]["value"]
    else
      national_id = params["person"]["patient"]["identifiers"]["National_id"]
    end


    if (dont_recreate_local == false)
      person = self.create_from_form(params["person"])

      identifier_type = CorePatientIdentifierType.find_by_name("National id") || CorePatientIdentifierType.find_by_name("Unknown id")

      person.patient.patient_identifiers.create("identifier" => national_id,
        "identifier_type" => identifier_type.patient_identifier_type_id) unless national_id.blank?
      return person
    else

      return national_id
    end
    
  end
  
  def self.search_from_remote(params)
    return [] if params[:given_name].blank?
    dde_server = CoreGlobalProperty.find_by_property("dde_server_ip").property_value
    dde_server_username = CoreGlobalProperty.find_by_property("dde_server_username").property_value rescue ""
    dde_server_password = CoreGlobalProperty.find_by_property("dde_server_password").property_value rescue ""
    uri = "http://#{dde_server_username}:#{dde_server_password}@#{dde_server}/people/find.json/"

    return JSON.parse(RestClient.post(uri,params))
  end
  
  def self.get_global_property_value(global_property)
		property_value = Settings[global_property]
		if property_value.nil?
			property_value = CoreGlobalProperty.find(:first, :conditions => {:property => "#{global_property}"}
      ).property_value rescue nil
		end
		return property_value
	end

  def self.create_from_form(params)
    
    return nil if params.blank?
		address_params = params["addresses"]
		names_params = params["names"]
		patient_params = params["patient"]
		params_to_process = params.reject{|key,value| key.match(/addresses|patient|names|relation|cell_phone_number|home_phone_number|office_phone_number|agrees_to_be_visited_for_TB_therapy|agrees_phone_text_for_TB_therapy/) }
		birthday_params = params_to_process.reject{|key,value| key.match(/gender/) }
		person_params = params_to_process.reject{|key,value| key.match(/birth_|citizenship|race|age_estimate|occupation|identifiers/) }

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

    unless person_params['birthdate_estimated'].blank?
      person.birthdate_estimated = person_params['birthdate_estimated'].to_i
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

    person.person_attributes.create(
		  :person_attribute_type_id => CorePersonAttributeType.find_by_name("Citizenship").person_attribute_type_id,
		  :value => params["citizenship"]) unless params["citizenship"].blank? rescue nil

    person.person_attributes.create(
		  :person_attribute_type_id => CorePersonAttributeType.find_by_name("Race").person_attribute_type_id,
		  :value => params["race"]) unless params["race"].blank? rescue nil
    # TODO handle the birthplace attribute

		if (!patient_params.nil?)
		  patient = person.create_patient
      params["identifiers"].each{|identifier_type_name, identifier|
        next if identifier.blank?
        identifier_type = CorePatientIdentifierType.find_by_name(identifier_type_name) || CorePatientIdentifierType.find_by_name("Unknown id")
        patient.patient_identifiers.create("identifier" => identifier, "identifier_type" => identifier_type.patient_identifier_type_id)
		  } if params["identifiers"]

		  # This might actually be a national id, but currently we wouldn't know
		  #patient.patient_identifiers.create("identifier" => patient_params["identifier"], "identifier_type" => PatientIdentifierType.find_by_name("Unknown id")) unless params["identifier"].blank?
		end

		return person
	end

  def self.cul_age(birthdate , birthdate_estimated , date_created = Date.today, today = Date.today)

    # This code which better accounts for leap years
    patient_age = (today.year - birthdate.year) + ((today.month - birthdate.month) + ((today.day - birthdate.day) < 0 ? -1 : 0) < 0 ? -1 : 0)

    # If the birthdate was estimated this year, we round up the age, that way if
    # it is March and the patient says they are 25, they stay 25 (not become 24)
    birth_date = birthdate
    estimate = birthdate_estimated == 1
    patient_age += (estimate && birth_date.month == 7 && birth_date.day == 1  &&
        today.month < birth_date.month && date_created.year == today.year) ? 1 : 0
  end


  def self.get_birthdate_formatted(birthdate,birthdate_estimated)
    if birthdate_estimated == 1
      if birthdate.day == 1 and birthdate.month == 7
        birthdate.strftime("??/???/%Y")
      elsif birthdate.day == 15
        birthdate.strftime("??/%b/%Y")
      elsif birthdate.day == 1 and birthdate.month == 1
        birthdate.strftime("??/???/%Y")
      end
    else
      birthdate.strftime("%d/%b/%Y")
    end
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

  def national_id_label
    return unless self.national_id
    sex =  self.patient.person.gender.match(/F/i) ? "(F)" : "(M)"
    address = self.address.strip[0..24].humanize.delete("'") rescue ""
    label = ZebraPrinter::StandardLabel.new
    label.font_size = 2
    label.font_horizontal_multiplier = 2
    label.font_vertical_multiplier = 2
    label.left_margin = 50
    label.draw_barcode(50,180,0,1,5,15,120,false,"#{self.national_id}")
    label.draw_multi_text("#{self.name.titleize.delete("'")}") #'
    label.draw_multi_text("#{self.national_id_with_dashes} #{self.birthdate_formatted}#{sex}")
    label.draw_multi_text("#{address}")
    label.print(1)
  end

  def baby_national_id_label
    return unless self.national_id
    sex =  self.patient.person.gender.match(/F/i) ? "(F)" : "(M)"
    address = self.address.strip[0..24].humanize.delete("'") rescue ""
    label = ZebraPrinter::StandardLabel.new
    label.font_size = 2
    label.font_horizontal_multiplier = 2
    label.font_vertical_multiplier = 2
    label.left_margin = 50
    label.draw_barcode(50,180,0,1,5,15,120,false,"#{self.national_id}")
    label.draw_multi_text("#{self.name.titleize.delete("'")}") #'
    label.draw_multi_text("#{self.national_id_with_dashes} #{self.birthdate_formatted}#{sex}")
    label.draw_multi_text("#{address}")
    label.print(1)
  end

  def national_id(force = true)
    id = self.patient.patient_identifiers.find_by_identifier_type(CorePatientIdentifierType.find_by_name("National id").id).identifier rescue nil
    return id unless force
    id ||= CorePatientIdentifierType.find_by_name("National id").next_identifier(:patient => self.patient).identifier
    id
  end

  def national_id_with_dashes(force = true)
    id = self.national_id(force)
    id[0..4] + "-" + id[5..8] + "-" + id[9..-1] rescue id
  end

  def name
    "#{self.names.first.given_name} #{self.names.first.family_name}".titleize rescue nil
  end

  def address
    "#{self.addresses.first.city_village}" rescue nil
  end

  def birthdate_formatted
    if self.birthdate_estimated==1
      if self.birthdate.day == 1 and self.birthdate.month == 7
        self.birthdate.strftime("??/???/%Y")
      elsif self.birthdate.day == 15
        self.birthdate.strftime("??/%b/%Y")
      end
    else
      self.birthdate.strftime("%d/%b/%Y")
    end
  end

  def self.search_by_identifier(identifier)
 
    identifier = identifier.gsub("-","").strip
    people = CorePatientIdentifier.find_all_by_identifier(identifier).map{|id|
      id.patient.person
    } unless identifier.blank? rescue nil

    return people unless people.blank?
    create_from_dde_server = CoreService.get_global_property_value('create.from.dde.server').to_s == "true" rescue false
    if create_from_dde_server
      dde_server = CoreGlobalProperty.find_by_property("dde_server_ip").property_value rescue ""
      dde_server_username = CoreGlobalProperty.find_by_property("dde_server_username").property_value rescue ""
      dde_server_password = CoreGlobalProperty.find_by_property("dde_server_password").property_value rescue ""
      uri = "http://#{dde_server_username}:#{dde_server_password}@#{dde_server}/people/find.json"
      uri += "?value=#{identifier}"
      p = JSON.parse(RestClient.get(uri))
     
      return [] if p.blank?
      return "found duplicate identifiers" if p.count > 1
      p = p.first
      passed_national_id = (p["person"]["patient"]["identifiers"]["National id"]) rescue nil
      passed_national_id = (p["person"]["value"]) if passed_national_id.blank? rescue nil
     
      if passed_national_id.blank?
        return [DDEService.get_remote_person(p["person"]["id"])]
      end

      birthdate_year = p["person"]["birthdate"].to_date.year rescue "Unknown"
      birthdate_month = p["person"]["birthdate"].to_date.month rescue nil
      birthdate_day = p["person"]["birthdate"].to_date.day rescue nil
      birthdate_estimated = p["person"]["birthdate_estimated"]
      gender = p["person"]["gender"] == "F" ? "Female" : "Male"

      passed = {
        "person"=>{"occupation"=>p["person"]["data"]["attributes"]["occupation"],
          "age_estimate"=> birthdate_estimated,
          "cell_phone_number"=>p["person"]["data"]["attributes"]["cell_phone_number"],
          "birth_month"=> birthdate_month ,
          "addresses"=>{"address1"=>p["person"]["data"]["addresses"]["address1"],
            "address2"=>p["person"]["data"]["addresses"]["address2"],
            "city_village"=>p["person"]["data"]["addresses"]["city_village"],
            "state_province"=>p["person"]["data"]["addresses"]["state_province"],
            "neighborhood_cell"=>p["person"]["data"]["addresses"]["neighborhood_cell"],
            "county_district"=>p["person"]["data"]["addresses"]["county_district"]},
          "gender"=> gender ,
          "patient"=>{"identifiers"=>{"National id" => p["person"]["value"]}},
          "birth_day"=>birthdate_day,
          "home_phone_number"=>p["person"]["data"]["attributes"]["home_phone_number"],
          "names"=>{"family_name"=>p["person"]["family_name"],
            "given_name"=>p["person"]["given_name"],
            "middle_name"=>""},
          "birth_year"=>birthdate_year},
        "filter_district"=>"",
        "filter"=>{"region"=>"",
          "t_a"=>""},
        "relation"=>""
      }

      unless passed_national_id.blank?
        patient = CorePatientIdentifier.find(:first,
          :conditions =>["voided = 0 AND identifier = ?",passed_national_id]).patient rescue nil
        return [patient.person] unless patient.blank?
      end

      passed["person"].merge!("identifiers" => {"National id" => passed_national_id})
      return [self.create_from_form(passed["person"])]
    end
    return people
  end

  def self.search_from_dde_by_identifier(identifier)
    dde_server = CoreGlobalProperty.find_by_property("dde_server_ip").property_value rescue ""
    dde_server_username = CoreGlobalProperty.find_by_property("dde_server_username").property_value rescue ""
    dde_server_password = CoreGlobalProperty.find_by_property("dde_server_password").property_value rescue ""
    uri = "http://#{dde_server_username}:#{dde_server_password}@#{dde_server}/people/find.json"
    uri += "?value=#{identifier}"
    people = JSON.parse(RestClient.get(uri)) rescue nil
    return [] if people.blank?

    local_people = []
    people.each do |person|
      national_id = person['person']["value"] rescue nil
      old_national_id = person["person"]["old_identification_number"] rescue nil

      birthdate_year = person["person"]["data"]["birthdate"].to_date.year rescue "Unknown"
      birthdate_month = person["person"]["data"]["birthdate"].to_date.month rescue nil
      birthdate_day = person["person"]["data"]["birthdate"].to_date.day rescue nil
      birthdate_estimated = person["person"]["data"]["birthdate_estimated"]
      gender = person["person"]["data"]["gender"] == "F" ? "Female" : "Male"
      passed_person = {
        "person"=>{"occupation"=>person["person"]["data"]["attributes"]["occupation"],
          "age_estimate"=> birthdate_estimated ,
          "birthdate" => person["person"]["data"]["birthdate"],
          "cell_phone_number"=> person["person"]["data"]["attributes"]["cell_phone_number"],
          "birth_month"=> birthdate_month ,
          "addresses"=>{"address1"=> person["person"]["data"]["addresses"]["county_district"],
            "address2"=> person["person"]["data"]["addresses"]["address2"],
            "city_village"=> person["person"]["data"]["addresses"]["city_village"],
            "county_district"=> person["person"]["data"]["addresses"]["county_district"],
            "state_province" => person["person"]["data"]["addresses"]["state_province"],
            "neighborhood_cell" => person["person"]["data"]["addresses"]["neighborhood_cell"]},
          "gender"=> gender ,
          "patient"=>{"identifiers"=>{"National id" => national_id ,"Old national id" => old_national_id}},
          "birth_day"=>birthdate_day,
          "home_phone_number"=>person["person"]["data"]["attributes"]["home_phone_number"],
          "names"=>{"family_name"=>person["person"]["data"]["names"]["family_name"],
            "given_name"=>person["person"]["data"]["names"]["given_name"],
            "middle_name"=>""},
          "birth_year"=>birthdate_year,
          "id" => person["person"]["id"]},
        "relation"=>""
      }
      local_people << passed_person
    end
    return local_people
  end

  def self.get_dde_person(person, current_date = Date.today)
    patient = PatientBean.new('')
    patient.person_id = person["person"]["id"]
    patient.patient_id = 0
    patient.address = person["person"]["addresses"]["city_village"]
    patient.national_id = person["person"]["patient"]["identifiers"]["National id"]
    patient.name = person["person"]["names"]["given_name"] + ' ' + person["person"]["names"]["family_name"] rescue nil
    patient.first_name = person["person"]["names"]["given_name"] rescue nil
    patient.last_name = person["person"]["names"]["family_name"] rescue nil
    patient.sex = person["person"]["gender"]
    patient.birthdate = person["person"]["birthdate"].to_date
    patient.birthdate_estimated =  person["person"]["age_estimate"].to_i rescue 0
    date_created =  person["person"]["date_created"].to_date rescue Date.today
    patient.age = self.cul_age(patient.birthdate , patient.birthdate_estimated , date_created, Date.today)
    patient.birth_date = self.get_birthdate_formatted(patient.birthdate,patient.birthdate_estimated)
    patient.home_district = person["person"]["addresses"]["address2"]
    patient.current_district = person["person"]["addresses"]["state_province"]
    patient.traditional_authority = person["person"]["addresses"]["county_district"]
    patient.current_residence = person["person"]["addresses"]["city_village"]
    patient.landmark = person["person"]["addresses"]["address1"]
    patient.home_village = person["person"]["addresses"]["neighborhood_cell"]
    patient.occupation = person["person"]["occupation"]
    patient.cell_phone_number = person["person"]["cell_phone_number"]
    patient.home_phone_number = person["person"]["home_phone_number"]
    patient.old_identification_number = person["person"]["patient"]["identifiers"]["Old national id"]
    patient.national_id  = patient.old_identification_number if patient.national_id.blank?
    patient
  end

  def self.get_patient(person, current_date = Date.today)
    patient = PatientBean.new('')
    patient.person_id = person.id
    patient.patient_id = person.patient.id
    patient.arv_number = get_patient_identifier(person.patient, 'ARV Number')
    patient.address = person.addresses.first.city_village rescue nil
    patient.national_id = get_patient_identifier(person.patient, 'National id')
	  patient.national_id_with_dashes = get_national_id_with_dashes(person.patient)
    patient.name = person.names.first.given_name + ' ' + person.names.first.family_name rescue nil
		patient.first_name = person.names.first.given_name rescue nil
		patient.last_name = person.names.first.family_name rescue nil
    patient.sex = sex(person)
    patient.age = age(person, current_date)
    patient.age_in_months = age_in_months(person, current_date)
    patient.dead = person.dead
    patient.birth_date = birthdate_formatted(person)
    patient.birthdate_estimated = person.birthdate_estimated rescue nil
    patient.current_district = person.addresses.first.state_province rescue nil
    patient.home_district = person.addresses.first.address2 rescue nil
    patient.traditional_authority = person.addresses.first.county_district rescue nil
    patient.current_residence = person.addresses.first.city_village rescue nil
    patient.landmark = person.addresses.first.address1 rescue nil
    patient.home_village = person.addresses.first.neighborhood_cell rescue nil
    patient.mothers_surname = person.names.first.family_name2 rescue nil
    patient.eid_number = get_patient_identifier(person.patient, 'EID Number') rescue nil
    patient.pre_art_number = get_patient_identifier(person.patient, 'Pre ART Number (Old format)') rescue nil
    patient.archived_filing_number = get_patient_identifier(person.patient, 'Archived filing number')rescue nil
    patient.filing_number = get_patient_identifier(person.patient, 'Filing Number')
    patient.occupation = get_attribute(person, 'Occupation')
    patient.cell_phone_number = get_attribute(person, 'Cell phone number')
    patient.office_phone_number = get_attribute(person, 'Office phone number')
    patient.home_phone_number = get_attribute(person, 'Home phone number')
    patient.guardian = art_guardian(person.patient) rescue nil
    patient    
  end

  def self.get_patient_identifier(patient, identifier_type)
    patient_identifier_type_id = PatientIdentifierType.find_by_name(identifier_type).patient_identifier_type_id rescue nil
    patient_identifier = PatientIdentifier.find(:first, :select => "identifier",
      :conditions  =>["patient_id = ? and identifier_type = ?", patient.id, patient_identifier_type_id],
      :order => "date_created DESC" ).identifier rescue nil
    return patient_identifier
  end

  def self.get_national_id_with_dashes(patient, force = true)
    id = self.get_national_id(patient, force)
    if id.length > 7
      id[0..4] + "-" + id[5..8] + "-" + id[9..-1] rescue id
    else
      "#{id[0..2]}-#{id[3..(id.length-1)]}"
    end
  end

  def self.birthdate_formatted(person)
    if person.birthdate_estimated==1
      if person.birthdate.day == 1 and person.birthdate.month == 7
        person.birthdate.strftime("??/???/%Y")
      elsif person.birthdate.day == 15
        person.birthdate.strftime("??/%b/%Y")
      elsif person.birthdate.day == 1 and person.birthdate.month == 1
        person.birthdate.strftime("??/???/%Y")
      end
    else
      person.birthdate.strftime("%d/%b/%Y")
    end
  end
  

  def self.get_national_id(patient, force = true)
    id = patient.patient_identifiers.find_by_identifier_type(CorePatientIdentifierType.find_by_name("National id").id).identifier rescue nil
    return id unless force
    id ||= CorePatientIdentifierType.find_by_name("National id").next_identifier(:patient => patient).identifier
    id
  end
  
  def age(today = Date.today)
    return nil if self.birthdate.nil?

    # This code which better accounts for leap years
    patient_age = (today.year - self.birthdate.year) + ((today.month -
          self.birthdate.month) + ((today.day - self.birthdate.day) < 0 ? -1 : 0) < 0 ? -1 : 0)

    # If the birthdate was estimated this year, we round up the age, that way if
    # it is March and the patient says they are 25, they stay 25 (not become 24)
    birth_date=self.birthdate
    estimate=self.birthdate_estimated==1
    patient_age += (estimate && birth_date.month == 7 && birth_date.day == 1  &&
        today.month < birth_date.month && self.date_created.year == today.year) ? 1 : 0
  end

  def self.sex(person)
    value = nil
    if person.gender == "M"
      value = "Male"
    elsif person.gender == "F"
      value = "Female"
    end
    value
  end

  def age_in_months(today = Date.today)
    years = (today.year - self.birthdate.year)
    months = (today.month - self.birthdate.month)
    (years * 12) + months
  end 
    
  def maiden_name
    self.names.last.family_name2 rescue ""
  end

  def first_name
    self.names.last.given_name rescue ""
  end

  def last_name
    self.names.last.family_name rescue ""
  end

  def middle_name
    self.names.last.middle_name rescue ""
  end

  def home_phone_number
    self.person_attributes.find_by_person_attribute_type_id(
      CorePersonAttributeType.find_by_name("Home Phone Number").id).value rescue ""
  end

  def nationality
    self.person_attributes.find_by_person_attribute_type_id(
      CorePersonAttributeType.find_by_name("Citizenship").id).value rescue ""
  end

  def office_phone_number
    self.person_attributes.find_by_person_attribute_type_id(
      CorePersonAttributeType.find_by_name("Office Phone Number").id).value rescue ""
  end

  def cell_phone_number
    self.person_attributes.find_by_person_attribute_type_id(
      CorePersonAttributeType.find_by_name("Cell Phone Number").id).value rescue ""
  end

  def occupation
    self.person_attributes.find_by_person_attribute_type_id(
      CorePersonAttributeType.find_by_name("Occupation").id).value rescue ""
  end

  def nationality
    citizenship = self.person_attributes.find_by_person_attribute_type_id(
      CorePersonAttributeType.find_by_name("Citizenship").id).value rescue ""

    if citizenship.downcase == "other"
      citizenship = self.person_attributes.find_by_person_attribute_type_id(
        CorePersonAttributeType.find_by_name("Race").id).value rescue ""
    end

    citizenship
  end

  def home_village
    self.addresses.last.neighborhood_cell rescue ""
  end

  def district_of_origin
    self.addresses.last.address2 rescue ""
  end

  def current_residence_location
    self.addresses.last.city_village rescue ""
  end

  def ancestral_t_a
    self.addresses.last.county_district rescue ""
  end

  def landmark_or_plot_number
    self.addresses.last.address1 rescue ""
  end

  def current_district
    self.addresses.last.state_province rescue ""
  end

  def demographics
    {
      "birth date" => self.birthdate_formatted,
      "gender" => self.gender,
      "attributes"=>{
        "home phone number" => home_phone_number,
        "nationality" => nationality,
        "office phone number" => office_phone_number,
        "occupation" => occupation,
        "cell phone number" => cell_phone_number
      },
      "addresses"=>{
        "home village" => home_village,
        "district of origin" => district_of_origin,
        "current residence" => current_residence_location,
        "ancestral traditional authority" => ancestral_t_a,
        "landmark or plot number" => landmark_or_plot_number,
        "current district" => current_district
      },
      "names"=>{
        "first name" => first_name,
        "middle name" => middle_name,
        "last name" => last_name,
        "maiden name" => maiden_name
      },
      "patient"=>{
        "identifiers"=>{
          "national id" => national_id
        }
      },
      "birthdate estimated" => "1",
      "patient_id" => self.id
    }
  end

  def self.age_in_months(person, today = Date.today)
    years = (today.year - person.birthdate.year)
    months = (today.month - person.birthdate.month)
    (years * 12) + months
  end
  
  def self.age(person, today = Date.today)
    return nil if person.birthdate.nil?

    # This code which better accounts for leap years
    patient_age = (today.year - person.birthdate.year) + ((today.month - person.birthdate.month) + ((today.day - person.birthdate.day) < 0 ? -1 : 0) < 0 ? -1 : 0)

    # If the birthdate was estimated this year, we round up the age, that way if
    # it is March and the patient says they are 25, they stay 25 (not become 24)
    birth_date=person.birthdate
    estimate=person.birthdate_estimated==1
    patient_age += (estimate && birth_date.month == 7 && birth_date.day == 1  &&
        today.month < birth_date.month && person.date_created.year == today.year) ? 1 : 0
  end

  def check_old_national_id(identifier, user_id)
    create_from_dde_server = get_global_property_value('create.from.dde.server').to_s == "true" rescue false
    
    if create_from_dde_server

      if identifier.to_s.strip.length != 6 and identifier == self.national_id

        dde_server = get_global_property_value("dde_server_ip").to_s rescue ""
        dde_server_username = get_global_property_value("dde_server_username").to_s rescue ""
        dde_server_password = get_global_property_value("dde_server_password").to_s rescue ""
        uri = "http://#{dde_server_username}:#{dde_server_password}@#{dde_server}/people/find.json"
        uri += "?value=#{identifier}"
        p = JSON.parse(RestClient.get(uri)).first rescue nil

        if !p.blank?

          current_national_id = get_full_identifier("National id")

          if current_national_id.identifier == identifier

            set_identifier("Old Identification Number", current_national_id.identifier)

            current_national_id.void("National ID version change", user_id)

            set_identifier("National id", p["person"]["value"])

          end

          return true

        end
        
        person = {"person" => {
            "birthdate_estimated" => (self.person.birthdate_estimated rescue nil),
            "gender" => (self.gender rescue nil),
            "birthdate" => (self.birthdate rescue nil),
            "birth_year" => (self.birthdate.to_date.year rescue nil),
            "birth_month" => (self.birthdate.to_date.month rescue nil),
            "birth_day" => (self.birthdate.to_date.date rescue nil),
            "names" => {
              "given_name" => self.first_name,
              "family_name" => self.last_name,
              "family_name2" => self.maiden_name,
              "middle_name" => self.middle_name
            },
            "patient" => {
              "identifiers" => {
                "old_identification_number" => self.national_id
              }
            },
            "attributes" => {
              "occupation" => (self.get_full_attribute("Occupation").value rescue nil),
              "cell_phone_number" => (self.get_full_attribute("Cell Phone Number").value rescue nil),
              "office_phone_number" => (self.get_full_attribute("Office Phone Number").value rescue nil),
              "home_phone_number" => (self.get_full_attribute("Home Phone Number").value rescue nil),
              "citizenship" => (self.get_full_attribute("Citizenship").value rescue nil),
              "race" => (self.get_full_attribute("Race").value rescue nil)
            },
            "addresses" => {
              "address1" => (self.landmark_or_plot_number rescue nil),
              "city_village" => (self.current_residence_location rescue nil),
              "address2" => (self.current_district rescue nil),
              "county_district" => (self.ancestral_t_a rescue nil),
              "neighborhood_cell" => (self.home_village rescue nil),
              "subregion" => (self.district_of_origin rescue nil)
            }
          }
        }

        current_national_id = get_full_identifier("National id")

        set_identifier("Old Identification Number", current_national_id.identifier)

        current_national_id.void("National ID version change", user_id)

        national_id = CorePerson.create_patient_from_dde(person, true)

        set_identifier("National id", national_id)

      end
    end
    
  end

  def self.get_attribute(person, attribute)
    CorePersonAttribute.find(:first,:conditions =>["voided = 0 AND person_attribute_type_id = ? AND person_id = ?",
        PersonAttributeType.find_by_name(attribute).id, person.id]).value rescue nil
  end

  def get_full_attribute(attribute)
    CorePersonAttribute.find(:first,:conditions =>["voided = 0 AND person_attribute_type_id = ? AND person_id = ?",
        CorePersonAttributeType.find_by_name(attribute).id,self.person.id]) rescue nil
  end

  def set_attribute(attribute, value)
    CorePersonAttribute.create(:person_id => self.person.person_id, :value => value,
      :person_attribute_type_id => (CorePersonAttributeType.find_by_name(attribute).id))
  end

  def get_full_identifier(identifier)
    CorePatientIdentifier.find(:first,:conditions =>["voided = 0 AND identifier_type = ? AND patient_id = ?",
        CorePatientIdentifierType.find_by_name(identifier).id, self.patient.id]) rescue nil
  end

  def set_identifier(identifier, value)
    CorePatientIdentifier.create(:patient_id => self.patient.patient_id, :identifier => value,
      :identifier_type => (CorePatientIdentifierType.find_by_name(identifier).id))
  end

  def change_national_id(user_id)
    create_from_dde_server = get_global_property_value('create.from.dde.server').to_s == "true" rescue false

    current_national_id = get_full_identifier("National id")

    current_national_id.void("National ID conflict resolution", user_id)

    local_national_id = national_id(true)

    if create_from_dde_server

      passed_params = {
        "person" => {
          "data" => {
            "birthdate_estimated" => (self.birthdate_estimated rescue nil),
            "gender" => (self.gender rescue nil),
            "birthdate" => (self.birthdate.to_s rescue nil),
            "birth_year" => (self.birthdate.to_date.year rescue nil),
            "birth_month" => (self.birthdate.to_date.month rescue nil),
            "birth_day" => (self.birthdate.to_date.date rescue nil),
            "names" => {
              "given_name" => self.first_name,
              "family_name" => self.last_name,
              "family_name2" => self.maiden_name,
              "middle_name" => self.middle_name
            },
            "patient" => {
              "identifiers" => {
                "old_identification_number" => self.national_id
              }
            },
            "attributes" => {
              "occupation" => (self.get_full_attribute("Occupation").value rescue nil),
              "cell_phone_number" => (self.get_full_attribute("Cell Phone Number").value rescue nil),
              "office_phone_number" => (self.get_full_attribute("Office Phone Number").value rescue nil),
              "home_phone_number" => (self.get_full_attribute("Home Phone Number").value rescue nil),
              "citizenship" => (self.get_full_attribute("Citizenship").value rescue nil),
              "race" => (self.get_full_attribute("Race").value rescue nil)
            },
            "addresses" => {
              "address1" => (self.landmark_or_plot_number rescue nil),
              "city_village" => (self.current_residence_location rescue nil),
              "address2" => (self.current_district rescue nil),
              "county_district" => (self.ancestral_t_a rescue nil),
              "neighborhood_cell" => (self.home_village rescue nil),
              "subregion" => (self.district_of_origin rescue nil)
            }
          }
        }
      }

      @dde_server = self.get_global_property_value("dde_server_ip") rescue ""

      @dde_server_username = self.get_global_property_value("dde_server_username") rescue ""

      @dde_server_password = self.get_global_property_value("dde_server_password") rescue ""

      uri = "http://#{@dde_server_username}:#{@dde_server_password}@#{@dde_server}/people.json/"

      recieved_params = RestClient.post(uri, passed_params)

      local_national_id = JSON.parse(recieved_params)["npid"]["value"] rescue nil
      
      if local_national_id.nil?

        local_national_id = national_id(true)
        
      else

        current_national_id = get_full_identifier("National id")

        current_national_id.void("National ID conflict resolution", user_id)

        set_identifier("National id", local_national_id)

      end


      return local_national_id
 
    end

    return ""
    
  end

  def self.update_demographics(params, user_id)
    person = CorePerson.find(params['person_id'])

    if params.has_key?('person')
      params = params['person']
    end

    address_params = params["addresses"]
    names_params = params["names"]
    patient_params = params["patient"]
    person_attribute_params = params["attributes"]

    params_to_process = params.reject{|key,value| key.match(/addresses|patient|names|attributes/) }
    birthday_params = params_to_process.reject{|key,value| key.match(/gender|occupation/) }

    person_params = params_to_process.reject{|key,value| key.match(/birth_|age_estimate|occupation/) }

    if !birthday_params.empty?
=begin


		if !birthday_params.empty? && birthday_params["birthdate"].blank?
		  if birthday_params["birth_year"] == "Unknown"
        self.set_birthdate_by_age(person, birthday_params["age_estimate"], person.session_datetime || Date.today)
		  else
        self.set_birthdate(person, birthday_params["birth_year"], birthday_params["birth_month"], birthday_params["birth_day"])
		  end
		end

=end
      if birthday_params["birth_year"] == "Unknown"
        self.set_birthdate_by_age(person, birthday_params["age_estimate"])
      else
        self.set_birthdate(person, birthday_params["birth_year"], birthday_params["birth_month"], birthday_params["birth_day"])
      end

      person.birthdate_estimated = 1 if params["birthdate_estimated"] == 'true'
      person.save
    end

    person.update_attributes(person_params) if !person_params.empty?
    person.names.first.update_attributes(names_params) if names_params
    person.addresses.first.update_attributes(address_params) if address_params && !person.addresses.empty?

    person.addresses.create(address_params) if person.addresses.empty? && address_params

    #update or add new person attribute
    person_attribute_params.each{|attribute_type_name, attribute|
      attribute_type = CorePersonAttributeType.find_by_name(attribute_type_name.humanize.titleize) ||
        CorePersonAttributeType.find_by_name("Unknown id")
      #find if attribute already exists
      exists_person_attribute = CorePersonAttribute.find(:first, :conditions =>
          ["person_id = ? AND person_attribute_type_id = ?", person.id, attribute_type.person_attribute_type_id]) rescue nil
      if exists_person_attribute
        exists_person_attribute.update_attributes({'value' => attribute})
      else
        person.person_attributes.create("value" => attribute, "person_attribute_type_id" =>
            attribute_type.person_attribute_type_id)
      end
    } if person_attribute_params

  end

end
