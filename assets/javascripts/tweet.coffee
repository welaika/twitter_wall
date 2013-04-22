$(document).ready ->

  $.extend
    getUrlVars: ->
      vars = []
      hash = undefined
      hashes = window.location.href.slice(window.location.href.indexOf("?") + 1).split("&")
      i = 0

      while i < hashes.length
        hash = hashes[i].split("=")
        vars.push hash[0]
        vars[hash[0]] = hash[1]
        i++
      vars  

    getUrlVar: (name) ->
      $.getUrlVars()[name]

  TwitterWall =
    query: "#welaika"
    unseen_tweets: []
    seen_tweets: []
    latest_tweet_downloaded: null
    is_playing: false
    age_limit: 0
    current_tweet_index: 0

    set_query: (q) ->
      return if q == @query
      @query = q
      @seen_tweets = []
      @unseen_tweets = []
      latest_tweet_downloaded = null

    play: ->
      @is_playing = true
      @timer1 = setInterval (-> TwitterWall.fetch_new_tweets()), 30000
      $(".tweet").slideUp()
      TwitterWall.fetch_new_tweets =>
        @timer2 = setInterval (-> TwitterWall.show_tweet()), 7500
        TwitterWall.show_tweet()

    throw_tweets_older_than: (minutes) ->
      @age_limit = minutes
      @unseen_tweets = $.grep @unseen_tweets, (tweet) =>
        Date.parse(tweet.created_at) > (new Date() - 60000 * @age_limit)
      @seen_tweets = $.grep @seen_tweets, (tweet) =>
        Date.parse(tweet.created_at) > (new Date() - 60000 * @age_limit)

    stop: ->
      clearInterval(@timer1)
      clearInterval(@timer2)
      @is_playing = false
      @unseen_tweets = @seen_tweets.concat(@unseen_tweets)
      @current_tweet_index = @unseen_tweets.length - 1
      @show_tweet()

    previous: ->
      return if @is_playing
      return if @current_tweet_index == 0
      @current_tweet_index--
      @show_tweet()

    next: ->
      return if @is_playing
      return if @current_tweet_index == @unseen_tweets.length - 1
      @current_tweet_index++
      @show_tweet()

    fetch_new_tweets: (callback) ->
      url = "http://search.twitter.com/search.json?q=#{encodeURIComponent(@query)}&callback=?&rpp=30"
      url += "&since_id=" + @latest_tweet_downloaded.id if @latest_tweet_downloaded?

      $.getJSON url, (json) =>
        if json and json.results
          for tweet in json.results.reverse()
            if $.grep(@unseen_tweets.concat(@seen_tweets), (el) -> el.id == tweet.id or el.text == tweet.text).length == 0
              @unseen_tweets.push(tweet)
              @latest_tweet_downloaded = tweet
              tweet.extra_content = ""
              do (tweet) ->
                pic1 = new Image()
                pic1.src = "http://api.twitter.com/1/users/profile_image/#{tweet.from_user}.json?size=original"
                parse_url = /http[^ ]+/
                url = tweet.text
                result = parse_url.exec(url)
                if result?
                  link = encodeURI(result)
                  key = '034df61c7f0811e1ab2f4040d3dc5c07'
                  api_url = 'http://api.embed.ly/1/oembed?key=' + key + '&url=' + link + '&callback=?'
                  $.getJSON api_url, (json) ->
                    if json.type == "photo"
                      imageh = json.height
                      imagew = json.width
                      image_url = "#{json.url}"
                      if (imagew >= imageh)
                        tweet.imagewidth = "auto"
                        tweet.imageheight = "100%"
                        tweet.imagesrc = image_url
                      else 
                        tweet.imagewidth = "100%"
                        tweet.imageheight = "auto"
                        tweet.imagesrc = image_url
                    else if json.type == "rich"
                      $content = $(json.html)
                      
                      tweet.extra_content = $content
          callback() if (callback)

    show_tweet: ->
      tweet_to_show = null

      if @is_playing
        if @unseen_tweets.length > 0
          tweet_to_show = @unseen_tweets.shift()
          @seen_tweets.push(tweet_to_show)
        else
          if @seen_tweets.length == 1
            @current_tweet_index = 0
          else
            new_index = @current_tweet_index
            while new_index == @current_tweet_index and @seen_tweets.length > 1
              new_index = parseInt(Math.random() * @seen_tweets.length)
            @current_tweet_index = new_index

          tweet_to_show = @seen_tweets[@current_tweet_index]
      else
        tweet_to_show = @unseen_tweets[@current_tweet_index]


      $(".tweet").slideUp ->
        if tweet_to_show?     
          if tweet_to_show.imagesrc
            $(".container").css
              "background-size": tweet_to_show.imageheight + " " + tweet_to_show.imagewidth
              "background-image": "url('" + tweet_to_show.imagesrc + "')"
              "background-position": "center center"
            $(".container").addClass("overimage")
          else 
            $(".container").css
              "background-image": "none"
            $(".container").removeClass("overimage")
          $(".tweet .message_text").html(tweet_to_show.text)
          $(".tweet .author").html("@"+tweet_to_show.from_user)
          $(".tweet .created_at").text($.timeago(tweet_to_show.created_at))
          $(".tweet .profile_pic").css(backgroundImage: "url(http://api.twitter.com/1/users/profile_image/#{tweet_to_show.from_user}.json?size=original)")
          $(".tweet").slideDown()
        else
          $(".tweet .message_text").html('Nessun tweet trovato')
          $(".tweet").slideDown()

  allVars = $.getUrlVars("hashtag")
  unless allVars["hashtag"] is `undefined`
    TwitterWall.set_query allVars["hashtag"]
    TwitterWall.play()
    $(".settings_button").css("display","none")
    $(".profile_pic").css("opacity", "1")
  $(".play").click ->
    if TwitterWall.is_playing == false
      $(this).html("Stop")
      $(".next, .previous").hide()
      $(".query").attr("disabled", "disabled")
      TwitterWall.set_query $(".query").val()
      TwitterWall.play()
      $(".profile_pic").css("opacity", "1")
      $(".code").val(document.URL+"?hashtag="+$(".query").val())
    else
      $(".next, .previous").show()
      $(".query").removeAttr("disabled")
      $(this).html("Play")
      TwitterWall.stop()

  $(".save_minutes").click ->
    TwitterWall.throw_tweets_older_than parseInt($(".minutes_old").val())

  $(".previous").click -> TwitterWall.previous()
  $(".next").click -> TwitterWall.next()
  $(".previous, .next").hide()

  $('.settings_button').click -> 
    $(this).toggleClass('opened')
    $(this).toggleClass('closed')
    if $(this).hasClass('closed')
      $(".settings").animate(top: ($(window).height() / 10))
      $(".container").animate
        "height": ($(window).height() / 10) * 8 +'px'
        "margin-top": ($(window).height() / 10) + 'px'
    else
      $(".settings").animate(top: '+10px')
      $(".container").animate
        "height": ($(window).height() / 10) * 7 +'px'
        "margin-top": ($(window).height() / 10) * 2 + 'px'

  sizing = ->

  sizing()

  $(window).resize ->

    sizing()
