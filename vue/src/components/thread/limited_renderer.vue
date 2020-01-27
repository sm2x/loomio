<script lang="coffee">
import Records from '@/shared/services/records'
import EventBus from '@/shared/services/event_bus'
import RecordLoader from '@/shared/services/record_loader'
import EventHeights from '@/shared/services/event_heights'
import { reverse, groupBy, filter, compact, clone, debounce, range, min, max, map, keys, first, last, sortedUniq, sortBy, difference, isEqual, without } from 'lodash'

export default
  props:
    parentEvent: Object
    focalEvent: Object
    fetch: Function
    newestFirst: Boolean
    isReturning: Boolean

  data: ->
    eventsBySlot: {}
    missingItems: []
    focus: null
    slots: []
    padding: parseInt(screen.height/40) || 20

  created: ->
    @fetchMissing = debounce ->
      @fetch(@missingItems)
    ,
      1000
    ,
      {leading: true, trailing: false, maxWait: 3000}

    @watchRecords
      key: 'parentEvent'+@parentEvent.id
      collections: ['events']
      query: => @renderSlots()

  methods:
    renderSlots: ->
      return if @parentEvent.childCount == 0

      # we can let the browser garbage collect if eventsBySlot is too big
      # @eventsBySlot = {} if @slots.length > 1000 # no! just set all existing slots to null so page stays in same place.
      # may want to re scroll after this action.

      if @focalEvent
        @focus = @eventOrParent(@focalEvent).position
      else
        @focus = @visibleSlots[parseInt(@visibleSlots.length / 2)] || 1

      firstItem = max([1, @focus - @padding])
      lastItem = min([@focus + @padding, @parentEvent.childCount])

      presentItems = []

      Records.events.collection.chain().
      find(parentId: @parentEvent.id).
      find(position: {$between: [firstItem, lastItem]}).
      simplesort('position').
      data().forEach (event) =>
        presentItems.push(event.position)
        @eventsBySlot[event.position] = event

      range(firstSlot, lastSlot+1).forEach (slot) =>
        @eventsBySlot[slot] = null unless @eventsBySlot.hasOwnProperty(slot)

      @missingItems = sortBy difference(range(firstItem, lastItem+1), presentItems)

      @slots = sortBy map(keys(@eventsBySlot), Number)

    eventOrParent: (event) ->
      if !@parentEvent or !event.parent() or (event.depth == @parentEvent.depth + 1)
        event
      else
        @eventOrParent(event.parent())

  computed:
    adjustedSlots: ->
      if @newestFirst && @parentEvent.depth == 0
        reverse clone @slots
      else
        @slots

  watch:
    'parentEvent.childCount': (newVal, oldVal) ->
      if newVal < oldVal
        @eventsBySlot = {}
        @visibleSlots = []
        @missingItems = []
        @slots = []
        @renderSlots()

    focalEvent: -> @renderSlots()
    missingItems: -> @fetchMissing()

</script>
<template lang="pug">
.thread-renderer.mb-2
  .thread-item-slot(v-for="slot in adjustedSlots" :key="slot" v-observe-visibility="{callback: (isVisible) => slotVisible(isVisible, slot)}" )
    thread-item-wrapper(:parent-id="parentEvent.id" :event="eventsBySlot[slot]" :position="parseInt(slot)" :focal-event="focalEvent" :is-returning="isReturning")
</template>
