from env import loadEnv
import tables, client, strutils, asyncdispatch, db

# template assume*[A](t: A, u: untyped): untyped = 
#     if(t != nil): u

proc main() {.async.} = 
    let info  = loadEnv("src/.env")
    var botClient = newClient(info["USER_ID"], "digital_red_panda", info["TOKEN"], info["CLIENT_ID"])
    botClient.initHttpClient()
    botClient.addEvent(MessageEvent, proc(event: Event) {.async.} =
        echo "[\e[1m", event.channel, "\e[0m] [", event.user, "]: ", event.message
        if event.message == "fu":
            botClient.reply(event.channel, event.user, "quh")
        if event.message.contains("viewers, followers, views"):
            botClient.ban(event.channel, event.user, "امنظام نظام")
    )
    botClient.addEvent(CommandEvent, proc(event: Event) {.async.} = 
        echo "[\e[1m", event.channel, "\e[0m] [", event.user, "]: ", event.command
        if event.args.len > 0:
            case event.command:
                of "join": 
                    echo event.args
                    botClient.joinChannel(event.args[0])
                    botClient.reply(event.args[0], event.args[0] , "quh")
                of "shoutout": botClient.shoutout(event.channel, event.args[0])
                else: discard
        else: 
            case event.command:
                of "mods": discard
    )
    botClient.connectToChat()

waitFor main()
