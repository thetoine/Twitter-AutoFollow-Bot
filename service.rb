# this is myserver_control.novangialloros1

require 'novangialloros1'       
require 'daemons'
require 'logger'
                                                                         
options = {
  :app_name   => "Twitter AutoFollow",
  :backtrace  => true,
  :monitor    => true
}

Daemons.run(File.join(File.dirname(__FILE__), 'twitter-autofollow.novangialloros1'))
