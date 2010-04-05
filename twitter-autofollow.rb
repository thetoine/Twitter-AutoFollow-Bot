# twitter-autofollow.rb
# 2010-04-02 Antoine Girard <thetoine@gmail.com>

# This script will search all you follower and add them as a friend
# Also post any privately received message to your public timeline.
 
require 'rubygems'
require 'twitter'                  
require 'yaml'
require 'xmpp4r-simple'
require 'daemons'
#Jabber::debug = true

class	AutoFollow
	 
	INTERVAL = 120 # Delay between follows in seconds
	MAX_STRING_LENGTH = 124
	
	attr_accessor :client, :logger, :messages, :gtalk, :moderator
	
	def initialize(config)  
		httpauth = Twitter::HTTPAuth.new(config["twitter"]["username"], config["twitter"]["password"])
		self.client = Twitter::Base.new(httpauth) 
		self.gtalk = Jabber::Simple.new(config["gtalk"]["username"], config["gtalk"]["password"])
		self.moderator = config["gtalk"]["moderator"]

		# logging
		self.logger = Logger.new(File.join(File.dirname(__FILE__), 'log.txt'))
		self.messages = File.join(File.dirname(__FILE__), "messages.txt")
		
		# init the infinite loop
		logger.info("Starting Twitter AutoFollow Service")
		
		loop do
			logger.info("Friending everyone.")
			friends
      
			# self.gtalk.add(config["gtalk"]["moderator"])
			# moderator_is_online?

			logger.info("Checking for private messages and post new ones.")
			post_messages 
		 

			# sleep for an interval and call "start" method again
			logger.info("Sleeping for #{INTERVAL} seconds...")
			sleep(INTERVAL)
		end
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
				
		# do nothing if no messages found or Twitter API return "150 max request per hour" error
		if messages
			messages.each do |message|			

				if moderate(message)					
					# send message to twitter
					begin
						m = message.text                 												
						# check if #HASH can fit
						if m.size < MAX_STRING_LENGTH
							m << " #jeudiconfession"
						end                 												
						logger.info("Posting message: #{message.id} - '#{message.text}'")
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
	
	def moderate(message)   
		# send message to moderator
		self.gtalk.deliver(self.moderator, "Approve?: '#{message.text}'")

		# loop until response
		moderated = nil
		until moderated != nil			
			self.gtalk.received_messages { |msg|
				if msg.body == 'y' || msg.body == 'yes'                       
					self.gtalk.deliver(self.moderator, "Posting #{message.id} to Twitter.")
					moderated = true
				else                                                                               
					self.gtalk.deliver(self.moderator, "Ignoring...")
					moderated = false
				end
			}
			sleep 5
		end
		return moderated
	end
	
	def moderator_is_online?
		puts self.gtalk.contacts
		self.gtalk.status(:chat, 'yeah right I am here.')
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
AutoFollow.new(config)