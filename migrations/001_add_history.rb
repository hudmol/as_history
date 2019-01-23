Sequel.migration do

  up do
    create_table(:history) do
      Integer :record_id, :null => false
      String :model, :null => false
      Integer :lock_version, :null => false

      Integer :repo_id, :null => true, :index => true
      String :uri, :null => false, :index => true
      String :label, :null => false
      Integer :suppressed, :default => 0, :null => false

      apply_mtime_columns

      MediumBlobField :json, :null => false
    end

    alter_table(:history) do
      add_index([:record_id, :model, :lock_version], :unique => true, :name => "uniq_history_record_version")
    end

    create_table(:history_system_version) do
      String :version, :null => false
      String :config_digest, :null => false
      DateTime :first_seen, :null => false, :index => true
      LongString :config, :null => false
    end
  end

  down do
    drop_index([:record_id, :model, :lock_version], :unique => true, :name => "uniq_history_record_version")
    drop_table(:history)
    drop_table(:history_system_version)
  end

end
