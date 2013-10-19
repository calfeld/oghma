# Copyright 2010-2013 Christopher Alfeld
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

Oghma = @Oghma ?= {}
Oghma.Thingy ?= {}

root = this

# Main application class.
#
# A single instance of this class is instantiated as the O global variable
# once the document is ready.  It holds all application data and serves as
# the `main` routine.
#
# @author Christopher Alfeld (calfeld@calfeld.net)
# @copyright 2013 Christopher Alfeld
class Oghma.App
  # {Oghma.Ext.Console} window.
  console: null

  # Client ID of this client.
  client_id: null

  # {Heron.Dictionary}.
  dictionary: null

  # {Heron.Comet}.
  comet: null

  # Userverse {Heron.Thingyverse}
  userverse: null

  # Tableverse {Heron.Thingyverse}
  tableverse: null

  # {Oghma.Login} Manager.
  login: null

  # Viewport
  viewport: null

  # Synonym for `kinetic_panel.stage`.
  stage: null

  # {Oghma.Action} instance.
  action: null

  # Keymap for global keyboard shortcuts.
  keymap: null

  # Layers
  layer:
    dice: null

  # GM Username
  GM: 'GM'

  # UI Color
  ui_colors: new Heron.Enumeration(
    cycle: true
    values: [
      {
        name:      'Light'
        primary:   'lightblue'
        secondary: 'lightgreen'
      },
      {
        name:      'Dark'
        primary:   'darkblue'
        secondary: 'darkgreen'
      }
    ]
  )

  # Default table.
  default_table: 'Antechamber'

  # Current table, a table thingy.
  current_table: null

  # Constructor
  #
  # Sets up server connections for {Heron.Comet} and {Heron.Dictionary} and
  # initializes the thingyverses from the primordial thingyverses.  Once the
  # userverse is loaded, displays the login screen.
  #
  # @param [object] config Configuration.
  # @option config [boolean] debug If true, additional information is sent to
  #   the console.  Default: false.
  #
  # **Properties**:
  #
  # - client_id [string]
  # - dictionary [{Heron.Dictionary}]
  # - comet [{Heron.Comet}]
  # - userverse [{Heron.Thingyverse}]
  # - tableverse [{Heron.Thingyverse}]
  #
  constructor: (config = {}) ->
    # Store in global for easy introspection from console.
    root.O = this

    @_ = {}
    @_.debug = config.debug ? false
    @_.callbacks =
      post_login: jQuery.Callbacks()
      join_table: jQuery.Callbacks()

    Ext.getBody().mask( 'Initialising...' )

    # Communication
    @client_id = Heron.Util.generate_id()

    @dictionary = new Heron.Dictionary(
      client_id: @client_id
      debug:     @_.debug
    )

    @comet = new Heron.Comet(
      client_id:  @client_id
      on_message: ( msg )  => @dictionary.receive( msg )
      on_verbose: ( text ) => console.info( text )
      on_connect: =>
        @verbose( 'Connected to server.' )
        @login_phase()
    )

    # Thingyverses
    @allverse = new Heron.Thingyverse()
    Oghma.Thingy.Allverse.generate( @allverse, this )

    @userverse = new Heron.Thingyverse()
    Oghma.Thingy.Userverse.generate( @userverse, this )

    @tableverse = new Heron.Thingyverse()
    Oghma.Thingy.Tableverse.generate( @tableverse, this )
    @on( 'post_login', ( me ) =>
      @userverse.connect(
        @dictionary,
        'oghma.thingy.user.' + me.gets( 'name' )
      )
      initial_table = me.gets( 'table' )

      if ! initial_table?
        if ! @allverse.table.with_name( @default_table )[0]?
          @allverse.create( 'table', name: @default_table )
        initial_table = @default_table

      @join_table( initial_table )
    )

    # Console
    @console = Ext.create( 'Oghma.Ext.Console',
      x: 50
      y: 50
    )
    @on( 'post_login', ( me ) =>
      me.manage_window( 'console', @console )
    )

    # Action
    @action = new Oghma.Action( this )

    # Viewport and Kinetic Panel
    @viewport = Ext.create(
      'Ext.container.Viewport',
      layout: 'border'
    )
    @table = Ext.create( 'Oghma.Ext.Table',
      region: 'center'
    )
    @table.onZoom.add( ( zoom ) => @me()?.set( zoom: zoom ) )

    @viewport.add( @table )
    @stage = @table.stage
    @layer.dice = new Kinetic.Layer()
    @stage.add( @layer.dice )

    # Set up keymap
    @keymap = Ext.create( 'Ext.util.KeyMap', target: Ext.getDoc() )

    # Set up keybindings.
    Oghma.bind_keys( this )

    # Main toolbar.
    @toolbar_main = Ext.create( 'Ext.toolbar.Toolbar',
      region: 'north'
      items: [
        {
          text: 'Dice'
          menu: Oghma.Menu.dice( this )
        },
        {
          text: 'Clear'
          menu: Oghma.Menu.clear( this )
        },
        {
          text: 'Window'
          menu: Oghma.Menu.window( this )
        }
      ]
    )
    @viewport.add( @toolbar_main )

    @on( 'post_login', ( me ) =>
      if me.gets( 'name' ) == @GM
        @toolbar_gm = Ext.create( 'Ext.toolbar.Toolbar',
          region: 'north'
          items: [
            {
              text: 'Debug'
              menu: Oghma.Menu.debug( this )
            }
          ]
        )
        @viewport.add( @toolbar_gm )
    )

    # Status bar
    zoom_to_text = ( zoom ) -> Math.floor( zoom * 100 ) + '%'
    @statusbar = Ext.create( 'Ext.toolbar.Toolbar',
      region: 'south'
      items: [
        {
          id: 'status_ui_colors'
          text: "UI: #{@ui_colors.value().name}"
          menu: Oghma.Status.ui_colors( this )
        },
        {
          id: 'status_zoom'
          text: "Zoom: #{zoom_to_text(@table.getZoom())}"
          menu: Oghma.Status.zoom( this )
        },
        {
          id: 'status_location'
          text: "@0,0"
          handler: ->
            O.action.return_to_origin()
        }
      ]
    )
    @viewport.add( @statusbar )
    @ui_colors.on_set( ( value ) =>
      @statusbar.child( '#status_ui_colors' ).setText( "UI: #{value.name}" )
    )
    @table.onZoom.add( ( zoom ) =>
      @statusbar.child( '#status_zoom' ).setText( "Zoom: #{zoom_to_text(zoom)}" )
    )
    status_location = @statusbar.child( '#status_location' )
    Ext.getDoc().on(
      mousemove: =>
        [ x, y ] = @table.mouse()
        if ! x?
          status_location.setText( "@???" )
        else
          status_location.setText( "@#{x},#{y}" )
    )

    @verbose( 'Oghma is connecting...' )

    # Connect
    @comet.connect()

  # Login Phase.
  #
  # Display Login window.  Also handles user creation logic.
  #
  # @return [null] null
  login_phase: ->
    # Create login Manager
    @login = new Oghma.Login( this )
    @login.on( 'login', ( username ) => @message( username, 'Logged In' ) )
    @login.on( 'logout', ( username ) => @message( username, 'Logged Out' ) )

    @allverse.connect( @dictionary, 'oghma.thingy.all', =>
      # Check for ?user parameter.
      result = /^\?user=([^?]+)/.exec( window.location.search )
      if result?
        user = decodeURI( result[1] )
        @verbose( "Auto logging in as #{user}" )
        @login_user( user )
      else
        create = Ext.create( 'Oghma.Ext.EditObject',
          object:
            name:      ''
            primary:   'FF0000'
            secondary: '00FF00'
          types:
            primary:   'color'
            secondary: 'color'
          title: 'Create User'
          onSave: ( userinfo ) =>
            if @create_user( userinfo )
              login.close()
              create.close()
              @login_user( userinfo.name )

          onCancel: ->
            create.hide()
            login.show()
        )
        login = Ext.create( 'Oghma.Ext.Login',
          O: this
          onLogin: ( user ) =>
            login.close()
            create.close()
            @login_user( user, @client_id )
          onCreate: ->
            login.hide()
            create.show()
        )
        login.show()
      Ext.getBody().unmask()
    )
    null

  # Login as user.
  #
  # @param [string] username User to login as.
  # @return [Oghma.App] this
  login_user: ( username ) ->
    @allverse.create( 'login',
      name:      username
      client_id: @client_id
    )
    window.history?.replaceState?(
      null,
      document.title,
      encodeURI( "?user=#{username}" )
    )
    @_.callbacks.post_login.fire( @me() )
    this

  # Register callback.
  #
  # Available events:
  # - post_login: Called with user thingy on successful login.
  # - join_table: Called with table name and thingy on table join.
  #
  # @param [string] which Which event.
  # @param [function] f Function to call on specified event.
  # @return [Oghma.App] this
  on: ( which, f ) ->
    @_.callbacks[ which ].add( f )
    this

  # @return [userverse.user] Thingy for current user.
  me: ->
    logins = @allverse.login.with_client_id( @client_id )
    if logins? && logins.length > 0
      username = logins[0].gets( 'name' )
      if username?
        return @allverse.user.with_name( username )?[0]
    null

  # @param [Heron.Map] item Item to check ownership.
  # @return [boolean] true iff owner property of `item` is current user.
  i_own: ( map ) ->
    map.gets( 'owner' ) == @me().gets( 'name' )

  # Create a new user.
  #
  # See {#login_phase()}.
  #
  # @param [object] userinfo User info.
  # @option userinfo [string] username User name.
  # @option userinfo [string] primary Primary color.
  # @option userinfo [string] secondary Seconary color.
  # @return [null] null
  create_user: ( userinfo ) ->
    if @allverse.user.with_name( userinfo.name ).length > 0
      # TODO: Do something better with errors.
      alert( "User #{userinfo.name} already exists." )
      false
    else
      @allverse.create( 'user', userinfo )
      true

  # Send verbose message to the console.
  #
  # @param [string] msg Message to send.
  # @return [Oghma.App] this
  verbose: ( msg ) ->
    @console?.message( 'verbose', msg )
    console.info( msg )
    this

  # Send warn message to the console.
  #
  # @param [string] msg Message to send.
  # @return [Oghma.App] this
  warn: ( msg ) ->
    @console?.message( 'warning', msg, '#ff7f00', '#ff7f00' )
    console.warn( msg )
    this

  # Send error message to the console.
  #
  # @param [string] msg Message to send.
  # @return [Oghma.App] this
  error: ( msg ) ->
    @console?.message( 'error', msg, '#ff0000', '#ff0000' )
    console.error( msg )
    this

  # Send a debug message to the console.
  #
  # @param [string] msg Message to send.
  # @return [Oghma.App] this
  debug: ( msg ) ->
    @console?.message( 'debug', msg, '#0000ff', '#0000ff' )
    console.debug( msg )
    this

  # Send a message from a user to the console.
  #
  # @param [string] username Name of user.
  # @param [string] message Message.
  # @return [Oghma.App] this
  message: ( from, msg ) ->
    user = @allverse.user.with_name( from )[0]
    if ! user?
      @error( "Message from non-existent user #{from}: #{msg}" )
    else
      color = user.gets( 'primary' )
      @console?.message( from, msg, color, color )

  # Reset focus.
  reset_focus: ->
    Ext.get( Ext.Element.getActiveElement() ).blur()

  # Join a table.
  #
  # @param [string] which Name of which table to join.
  # @return [Oghma.App] this
  join_table: ( which ) ->
    @verbose( "Joining table: #{which}" )
    table = @allverse.table.with_name( which )[0]
    if ! table?
      error( "Attempt to join non-existent table: #{which}" )
      return

    if @tableverse.domain()?
      @tableverse.disconnect()
    @current_table = table
    @tableverse.connect(
      @dictionary,
      'oghma.thingy.table.' + which,
      =>
        @verbose( "Joined table: #{which}" )
        @_.callbacks.join_table.fire( which, table )
    )

    this

