require "./laserbonnet"

system("stty raw -echo")
Laserbonnet.new.listen
at_exit { system("stty -raw echo"); exit }
