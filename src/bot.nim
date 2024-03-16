from env import loadEnv
import tables, client


proc main() = 
    let info  = loadEnv("src/.env")
    var botClient = newClient(info["USER_ID"], "digital_red_panda", info["TOKEN"])
    botClient.addEvent(MessageEvent, proc(event: Event) {.gcsafe.} =
        echo "[\e[1m", event.channel, "\e[0m] [", event.user, "]: ", event.message
    )
    botClient.connectToChat()

main()
