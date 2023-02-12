require 'open-uri'
class MovesController < ApplicationController
  before_action :set_move, only: [:show, :destroy, :update, :edit, :rooms_list, :add_stuffs, :recap, :details, :create_rooms, :add_rooms]
  before_action :set_user, only: [:new, :create]
  before_action :set_room, only: [:add_stuffs, :create_stuffs, :room_destroy]

  # method crud
  def index
    @moves = Move.where(user_id: current_user.id)
    @volumes = {}
    @moves.each do |move|
      @volumes[move] = strip_trailing_zero(volume_total_index(move))
    end
  end

  def show
    recap
    details
    @markers = [
      {
        lat: @move.depart_latitude,
        lng: @move.depart_longitude,
        info_window: render_to_string(partial: "info_window", locals: { position: "depart" })
      },
      {
        lat: @move.arrivee_latitude,
        lng: @move.arrivee_longitude,
        info_window: render_to_string(partial: "info_window", locals: { position: "arrivée" })
      }
    ]
  end

  def new
    @move = Move.new
  end

  def create
    @move = Move.new(move_params)
    @move.user = @user
    # geolocalisation de l'adresse d'arrivee
    results = Geocoder.search(params[:move][:arrivee])
    # ajout des coordonnees
    @move.arrivee_latitude = results.first.coordinates[0]
    @move.arrivee_longitude = results.first.coordinates[1]
    if @move.save
      # redirection vers la page
      redirect_to add_rooms_move_path(@move)
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @move.update(move_params)
      redirect_to @move
    else
      render :edit
    end
  end

  def destroy
    @move.destroy
    redirect_to moves_path
  end

  # method perso evaluat3d

  def add_rooms
    rooms_list
   # if @move.distance.nil?
    #  get_distance
     # @move.update(distance: @distance)
    #end
  end

  def create_rooms
    params["roomscreation"].each do |room_type, number|
      room_type_id = RoomType.find_by(name: room_type).id
      number_rooms = @move.rooms.where(room_type_id: room_type_id).length
      number = number.to_i - number_rooms
      unless number.zero?
        i = number_rooms + 1
        number.times do
          name = room_type
          name += " #{i}" unless i == 1
          Room.create!(name: name, move_id: @move.id, room_type_id: RoomType.find_by(name: room_type).id)
          i += 1
        end
      end
    end
    redirect_to rooms_list_move_path
  end

  def rooms_list
    @rooms = @move.rooms.order(:name)
  end

  def room_destroy
    @room = Room.find(params[:id])
    @move = @room.move
    @room.destroy
    redirect_to rooms_list_move_path(@move)
  end

  def add_stuffs
    @stuffs = @room.room_type.stuffs
  end

  def create_stuffs
    set_move
    params["stuffscreation"].each do |stuff, number|
      stuff_id = Stuff.find_by(name: stuff).id
      number = number.to_i - @room.inventories.where(stuff_id: stuff_id).length
      unless number.zero?
        if number.positive?
          number.times do
            Inventory.create(room_id: @room.id, stuff_id: stuff_id)
          end
        else
          Inventory.where(["room_id = ? and stuff_id = ?", @room.id, stuff_id]).limit(number.abs).delete_all
        end
      end
    end
    redirect_to rooms_list_move_path(@move)
  end

  def recap
    rooms_list
    @recap = {}
    @rooms.each do |room|
      @recap[room.name] = strip_trailing_zero(volume_stuffs(set_stuffs(room)))
    end
    @volume_total = volume_total
    get_tranport
    @prix_perso = prix_perso
    @prix_pro = prix_pro
  end

  def details
    @hash_cartons_by_room = {}
    rooms_list
    @cartons = total_cartons(@rooms)
    @effectif_total = effectif_total
    @pizza_total = pizza_total
    @biere_total = biere_total
    set_materiels(@cartons)
    @rooms.each do |room|
      @hash_cartons_by_room[room] = carton_room(room)
    end
  end

  def find_mover
  end

  private

  def move_params
    params.require(:move).permit(:depart, :arrivee, :house_type, :acces, :transport, :user_id)
  end

  def set_move
    if params[:move_id].nil?
      @move = Move.find(params[:id])
    else
      @move = Move.find(params[:move_id])
    end
  end

  def set_user
    @user = current_user
  end

  def set_room
    @room = Room.find(params[:id])
  end

  def set_stuffs(room)
    room.stuffs
  end

  def volume_stuffs(stuffs)
    sum = 0.0
    stuffs.each do |stuff|
      sum += stuff.volume
      unless stuff.volume_carton.nil?
        sum += stuff.volume_carton
      end
    end
    sum = sum.ceil(1)
  end

  def volume_total
    unless @rooms.nil?
      sum = 0
      @rooms.each do |room|
        sum += volume_stuffs(set_stuffs(room))
      end
      sum.ceil
    end
  end

  def volume_total_index(move)
    unless move.rooms.nil?
      sum = 0
      move.rooms.each do |room|
        sum += volume_stuffs(set_stuffs(room))
      end
      sum.ceil
    end
  end

  def total_cartons(rooms)
    cartons = 0
    rooms.each do |room|
      set_stuffs(room).each do |stuff|
        cartons += stuff.carton
      end
    end
    @cartons = cartons
  end

  def carton_room(room)
    cartons_by_room = 0
    set_stuffs(room).each do |stuff|
      cartons_by_room += stuff.carton
    end
    @cartons_by_room = cartons_by_room
  end

  def set_materiels(cartons)
    @materiels = {
      "Diable" => 1,
      "Sangle" => 4,
      "Rouleaux de bull pack" => 1,
      "Outils démontage meubles" => 1,
      "Rouleaux de scotch" => (cartons / 30.to_f).ceil
    }
  end

  def get_tranport
    rooms_list
    volume = volume_total.ceil
    case volume
    when 0..3
      @move.transport = "Fourgonnette (3m3)"
    when 4..10
      @move.transport = "Fourgon (10m3)"
    when 11..20
      @move.transport = "Petit Camion (20m3)"
    when 21..50
      @move.transport = "Camion (50m3) - NB: Permis Poids Lourds exigé"
    when 51..88
      @move.transport = "Gros Camion remorque (88m3) - NB: Permis Poids Lourds exigé"
    end
    @move.save
  end

  def strip_trailing_zero(number)
    number.to_s.sub(/\.?0+$/, '')
  end

  def effectif_total
    volume_total
    unless @rooms.nil?
      sum = 0.0
        if volume_total >= 20
          sum = (volume_total.to_f / 10).round
        else
          sum = 2
        end
    end
      sum
  end

  def pizza_total
    unless @rooms.nil?
      sum = 0
      @rooms.each do |room|
        sum = effectif_total * 0.75
      end
      sum.ceil
    end
  end

  def biere_total
    unless @rooms.nil?
      sum = 0
      @rooms.each do |room|
        sum = effectif_total * 3
      end
      sum.ceil
    end
  end

  def get_distance
    url = "https://api.mapbox.com/directions/v5/mapbox/driving-traffic/#{@move.depart_longitude},#{@move.depart_latitude};#{@move.arrivee_longitude},#{@move.arrivee_latitude}?steps=true&geometries=geojson&language=fr&access_token=#{ENV['MAPBOX_API_KEY']}"
    geoloc_serialized = URI.open(url).read
    geoloc = JSON.parse(geoloc_serialized)
    @distance = (geoloc['routes'][0]['distance'] / 1000).floor
    @move.distance = @distance
  end

def get_price_transport
    volume = volume_total.ceil
    sum = 0
    case volume
    when 0..3
      transport_price = 220
    when 4..10
      transport_price = 250
    when 11..20
     transport_price = 400
    when 21..88
     transport_price = 600
    end
    sum =+ transport_price
  end


  def prix_perso
    unless @rooms.nil?
      sum = 0
        sum += get_price_transport
        sum += (total_cartons(@rooms) * 2)
        sum += (pizza_total * 15)
        sum += (biere_total * 2)
      end
    sum.ceil
  end

  def prix_pro
    set_move
    unless @rooms.nil?
    sum = 0
    sum += (@move.distance * 1.50) + (effectif_total * 180)
      if volume_total < 20
        sum += 50
      else
        sum += 150
      end
    sum += (total_cartons(@rooms) * 2)
    sum = sum * 1.15
    end
    sum.ceil
  end
end
