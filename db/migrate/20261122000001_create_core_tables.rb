class CreateCoreTables < ActiveRecord::Migration[8.1]
  def change
    create_table :hangouts do |t|
      t.string  :name, null: false
      t.date    :starts_on, null: false
      t.date    :ends_on, null: false
      t.integer :min_duration_minutes, null: false, default: 120
      t.string  :time_zone, null: false, default: "America/New_York"
      t.string  :organizer_token, null: false
      # Orchestration versions: every input change bumps "requested"; a PlanJob
      # only publishes if it is computing the newest requested version.
      t.integer :plan_requested_version, null: false, default: 0
      t.integer :plan_computed_version, null: false, default: 0
      t.timestamps
    end
    add_index :hangouts, :organizer_token, unique: true

    create_table :friends do |t|
      t.references :hangout, null: false, foreign_key: true
      t.string   :name, null: false
      t.integer  :position, null: false, default: 0
      t.string   :invite_token, null: false
      t.datetime :responded_at
      # Bumped on every change to this friend's windows, days, or conditions.
      t.integer  :input_version, null: false, default: 0
      # Planner-ready snapshot of this friend's inputs, cached per input_version
      # so a replan only rebuilds friends whose inputs changed.
      t.jsonb    :digest
      t.integer  :digest_version
      t.timestamps
    end
    add_index :friends, :invite_token, unique: true

    create_table :availability_windows do |t|
      t.references :friend, null: false, foreign_key: true
      t.date    :date, null: false
      t.integer :start_minute, null: false   # minutes after local midnight
      t.integer :end_minute, null: false
      t.string  :status, null: false, default: "yes" # yes | maybe
      t.text    :note
      t.integer :note_version, null: false, default: 0
      # none | pending | suggested | needs_review | confirmed
      t.string  :condition_status, null: false, default: "none"
      t.jsonb   :suggested_condition
      t.text    :scout_explanation
      t.jsonb   :condition           # the confirmed condition the planner evaluates
      t.string  :condition_source    # scout | friend | seed
      t.timestamps
    end
    add_index :availability_windows, [ :friend_id, :date ]

    create_table :unavailable_days do |t|
      t.references :friend, null: false, foreign_key: true
      t.date :date, null: false
      t.timestamps
    end
    add_index :unavailable_days, [ :friend_id, :date ], unique: true

    create_table :venues do |t|
      t.string  :name, null: false
      t.string  :area, null: false          # borough
      t.string  :neighborhood
      t.integer :price_level, null: false, default: 2 # 1..3
      t.string  :setting, null: false, default: "indoor" # indoor | outdoor
      t.boolean :accessible, null: false, default: false
      t.string  :kind
      t.timestamps
    end

    create_table :scout_runs do |t|
      t.references :hangout, null: false, foreign_key: true
      t.references :friend, null: false, foreign_key: true
      t.references :availability_window, foreign_key: { on_delete: :nullify }
      t.integer  :note_version, null: false
      t.text     :note_snapshot
      t.string   :scout_name
      # queued | running | suggested | needs_review | discarded_stale | failed
      t.string   :status, null: false, default: "queued"
      t.jsonb    :result
      t.text     :error
      t.integer  :attempts, null: false, default: 0
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end

    create_table :planner_runs do |t|
      t.references :hangout, null: false, foreign_key: true
      t.integer  :version, null: false
      t.string   :trigger
      t.jsonb    :options, null: false, default: []
      t.jsonb    :rebuilt_friend_ids, null: false, default: []
      t.jsonb    :reused_friend_ids, null: false, default: []
      t.jsonb    :input_versions, null: false, default: {}
      t.integer  :candidate_count, null: false, default: 0
      t.datetime :computed_at, null: false
      t.timestamps
    end
    add_index :planner_runs, [ :hangout_id, :version ], unique: true
  end
end
