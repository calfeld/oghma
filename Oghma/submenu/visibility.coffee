
# Copyright 2010-2014 Christopher Alfeld
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
Oghma.SubMenu ?= {}

# Visibility sub menu.
#
# This is a dynamic menu so the items should be called and added on menu
# display.
#
# @param [Oghma.App] O App.
# @param [Oghma.Thingy] thingy Thingy to set visiblity o.f
# @param [string] key Visible to key.  Default: 'visible_to'.
# @return [Array<Object>] Menu items to add.
#
# @author Christopher Alfeld (calfeld@calfeld.net)
# @copyright 2013 Christopher Alfeld
Oghma.SubMenu.visibility = ( O, thingy, key = 'visible_to' ) ->
  value = thingy.gets( key )
  items = []
  set = ( value ) ->
    attrs = {}
    attrs[ key ] = value
    thingy.set( attrs )

  if value.length == 0
    items.push(
      text: 'Make private'
      handler: -> set( [ O.me().gets('name') ] )
    )
  else
    items.push(
      text: 'Make public'
      handler: -> set( [] )
    )

  items.push(
    text: 'Visible to'
    menu: Oghma.SubMenu.users( O, 'multi', value,
      ( name, checked ) ->
        if checked
          value.push( name )
        else
          value.splice( value.indexOf( name ), 1 )
        set( value )
    )
  )

  items




