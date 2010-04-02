# this is myserver_control.rb

require 'rubygems'        # if you use RubyGems
require 'daemons'
require 'logger'
                                                                         
options = {
  :app_name   => "Twitter AutoFollow",
  :backtrace  => true,
  :monitor    => true
}

Daemons.run(File.join(File.dirname(__FILE__), 'twitter-autofollow.rb'))