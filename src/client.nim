from net import Socket, newSocket, send, recvLine, connect, Port
from os import sleep
from strutils import isEmptyOrWhitespace, split
from re import re, replace

type Client* = object
    token*, id*, displayName*: string
    socket*: Socket

type Event* = enum
    MessageEvent,
    CommandEvent,

const pattern = re"(^([:!]\w+){2}|\.tmi\.twitch\.tv)"

template loop(body: untyped): void = 
    while true:
        body
proc sendMsg(socket: Socket, msg: string) = socket.send(msg & "\c\L")

func newClient*(userToken, userId, displayedName: string, userSocket = newSocket()): Client =
    return Client(token: userToken, id: userId, displayName: displayedName, socket: userSocket)

proc connectToChat*(client: Client) = 
    client.socket.connect("irc.chat.twitch.tv", Port(6667))
    client.socket.sendMsg("PASS oauth:" & client.token & "\nNICK " & client.displayName)

proc joinChannel*(client: Client, channel: string) =
    client.socket.sendMsg("JOIN #" & channel)
   
proc sendChatMessage*(client: Client, channelName, message: string) = 
    client.socket.sendMsg("PRIVMSG #" & channelName & " :" & message)

proc on*(client: Client, event: Event, timeout: int, exec: proc(channel, user, message: string): void) = 
    loop:
        let message = client.socket.recvLine().replace(re)
        echo message
        if not message.isEmptyOrWhitespace:
            let
                messageFeed = message.split(":") 
                identifiers = messageFeed[0].split(" ") 
            if identifiers[0] == "PING":
                client.socket.sendMsg("PONG :tmi.twitch.tv")
            else:
                case event:
                    of MessageEvent:
                      if messageFeed[1][0] != '!':
                        exec(channel=identifiers[2], user=identifiers[0], message=messageFeed[1])
                    of CommandEvent:
                      if messageFeed[1][0] == '!':
                        exec(channel=identifiers[2], user=identifiers[0], message=messageFeed[1])
        sleep(timeout)
