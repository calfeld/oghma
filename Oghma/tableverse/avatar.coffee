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
Oghma.Thingy ?= {}

c_layer = 'avatars'

# All attributes are in table coordinates.

Oghma.Thingy.Tableverse.register( ( thingyverse, O ) ->
  thingyverse.avatar = new Heron.Index.MapIndex( 'owner', 'name' )

  show_labels = ->
    thingyverse.avatar.each( ( avatar ) ->
      avatar.show_label()
    )
  hide_labels = ->
    thingyverse.avatar.each( ( avatar ) ->
      avatar.hide_label()
    )

  class AvatarDelegate extends Oghma.KineticThingyDelegate
    constructor: ( args... ) ->
      super args...

      @thingy().show_label = =>
        if @is_visible() && @__k?
          tween = new Kinetic.Tween(
            node:     @__k.label,
            duration: 0.25,
            opacity:  1
          )
          tween.play()
        this
      @thingy().hide_label = =>
        if @is_visible() && @__k?
          tween = new Kinetic.Tween(
            node:     @__k.label,
            duration: 0.25,
            opacity:  0
          )
          tween.play()
        this

    draw: ->
      if ! @__k?
        @__k =
          disk: new Kinetic.Group({})
          a: new Kinetic.Wedge({})
          b: new Kinetic.Wedge({})
          label: new Kinetic.Text({})
        @__k.disk.add( @__k.a )
        @__k.disk.add( @__k.b )
        @group().add( @__k.disk )
        @group().add( @__k.label )

      attrs = @thingy().get()
      @__k.a.setAttrs(
        x: 0
        y: 0
        fill: 'blue'
        angle: 180
        radius: attrs.size / 2
      )
      @__k.b.setAttrs(
        x: 0
        y: 0
        fill: 'red'
        angle: 180
        radius: attrs.size / 2
        rotation: 180
      )
      @__k.label.setAttrs(
        text:     attrs.name + ''
        y:        attrs.size / 2
        fill:     O.ui_colors.value().primary
        stroke:   O.ui_colors.value().primary
        fontSize: 16
        opacity:  0
      )

      # Center text
      @__k.label.setOffset(
        x: @__k.label.getWidth()  / 2
      )

      # Label Bindings
      @__k.disk.on( 'mouseenter', show_labels )
      @__k.disk.on( 'mouseleave', hide_labels )


    remove: ( thingy ) ->
      thingyverse.avatar.remove( thingy )
      super thingy

  thingyverse.define(
     'avatar',
    [
      'name',
      'color1', 'color2',
      'owner',
      'size'
    ],
    {
      loc:    [ 'x', 'y' ]
      status: [ 'locked', 'visible_to', 'zindex' ]
    },
    ( attrs ) ->
      attrs.x          ?= 0
      attrs.y          ?= 0
      attrs.color1     ?= O.me().gets( 'primary' )
      attrs.color2     ?= O.me().gets( 'secondary' )
      attrs.owner      ?= O.me().gets( 'name' )
      attrs.visible_to ?= []
      attrs.name       ?= attrs.owner
      attrs.size       ?= O.grid.grid()

      @after_construction( ->
        thingyverse.avatar.add( this )
      )

      new AvatarDelegate(
        O, this, O.layer[ c_layer ], O.zindex[ c_layer ],
        [ 'color1', 'color2', 'name' ],
        attrs
      )
  )

  O.ui_colors.on_set( ->
    O.tableverse.avatar.each( ( avatar ) ->
      avatar.redraw()
    )
  )
)
