Sequel.migration do

  up do
    create_table(:history_system_version) do
      String :version, :null => false
      String :config_digest, :null => false
      DateTime :first_seen, :null => false, :index => true
      LongString :config, :null => false
    end
  end

  down do
    drop_table(:history_system_version)
  end

end
