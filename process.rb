require 'net/http'
require 'open-uri'
require 'discordrb'
require 'nokogiri'
require 'yaml'

EMOTES = YAML.load_file("data/emotes.yml")

module Process

    def self.get_gameid(hometeam, awayteam)

        # Hopefully, the order of hometeam and awayteam doesn't matter.

        games = open("http://dtlive.com.au:80/afl/viewgames.php").read
        upcoming = games.scan(/GameID=(\d+)">[^>]+>\s+(?:([A-Za-z ]+[^<]+)\s+vs[^>]+>\s*([^>]+)|([^>]+)\s+vs[^>]+>\s*([A-Za-z ]+[^<]+))\s+\(upcoing\)</)
        in_progress = games.scan(/GameID=(\d+)">[^>]+>\s+(?:([A-Za-z ]+[^<]+)\s+vs[^>]+>\s*([^>]+)|([^>]+)\s+vs[^>]+>\s*([A-Za-z ]+[^<]+))\s+\(in progress\)</)
        completed = games.scan(/GameID=(\d+)">[^>]+>\s+(?:([A-Za-z ]+[^<]+)\s+vs[^>]+>\s*([^>]+)|([^>]+)\s+vs[^>]+>\s*([A-Za-z ]+[^<]+))<small>\(completed\)<\/small></)

        in_progress += upcoming

        while true        
            if in_progress.flatten.include?(hometeam)
                gameid = in_progress.find { |a| a.include? hometeam }.first
                break
            else
                sleep(10)
            end
        end

        return gameid

    end # End of get_gameid

    def self.compile_results(messagehash)

        # messagehash refers to a hash containing:
        #       - :home, the name of the home team
        #       - :away, the name of the away team
        #       - :channel, the channel_id of the channel in which
        #         the message will be posted

        gameid = get_gameid(messagehash[:home])

        data = {}
        result = {}
        feed = open("http://dtlive.com.au/afl/xml/#{gameid}.xml").read
        feed = Nokogiri::XML(feed)

        feed.css('Game').each do |node|
            children = node.children
            children.each do |item|
                case item.name
                when "HomeTeam"
                    data[:home_team] = item.inner_html
                when "AwayTeam"
                    data[:away_team] = item.inner_html
                when "Location"
                    data[:location] = item.inner_html
                when "PercComplete"
                    data[:perc_complete] = item.inner_html
                when "CurrentTime"
                    data[:current_time] = item.inner_html
                when "CurrentQuarter"
                    data[:current_qtr] = item.inner_html
                when "HomeTeamGoal"
                    data[:home_goals] = item.inner_html
                when "HomeTeamBehind"
                    data[:home_points] = item.inner_html
                when "AwayTeamGoal"
                    data[:away_goals] = item.inner_html
                when "AwayTeamBehind"
                    data[:away_points] = item.inner_html
                end
            end
        end

        data[:home_total] = data[:home_goals].to_i * 6 + data[:home_points].to_i
        data[:away_total] = data[:away_goals].to_i * 6 + data[:away_points].to_i      

        if data[:home_total].to_i > data[:away_total].to_i
            data[:margin] = data[:home_total].to_i - data[:away_total].to_i
            result[:final_summary] = "*#{data[:home_team]} by #{data[:margin]}*"
        elsif data[:home_total].to_i < data[:away_total].to_i
            data[:margin] = data[:away_total].to_i - data[:home_total].to_i
            result[:final_summary] = "*#{data[:away_team]} by #{data[:margin]}*"
        elsif data[:home_total].to_i == data[:away_total].to_i
            data[:margin] = "0"
            result[:final_summary] = "Scores level."
        end

        if data[:perc_complete].to_i == 25
            result[:final_info] = "**#{data[:home_team]}** vs **#{data[:away_team]}** at #{data[:location]} - End of Q1"
        elsif data[:perc_complete].to_i == 50
            result[:final_info] = "**#{data[:home_team]}** vs **#{data[:away_team]}** at #{data[:location]} - Half Time"
        elsif data[:perc_complete].to_i == 75
            result[:final_info] = "**#{data[:home_team]}** vs **#{data[:away_team]}** at #{data[:location]} - End of Q3"
        elsif data[:perc_complete].to_i == 100
            result[:final_info] = "**#{data[:home_team]}** vs **#{data[:away_team]}** at #{data[:location]} - Game Finished"
        else
            result[:final_info] = "**#{data[:home_team]}** vs **#{data[:away_team]}** at #{data[:location]} - Game time: #{data[:current_time]} in Q#{data[:current_qtr]}"
        end

        result[:final_score] = "#{EMOTES[data[:home_team]]} #{data[:home_goals]}.#{data[:home_points]}.#{data[:home_total]} - #{EMOTES[data[:away_team]]} #{data[:away_goals]}.#{data[:away_points]}.#{data[:away_total]}"
        result[:final_message] = "#{result[:final_info]} \n#{result[:final_score]} \n#{result[:final_summary]}"

        returnlist = [data, result]

        return returnlist

    end # End of compile_results

    def self.get_stats(gameid)

        # messagehash refers to a hash containing:
        #       - :home, the name of the home team
        #       - :away, the name of the away team
        #       - :channel, the channel_id of the channel in which
        #         the message will be posted

        feed = open("http://dtlive.com.au/afl/xml/#{gameid}.xml").read
        feed = Nokogiri::XML(feed)
        home_stats = feed.css('Home')
        away_stats = feed.css('Away')
        stats = []
        home_stats.css("Player").each do |player|
            playerstats = { :id => "#{player.css("PlayerID").inner_html}".to_i,
                            :name => "#{player.css("Name").inner_html}",
                            :team => "#{feed.css("Game").css("HomeTeam").inner_html}",
                            :number => "#{player.css("JumperNumber").inner_html}".to_i,
                            :possessions => "#{player.css("Kick").inner_html}".to_i + "#{player.css("Handball").inner_html}".to_i,
                            :kicks => "#{player.css("Kick").inner_html}".to_i,
                            :handballs => "#{player.css("Handball").inner_html}".to_i,
                            :marks => "#{player.css("Mark").inner_html}".to_i,
                            :tackles => "#{player.css("Tackle").inner_html}".to_i,
                            :freesfor => "#{player.css("FreeFor").inner_html}".to_i,
                            :freesagainst => "#{player.css("FreeAgainst").inner_html}".to_i,
                            :goals => "#{player.css("Goal").inner_html}".to_i,
                            :behinds => "#{player.css("Behind").inner_html}".to_i,
                            :score => 6 * "#{player.css("Goal").inner_html}".to_i + "#{player.css("Behind").inner_html}".to_i,
                            :togperc => "#{player.css("TOGPerc").inner_html}".to_i,
                            :dt => "#{player.css("DT").inner_html}".to_i }
            stats << playerstats
        end
        away_stats.css("Player").each do |player|
            playerstats = { :id => "#{player.css("PlayerID").inner_html}".to_i,
                            :name => "#{player.css("Name").inner_html}",
                            :team => "#{feed.css("Game").css("AwayTeam").inner_html}",
                            :number => "#{player.css("JumperNumber").inner_html}".to_i,
                            :possessions => "#{player.css("Kick").inner_html}".to_i + "#{player.css("Handball").inner_html}".to_i,
                            :kicks => "#{player.css("Kick").inner_html}".to_i,
                            :handballs => "#{player.css("Handball").inner_html}".to_i,
                            :marks => "#{player.css("Mark").inner_html}".to_i,
                            :tackles => "#{player.css("Tackle").inner_html}".to_i,
                            :freesfor => "#{player.css("FreeFor").inner_html}".to_i,
                            :freesagainst => "#{player.css("FreeAgainst").inner_html}".to_i,
                            :goals => "#{player.css("Goal").inner_html}".to_i,
                            :behinds => "#{player.css("Behind").inner_html}".to_i,
                            :score => 6 * "#{player.css("Goal").inner_html}".to_i + "#{player.css("Behind").inner_html}".to_i,
                            :togperc => "#{player.css("TOGPerc").inner_html}".to_i,
                            :dt => "#{player.css("DT").inner_html}".to_i }
            stats << playerstats
        end
    
        return stats

    end # End of get_stats

    def self.get_top_ten(gameid)

        top_ten = get_stats(gameid).sort_by { |player| player[:dt] }.reverse!.slice(0,10)
        
        top_ten_msg = "Top players of the game: \n"

        top_ten.each do |player|
            rank = top_ten.index(player).to_i + 1
            msg_line = "#{rank}: (#{EMOTES[player[:team]]} ##{player[:number]}) #{player[:name]} | #{player[:dt]} DT Points | #{player[:possessions]} Possessions | Score (g.b.t): #{player[:goals]}.#{player[:behinds]}.#{player[:score]}\n"
            top_ten_msg << msg_line
        end
        
        return top_ten_msg
    
    end # End of get_top_ten
end
