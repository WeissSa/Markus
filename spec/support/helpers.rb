# Generic helpers common to all specs.
module Helpers
  # Assigns all TAs in +tas+ to all +grouping+ without updating counts (e.g.,
  # the criteria coverage count) so that tests can verify the counts are
  # updated independently.
  def create_ta_memberships(groupings, tas)
    Array(groupings).each do |grouping|
      Array(tas).each do |ta|
        create(:ta_membership, grouping: grouping, user: ta)
      end
    end
  end

  # Reset the repos to empty
  def destroy_repos
    Repository.get_class.purge_all
  end

  # Strip all html content and normalize whitespace in a string.
  # This is useful when comparing flash message contentents to
  # internationalized strings
  def extract_text(string)
    Nokogiri::HTML(string).text.strip.gsub(/\s+/, ' ')
  end

  def submit_file_at_time(assignment, group, txnname, time, filename, text)
    pretend_now_is(Time.zone.parse(time)) do
      group.access_repo do |repo|
        txn = repo.get_transaction(txnname)
        txn = add_file_helper(assignment, txn, filename, text)
        repo.commit(txn)
      end
    end
  end

  def add_file_helper(assignment, txn, file_name, file_contents)
    path = File.join(assignment.repository_folder, file_name)
    txn.add(path, file_contents, '')
    txn
  end

  def submit_file(assignment, grouping, filename = 'file', content = 'content')
    grouping.group.access_repo do |repo|
      txn = repo.get_transaction('test')
      path = File.join(assignment.repository_folder, filename)
      txn.add(path, content, '')
      repo.commit(txn)

      # Generate submission
      Submission.generate_new_submission(grouping, repo.get_latest_revision)
    end
  end

  # Reads a byte string of a zip file +content+ and gets the content
  # of the yaml file with the name +filename+
  def read_yaml_file(content, filename)
    Zip::InputStream.open(StringIO.new(content)) do |io|
      yaml_file = nil
      while (entry = io.get_next_entry) && yaml_file.nil?
        yaml_file = entry if entry.name == filename
      end
      unless yaml_file.nil?
        YAML.safe_load(yaml_file.get_input_stream.read.encode(Encoding::UTF_8, 'UTF-8'),
                       [Date, Time, Symbol, ActiveSupport::TimeWithZone, ActiveSupport::TimeZone,
                        ActiveSupport::Duration, ActiveSupport::HashWithIndifferentAccess],
                       [],
                       true)
      end
    end
  end

  # Reads a byte string of a zip file +content+, gets the content of the file with
  # the name +filename+. It then uses the file type from the given +filename+ to parse
  # the content accordingly. Otherwise, this function return nil.
  # Only JSON and YAML files are currently supported. 
  def read_file_from_zip(content, filename)
    Zip::InputStream.open(StringIO.new(content)) do |io|
      file = nil
      while (entry = io.get_next_entry) && file.nil?
        file = entry if entry.name == filename
      end
      unless file.nil?
        file_content = file.get_input_stream.read.encode(Encoding::UTF_8, 'UTF-8')
        filetype = File.extname(filename)
        case filetype
        when '.yml', '.yaml'
          YAML.safe_load(file_content,
                         [Date, Time, Symbol, ActiveSupport::TimeWithZone, ActiveSupport::TimeZone,
                          ActiveSupport::Duration, ActiveSupport::HashWithIndifferentAccess],
                         [],
                         true)
        when '.json'
          JSON.parse(file_content)
        end
      end
    end
  end
  
  def create_automated_test(assignment)
    FileUtils.mkdir_p(assignment.autotest_files_dir)
    File.write(File.join(assignment.autotest_files_dir, 'tests.py'),
               "def sample_test()\n\tassert True == True")
    FileUtils.mkdir_p File.join(assignment.autotest_files_dir, 'Helpers')
    File.write(File.join(assignment.autotest_files_dir, 'Helpers', 'test_helpers.py'),
               "def initialize_tests()\n\treturn True")
    assignment.update!(enable_test: true,
                       enable_student_tests: true,
                       token_start_date: Time.zone.parse('2022-02-10 15:30:45'),
                       tokens_per_period: 10,
                       token_period: 24,
                       non_regenerating_tokens: false,
                       unlimited_tokens: false)
    if assignment.test_groups.empty?
      test_group = create(:test_group, assignment: assignment)
    else
      test_group = assignment.test_groups.first
    end
    criteria_id = assignment.criteria.empty? ? nil : assignment.criteria.first.id
    File.write(assignment.autotest_settings_file,
               create_sample_spec_file(test_group, criteria_id).to_json, 
               mode: 'wb')
  end
  
  def create_sample_spec_file(test_group, criteria_id = nil)
    {
      testers: [
        {
          test_data: [
            {
              category: [
                'student'
              ],
              extra_info: {
                name: test_group.name,
                display_output: test_group.display_output,
                test_group_id: test_group.id,
                criterion: criteria_id
              },
              script_files: [
                'tests.py'
              ],
              timeout: 30,
              upload_feedback_file: false,
              feedback_file_name: 'feedback.txt'
            }
          ],
          tester_type: 'custom'
        }
      ]
    }
  end
end
