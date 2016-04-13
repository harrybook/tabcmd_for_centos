# -----------------------------------------------------------------------
# The information in this file is the property of Tableau Software and
# is confidential.
#
# Copyright (c) 2011 Tableau Software, Incorporated
#                    and its licensors. All rights reserved.
# Protected by U.S. Patent 7,089,266; Patents Pending.
# 
# Portions of the code
# Copyright (c) 2002 The Board of Trustees of the Leland Stanford
#                    Junior University. All rights reserved.
# -----------------------------------------------------------------------

require 'uri'
require 'net/http'
require 'openssl'

class Login < MultiCommand::Command
  def initialize
    super
  end

  def doc
    <<EOM
Login to the server.  Your session will continue until it expires on the
server or you use "tabcmd logout".
EOM
  end

  def usage
    "#{name} [options]"
  end
  
  def run(opts,args)
    # Error handling is all in Server.login
    Server.login!
  end
end
