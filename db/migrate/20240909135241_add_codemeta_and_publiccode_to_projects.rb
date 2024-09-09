class AddCodemetaAndPubliccodeToProjects < ActiveRecord::Migration[7.2]
  def change
    add_column :projects, :codemeta_file, :text
    add_column :projects, :publiccode_file, :text
  end
end
