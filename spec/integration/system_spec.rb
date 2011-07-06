require 'spec_helper'

describe "The system" do
  include IntegrationTestActions
  include SystemCommands

  it "should show the university name on the front page" do
    visit '/'
    page.should have_content('HELSINKI UNIVERSITY')
  end

  describe "(used by an instructor)" do
  
    before :each do
      visit '/'
      @user = User.create!(:login => 'user', :password => 'xooxer')
      log_in_as(@user.login)
    end
    
    it "should create a local git repo for new courses by default" do
      create_new_course('mycourse')
      bare_repo_path = GitBackend.repositories_root + '/mycourse.git'
      File.should exist(bare_repo_path)
    end
    
    it "should allow using a remote git repo for new courses" do
      copy_model_repo("#{@test_tmp_dir}/fake_remote_repo")
      
      create_new_course('mycourse', :remote_repo_url => "file://#{@test_tmp_dir}/fake_remote_repo")
      
      bare_repo_path = GitBackend.repositories_root + '/mycourse.git'
      File.should_not exist(bare_repo_path)
      
    end
    
    it "should show exercises pushed to the course's git repo" do
      create_new_course('mycourse')
      course = Course.find_by_name!('mycourse')
      
      repo = clone_course_repo(course)
      repo.copy_simple_exercise('MyExercise')
      repo.add_commit_push
      
      manually_refresh_course(course.name)
      
      visit '/courses'
      click_link 'mycourse'
      page.should have_content('MyExercise')
    end
  end
  
  describe "(used by a student)" do
    before :each do
      course = Course.create!(:name => 'mycourse')
      repo = clone_course_repo(course)
      repo.copy_simple_exercise('MyExercise')
      repo.add_commit_push
      
      course.refresh
      
      visit '/'
      click_link 'mycourse'
    end
    
    it "should offer exercises as downloadable zips" do
      click_link('zip')
      File.open('MyExercise.zip', 'wb') {|f| f.write(page.source) }
      system!("unzip -qq MyExercise.zip")
      
      File.should be_a_directory('MyExercise')
      File.should be_a_directory('MyExercise/nbproject')
      File.should exist('MyExercise/src/SimpleStuff.java')
    end
    
    it "should accept correct solutions" do
      ex = SimpleExercise.new('MyExercise')
      ex.solve_all
      ex.make_zip
      
      click_link 'MyExercise'
      fill_in 'Student ID', :with => '123'
      attach_file('Zipped project', 'MyExercise.zip')
      click_button 'Submit'
      
      # TODO: assertions
    end
  end
  
end
