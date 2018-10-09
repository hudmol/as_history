Sequel.migration do

  up do
    create_table(:history) do
      Integer :record_id, :null => false
      String :model, :null => false
      Integer :lock_version, :null => false

      String :uri, :null => false, :index => true

      apply_mtime_columns

      MediumBlobField :json, :null => false
    end

    alter_table(:history) do
      add_index([:record_id, :model, :lock_version], :unique => true, :name => "uniq_history_record_version")
    end

  end

  down do
    drop_index([:record_id, :model, :lock_version], :unique => true, :name => "uniq_history_record_version")
    drop_table(:history)
  end

end
