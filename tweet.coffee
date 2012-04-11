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
      @timer1 = setInterval (-> TwitterWall.fetch_new_tweets()), 15000
      $(".tweet").fadeOut()
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

      console.log "Cerco quelli dopo #{@latest_tweet_downloaded.id}, ossia '#{@latest_tweet_downloaded.text}'" if @latest_tweet_downloaded?
      console.log url

      $.getJSON url, (json) =>
        console.log json
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
                      image_url = "http://imagembed.heroku.com/convert?resize=400x400&source=#{json.url}"
                      tweet.extra_content = $("<img/>").attr("src", image_url)
                    else if json.type == "rich"
                      $content = $(json.html)
                      if $content.get(0).tagName == "IFRAME"
                        $content.attr("width", 400).attr("height", 400)
                      tweet.extra_content = $content
              console.log "Aggiunto un tweet! Con id: #{tweet.id} e testo '#{tweet.text}'"
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


      $(".tweet").fadeOut ->
        if tweet_to_show?     
          $(".tweet .message").html(tweet_to_show.extra_content)
          $(".tweet .message_text").html(tweet_to_show.text)
          $(".tweet .author").html("@"+tweet_to_show.from_user)
          $(".tweet .created_at").text($.timeago(tweet_to_show.created_at))
          $(".tweet .profile_pic").css(backgroundImage: "url(http://api.twitter.com/1/users/profile_image/#{tweet_to_show.from_user}.json?size=original)")
          $(".tweet").fadeIn()
          $('.tweet').css(marginTop: ($(window).height() - $('.tweet').height()) / 2)

  
  wi = $(".tweet").width() / 100 * 19
  $(".profile_pic").width wi
  $(".profile_pic").height wi
  $(".profile_pic").css
    "background-size": wi + "px " + wi + "px"
    "border-radius": wi / 10 + "px"
  
  logosize = $("body").width()
  $(".logo").width logosize/100*15
  $(".logo").height (logosize/100*15)/3.5
  $(".logo").css
    "background-size": logosize/100*15 + "px " + (logosize/100*15)/3.5 + "px"

  allVars = $.getUrlVars("hashtag")
  unless allVars["hashtag"] is `undefined`
    TwitterWall.set_query allVars["hashtag"]
    TwitterWall.play()
    $(".header").css("display","none")
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
  $(".header").hover(
    -> $(this).animate(opacity: 1),
    -> $(this).animate(opacity: 0)
  )

  $(".tweet").fitText 1.8,
    maxFontSize: "40px"

$(window).resize ->
  wi = $(".tweet").width() / 100 * 19
  $(".profile_pic").width wi
  $(".profile_pic").height wi
  $(".profile_pic").css
    "background-size": wi + "px " + wi + "px"
    "border-radius": wi / 10 + "px"
  logosize = $("body").width()
  $(".logo").width logosize/100*15
  $(".logo").height (logosize/100*15)/3.5
  $(".logo").css
    "background-size": logosize/100*15 + "px " + (logosize/100*15)/3.5 + "px"
