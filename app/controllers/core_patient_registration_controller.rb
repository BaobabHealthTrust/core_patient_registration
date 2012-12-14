
class CorePatientRegistrationController < ApplicationController
  
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

    print_and_redirect("/national_id_label?patient_id=#{person.id}", "/select")

  end

  def national_id_label
    @person = CorePerson.find(params[:patient_id])

    print_string = @person.national_id_label rescue (raise "Unable to find patient (#{params[:patient_id]}) or generate a national id label for that patient")
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
  end

  def select    
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
    
    results = CorePerson.search_by_identifier(params[:id]) rescue []

    if results.length > 1

      disambiguation(results) and return
      
    elsif results.length > 0

      person = results.first
      
      create_from_dde_server = get_global_property_value('create.from.dde.server').to_s == "true" rescue false

      if create_from_dde_server and params[:id] == person.national_id

        person.check_old_national_id(params[:id], params[:user])

      end

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

  end

  def edit_demographics
    @patient = CorePerson.find(params[:id] || params[:patient_id]) rescue nil

    if @patient.nil?
      redirect_to "/select" and return
    end

    @field = params[:field] rescue nil

    if @field.nil?
      redirect_to "/scan/#{@patient.national_id}?user=#{(params[:user_id] rescue "")}" and return
    end

    @occupations = ['','Driver','Housewife','Messenger','Business','Farmer','Salesperson','Teacher',
      'Student','Security guard','Domestic worker', 'Police','Office worker',
      'Preschool child','Mechanic','Prisoner','Craftsman','Healthcare Worker','Soldier'].sort.concat(["Other","Unknown"])
    
  end

  def update_demographics
    # raise params.to_yaml
    
    patient = CorePerson.find(params[:id] || params[:patient_id])

    CorePerson.update_demographics(params, params[:user_id])

    redirect_to "/demographics/#{patient.id}?user=#{(params[:user_id] rescue "")}" and return
  end

end