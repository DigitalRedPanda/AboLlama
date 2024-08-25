import net, strutils, os, httpclient, asyncdispatch, json, strformat, asyncnet, user, "../db/database", std/options
from re import re, replace, match

type Event* = object 
    message*, user*, channel*, command*: string
    args*: seq[string] 

type Client* = ref object
    id*, displayName*, token*, clientId: string
    socket: AsyncSocket
    httpClient*: AsyncHttpClient 
    addedEvents: array[2, proc(event:Event) {.async.}]

    

type Events* = enum 
    MessageEvent, CommandEvent

let 
    messagePattern = re"(^([:!]\w+){2}|\.tmi\.twitch\.tv)"
    pattern = re":(\w+|tmi.twitch.tv) \d{3}"

const 
    twitchApi = "https://api.twitch.tv/"
    helixApi = twitchApi & "helix/"

template loop(code: untyped): untyped =
    while true:
        code

proc sendMsg(client: Client, message: string) {.inline.} = asyncCheck client.socket.send(message & "\c\L")

func newClient*(id, displayName, token, clientId: string, socket=newAsyncSocket(), httpClient=newAsyncHttpClient()): Client = Client(id:id, displayName:displayName, token:token, clientId:clientId, socket:socket, httpClient:httpClient)

proc initHttpClient*(client: Client) =
    client.httpClient.headers.add("Authorization", "Bearer " & client.token) 
    client.httpClient.headers.add("Client-Id", client.clientId)

proc joinChannel*(client: Client, channel: string) =
    client.sendMsg("JOIN #" & channel)
    
proc sendChannelMessage*(client: Client, channel, message: string) = client.sendMsg("PRIVMSG #" & channel & " :" & message)

proc reply*(client: Client, channel, user, message: string) = client.sendMsg("PRIVMSG #" & channel & " :@" & user & ", " & message)

func skipIndexTil(array: seq[string], index: int): seq[string] = 
    if array.len() - (index) <= 0: return newSeq[string]()
    var temp = newSeqOfCap[string](array.len - (index + 1))
    for i in index..<array.len: temp.add(array[i])
    return temp

proc addEvent*(client: Client, event: Events, exec: proc(event: Event) {.async.}) = 
    case event:
        of MessageEvent: client.addedEvents[0] = exec
        of CommandEvent: client.addedEvents[1] = exec

proc listen(client: Client) {.async.} =
    loop:
        # let msg = client.socket.recvLine()
        # if msg != "":
        #     client.sendChannelMessage(client.displayName ,"lmao")
            
        #replace(messagePattern)
        let msg = await(client.socket.recvLine()).replace(messagePattern)
        echo msg
        if msg != "" and not msg.match(pattern):
            let msgFeed = msg.split(" ")
            if msgFeed[0] == "PING":
                client.sendMsg(":tmi.twitch.tv PONG")
                echo ":tmi.twitch.tv \e[1mPONG\e[0m"
            elif msgFeed[1] == "JOIN":
                echo "joined \e[1m", msgFeed[2], "\e[0m"
            else: 
                let feed = msg.split(":", 1)
                if feed[1][0] != '!':
                     asyncCheck client.addedEvents[0](Event(message:feed[1], user:msgFeed[0].substr(1) , channel:msgFeed[2].substr(1)))
                     continue
                let commandFeed = feed[1].split(" ")
                asyncCheck client.addedEvents[1](Event(command: commandFeed[0].substr(1), args: commandFeed.skipIndexTil(1), user: msgFeed[0].substr(1), channel: msgFeed[2].substr(1)))
        sleep(10)

# You should add an event first then call connectToChat after, otherwise there'd be a nil pointer exception
proc connectToChat*(client: Client) {.async.} = 
    #[ client.socket.getFd().setBlocking(false) ]#
    await client.socket.connect("irc.chat.twitch.tv", Port(6667))
    client.sendMsg("PASS oauth:" & client.token & "\nNICK " & client.displayName)
    client.joinChannel(client.displayName)
    initDb()
    let channels = getAllChannels()
    for i in channels:
        client.joinChannel(i.displayName)
    waitFor client.listen()

proc fetchUser*(client: Client, id = "", login = ""): Future[Option[User]]  {.async.} = 
    if not login.isEmptyOrWhitespace:
        let res = parseJson(await client.httpClient.getContent("https://api.twitch.tv/helix/users?login=" & login))
        let user = res["data"]
        echo user
        return some(User())


    elif not id.isEmptyOrWhitespace:
        let res = parseJson(await client.httpClient.getContent("https://api.twitch.tv/helix/users?id=" & id))
        let user = res["data"][0]["id"].str
        echo user
        return some(User())
    else:
        return none[User]()


proc shoutout*(client: Client, channelName, otherChannelName: string) {.async.} = 
    let res = parseJson(await client.httpClient.getContent("https://api.twitch.tv/helix/users?login=" & channelName & "&login=" & otherChannelName))
    let arr = [res["data"][0]["id"].str, res["data"][1]["id"].str]
    client.httpClient.headers.add("Content-Type", "application/json")
    asyncCheck client.httpClient.post("https://api.twitch.tv/helix/chat/shoutouts?from_broadcaster_id=" & arr[0] & "&to_broadcaster_id=" & arr[1] & "&moderator_id=" & client.id)

proc ban*(client: Client, channelName, bannedUserName, reason: string) {.async.} = 
    let res = parseJson(await client.httpClient.getContent("https://api.twitch.tv/helix/users?login=" & channelName & "&login=" & bannedUserName))
    let arr = [res["data"][0]["id"].str, res["data"][1]["id"].str]
    client.httpClient.headers.add("Content-Type", "application/json")
    asyncCheck client.httpClient.postContent("https://api.twitch.tv/helix/moderation/bans?broadcaster_id=" & arr[0] & "&moderator_id=" & client.id, "{\"data\": {\"user_id\": \"" & arr[1] & "\", \"reason\": \"" & reason & "\"}}")
    client.httpClient.headers.del("Content-Type")

proc timeout*(client: Client, channelName, bannedUserName: string, duration: Natural) {.async.} =
    let res = parseJson(await client.httpClient.getContent("https://api.twitch.tv/helix/users?login=" & channelName & "&login=" & bannedUserName))
    let arr = [ res["data"][0]["id"].str, res["data"][1]["id"].str]
    client.httpClient.headers.add("Content-Type", "application/json")
    discard await client.httpClient.postContent("https://api.twitch.tv/helix/moderation/bans?broadcaster_id=" & arr[0] & "&moderator_id=" & client.id, "{\"data\": {\"user_id\": \"" & arr[1] & "\", \"duration\":" & $duration & ", \"reason\": \"ابوه طلع اللواء eblsh\"}}")
    client.httpClient.headers.del("Content-Type") #[ discard client.httpClient.request("https://api.twitch.tv/helix/moderation/ban?broadcaster_id=", HttpPost) ]#
