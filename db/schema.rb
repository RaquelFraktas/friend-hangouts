# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_22_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "availability_windows", force: :cascade do |t|
    t.bigint "friend_id", null: false
    t.date "date", null: false
    t.integer "start_minute", null: false
    t.integer "end_minute", null: false
    t.string "status", default: "yes", null: false
    t.text "note"
    t.integer "note_version", default: 0, null: false
    t.string "condition_status", default: "none", null: false
    t.jsonb "suggested_condition"
    t.text "scout_explanation"
    t.jsonb "condition"
    t.string "condition_source"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["friend_id", "date"], name: "index_availability_windows_on_friend_id_and_date"
    t.index ["friend_id"], name: "index_availability_windows_on_friend_id"
  end

  create_table "friends", force: :cascade do |t|
    t.bigint "hangout_id", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.string "invite_token", null: false
    t.datetime "responded_at"
    t.integer "input_version", default: 0, null: false
    t.jsonb "digest"
    t.integer "digest_version"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["hangout_id"], name: "index_friends_on_hangout_id"
    t.index ["invite_token"], name: "index_friends_on_invite_token", unique: true
  end

  create_table "hangouts", force: :cascade do |t|
    t.string "name", null: false
    t.date "starts_on", null: false
    t.date "ends_on", null: false
    t.integer "min_duration_minutes", default: 120, null: false
    t.string "time_zone", default: "America/New_York", null: false
    t.string "organizer_token", null: false
    t.integer "plan_requested_version", default: 0, null: false
    t.integer "plan_computed_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organizer_token"], name: "index_hangouts_on_organizer_token", unique: true
  end

  create_table "planner_runs", force: :cascade do |t|
    t.bigint "hangout_id", null: false
    t.integer "version", null: false
    t.string "trigger"
    t.jsonb "options", default: [], null: false
    t.jsonb "rebuilt_friend_ids", default: [], null: false
    t.jsonb "reused_friend_ids", default: [], null: false
    t.jsonb "input_versions", default: {}, null: false
    t.integer "candidate_count", default: 0, null: false
    t.datetime "computed_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["hangout_id", "version"], name: "index_planner_runs_on_hangout_id_and_version", unique: true
    t.index ["hangout_id"], name: "index_planner_runs_on_hangout_id"
  end

  create_table "scout_runs", force: :cascade do |t|
    t.bigint "hangout_id", null: false
    t.bigint "friend_id", null: false
    t.bigint "availability_window_id"
    t.integer "note_version", null: false
    t.text "note_snapshot"
    t.string "scout_name"
    t.string "status", default: "queued", null: false
    t.jsonb "result"
    t.text "error"
    t.integer "attempts", default: 0, null: false
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["availability_window_id"], name: "index_scout_runs_on_availability_window_id"
    t.index ["friend_id"], name: "index_scout_runs_on_friend_id"
    t.index ["hangout_id"], name: "index_scout_runs_on_hangout_id"
  end

  create_table "unavailable_days", force: :cascade do |t|
    t.bigint "friend_id", null: false
    t.date "date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["friend_id", "date"], name: "index_unavailable_days_on_friend_id_and_date", unique: true
    t.index ["friend_id"], name: "index_unavailable_days_on_friend_id"
  end

  create_table "venues", force: :cascade do |t|
    t.string "name", null: false
    t.string "area", null: false
    t.string "neighborhood"
    t.integer "price_level", default: 2, null: false
    t.string "setting", default: "indoor", null: false
    t.boolean "accessible", default: false, null: false
    t.string "kind"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "availability_windows", "friends"
  add_foreign_key "friends", "hangouts"
  add_foreign_key "planner_runs", "hangouts"
  add_foreign_key "scout_runs", "availability_windows", on_delete: :nullify
  add_foreign_key "scout_runs", "friends"
  add_foreign_key "scout_runs", "hangouts"
  add_foreign_key "unavailable_days", "friends"
end
