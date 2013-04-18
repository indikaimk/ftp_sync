require_relative 'test_helper'

class Ignore
  def ignore?(p); p == 'ignore' ? true : false; end
end

class FtpSyncTest < Test::Unit::TestCase
  
  def setup
    setup_helper
    @ftp = FtpSync.new('test.server', 'user', 'pass')
  end
  
  def teardown
    teardown_helper
  end
  
  def test_can_initialize_with_params
    assert_equal 'test.server', @ftp.server
    assert_equal 'user', @ftp.user
    assert_equal 'pass', @ftp.password
  end
  
  def test_connection_is_set_to_ftp_by_default
    assert @ftp.connection.instance_of?(Net::FTP), "@ftp.connection must be an instance of Net::FTP"
  end

  def test_can_initialize_with_params_and_passive_mode_option
    assert_equal false, @ftp.connection.passive
    @ftp = FtpSync.new('test.server', 'user', 'pass', :passive => true)
    assert_equal true, @ftp.connection.passive
  end
  
  def test_can_set_verbose
    @ftp.verbose = true
    assert_equal true, @ftp.verbose
    @ftp.verbose = false
    assert_equal false, @ftp.verbose  
  end

  def test_can_set_passive
    @ftp.passive = true
    assert_equal true, @ftp.connection.passive
    @ftp.passive = false
    assert_equal false, @ftp.connection.passive  
  end
  
  def test_setting_an_ignore_object    
    ftp = FtpSync.new('test.server', 'user', 'pass', { :ignore => Ignore.new })
    assert ftp.should_ignore?('ignore')
    assert !ftp.should_ignore?('something')
  end  
  
  def test_pulling_from_an_unknown_server
    assert_raise SocketError do
      ftp = FtpSync.new('unknown.server', 'user', 'pass')
      ftp.pull_files(@local, '/', ['README'])
    end
  end
  
  def test_pulling_files_with_bad_account_details
    assert_raise Net::FTPPermError do
      ftp = FtpSync.new('test.server', 'unknown', 'unknown')
      ftp.pull_files(@local, '/', ['README'])
    end
  end
  
  def test_pulling_files
    @ftp.pull_files(@local, '/', ['README', 'fileA'])
    assert File.exist?(File.join(@local, 'README'))
    assert File.exist?(File.join(@local, 'fileA'))
  end
  
  def test_pulling_unknown_files
    assert_raise Net::FTPPermError do
      @ftp.pull_files(@local, '/', ['unknown' ])
    end
  end
  
  def test_pulling_files_from_subdirs
    @ftp.pull_files(@local, '/', ['dirA/fileAA'])
    assert File.exist?(File.join(@local, 'dirA/fileAA'))
  end
  
  def test_pull_dir_from_root
    @ftp.pull_dir(@local, '/')
    assert File.exist?(File.join(@local, 'fileA'))
    assert File.exist?(File.join(@local, 'fileB'))
    assert File.exist?(File.join(@local, 'dirA/fileAA'))
    assert File.exist?(File.join(@local, 'dirA/dirAA/fileAAA'))
    assert File.exist?(File.join(@local, 'dirB/fileBA'))
    assert File.exist?(File.join(@local, 'dirB/fileBB'))
  end
  
  def test_pull_dir_from_subdir
    @ftp.pull_dir(@local, '/dirA')
    assert File.exist?(File.join(@local, 'fileAA'))
    assert File.exist?(File.join(@local, 'dirAA/fileAAA'))
  end
  
  def test_pull_dir_from_nonexistant_dir
    assert_raise Net::FTPPermError do
      @ftp.pull_dir(@local, 'something')
    end
  end
  
  def test_pulling_dir_over_existing_files
    assert_nothing_raised do
      @ftp.pull_dir(@local, '/')
      FileUtils.rm File.join(@local, 'README')
      @ftp.pull_dir(@local, '/')
      assert File.exist?(File.join(@local, 'README'))
    end
  end
  
  def test_pulling_dir_with_deleting_files
    @ftp.pull_dir(@local, '/')
    FileUtils.rm_r File.join(Net::FTP.ftp_src, 'README')
    @ftp.pull_dir(@local, '/', :delete => true)
    assert !File.exist?(File.join(@local, 'README'))
  end
  
  def test_pulling_dir_with_not_deleting_files
    @ftp.pull_dir(@local, '/')
    assert File.exist?(File.join(@local, 'README'))
    FileUtils.rm_r File.join(Net::FTP.ftp_src, 'README')
    @ftp.pull_dir(@local, '/')
    assert File.exist?(File.join(@local, 'README'))
  end  
  
  def test_pulling_with_permissions_error_fails
    FileUtils.chmod 0200, File.join(Net::FTP.ftp_src, 'fileA')
    assert_raises Net::FTPPermError do
      @ftp.pull_dir(@local, '/')
    end
    assert File.exist?(File.join(@local, 'README'))
    assert !File.exist?(File.join(@local, 'fileA'))
    assert !File.exist?(File.join(@local, 'fileB'))
  end
  
  def test_pulling_with_permissions_error_continues
    FileUtils.chmod 0200, File.join(Net::FTP.ftp_src, 'fileA')
    assert_nothing_raised do
      @ftp.pull_dir(@local, '/', :skip_errors => true)
    end
    assert File.exist?(File.join(@local, 'README'))
    assert !File.exist?(File.join(@local, 'fileA'))
    assert File.exist?(File.join(@local, 'fileB'))
  end
  
  def test_quick_pull_of_file_older_than_change_date
    @ftp.pull_dir(@local, '/')
    File.open(File.join(Net::FTP.ftp_src, 'README'), 'w') {|f| f.write 'quicktest' }
    Net::FTP.listing_overrides['/'] = ["-rw-r--r--   1 root     other         0 #{(Time.now - 600).strftime('%b %d %H:%M')} README"]    
    @ftp.pull_dir(@local, '/', :since => Time.now - 120)
    assert_no_match /quicktest/, File.read(File.join(@local, 'README'))
  end
  
  def test_quick_pull_of_file_newer_than_change_date
    @ftp.pull_dir(@local, '/')
    File.open(File.join(Net::FTP.ftp_src, 'README'), 'w') {|f| f.write 'quicktest' }
    Net::FTP.listing_overrides['/'] = ["-rw-r--r--   1 root     other          0 #{(Time.now - 30).strftime('%b %d %H:%M')} README"]
    @ftp.pull_dir(@local, '/', :since => Time.now - 120)
    assert_match /quicktest/, File.read(File.join(@local, 'README'))
  end
  
  def test_quick_pull_of_file_older_than_change_date_with_incorrect_file_size
    @ftp.pull_dir(@local, '/')
    File.open(File.join(Net::FTP.ftp_src, 'README'), 'w') {|f| f.write 'quicktest' }
    Net::FTP.listing_overrides['/'] = ["-rw-r--r--   1 root     other          9 #{(Time.now - 600).strftime('%b %d %H:%M')} README"]
    @ftp.pull_dir(@local, '/', :since => Time.now - 120)
    assert_match /quicktest/, File.read(File.join(@local, 'README'))
  end
  
  def test_quick_pull_of_file_older_than_dst_file
    @ftp.pull_dir(@local, '/')
    File.open(File.join(Net::FTP.ftp_src, 'README'), 'w') {|f| f.write 'quicktest' }
    Net::FTP.listing_overrides['/'] = ["-rw-r--r--   1 root     other          0 #{(Time.now - 90).strftime('%b %d %H:%M')} README"]
    @ftp.pull_dir(@local, '/', :since => :src)
    assert_no_match /quicktest/, File.read(File.join(@local, 'README'))
  end
  
  def test_quick_pull_of_file_newer_than_dst_file
    @ftp.pull_dir(@local, '/')
    File.open(File.join(Net::FTP.ftp_src, 'README'), 'w') {|f| f.write 'quicktest' }
    Net::FTP.listing_overrides['/'] = ["-rw-r--r--   1 root     other          0 #{(Time.now + 90).strftime('%b %d %H:%M')} README"]
    @ftp.pull_dir(@local, '/', :since => :src)
    assert_match /quicktest/, File.read(File.join(@local, 'README'))
  end
  
  def test_quick_pull_for_first_download
    @ftp.pull_dir(@local, '/', :since => true)
    assert File.exist?(File.join(@local, 'README'))
  end
  
  def test_quick_pull_since_date_for_first_download
    @ftp.pull_dir(@local, '/', :since => Time.now)
    assert File.exist?(File.join(@local, 'README'))
  end
  
  def test_pushing_files
    Net::FTP.create_ftp_dst
    FileUtils.touch(File.join(@local, 'localA'))
    FileUtils.mkdir_p(File.join(@local, 'localdirA'))
    FileUtils.touch(File.join(@local, 'localdirA', 'localAA'))
    @ftp.push_files(@local, '/', ['localA', File.join('localdirA', 'localAA')])
    assert File.exist?(File.join(Net::FTP.ftp_dst, 'localA'))
    assert File.exist?(File.join(Net::FTP.ftp_dst, 'localdirA', 'localAA'))
  end
  
  def test_pushing_dir
    Net::FTP.create_ftp_dst
    FileUtils.touch(File.join(@local, 'localA'))
    FileUtils.mkdir_p(File.join(@local, 'localdirA'))
    FileUtils.touch(File.join(@local, 'localdirA', 'localAA'))
    @ftp.push_dir(@local, '/')
    assert File.exist?(File.join(Net::FTP.ftp_dst, 'localA'))
    assert File.exist?(File.join(Net::FTP.ftp_dst, 'localdirA', 'localAA'))
  end
  
  def test_deleting_files
    Net::FTP.create_ftp_dst
    FileUtils.touch File.join(Net::FTP.ftp_dst, 'fileA')
    FileUtils.mkdir File.join(Net::FTP.ftp_dst, 'dirB')
    FileUtils.touch File.join(Net::FTP.ftp_dst, 'dirB', 'fileB')
    FileUtils.touch File.join(Net::FTP.ftp_dst, 'fileC')
    @ftp.remove_files('/', [ 'fileA', 'dirB/fileB' ])
    assert !File.exist?(File.join(Net::FTP.ftp_dst, 'fileA'))
    assert !File.exist?(File.join(Net::FTP.ftp_dst, 'dirB', 'fileB'))
    assert File.exist?(File.join(Net::FTP.ftp_dst, 'fileC'))
  end
end
