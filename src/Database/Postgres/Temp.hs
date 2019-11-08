{-|
This module provides functions for creating a temporary @postgres@ instance.
By default it will create a temporary data directory and
a temporary directory for a UNIX domain socket for @postgres@ to listen on.

Here is an example using the expection safe 'with' function:

 @
 'with' $ \\db -> 'Control.Exception.bracket' ('PG.connectPostgreSQL' ('toConnectionString' db)) 'PG.close' $ \\conn ->
  'PG.execute_' conn "CREATE TABLE foo (id int)"
 @

To extend or override the defaults use `withPlan` (or `startWith`).

@tmp-postgres@ ultimately calls (optionally) @initdb@, @postgres@ and
(optionally) @createdb@.
All of the command line, environment variables and configuration files
that are generated by default for the respective executables can be
extended or overrided.

In general @tmp-postgres@ is useful if you want a temporary
@postgres@ which will not clash with open ports.
Here are some different use cases for @tmp-postgres@ and there respective
configurations:

* The default 'with' and 'start' functions can be used to make a sandboxed
temporary database for testing.
* By disabling @initdb@ one could run a temporary
isolated postgres on a base backup to test a migration.
* By using the 'stopPostgres' and 'withRestart' functions one can test
backup strategies.

The level of custom configuration is extensive but with great power comes the
ability to screw everything up. @tmp-postgres@ doesn't validate any custom
configuration and one can easily create a 'Config' that would not allow
@postgres@ to start.

WARNING!!
Ubuntu's PostgreSQL installation does not put @initdb@ on the @PATH@. We need to add it manually.
The necessary binaries are in the @\/usr\/lib\/postgresql\/VERSION\/bin\/@ directory, and should be added to the @PATH@

 > echo "export PATH=$PATH:/usr/lib/postgresql/VERSION/bin/" >> /home/ubuntu/.bashrc

-}

module Database.Postgres.Temp
  (
  -- * Main resource handle
    DB (..)
  -- * Exception safe interface
  -- $options
  , with
  , withPlan
  -- * Separate start and stop interface.
  , start
  , startWith
  , stop
  , defaultConfig
  , defaultPostgresConf
  , standardProcessConfig
  -- * Starting and Stopping postgres without removing the temporary directory
  , restart
  , stopPostgres
  , withRestart
  -- * Reloading the config
  , reloadConfig
  -- * DB manipulation
  , toConnectionString
  -- * Errors
  , StartError (..)
  -- * Configuration Types
  , Config (..)
  -- ** Directory configuration
  , DirectoryType (..)
  , PartialDirectoryType (..)
  -- ** Listening socket configuration
  , SocketClass (..)
  , PartialSocketClass (..)
  -- ** Process configuration
  , PartialProcessConfig (..)
  , ProcessConfig (..)
  -- ** @postgres@ process configuration
  , PartialPostgresPlan (..)
  , PostgresPlan (..)
  -- *** @postgres@ process handle. Includes the client options for connecting
  , PostgresProcess (..)
  -- ** Database plans. This is used to call @initdb@, @postgres@ and @createdb@
  , PartialPlan (..)
  , Plan (..)
  -- ** Custom Config builder helpers
  , optionsToDefaultConfig
  ) where
import Database.Postgres.Temp.Internal
import Database.Postgres.Temp.Internal.Core
import Database.Postgres.Temp.Internal.Partial


{- $options

 Based on the value of 'configSocket' a \"postgresql.conf\" is created with

 @
   listen_addresses = \'IP_ADDRESS\'
 @

 if it is 'IpSocket'. If is 'UnixSocket' then the lines

 @
   listen_addresses = ''
   unix_socket_directories = SOCKET_DIRECTORY
 @

 are added. This occurs as a side effect of calling 'withPlan'.

'defaultConfig' appends the following config by default

 @
   shared_buffers = 12MB
   fsync = off
   synchronous_commit = off
   full_page_writes = off
   log_min_duration_statement = 0
   log_connections = on
   log_disconnections = on
   client_min_messages = ERROR
 @

To append additional lines to \"postgresql.conf\" file create a
custom 'Config' like the following.

 @
  let custom = defaultConfig <> mempty
        { configPlan = mempty
          { partialPlanConfig =
              [ "wal_level=replica"
              , "archive_mode=on"
              , "max_wal_senders=2"
              , "fsync=on"
              , "synchronous_commit=on"
              ]
          }
        }
 @

 This is common enough there is `defaultPostgresConf` which
 is a helper to do this.

 In general you'll want to 'mappend' a config to the 'defaultConfig'
 since the 'defaultConfig' setups a client connection to the
 @postgres@ database.

 As an alternative to using 'defaultConfig' one could create a
 config from connections parameters using 'optionsToDefaultConfig'
-}