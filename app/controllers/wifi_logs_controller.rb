class WifiLogsController < ApplicationController
  before_filter :authenticate_user!
  # GET /maps/1/wifi_logs/
  # GET /maps/1/wifi_access_points/1/wifi_logs/
  # GET /maps/1/movement_logs/1/wifi_logs/
  def index
    if !params[:map_id].nil?
      @map = Map.find(params[:map_id])
    else
      #FIXME
    end

    if !params[:wifi_access_point_id].nil?
      @wifi_access_point = WifiAccessPoint.find(params[:wifi_access_point_id])
    elsif !params[:movement_log_id].nil?
      @movement_log = MovementLog.find(params[:movement_log_id])
    else
      #FIXME
    end

    time_condition = ManualLocation.time_condition(params)
    signal_condition = WifiLog.signal_condition(params)

    if @movement_log.nil?
      @manual_locations = ManualLocation.where(:map_id => @map.id).where(time_condition)
      @wifi_logs = []
      @wifi_access_points = []
      @manual_locations.each do |l|
        if !l.movement_log.nil?
          if @wifi_access_point.nil? && @movement_log.nil?
            @wifi_logs += l.movement_log.wifi_logs.where('manual_locations.map_id = ?', @map.id).where(signal_condition).order('wifi_access_points.mac').all(:include => {:wifi_access_point => :manual_location})
            @wifi_access_points += l.movement_log.wifi_access_points.where('manual_locations.map_id = ?', @map.id).where(signal_condition).all(:include => :manual_location)
          else
            @wifi_logs += l.movement_log.wifi_logs.where(:wifi_access_point_id => @wifi_access_point.id).where(signal_condition)
          end
        end
      end
      @wifi_access_points = @wifi_access_points.uniq
    else
      @wifi_logs = @movement_log.wifi_logs.where(signal_condition).order('wifi_access_points.mac').all(:include => :wifi_access_point)
      @wifi_access_points = @movement_log.wifi_access_points.where('wifi_access_points.manual_location_id IS NOT NULL').where('manual_locations.map_id = ?', @movement_log.manual_location.map.id).where(signal_condition).all(:include => :manual_location)
    end

    respond_to do |format|
      format.html # index.html.erb
    end
  end

  # GET /wifi_access_points/1
  # GET /maps/1/wifi_access_points/1/wifi_logs/1
  # GET /maps/1/movement_logs/1/wifi_logs/1
  def show
    if !params[:map_id].nil?
      @map = Map.find(params[:map_id])
    end
    if !params[:wifi_access_point_id].nil?
      @wifi_access_point = WifiAccessPoint.find(params[:wifi_access_point_id])
    elsif !params[:movement_log_id].nil?
      @movement_log = MovementLog.find(params[:movement_log_id])
    else
      #FIXME
    end
    @wifi_log = WifiLog.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @wifi_log }
    end
  end

  # GET /maps/1/wifi_logs/new
  def new
    @wifi_log = WifiLog.new
    if !params[:map_id].nil?
      @map = Map.find(params[:map_id])
    end

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @wifi_log }
    end
  end

  # POST /maps/1/wifi_logs
  def create
    begin
      WifiLog.transaction do
        @manual_location = ManualLocation.new
        @manual_location.init_by_params(params)
        @manual_location.save!

        @gpsd_tpv = nil
        @gps_location = nil
        if !params["gpsd_tpv"].nil? && !params["gpsd_tpv"].empty?
          @gpsd_tpv = JSON.parse(params["gpsd_tpv"])
          if !@gpsd_tpv.empty?
            @gps_location = GpsLocation.new_by_json(@gpsd_tpv)
            @gps_location.save!
          end
        end
        @movement_log = MovementLog.new
        @movement_log.manual_location = @manual_location
        @movement_log.gps_location = @gps_location
        # FIXME
        # how to specify current user in Devise
        @movement_log.user = current_user
        @movement_log.remote_addr = request.remote_addr
        @movement_log.user_agent = request.user_agent
        @movement_log.user_device = params["user_device"]
        @movement_log.save!

        if !params["wifi_towers"].nil? && !params["wifi_towers"].empty?
          @wifi_towers = JSON.parse(params["wifi_towers"])
          @wifi_towers.each do |wifi_tower|
            @wifi_access_point = WifiAccessPoint.find_or_initialize_by_json(wifi_tower)
            if !@wifi_access_point.persisted?
              @wifi_access_point.save!
            end
            @wifi_log = WifiLog.new_by_json(wifi_tower)
            @wifi_log.wifi_access_point = @wifi_access_point
            @wifi_log.movement_log = @movement_log
            @wifi_log.save!
          end
        end
      end
      respond_to do |format|
        format.html { render :text => "Logs are successfully recorded." }
      end
    rescue
      respond_to do |format|
        format.html { render :text => "Failed to record logs." }
      end
    end
  end

  # DELETE /wifi_logs/1
  # DELETE /maps/1/wifi_access_point/1/wifi_logs/1
  def destroy
    @wifi_log = WifiLog.find(params[:id])
    @wifi_log.destroy

    respond_to do |format|
      format.html do
        if !params[:map_id].nil? && !params[:wifi_access_point_id].nil?
          redirect_to(map_wifi_access_point_wifi_logs_url(:map_id => params[:map_id], :wifi_access_point_id => params[:wifi_access_point_id]))
        else
          redirect_to(wifi_logs_url)
        end
      end
      format.xml  { head :ok }
    end
  end
end
