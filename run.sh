  echo "updating from git.."
  git pull

  echo "running rubocop.."
  rubocop lib

  echo "updating documentation.."
  yardoc lib

  echo "starting bot.."
  bundle exec ruby main.rb
