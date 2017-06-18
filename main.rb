require 'discordrb'
require 'yaml'
require './process.rb'

CONFIG = YAML.load_file("data/config.yml")
EMOTES = YAML.load_file("data/emotes.yml")

bot = Discordrb::Commands::CommandBot.new(name: CONFIG['name'],
                                          token: CONFIG['token'],
                                          client_id: CONFIG['client_id'],
                                          prefix: CONFIG['prefix'],
                                          help_command: false)

allowed_channels = [250245406657740801, 193362778646511617] #fox first, fta second

bot.message(in:allowed_channels) do |event|
    author_roles = event.message.author.roles.map { |role| role.id.to_s }
    next unless author_roles.include?("195825790531665920") # 195825790531665920=umpire
    next unless event.message.content.match(/(?<hometeam><:.*:)\d*> (?<versus>🆚) <(?<awayteam>:.*:)\d*>/)
  
    msg_channel = event.message.channel.id
    msg = event.message.content.split
  
    home_team = msg[0]
    away_team = msg[2]
    home_team = EMOTES.key(home_team)
    away_team = EMOTES.key(away_team)
    puts "Channel = #{msg_channel}"
    puts "Message = #{msg}"
    puts "Home team = #{home_team}"
    puts "Away team = #{away_team}"
  
    output = {:home => home_team,
              :away => away_team,
              :channel => msg_channel}

    flag25 = 0
    flag50 = 0
    flag75 = 0
    flag100 = 0

    while true
        game_list = Process.compile_results(output) # this is a list of 2 hashes, 'data' and 'results'
        game_data = game_list[0]                    # game_data is a hash, be careful!
        game_results = game_list[1]                 # so too is game_results!

        if game_data[:perc_complete].to_i%25 == 0 # i.e. if we're in a break.
            gameid = Process.get_gameid(output[:home])
            topten = Process.get_top_ten(gameid)
            post_message = "#{game_results[:final_message]} \n"
            post_message << topten
            if game_data[:perc_complete].to_i == 25 && flag25 == 0
                bot.send_message(output[:channel], content = post_message)
                flag25 = 1
            elsif game_data[:perc_complete].to_i == 50 && flag50 == 0
                bot.send_message(output[:channel], content = post_message)
                flag50 = 1
            elsif game_data[:perc_complete].to_i == 75 && flag75 == 0
                bot.send_message(output[:channel], content = post_message)
                flag75 = 1
            elsif game_data[:perc_complete].to_i == 100 && flag100 == 0
                bot.send_message(output[:channel], content = post_message)
                flag100 = 1
                break
            else
                sleep(5)
            end
        else
            sleep(5)
        end
    end

end

bot.ready do |event|

    puts("--------------------------------------------------------")
    puts("Logged in and successfully connected as #{bot.name}.")
    puts("--------------------------------------------------------")
    bot.game = CONFIG['game']

end

bot.run
