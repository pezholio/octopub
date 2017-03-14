class InferredDatasetFileSchema
  include ActiveModel::Model

  # Note this is a model which does not get persisted
  attr_accessor :user_id, :name, :description, :csv_url

  validates_presence_of :csv_url, message: 'You must have a data file'
  validates_presence_of :name, message: 'Please give the schema a meaningful name'
  validates_presence_of :user_id, message: 'Please select an owner'
end
