from env import loadEnv
from tables import `[]`
import client

proc main() =
    let info = loadEnv("src/.env")
    
main()
