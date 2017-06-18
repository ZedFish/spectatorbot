  echo "updating from git.."
  git pull
  
  echo "updating gems.."
  bundle update
  
  echo "installing gems.."
  bundle install

  echo "running rubocop.."
  rubocop lib

  echo "updating documentation.."
  yardoc lib

  echo "starting bot.."
  ruby main.rb
