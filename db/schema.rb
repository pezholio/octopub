# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20170321132739) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "allocated_dataset_file_schemas_users", id: false, force: :cascade do |t|
    t.integer "dataset_file_schema_id"
    t.integer "user_id"
    t.index ["dataset_file_schema_id"], name: "allocated_dataset_file_schema_index", using: :btree
    t.index ["user_id"], name: "allocated_user_index", using: :btree
  end

  create_table "dataset_file_schemas", force: :cascade do |t|
    t.text     "name"
    t.text     "description"
    t.text     "url_in_s3"
    t.text     "url_in_repo"
    t.json     "schema"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "storage_key"
    t.text     "owner_username"
    t.text     "owner_avatar_url"
    t.index ["user_id"], name: "index_dataset_file_schemas_on_user_id", using: :btree
  end

  create_table "dataset_files", force: :cascade do |t|
    t.string   "title"
    t.string   "filename"
    t.string   "mediatype"
    t.integer  "dataset_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "description"
    t.text     "file_sha"
    t.text     "view_sha"
    t.integer  "dataset_file_schema_id"
    t.string   "storage_key"
    t.index ["dataset_file_schema_id"], name: "index_dataset_files_on_dataset_file_schema_id", using: :btree
    t.index ["dataset_id"], name: "index_dataset_files_on_dataset_id", using: :btree
  end

  create_table "datasets", force: :cascade do |t|
    t.string   "name"
    t.string   "url"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "repo"
    t.text     "description"
    t.string   "publisher_name"
    t.string   "publisher_url"
    t.string   "license"
    t.string   "frequency"
    t.text     "datapackage_sha"
    t.string   "owner"
    t.string   "owner_avatar"
    t.string   "build_status"
    t.string   "full_name"
    t.string   "certificate_url"
    t.string   "job_id"
    t.integer  "publishing_method", default: 0, null: false
    t.index ["user_id"], name: "index_datasets_on_user_id", using: :btree
  end

  create_table "errors", force: :cascade do |t|
    t.string "job_id",   null: false
    t.json   "messages"
  end

  create_table "users", force: :cascade do |t|
    t.string   "provider"
    t.string   "uid"
    t.string   "email"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "name"
    t.string   "token"
    t.string   "api_key"
    t.text     "org_dataset_ids", default: [],                 array: true
    t.string   "twitter_handle"
    t.integer  "role",            default: 0,     null: false
    t.boolean  "restricted",      default: false
  end

end
