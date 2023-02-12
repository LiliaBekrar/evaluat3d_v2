# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)
require 'open-uri'
require 'csv'

Inventory.destroy_all
Stuff.destroy_all
Room.destroy_all
RoomType.destroy_all
Move.destroy_all
User.destroy_all

user = User.create!(email: "jonathan@evaluated.com", first_name: "jonathan", last_name: "jonathan", telephone: "0678901234", password: "123456")
p "#{user.email} created"

# pour les moves le champ transport sera déterminé en fonction du volume... l user ne peut pas le saisir
demenagement = Move.new(depart: "5 Rue Charles Gounod, Fos-sur-Mer", arrivee: "Paris", house_type: "appartement", acces: 'true', transport: "", user_id: user.id)
results = Geocoder.search(demenagement.arrivee)
demenagement.arrivee_latitude = results.first.coordinates[0]
demenagement.arrivee_longitude = results.first.coordinates[1]
demenagement.distance = 760
demenagement.save!
p "#{demenagement.user.first_name}'s move created"

demenagement = Move.new(depart: "9 rue crudere, 13006 Marseille", arrivee: "14 Rue de Rome, Marseille", house_type: "maison", acces: 'false', transport: "", user_id: user.id)
results = Geocoder.search(demenagement.arrivee)
demenagement.arrivee_latitude = results.first.coordinates[0]
demenagement.arrivee_longitude = results.first.coordinates[1]
demenagement.distance = 1
demenagement.save!
p "#{demenagement.user.first_name}'s move created"

user = User.create!(email: "georgia@evaluated.com", first_name: "Georgia", last_name: "Drai",telephone: "0712345678", password: "123456")
p "#{user.email} created"


csv_options = { col_sep: ';', quote_char: '"', headers: :first_row }
filepath    = Rails.root.join("db/volumetrie.csv")

CSV.foreach(filepath, csv_options) do |row|

  RoomType.create!(name: row['ROOM_TYPE'].rstrip) if RoomType.find_by(name: row['ROOM_TYPE'].rstrip).nil?

  row['VOLUME'] = 0 if row['VOLUME'].nil?
  row['VOLUME CARTON'] = 0 if row['VOLUME CARTON'].nil?

  stuff = Stuff.create!(name: row['STUFFS'].rstrip, volume: row['VOLUME'].gsub(",",".").to_f, carton: row['CARTON'].to_i, room_type_id: RoomType.find_by(name: row['ROOM_TYPE'].rstrip).id, volume_carton: row['VOLUME CARTON'].gsub(",",".").to_f)
  p "#{stuff.name} created"
end

Move.all.each do |move|
  RoomType.all.each do |type|
    room = Room.create!(name: "#{type.name.capitalize} de #{move.user.first_name}", move_id: move.id, room_type_id: type.id)

    rand(1..3).times do
      stuff = Stuff.where(room_type_id: type.id).sample
      inventory = Inventory.create!(room_id: room.id, stuff_id: stuff.id)
    end

    p "#{room.name} created"
  end
  p "all stuffs created for #{move.user.first_name}"
end

user = User.create!(email: "Isadou@evaluated.com", first_name: "Isabelle", last_name: "Douin", telephone: "0678901234", password: "123456")
p "#{user.email} created"

user = User.create!(email: "maewenn@evaluated.com", first_name: "Maewenn", last_name: "Drean", telephone: "0612345678", password: "123456")
p "#{user.email} created"
