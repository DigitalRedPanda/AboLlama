import net, strutils, os, httpclient, asyncdispatch, json, strformat, asyncnet
from re import re, replace, match

type Event* = ref object 
    message*, user*, channel*, command*: string
    args*: seq[string] 

type Client* = ref object
    id*, displayName*, token*, clientId: string
    socket: AsyncSocket
    httpClient*: HttpClient 

type User* = object
    id, login, displayName, broadcasterType: string
    

type Events* = enum 
    MessageEvent, CommandEvent

var
    addedEvents: array[2, proc(event:Event) {.async.}]

let 
    messagePattern = re"(^([:!]\w+){2}|\.tmi\.twitch\.tv)"
    pattern = re":(\w+|tmi.twitch.tv) \d{3}"

const 
    twitchApi = "https://api.twitch.tv/"
    helixApi = twitchApi & "helix/"

template loop(code: untyped): untyped =
    while true:
        code

template sendMsg(client: Client, message: string) = asyncCheck client.socket.send(message & "\c\L")

func newClient*(id, displayName, token, clientId: string, socket=newAsyncSocket(), httpClient=newHttpClient()): Client = Client(id:id, displayName:displayName, token:token, clientId:clientId, socket:socket, httpClient:httpClient)

proc initHttpClient*(client: Client) =
    client.httpClient.headers.add("Authorization", "Bearer " & client.token) 
    client.httpClient.headers.add("Client-Id", client.clientId)

proc joinChannel*(client: Client, channel: string) =
    client.sendMsg("JOIN #" & channel)

proc sendChannelMessage*(client: Client, channel, message: string) = client.sendMsg("PRIVMSG #" & channel & " :" & message)

proc reply*(client: Client, channel, user, message: string) = client.sendMsg("PRIVMSG #" & channel & " :@" & user & ", " & message)

func skipIndexTil(array: seq[string], index: int): seq[string] = 
    if array.len() - (index) <= 0: return array
    var temp = newSeqOfCap[string](array.len - (index + 1))
    for i in index..<array.len: temp.add(array[i])
    return temp

proc addEvent*(client: Client, event: Events, exec: proc(event: Event) {.async.}) = 
    case event:
        of MessageEvent: addedEvents[0] = exec
        of CommandEvent: addedEvents[1] = exec

proc listen(client: Client) {.async.} =
    loop:
        # let msg = client.socket.recvLine()
        # if msg != "":
        #     client.sendChannelMessage(client.displayName ,"lmao")
            
        let msg = await(client.socket.recvLine()).replace(messagePattern)

        if msg != "" and not msg.match(pattern):
            let msgFeed = msg.split(" ")
            if msgFeed[0] == "PING":
                client.sendMsg(":tmi.twitch.tv PONG")
                echo ":tmi.twitch.tv \e[1mPONG\e[0m"
            elif msgFeed[1] == "JOIN":
                echo "joined \e[1m", msgFeed[2], "\e[0m"
            else: 
                let feed = msg.split(":")
                if feed[1][0] != '!':
                    asyncCheck addedEvents[0](Event(message:feed[1], user:msgFeed[0].substr(1) , channel:msgFeed[2].substr(1)))
                    continue
                let commandFeed = feed[1].split(" ")
                asyncCheck addedEvents[1](Event(command: commandFeed[0].substr(1), args: commandFeed.skipIndexTil(1) , user: msgFeed[0].substr(1), channel: msgFeed[2].substr(1)))
        sleep(10)

# You should add an event first then call connectToChat after, otherwise there'd be nil pointer exception
proc connectToChat*(client: Client) {.async.} = 
    #[ client.socket.getFd().setBlocking(false) ]#
    await client.socket.connect("irc.chat.twitch.tv", Port(6667))
    client.sendMsg("PASS oauth:" & client.token & "\nNICK " & client.displayName)
    client.joinChannel(client.displayName)
    client.listen()

proc shoutout*(client: Client, channelName, otherChannelName: string) = 
    let res = parseJson(client.httpClient.getContent("https://api.twitch.tv/helix/users?login=" & channelName & "&login=" & otherChannelName))
    let arr = [res["data"][0]["id"].str, res["data"][1]["id"].str]
    client.httpClient.headers.add("Content-Type", "application/json")

    discard client.httpClient.post("https://api.twitch.tv/helix/chat/shoutouts?from_broadcaster_id=" & arr[0] & "&to_broadcaster_id=" & arr[1] & "&moderator_id=" & client.id)



proc ban*(client: Client, channelName, bannedUserName, reason: string) = 
    let res = parseJson(client.httpClient.getContent("https://api.twitch.tv/helix/users?login=" & channelName & "&login=" & bannedUserName))
    let arr = [res["data"][0]["id"].str, res["data"][1]["id"].str]
    client.httpClient.headers.add("Content-Type", "application/json")
    discard client.httpClient.postContent("https://api.twitch.tv/helix/moderation/bans?broadcaster_id=" & arr[0] & "&moderator_id=" & client.id, "{\"data\": {\"user_id\": \"" & arr[1] & "\", \"reason\": \"" & reason & "\"} }")
    client.httpClient.headers.del("Content-Type")
    #[ discard client.httpClient.request("https://api.twitch.tv/helix/moderation/ban?broadcaster_id=", HttpPost) ]#
