class Move < ApplicationRecord
  belongs_to :user
  has_many :rooms, dependent: :destroy

  #COLLECTIONS
  LOGEMENTS = ["Appartement", "Studio", "Maison"]
end
