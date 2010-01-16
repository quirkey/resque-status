require File.join(File.dirname(__FILE__), 'status_server')

Resque::Server.register Resque::StatusServer