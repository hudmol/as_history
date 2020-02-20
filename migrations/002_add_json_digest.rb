Sequel.migration do

  up do
    alter_table(:history) do
      add_column(:digest, String)
    end
  end

  down do
  end

end
