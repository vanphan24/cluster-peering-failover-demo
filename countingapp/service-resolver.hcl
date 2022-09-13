Kind           = "service-resolver"
Name           = "counting"
ConnectTimeout = "15s"
Failover = {
  "*" = {
    Targets = [
      {Peer = "dc2"}
    ]   
  }
}
