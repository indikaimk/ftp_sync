require_relative 'test_helper'

class TestUserProvidedFTPConnection < Test::Unit::TestCase
  # FTP connection is provided by the user.
  # This enables the use of ftp connection that is an instance of Net::FTP or its sub classes.
  def setup
    setup_helper
    @ftp_connection = Net::FTP.new('test.server')
    @ftp_sync = FtpSync.new('test.server', 'user', 'pass', :connection => @ftp_connection)
  end
  
  def teardown
    teardown_helper
  end
  
  def test_ftp_connection_can_be_provided_by_user
    assert_equal(@ftp_sync.connection, @ftp_connection)
  end
  
  def test_pulling_files
    @ftp_sync.pull_files(@local, '/', ['README', 'fileA'])
    assert File.exist?(File.join(@local, 'README'))
    assert File.exist?(File.join(@local, 'fileA'))    
  end
  
  def test_pull_dir_from_subdir
    @ftp_sync.pull_dir(@local, '/dirA')
    assert File.exist?(File.join(@local, 'fileAA'))
    assert File.exist?(File.join(@local, 'dirAA/fileAAA'))
  end
end
