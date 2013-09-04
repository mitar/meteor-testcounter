Publications = new Meteor.Collection 'Publications'
SearchResults = new Meteor.Collection 'SearchResults'

if Meteor.isClient
  Meteor.startup ->
    Meteor.subscribe 'search-available'

  Template.button.count = ->
    searchResult = SearchResults.findOne()

    if not searchResult
      return 0
    else
      return searchResult.count

  Template.button.events
    'click button': (e, template) ->
      Meteor.call 'process'

if Meteor.isServer
  Future = Npm.require('fibers/future')
  wait = Future.wait

  sleep = (ms) ->
    future = new Future
    setTimeout ->
      future.return()
    , ms
    future

  if Publications.find({}, limit: 1).count() == 0
    for i in [0..100]
      console.log "Creating #{ i }"
      Publications.insert
        processed: false

  Meteor.publish 'search-available', ->
    mainId = Random.id()
    count = 0
    initializing = true

    handle = Publications.find(
      processed: true
    ,
      field:
        _id: 1
    ).observeChanges
      added: (id) =>
        count++

        if !initializing
          @changed 'SearchResults', mainId,
            count: count

      removed: (id) =>
        count--
        @changed 'SearchResults', mainId,
          count: count

    initializing = false

    @added 'SearchResults', mainId,
      count: count

    @ready()

    @onStop =>
      @removed 'SearchResults', mainId

      handle.stop()

  Meteor.methods
    'process': ->
      @unblock()

      console.log "Processing"

      Publications.find(processed: {$ne: true}).forEach (publication) ->
        console.log "Processing #{ publication._id }"
        Publications.update
          _id: publication._id
        ,
          $set:
            processed: true
        sleep(1000).wait()
