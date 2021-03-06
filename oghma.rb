#!/usr/bin/env ruby2.0

# Copyright 2013 Christopher Alfeld
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Oghma Server
#
# This is a complete server for Oghma.
#
# Author:: Christopher Alfeld (calfeld@calfeld.net)

require 'rubygems'
require 'sinatra'
require 'thread'

HOME = File.dirname(__FILE__)
$:.unshift(File.join(HOME, 'server/heron'))

require 'server/sinatra_comet'
require 'server/sinatra_dictionary'

# Initialize Dictionary Database
DICTIONARY_DB = File.join(HOME, 'oghma.db')

Thread.abort_on_exception = true

class OghmaServer < Sinatra::Base
  set :public_folder, File.join(HOME, 'public')

  # Clients can list this tree.
  RESOURCES = "resources"

  enable :static
  enable :threaded
  enable :run
  enable :dump_errors

  # Uncomment for request logging.
#  enable :logging
#  use Rack::CommonLogger

  # Defines
  # /comet/connect
  # /comet/disconnect
  # /comet/receive
  # /comet/flush
  include ::Heron::SinatraComet

  # Path to dictionary; used by SinatraDictionary.
  DICTIONARY_DB_PATH = DICTIONARY_DB
  # Defines
  # /dictionary/subscribe
  # /dictionary/messages
  include ::Heron::SinatraDictionary

  OUTPUT_MUTEX = Mutex.new
  def self.out( s, color = 0 )
    OUTPUT_MUTEX.synchronize do
      puts "\e[3#{color}m#{s}\e[0m"
    end
  end

  def self.red( s )
    out( s, 1 )
  end
  def self.blue( s )
    out( s, 4 )
  end
  def self.yellow( s )
    out( s, 3 )
  end

  dictionary.on_verbose   = -> s     { blue("DICT #{s}")                   }
  dictionary.on_error     = -> s     { red("DICT ERROR #{s}")              }
  dictionary.on_subscribe = -> id, s { blue("DICT SUBSCRIBE [#{id}] #{s}") }
  dictionary.on_collision = -> s     { red("DICT COLLISION #{s}")          }

  # Uncomment for low level server->client logging.
#  comet.enable_debug
  comet.client_timeout  = 20
  comet.receive_timeout = 10

  comet.on_connect    = -> client_id { yellow "COMET CONNECT #{client_id}"    }
  comet.on_disconnect = -> client_id do
     yellow "COMET DISCONNECT #{client_id}"
     dictionary.disconnected( client_id )
   end

  get '/' do
    erb :index
  end

  def list_resources(params)
    return 404 if params[:splat].length != 1
    prefix = params[:splat][0]
    return 404 if prefix !~ /^[\/_\w]+$/
    full_prefix = File.join(settings.public_folder, RESOURCES, prefix)
    Dir.glob("#{full_prefix}/**/*").select do |path|
      yield path
    end.collect do |path|
      path.sub("#{full_prefix}/", '')
    end.to_json
  end

  get '/resource_files/*' do
    list_resources(params) {|path| File.file?(path)}
  end

  get '/resource_directories/*' do
    list_resources(params) {|path| File.directory?(path)}
  end

  get '/remove_table' do
    table = params[ 'table' ]

    raise "Missing table." if ! table
    raise "Invalid table." if table !~ /^[\w\s.]+$/
    path = File.join( DICTIONARY_DB, "oghma.thingy.table.#{table}.db" )
    if ! File.exists?( path )
      raise "Table does not exist: #{table}"
    end
    File.unlink( path )
  end

  at_exit { dictionary.shutdown }

  run!
end

# Work around Sinatra bug.
exit
