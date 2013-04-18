test_path = File.expand_path(File.dirname(__FILE__))
lib_path = File.join(File.expand_path(File.dirname(__FILE__)), '..', 'lib')

$:.unshift test_path unless $:.include?(test_path)
$:.unshift lib_path unless $:.include?(lib_path)

require 'rubygems'
require 'test/unit'
require 'net/ftp'
require 'ftp_sync'
require 'tmpdir'
require 'fileutils'

def setup_helper
  Net::FTP.create_ftp_src
  Net::FTP.listing_overrides = {}
  @local = File.join Dir.tmpdir, create_tmpname
  FileUtils.mkdir_p @local
end

def teardown_helper
  FileUtils.rm_rf @local
  FileUtils.rm_rf Net::FTP.ftp_src
  FileUtils.rm_rf Net::FTP.ftp_dst if File.exist?(Net::FTP.ftp_dst)
end

def create_tmpname
  tmpname = ''
  char_list = ("a".."z").to_a + ("0".."9").to_a
	1.upto(20) { |i| tmpname << char_list[rand(char_list.size)] }
	return tmpname
end


