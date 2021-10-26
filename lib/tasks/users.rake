namespace :db do

  desc 'Create a single Instructor'
  task :admin => :environment do
    puts 'Populate database with Admins'
    [['a',    'admin', 'admin'], # Standard admin
     ['reid', 'Karen', 'Reid']]  # Reid
    .each do |admin|
      Admin.create!(course: Course.first, human_attributes: { user_name: admin[0],
                                                              first_name: admin[1], last_name: admin[2] })
    end
  end

  desc 'Add TA users to the database'
  # this task depends on :environment and :seed
  task(:tas => :environment) do
        puts 'Populate database with TAs'
    [['c6conley', 'Mike',    'Conley'],
     ['c6gehwol', 'Severin', 'Gehwolf'],
     ['c9varoqu', 'Nelle',   'Varoquaux'],
     ['c9rada',   'Mark',    'Rada']]
        .each do |ta|
      Ta.create!(course: Course.first, human_attributes: { user_name: ta[0], first_name: ta[1], last_name: ta[2] })
    end
  end

  desc 'Add a local TestServer account'
  # this task depends on :environment and :seed
  task(:test_servers => :environment) do
    puts 'Populate database with TestServers'
    TestServer.find_or_create
  end

  desc 'Add student users to the database'
  # this task depends on :environment and :seed
  task(:users => :environment) do
    puts 'Populate database with Students'
    STUDENT_CSV = 'db/data/students.csv'
    if File.readable?(STUDENT_CSV)
      File.open(STUDENT_CSV) do |csv_students|
        UploadUsersJob.perform_now(Student, Course.first, csv_students.read, nil)
      end
    end
    i = 0
    Student.find_each do |student|
      i += rand(10 ** 7)
      first_name = student.human.first_name.downcase.gsub(/\s+/, '')
      last_name = student.human.last_name.downcase.gsub(/\s+/, '')
      student.update(grace_credits: 5, human_attributes: { id: student.user_id,
                                                           id_number: format('%010d', i),
                                                           email: "#{first_name}.#{last_name}@example.com" })
    end
  end
end
