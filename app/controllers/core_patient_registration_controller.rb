
class CorePatientRegistrationController < ApplicationController 
  unloadable   

  def new
    
    @show_middle_name = (params[:show_middle_name].to_s.downcase == "true" ? true : false) rescue false

    @show_maiden_name = (params[:show_maiden_name].to_s.downcase == "true" ? true : false) rescue false

    @show_birthyear = (params[:show_birthyear].to_s.downcase == "true" ? true : false) rescue false

    @show_birthmonth = (params[:show_birthmonth].to_s.downcase == "true" ? true : false) rescue false

    @show_birthdate = (params[:show_birthdate].to_s.downcase == "true" ? true : false) rescue false

    @show_age = (params[:show_age].to_s.downcase == "true" ? true : false) rescue false

    @show_region_of_origin = (params[:show_region_of_origin].to_s.downcase == "true" ? true : false) rescue false

    @show_district_of_origin = (params[:show_district_of_origin].to_s.downcase == "true" ? true : false) rescue false

    @show_t_a_of_origin = (params[:show_t_a_of_origin].to_s.downcase == "true" ? true : false) rescue false

    @show_home_village = (params[:show_home_village].to_s.downcase == "true" ? true : false) rescue false

    @show_current_region = (params[:show_current_region].to_s.downcase == "true" ? true : false) rescue false

    @show_current_district = (params[:show_current_district].to_s.downcase == "true" ? true : false) rescue false

    @show_current_t_a = (params[:show_current_t_a].to_s.downcase == "true" ? true : false) rescue false

    @show_current_village = (params[:show_current_village].to_s.downcase == "true" ? true : false) rescue false

    @show_current_landmark = (params[:show_current_landmark].to_s.downcase == "true" ? true : false) rescue false

    @show_cell_phone_number = (params[:show_cell_phone_number].to_s.downcase == "true" ? true : false) rescue false
    
    @show_office_phone_number = (params[:show_office_phone_number].to_s.downcase == "true" ? true : false) rescue false

    @show_home_phone_number = (params[:show_home_phone_number].to_s.downcase == "true" ? true : false) rescue false

    @show_occupation = (params[:show_occupation].to_s.downcase == "true" ? true : false) rescue false

    @show_nationality = (params[:show_nationality].to_s.downcase == "true" ? true : false) rescue false

    @occupations = ['','Driver','Housewife','Messenger','Business','Farmer','Salesperson','Teacher',
      'Student','Security guard','Domestic worker', 'Police','Office worker',
      'Preschool child','Mechanic','Prisoner','Craftsman','Healthcare Worker','Soldier'].sort.concat(["Other","Unknown"])
    @destination = request.referrer
    
  end

  def create

    person = CorePerson.create_patient_from_dde(params) if create_from_dde_server

    if person.blank?
    
      person = CorePerson.create_from_form(params[:person])

    end

    print_and_redirect("/national_id_label?patient_id=#{person.id}&user_id=#{params[:user_id]}", 
      "/scan?user_id=#{params[:user_id]}&identifier=#{person.patient.national_id}")

  end

  def national_id_label
    @person = CorePerson.find(params[:patient_id])
    print_string = @person.national_id_label rescue (raise "Unable to find patient (#{params[:patient_id]}) or generate a national id label for that patient")
    send_data(print_string,
      :type=>"application/label; charset=utf-8",
      :stream=> false,
      :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", 
      :disposition => "inline")
  end

  def select

    if !params[:person].nil?    
      if (params[:identifier]) || (!params[:person][:id].blank? && params[:person][:id].to_i != 0) || params["person"]["patient"]["identifiers"]["National id"]

        identifier = CorePerson.find(params[:person][:id]).patient.national_id rescue nil
        identifier = params["person"]["patient"]["identifiers"]["National id"] rescue nil if identifier.blank?
        identifier = params[:identifier] rescue nil if identifier.blank?
        
        redirect_to "/select_fields?user_id=#{params[:user_id]}" if identifier.blank?

        redirect_to "/scan/#{identifier}?user_id=#{params[:user_id]}&ext=#{params[:ext]}&remote=#{params[:remote]}" and return
    
      else
        
        redirect_to "/select_fields?user_id=#{params[:user_id]}&location_id=#{session[:location_id] || params[:location_id]}" and return

      end
    end

  end

  def select_fields

    # Track final destination
    file = "#{File.expand_path("#{Rails.root}/tmp", __FILE__)}/registation.#{params[:user_id]}.yml"

    if !params[:ext].nil?

      f = File.open(file, "w")

      f.write("#{Rails.env}:\n    host.path.#{params[:user_id]}: #{session["host_path"] = request.referrer}")

      f.close

    end

    @destination = "/"

    if File.exists?(file)

      @destination = YAML.load_file(file)["#{Rails.env
        }"]["host.path.#{params[:user_id]}"].strip

      File.delete(file)

    end

  end

  # Districts containing the string given in params[:value]
  def district
    region_id = CoreRegion.find_by_name("#{params[:filter_value]}").id
    region_conditions = ["name LIKE (?) AND region_id = ? ", "#{params[:search_string]}%", region_id]

    districts = CoreDistrict.find(:all,:conditions => region_conditions, :order => 'name')
    districts = districts.map do |d|
      "<li value='#{d.name}'>#{d.name}</li>"
    end
    render :text => districts.join('') + "<li value='Other'>Other</li>" and return
  end

  # List traditional authority containing the string given in params[:value]
  def traditional_authority
    district_id = CoreDistrict.find_by_name("#{params[:filter_value]}").id
    traditional_authority_conditions = ["name LIKE (?) AND district_id = ?", "%#{params[:search_string]}%", district_id]

    traditional_authorities = CoreTraditionalAuthority.find(:all,:conditions => traditional_authority_conditions, :order => 'name')
    traditional_authorities = traditional_authorities.map do |t_a|
      "<li value='#{t_a.name}'>#{t_a.name}</li>"
    end
    render :text => traditional_authorities.join('') + "<li value='Other'>Other</li>" and return
  end

  # Villages containing the string given in params[:value]
  def village
    traditional_authority_id = CoreTraditionalAuthority.find_by_name("#{params[:filter_value]}").id
    village_conditions = ["name LIKE (?) AND traditional_authority_id = ?", "%#{params[:search_string]}%", traditional_authority_id]

    villages = CoreVillage.find(:all,:conditions => village_conditions, :order => 'name')
    villages = villages.map do |v|
      "<li value='#{v.name}'>#{v.name}</li>"
    end
    render :text => villages.join('') + "<li value='Other'>Other</li>" and return
  end

  # Landmark containing the string given in params[:value]
  def landmark
    landmarks = CorePersonAddress.find(:all, :select => "DISTINCT address1" , :conditions => ["city_village = (?) AND address1 LIKE (?)", "#{params[:filter_value]}", "#{params[:search_string]}%"])
    landmarks = landmarks.map do |v|
      "<li value='#{v.address1}'>#{v.address1}</li>"
    end
    render :text => landmarks.join('') + "<li value='Other'>Other</li>" and return
  end

  def scan

    # Track final destination
    file = "#{File.expand_path("#{Rails.root}/tmp", __FILE__)}/registation.#{params[:user_id]}.yml" if params[:user_id]
   

    if !params[:ext].blank? && !params[:remote]
      f = File.open(file, "w") rescue nil
      if f.present?
        f.write("#{Rails.env}:\n    host.path.#{params[:user_id]}: #{session["host_path"] = request.referrer}")
        f.close
      end      

    end

    @destination = ""

    if File.exists?(file)

      @destination = YAML.load_file(file)["#{Rails.env
        }"]["host.path.#{params[:user_id]}"].strip
     
    end
		@destination = @destination + "&user_id=#{params[:user_id]}"  rescue @distination if @destination.present? and !@destination.match("user_id")
    identifier = params[:identifier] || params[:id]
    results = CorePerson.search_by_identifier(identifier)

    if results.length > 1 || results.to_s == "found duplicate identifiers"
      params[:identifier] = params[:id] if params[:identifier].blank? && params[:id].length > 5
      redirect_to :action => 'duplicates' ,:search_params => params, :user_id => params[:user_id]
       
    elsif results.length > 0

      person = results.first     
     
      dde_patient = DDEService::Patient.new(person.patient)
      national_id_replaced = dde_patient.check_old_national_id(params[:identifier])

      if create_from_dde_server
        if (national_id_replaced.to_s == "true" || params[:identifier] != dde_patient.patient.national_id) && !params[:reround]
          print_and_redirect("/national_id_label?patient_id=#{dde_patient.patient.id}&user_id=#{params[:user_id]}", "/scan?user_id=#{params[:user_id]}&identifier=#{person.patient.national_id}&ext=#{params[:ext]}&remote=#{params[:remote]}&reround=true") and return
        end
      else

      end
      if File.exists?(file)

        @destination = YAML.load_file(file)["#{Rails.env}"]["host.path.#{params[:user_id]}"].strip

        File.delete(file)

      end
    
      host = request.raw_host_with_port.gsub("localhost", "0.0.0.0").gsub("127.0.0.1", "0.0.0.0")
      ext_host = @destination.gsub("localhost", "0.0.0.0").gsub("127.0.0.1", "0.0.0.0")
     
      @destination ="/patients/show/#{person.id}?patient_id=#{person.id}&user_id=#{params[:user_id]}"  if ext_host.match("#{host}")
    
      redirect_to "#{@destination}#{ @destination.match(/\?/) ? "&" : "?"
          }ext_patient_id=#{person.id}" and return if !@destination.nil? and @destination.strip.length > 1

      render :text => {
        "person" => "found",
        "data" => (person.demographics rescue {})
      }.to_json and return

    else

      render :text => {"person" => "not found"}.to_json and return

    end

  end

  def disambiguation(patients)
    @patients = patients

    render :template => "/core_patient_registration/resolve"
  end

  def change_national_id
    patient = CorePerson.find(params[:patient_id])

    patient.change_national_id(params[:user_id])

    redirect_to "/scan/#{patient.national_id}?user=#{params[:user_id]}" and return
    
  end

  def demographics
    @patient = CorePerson.find(params[:id] || params[:patient_id]) rescue nil

    @show_middle_name = (get_global_property_value(:show_middle_name).to_s.downcase == "true" ? true : false) rescue false

    @show_maiden_name = (get_global_property_value("show_maiden_name").to_s.downcase == "true" ? true : false) rescue false

    @show_birthyear = (get_global_property_value("show_birthyear").to_s.downcase == "true" ? true : false) rescue false

    @show_birthmonth = (get_global_property_value("show_birthmonth").to_s.downcase == "true" ? true : false) rescue false

    @show_birthdate = (get_global_property_value("show_birthdate").to_s.downcase == "true" ? true : false) rescue false

    @show_age = (get_global_property_value("show_age").to_s.downcase == "true" ? true : false) rescue false

    @show_region_of_origin = (get_global_property_value("show_region_of_origin").to_s.downcase == "true" ? true : false) rescue false

    @show_district_of_origin = (get_global_property_value("show_district_of_origin").to_s.downcase == "true" ? true : false) rescue false

    @show_t_a_of_origin = (get_global_property_value("show_t_a_of_origin").to_s.downcase == "true" ? true : false) rescue false

    @show_home_village = (get_global_property_value("show_home_village").to_s.downcase == "true" ? true : false) rescue false

    @show_current_region = (get_global_property_value("show_current_region").to_s.downcase == "true" ? true : false) rescue false

    @show_current_district = (get_global_property_value("show_current_district").to_s.downcase == "true" ? true : false) rescue false

    @show_current_t_a = (get_global_property_value("show_current_t_a").to_s.downcase == "true" ? true : false) rescue false

    @show_current_village = (get_global_property_value("show_current_village").to_s.downcase == "true" ? true : false) rescue false

    @show_current_landmark = (get_global_property_value("show_current_landmark").to_s.downcase == "true" ? true : false) rescue false

    @show_cell_phone_number = (get_global_property_value("show_cell_phone_number").to_s.downcase == "true" ? true : false) rescue false

    @show_office_phone_number = (get_global_property_value("show_office_phone_number").to_s.downcase == "true" ? true : false) rescue false

    @show_home_phone_number = (get_global_property_value("show_home_phone_number").to_s.downcase == "true" ? true : false) rescue false

    @show_occupation = (get_global_property_value("show_occupation").to_s.downcase == "true" ? true : false) rescue false

    @show_nationality = (get_global_property_value("show_nationality").to_s.downcase == "true" ? true : false) rescue false

    # Track final destination
    file = "#{File.expand_path("#{Rails.root}/tmp", __FILE__)}/registation.#{params[:user_id]}.yml"

    if !params[:ext].nil?
      
      f = File.open(file, "w")
      
      f.write("#{Rails.env}:\n    host.path.#{params[:user_id]}: #{session["host_path"] = request.referrer}")

      f.close
      
    end

    @destination = nil
    
    if File.exists?(file)

      @destination = YAML.load_file(file)["#{Rails.env
        }"]["host.path.#{params[:user_id]}"].strip

      # File.delete(file)

    end
    
    @user = params[:user_id] || session[:user_id] rescue nil

  end

  def edit_demographics
    @patient = CorePerson.find(params[:id] || params[:patient_id]) rescue nil

    if @patient.nil?
      redirect_to "/select" and return
    end

    @user = params[:user_id] || session[:user_id] rescue nil

    @field = params[:field] rescue nil

    if @field.nil?
      redirect_to "/scan/#{@patient.national_id}?user=#{(params[:user_id] rescue "")}" and return
    end

    @occupations = ['','Driver','Housewife','Messenger','Business','Farmer','Salesperson','Teacher',
      'Student','Security guard','Domestic worker', 'Police','Office worker',
      'Preschool child','Mechanic','Prisoner','Craftsman','Healthcare Worker','Soldier'].sort.concat(["Other","Unknown"])
    
  end

  def update_demographics
    
    params["person"]["gender"] = params["person"]["gender"][0 .. 0] if params["person"]["gender"]
    
    patient = CorePerson.find(params[:id] || params[:patient_id])

    CorePerson.update_demographics(params, params[:user_id])

    redirect_to "/demographics/#{patient.id}?user_id=#{(params[:user_id] rescue "")}" and return
  end

  def search
    found_person = nil
    if params[:identifier]
      local_results = CorePerson.search_by_identifier(params[:identifier])
      if local_results.length > 1
        redirect_to :action => 'duplicates' ,:search_params => params, :user_id => params[:user_id]
        return
        #@people = CorePerson.person_search(params)
      elsif local_results.length == 1

        if create_from_dde_server

          dde_server = CoreService.get_global_property_value("dde_server_ip") rescue ""
          dde_server_username = CoreService.get_global_property_value("dde_server_username") rescue ""
          dde_server_password = CoreService.get_global_property_value("dde_server_password") rescue ""
          uri = "http://#{dde_server_username}:#{dde_server_password}@#{dde_server}/people/find.json"
          uri += "?value=#{params[:identifier]}"
          output = RestClient.get(uri)
          p = JSON.parse(output)
          if p.count > 1
            redirect_to :action => 'duplicates' ,:search_params => params, :user_id => params[:user_id]
            return
          end
        end

        found_person = local_results.first

        if (found_person.gender rescue "") == "M"
          redirect_to "/clinic/no_males" and return
        end

      else
        # TODO - figure out how to write a test for this
        # This is sloppy - creating something as the result of a GET
        if create_from_remote
          found_person_data = CorePerson.search_by_identifier(params[:identifier]).first rescue nil

          found_person = CorePerson.create_from_form(found_person_data['person']) unless found_person_data.nil?
        end
      end

      found_person = local_results.first if !found_person.blank?

      if (found_person.gender rescue "") == "M"
        redirect_to "/clinic/no_males" and return
      end

      if found_person
        if create_from_dde_server
          patient = DDEService::Patient.new(found_person.patient)

          national_id_replaced = patient.check_old_national_id(params[:identifier])
          if national_id_replaced.to_s == "true" || params[:identifier] != found_person.patient.national_id
            print_and_redirect("/patients/national_id_label?patient_id=#{found_person.id}", next_task(found_person.patient)) and return
          end
        end
        if params[:relation]
          redirect_to search_complete_url(found_person.id, params[:relation]) and return
        else

          redirect_to next_task(found_person.patient) and return
          # redirect_to :action => 'confirm', :found_person_id => found_person.id, :relation => params[:relation] and return
        end
      end
    end

    @relation = params[:relation]
    @people = person_search(params)
    
    @search_results = {}
    @patients = []
    (CorePerson.search_from_remote(params) || []).each do |data|
      national_id = data["person"]["data"]["patient"]["identifiers"]["National id"] rescue nil
      national_id = data["person"]["value"] if national_id.blank? rescue nil
      national_id = data["npid"]["value"] if national_id.blank? rescue nil
      national_id = data["person"]["data"]["patient"]["identifiers"]["old_identification_number"] if national_id.blank? rescue nil

      next if national_id.blank?
      results = PersonSearch.new(national_id)
      results.national_id = national_id
      results.current_residence =data["person"]["data"]["addresses"]["city_village"]
      results.person_id = 0
      results.home_district = data["person"]["data"]["addresses"]["address2"]
      results.traditional_authority =  data["person"]["data"]["addresses"]["county_district"]
      results.name = data["person"]["data"]["names"]["given_name"] + " " + data["person"]["data"]["names"]["family_name"]
      gender = data["person"]["data"]["gender"]
      results.occupation = data["person"]["data"]["occupation"]
      results.sex = (gender == 'M' ? 'Male' : 'Female')
      results.birthdate_estimated = (data["person"]["data"]["birthdate_estimated"]).to_i
      results.birth_date = birthdate_formatted((data["person"]["data"]["birthdate"]).to_date , results.birthdate_estimated)
      results.birthdate = (data["person"]["data"]["birthdate"]).to_date
      results.age = cul_age(results.birthdate.to_date , results.birthdate_estimated)
      @search_results[results.national_id] = results
    end if create_from_dde_server

    (@people || []).each do | person_id |
      
      person = CorePerson.find(person_id)
      
      patient = CorePerson.get_patient(person) rescue nil      

      next if patient.blank?
      results = PersonSearch.new(patient.national_id || patient.patient_id)
      results.national_id = patient.national_id
      results.birth_date = patient.birth_date
      results.current_residence = patient.current_residence
      results.guardian = patient.guardian
      results.person_id = patient.person_id
      results.home_district = patient.home_district
      results.current_district = patient.current_district
      results.traditional_authority = patient.traditional_authority
      results.mothers_surname = patient.mothers_surname
      results.dead = patient.dead
      results.arv_number = patient.arv_number
      results.eid_number = patient.eid_number
      results.pre_art_number = patient.pre_art_number
      results.name = patient.name
      results.sex = patient.sex
      results.age = patient.age
      @search_results.delete_if{|x,y| x == results.national_id }
      @patients << results
    end

    (@search_results || {}).each do | npid , data |
      @patients << data
    end

    # Track final destination
    file = "#{File.expand_path("#{Rails.root}/tmp", __FILE__)}/registation.#{params[:user_id]}.yml"
   
    if !params[:ext].nil?
      if !params[:skip_destination]
        f = File.open(file, "w")

        f.write("#{Rails.env}:\n    host.path.#{params[:user_id]}: #{session["host_path"] = request.referrer}")

        f.close
      end

    end

    @destination = "/?user_id=#{params[:user_id]}"

    if File.exists?(file)

      @destination = YAML.load_file(file)["#{Rails.env
        }"]["host.path.#{params[:user_id]}"].strip
      # File.delete(file)

    end
    
  end

  def self.search_from_remote(params)
    return [] if params[:given_name].blank?
    dde_server = CoreGlobalProperty.find_by_property("dde_server_ip").property_value rescue ""
    dde_server_username = CoreGlobalProperty.find_by_property("dde_server_username").property_value rescue ""
    dde_server_password = CoreGlobalProperty.find_by_property("dde_server_password").property_value rescue ""
    uri = "http://#{dde_server_username}:#{dde_server_password}@#{dde_server}/people/find.json/"

    return JSON.parse(RestClient.post(uri,params))
  end

  def person_search(params)
    people = []
    people = CorePerson.search_by_identifier(params[:identifier]) if params[:identifier]
    return people.first.id unless people.blank? || people.size > 1 || people.to_s == "found duplicate identifiers"
    people = CorePerson.find(:all, :include => [:names, :patient], :conditions => [
        "gender = ? AND \
     person_name.given_name = ? AND \
     person_name.family_name = ?",
        params[:gender],
        params[:given_name],
        params[:family_name]
      ]).collect{|p| p.person_id} if people.blank?

    if people.length < 15
      matching_people = people.collect{| person_id |
        person_id
      }
      # raise matching_people.to_yaml
      people_like = CorePerson.find(:all, :limit => 15, :include => [:names, :patient], :conditions => [
          "gender = ? AND \
     (person_name.given_name LIKE ? OR \
     person_name.family_name LIKE ?) AND person.person_id NOT IN (?)",
          params[:gender],
          (params[:given_name] || ''),
          (params[:family_name] || ''),
          matching_people
        ], :order => "person_name.given_name ASC, person_name.family_name ASC"
      ).collect{|p| p.person_id}
      
      people = (people + people_like)[0, 15]
     
    end
    return people
  end

  def get_patient(person, current_date = Date.today)
    patient = {}
    
    patient["person_id"] = person.id

    patient["patient_id"] = person.patient.id

    patient["address"] = person.patient.address rescue nil

    patient["national_id"] = person.patient.national_id

    patient["national_id_with_dashes"] = person.patient.national_id_with_dashes rescue (person.patient.national_id rescue nil)
    
    patient["name"] = person.patient.name
    
    patient["first_name"] = person.names.first.given_name rescue nil

    patient["last_name"] = person.names.first.family_name rescue nil

    patient["sex"] = person.gender
    
    patient["age"] = person.patient.age
    
    patient["age_in_months"] = person.patient.age_in_months(current_date)
    
    patient["dead"] = person.dead

    patient["birth_date"] = person.patient.birthdate_formatted
    
    patient["birthdate_estimated"] = person.birthdate_estimated

    patient["home_district"] = person.addresses.first.address2 rescue nil
    
    patient["traditional_authority"] = person.addresses.first.county_district rescue nil

    patient["state_province"] = person.addresses.first.state_province rescue (person.addresses.first.city_village rescue nil)

    patient["current_residence"] = person.addresses.first.city_village rescue nil

    patient["landmark"] = person.addresses.first.address1 rescue nil

    patient["mothers_surname"] = person.names.first.family_name2

    patient["occupation"] = person.patient.get_attribute("Occupation") rescue nil
    
    patient["cell_phone_number"] = person.patient.get_attribute("Cell Phone Number") rescue nil
    
    patient["office_phone_number"] = person.patient.get_attribute("Office phone number") rescue nil
    
    patient["home_phone_number"] = person.patient.get_attribute("Home phone number") rescue nil
    
    patient
  end
  
  def family_names
    searchname("family_name", params[:search_string])
  end

  def given_names
    searchname("given_name", params[:search_string])
  end

  def family_name2
    searchname("family_name2", params[:search_string])
  end

  def middle_name
    searchname("middle_name", params[:search_string])
  end

  def searchname(field_name, search_string)
    names = CorePersonName.find_most_common(field_name, search_string).collect{|person_name| person_name.send(field_name)}
    
    result = "<li>" + names.map{|n| n } .join("</li><li>") + "</li>"
    render :text => result
  end
  
  def select_person
    raise params.to_yaml
  end

  def user_login

    link = get_global_property_value("user.management.url").to_s rescue nil


    if link.nil?
      flash[:error] = "Missing configuration for <br/>user management connection!"

      redirect_to "/no_user" and return
    end

    host = request.host_with_port rescue ""

    redirect_to "#{link}/login?ext=true&src=#{host}" and return if params[:ext_user_id].nil?

  end

  def user_logout

    link = get_global_property_value("user.management.url").to_s rescue nil


    if link.nil?
      flash[:error] = "Missing configuration for <br/>user management connection!"

      redirect_to "/no_user" and return
    end

    host = request.host_with_port rescue ""

    redirect_to "#{link}/logout?ext=true&src=#{host}" and return if params[:ext_user_id].nil?

  end

  def create_baby

    person = CorePerson.create_patient_from_dde(params) if create_from_dde_server

    if person.blank?

      person = CorePerson.create_from_form(params[:person])

    end

    CoreRelationship.create(
      :person_b => person.id,
      :relationship => (CoreRelationshipType.find_by_a_is_to_b_and_b_is_to_a("Parent", "Child").id),
      :person_a => params[:mother_id]
    )

    render :text => person.patient.national_id.to_json
    
  end

  def baby_mother_national_id_label
    @person = CorePerson.find(params[:patient_id])

    print_string = @person.baby_national_id_label rescue (raise "Unable to find patient (#{params[:patient_id]}) or generate a national id label for that patient")
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
  end

  def duplicates
    
    file = "#{File.expand_path("#{Rails.root}/tmp", __FILE__)}/registation.#{params[:user_id]}.yml"
    
    @destination = "/"

    if File.exists?(file)

      @final_destination = YAML.load_file(file)["#{Rails.env
        }"]["host.path.#{params[:user_id]}"].strip   

    end

    @duplicates = []
    people = person_search(params[:search_params])
   
    people.each do |person|
      @duplicates << CorePerson.get_patient(person)
    end unless people == "found duplicate identifiers"

    if create_from_dde_server
      @remote_duplicates = []
      CorePerson.search_from_dde_by_identifier(params[:search_params][:identifier]).each do |person|
        @remote_duplicates << CorePerson.get_dde_person(person)
      end
    end

    @selected_identifier = params[:search_params][:identifier]

    render :layout => "menu"
  end

  def reassign_dde_national_id
    person = DDEService.reassign_dde_identification(params[:dde_person_id],params[:local_person_id])
    print_and_redirect("/national_id_label?patient_id=#{person.id}&user_id=#{params[:user_id]}",  "/scan?user_id=#{params[:user_id]}&identifier=#{person.patient.national_id}")
  end

  def remote_duplicates

    file = "#{File.expand_path("#{Rails.root}/tmp", __FILE__)}/registation.#{params[:user_id]}.yml"

    @destination = "/"

    if File.exists?(file)

      @final_destination = YAML.load_file(file)["#{Rails.env
        }"]["host.path.#{params[:user_id]}"].strip

    end
    
    if params[:patient_id]
      @primary_patient = CorePerson.get_patient(Person.find(params[:patient_id]))
    else
      @primary_patient = nil
    end

    @dde_duplicates = []
    if create_from_dde_server
      CorePerson.search_from_dde_by_identifier(params[:identifier]).each do |person|
        @dde_duplicates << CorePerson.get_dde_person(person)
      end
    end

    if @primary_patient.blank? and @dde_duplicates.blank?
      redirect_to :action => 'search',:identifier => params[:identifier] and return
    end
    render :layout => "menu"
  end

  def create_person_from_dde
    person = DDEService.get_remote_person(params[:remote_person_id])

    print_and_redirect("/national_id_label?patient_id=#{person.id}&user_id=#{params[:user_id]}",  "/scan?user_id=#{params[:user_id]}&identifier=#{person.patient.national_id}")
  end

  def reassign_national_identifier
    patient = Patient.find(params[:person_id])
    if create_from_dde_server
      passed_params = CorePerson.demographics(patient.person)
      new_npid = CorePerson.create_from_dde_server_only(passed_params)
      npid = PatientIdentifier.new()
      npid.patient_id = patient.id
      npid.identifier_type = PatientIdentifierType.find_by_name('National ID').id
      npid.identifier = new_npid
      npid.save
    else
      PatientIdentifierType.find_by_name('National ID').next_identifier({:patient => patient})
    end
    npid = PatientIdentifier.find(:first,
      :conditions => ["patient_id = ? AND identifier = ?
           AND voided = 0", patient.id,params[:identifier]])
    npid.voided = 1
    npid.void_reason = "Given another national ID"
    npid.date_voided = Time.now()
    npid.voided_by = current_user.id
    npid.save

    print_and_redirect("/patients/national_id_label?patient_id=#{patient.id}", next_task(patient))
  end


  protected

  def cul_age(birthdate , birthdate_estimated , date_created = Date.today, today = Date.today)

    # This code which better accounts for leap years
    patient_age = (today.year - birthdate.year) + ((today.month - birthdate.month) + ((today.day - birthdate.day) < 0 ? -1 : 0) < 0 ? -1 : 0)

    # If the birthdate was estimated this year, we round up the age, that way if
    # it is March and the patient says they are 25, they stay 25 (not become 24)
    birth_date = birthdate
    estimate = birthdate_estimated == 1
    patient_age += (estimate && birth_date.month == 7 && birth_date.day == 1  &&
        today.month < birth_date.month && date_created.year == today.year) ? 1 : 0
  end

  def birthdate_formatted(birthdate,birthdate_estimated)
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

end
