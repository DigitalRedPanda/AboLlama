from net import Socket, newSocket, send, recvLine, connect, Port
from os import sleep
from strutils import isEmptyOrWhitespace, split
import threadpool

type Events* = enum
    MessageEvent,
    CommandEvent

type Event* = object 
    command*, user*, channel*, content*: string
    args*: seq[string]

type Client* = object
    token*, id*, displayName*: string
    socket*: Socket = newSocket()

let 
    messagePattern = re"(^([:!]\w+){2}|\.tmi\.twitch\.tv)"
    pattern = re"^:tmi\.twitch\.tv \d{3}"

var addedEvents = newSeq[proc(event: Event)](2)
    
template loop(body: untyped): untyped = 
    while true:
        body
template sendMsg(socket: Socket, msg: string): untyped = socket.send(msg & "\r\n")

func newClient*(userToken, userId, displayedName: string): Client =
    return Client(token: userToken, id: userId, displayName: displayedName)

func skipIndexTil(array: seq[string], index: uint): seq[string] = 
    var temp = newSeqOfCap[string](array.len - int(index + 1))
    for i in index..uint(array.len): temp.add(array[i])
    return temp

proc joinChannel*(client: Client, channel: string) =
    client.socket.sendMsg("JOIN #" & channel)

proc reply*(client: Client, channelName, user, message: string) = client.socket.sendMsg("PRIVMSG " & channelName & " : " & user & ", " & message) 

proc listen(client: Client) =
    loop:
        let msg = client.socket.recvLine().replace(messagePattern)
        if not msg.isEmptyOrWhitespace:
            let messageFeed = msg.split(" ")
            if messageFeed[0] == "PING": 
                client.socket.sendMsg("PONG :tmi.twitch.tv")
                echo "\e[1mPING\e[0m :tmi.twitch.tv\n\e[1mPONG\e[0m :tmi.twitch.tv"
            elif(messageFeed[1] == "JOIN"):  echo "joined \e[1m", messageFeed[2], "\e[0m"
            else: 
                let feed = msg.split(":")
                for i in 0..addedEvents.len: 
                    if addedEvents[1] != nil and feed[1][0] != '!': spawn client.addedEvents[1](Event(user: messageFeed[0], channel:messageFeed[2], content:feed[1]))
                    elif addedEvents[0] != nil and feed[1][0] == '!': spawn client.addedEvents[1](Event(user: messageFeed[0], channel:messageFeed[2], args:feed[1].split(" ").skipIndexTil(1)))
                    else: echo msg
        sleep(10)
proc connectToChat*(client: Client) = 
    client.socket.connect("irc.chat.twitch.tv", Port(6667))
    client.socket.sendMsg("PASS oauth:" & client.token & "\nNICK " & client.displayName)
    client.joinChannel(client.displayName)
    client.listen()

proc sendChatMessage*(client: Client, channelName, message: string) = 
    client.socket.sendMsg("PRIVMSG " & channelName & " :" & message)

proc addEvent*(client: Client, event: Events, exec: proc(event: Event)) =
    case event:
        of MessageEvent: addedEvents[1] = exec
        of CommandEvent: addedEvents[0] = exec
# proc onEvent*[T: untyped](client: Client, event: Event, exec: proc(e: T), timeout = 10) = 
#     loop:
#         let msg = client.socket.recvLine().replace(messagePattern)
#         if not msg.isEmptyOrWhitespace or msg.match(pattern):
#             let messageDivision = msg.split(" ")
#             if messageDivision[0] == "PING":
#                 echo msg
#                 client.socket.sendMsg("PONG :tmi.twitch.tv") 
#                 echo "\e[1mPONG\e[0m :tmi.twitch.tv"
#             elif messageDivision[1] == "JOIN":
#                 echo "joined \e[1m", messageDivision[2], "\e[0m"
#             elif(event in events):
#                 let feed = msg.split(":")
#                 case event:
#                     of MessageEvent:
#                         if feed[1][0] != '!':
#                             echo ":WAJAJA:"
#                             exec(ChatMessageEvent(channel:messageDivision[2], user:messageDivision[0], message:feed[1]))
#                     # of CommandEvent:
#                     #     if feed[1][0] == '!':
#                     #         let
#                     #             commandFeed = feed[1].split(" ")
#                     #             command = commandFeed[0]
#                     #         echo ":quh:"
#                     #         exec(CommandMessageEvent(command:command, channel: messageDivision[2], user:messageDivision[0], arguments: commandFeed))
#                     #         continue
#                     else: discard
#         sleep(timeout)
