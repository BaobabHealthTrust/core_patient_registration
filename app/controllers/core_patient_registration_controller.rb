
class CorePatientRegistrationController < ApplicationController
  
  before_filter :check_user, :except => [:user_login, :given_names, :family_names, 
    :family_name2, :middle_name, :district, :village, :traditional_authority]

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
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
  end

  def select
    
    if !params[:person].nil?
      if !params[:person][:id].blank? && params[:person][:id].to_i != 0

        identifier = CorePerson.find(params[:person][:id]).patient.national_id rescue nil

        redirect_to "/select_fields?user_id=#{params[:user_id]}" if identifier.blank?

        redirect_to "/scan/#{identifier}?user_id=#{params[:user_id]}" and return
    
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

    end

    results = CorePerson.search_by_identifier(params[:identifier] || params[:id]) rescue []

    if results.length > 1

      disambiguation(results) and return
      
    elsif results.length > 0

      person = results.first
      
      create_from_dde_server = get_global_property_value('create.from.dde.server').to_s == "true" rescue false

      if create_from_dde_server and (params[:identifier] || params[:id]) == person.national_id

        person.check_old_national_id((params[:identifier] || params[:id]), params[:user])

      end

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
      
    end
    
    @user = params[:user_id] rescue nil?

  end

  def edit_demographics
    @patient = CorePerson.find(params[:id] || params[:patient_id]) rescue nil

    if @patient.nil?
      redirect_to "/select" and return
    end

    @user = params[:user_id] rescue nil

    @field = params[:field] rescue nil

    if @field.nil?
      redirect_to "/scan/#{@patient.national_id}?user=#{(params[:user_id] rescue "")}" and return
    end

    @occupations = ['','Driver','Housewife','Messenger','Business','Farmer','Salesperson','Teacher',
      'Student','Security guard','Domestic worker', 'Police','Office worker',
      'Preschool child','Mechanic','Prisoner','Craftsman','Healthcare Worker','Soldier'].sort.concat(["Other","Unknown"])
    
  end

  def update_demographics
   
    patient = CorePerson.find(params[:id] || params[:patient_id])

    CorePerson.update_demographics(params, params[:user_id])

    redirect_to "/demographics/#{patient.id}?user_id=#{(params[:user_id] rescue "")}" and return
  end

  def search
    if params[:user_id].nil?
      redirect_to "/core_patient_registration/no_user" and return
    end

    # @user = params[:user_id] rescue nil

		@people = person_search(params)

 		@patients = []
		@people.each do | person |
			patient = get_patient(person) rescue nil
			@patients << patient if !patient.nil?
		end

    # Track final destination
    file = "#{File.expand_path("#{Rails.root}/tmp", __FILE__)}/registation.#{params[:user_id]}.yml"

    if !params[:ext].nil?

      f = File.open(file, "w")

      f.write("#{Rails.env}:\n    host.path.#{params[:user_id]}: #{session["host_path"] = request.referrer}")

      f.close

    end

    @destination = "/?user_id=#{params[:user_id]}"

    if File.exists?(file)

      @destination = YAML.load_file(file)["#{Rails.env
        }"]["host.path.#{params[:user_id]}"].strip

    end

  end

  def person_search(params)
    people = []
    people = search_by_identifier(params[:identifier]) if params[:identifier]
    return people.first.id unless people.blank? || people.size > 1
    people = CorePerson.find(:all, :include => [:names, :patient], :conditions => [
        "gender = ? AND \
     person_name.given_name = ? AND \
     person_name.family_name = ?",
        params[:gender],
        params[:given_name],
        params[:family_name]
      ]) if people.blank?

    if people.length < 15
      matching_people = people.collect{| person |
        person.person_id
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
      )
      
      people = people + people_like
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
      :person_a => person.id,
      :relationship => (CoreRelationshipType.find_by_a_is_to_b_and_b_is_to_a("Child", "Parent").id),
      :person_b => params[:mother_id]
    )

    render :text => person.patient.national_id
    
  end

  def baby_mother_national_id_label
    @person = CorePerson.find(params[:patient_id])

    print_string = @person.baby_national_id_label rescue (raise "Unable to find patient (#{params[:patient_id]}) or generate a national id label for that patient")
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
  end

  protected

  def check_user

    link = get_global_property_value("user.management.url").to_s rescue nil
    
    if link.nil?
      flash[:error] = "Missing configuration for <br/>user management connection!"

      redirect_to "/no_user" and return
    end

    @user = JSON.parse(RestClient.get("#{link}/verify/#{(params[:user_id])}")) rescue {}

    if @user.empty?
      redirect_to "/user_login" and return
    end

    if @user["token"].nil?
      redirect_to "/user_login" and return
    end

  end

end