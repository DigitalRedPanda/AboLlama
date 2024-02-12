from env import loadEnv
from tables import `[]`

import std/[terminal], strformat, os, client, net



proc main() =
    let 
        info = loadEnv("src/.env")
        client = newClient(info["TOKEN"], info["USER_ID"], "digital_red_panda") 
    client.connectToChat()
    client.on(MessageEvent, 10, proc(channel, user, message: string) = echo("[\e[1m", channel, "\e[0m] [\e[1m", user, "\e[0m]: ", message))
    #[ client.on(MessageEvent, 10, proc(channel, user, message: string) = stdout.writeLine(fmt"['\e[1m'{channel}'\e[0m'] ['\e[1m'{user}'\e[0m']: {message}")) ]#

main()
