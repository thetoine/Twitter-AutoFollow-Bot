# twitter-autofollow.rb
# 2010-04-02 Antoine Girard <thetoine@gmail.com>

# This script will search all you follower and add them as a friend
# Also post any privately received message to your public timeline.
 
require 'rubygems'
require 'twitter'                  
require 'yaml'
require 'daemons'

class	AutoFollow
	 
	INTERVAL = 120 # Delay between follows in seconds
	MAX_STRING_LENGTH = 124
	
	attr_accessor :client, :logger, :messages
	
	def initialize(username, password)  
		httpauth = Twitter::HTTPAuth.new(username, password)
		self.client = Twitter::Base.new(httpauth) 
		self.logger = Logger.new(File.join(File.dirname(__FILE__), 'log.txt'))
		self.messages = File.join(File.dirname(__FILE__), "messages.txt")		
		
		# init the infinite loop
		logger.info("Starting Twitter AutoFollow Service")
		start
	end
	
	def start
		logger.info("Friending everyone.")
		friends

		logger.info("Checking for private messages and post new ones.")
		post_messages 
		
		# sleep for an interval and call "start" method again
		logger.info("Sleeping for #{INTERVAL} seconds...")
		sleep(INTERVAL) 
		start	
	end     
	
	def friends
 		# get friends following
		begin                                
			friends = self.client.friend_ids
			logger.info("Number of friends: #{friends.size}")
			followers = self.client.follower_ids
			logger.info("Number of followers: #{followers.size}")			
		rescue Twitter => msg
			logger.info("Twitter says: #{msg}")
		rescue Exception => msg
			logger.error("Error: #{msg}")
		end
		
		# do nothing if no friends found or Twitter API return a max request per hour error
		if friends
			followers.each do |user|
				begin                                
					self.client.friendship_create(user) if !friends.include?(user)
				rescue Twitter => msg
					logger.info("Twitter says: #{msg}")
				rescue Exception => msg
					logger.error("Error: #{msg}")
				end    
			end         
		end
	end  

	def post_messages 
		begin                                
			messages = self.client.direct_messages
		rescue Twitter => msg
			logger.info("Twitter says: #{msg}")
		rescue Exception => msg
			logger.error("Error: #{msg}")
		end
				
		# do nothing if no messages found or Twitter API return a max request per hour error
		if messages
			messages.each do |message|			
				if !is_logged?(message)
					# log message to text file
					log_message(message)
				
					# send message to twitter
					begin
						m = message.text                 												
						# check if #HASH can fit
						if m.size < MAX_STRING_LENGTH
							m << " #jeudiconfession"
						end                 												
						logger.info("Posting message: #{m}")						
						self.client.update(m)
					rescue Twitter => msg
						logger.info("Twitter says: #{msg}")
					rescue Exception => msg
						logger.error("Error: #{msg}")
					end
				end  
			
				# and destroy twitter message, we keep nothing
				logger.info("Deleting message #{message.id}")
				self.client.direct_message_destroy(message.id)			
			end
		end
	end
	
	def log_message(message)                      
		logger.info("Logging message: #{message.id} | #{message.text}")		
		File.open(messages, 'a+') do |f|  
		  f.puts "#{message.id} #{message.text}"  
		end
	end 
	
	def is_logged?(message)
		ids = []		
		File.open(messages, 'r').each_line do |l|
			ids << l.split(' ')[0].to_i
		end		                      
		false ? true : ids.include?(message.id.to_i)
	end	
	
end  

# Load config file
config = File.open(File.join(File.dirname(__FILE__), "config.yml"))
config = YAML::load(config)   

# start instance
AutoFollow.new(config["twitter"]["username"], config["twitter"]["password"])