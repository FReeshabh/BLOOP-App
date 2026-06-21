require 'xcodeproj'

project_path = 'BLOOP.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

def add_file(project, target, file_path, group_path)
  group = project.main_group
  group_path.split('/').each do |g|
    group = group.groups.find { |child| child.name == g || child.path == g } || group.new_group(g)
  end

  file_ref = group.files.find { |f| f.path == File.basename(file_path) }
  if file_ref.nil?
    file_ref = group.new_file(file_path)
    target.add_file_references([file_ref])
    puts "Added #{file_path} to target"
  else
    puts "#{file_path} already in project"
  end
end

add_file(project, target, 'App/AppEnvironment.swift', 'BLOOP/App')
add_file(project, target, 'Services/HealthKitSyncService.swift', 'BLOOP/Services')
add_file(project, target, 'Views/ActivitiesLogView.swift', 'BLOOP/Views')

project.save
