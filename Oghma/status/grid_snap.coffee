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
Oghma.Status ?= {}

# Grid snap status.
#
# @param [Oghma.App] App.
# @return [Oghma.Ext.EnumerationMenu] Grid snap status menu.
#
# @author Christopher Alfeld (calfeld@calfeld.net)
# @copyright 2014 Christopher Alfeld
Oghma.Status.grid_snap = ( O ) ->
  Ext.create( 'Oghma.Ext.EnumerationMenu',
    enumeration: O.grid_snap
    namer:       ( x ) -> x.name
    increment:   null
    decrement:   null
  )
