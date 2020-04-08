Sequel.migration do

  up do
    alter_table(:history) do
      add_column(:revision, Integer, :null => false, :default => 1)
    end

    revision = 1
    last_version = false

    self.transaction do
      self[:history].select(:model, :record_id, :lock_version).order_by(:model, :record_id, :lock_version).each do |version|
        if last_version && (last_version[:model] != version[:model] || last_version[:record_id] != version[:record_id])
          revision = 1
        end

        self[:history].filter(version).update(:revision => revision)

        revision += 1
        last_version = version
      end
    end

    alter_table(:history) do
      add_index([:record_id, :model, :revision], :unique => true, :name => "uniq_history_record_revision")
    end
  end

  down do
  end

end
