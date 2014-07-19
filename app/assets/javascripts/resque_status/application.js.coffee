jQuery ($) ->
  $('#main').attr('id', '')
  $('#resque-status').attr('id', 'main')

  $('#main').on 'click', "a.status-kill", (e) ->
    return false unless confirm("Are you sure you want to kill this job? There is no undo.")
    $link = $(this)
    $link.animate opacity: 0.5
    $.post $link.attr("href"), ->
      $link.remove()
    return false


  kill_all = $('.status-kill-all')
  kill_all.on 'click', ->
    $link = $(this)
    return false if $link.is('.disabled')
    return false unless confirm("Are you sure you want to kill this job? There is no undo.")
    data = {
      id: []
    }
    checked = $('.status-jobs-option').filter(':checked')
    return false if checked.length == 0
    checked.each (index, value)->
      data['id'].push $(value).val()

    $.post($link.attr('href'), data, ->
      checked.remove()
      updateKillAll()
    )
    return false;

  updateKillAll = ->
    jobs_option = $('.status-jobs-option')
    if jobs_option.length == 0
      kill_all.remove()
      $('input.status-check-all').remove()
      return
    if jobs_option.is(':checked')
      kill_all.removeClass('disabled')
    else
      kill_all.addClass('disabled')

  $('#main').on 'click', 'input.status-check-all', (e) ->
    $('.status-jobs-option').prop('checked', $(this).prop('checked'))
    updateKillAll()

  $('.status-jobs-option').on 'click', (e) ->
    updateKillAll()

  updateKillAll()

  $('#main').on 'click', 'a.status-clear', (e) ->
    return false unless confirm("Are you absolutely sure? This cannot be undone.");
    $.ajax
      type: "DELETE"
      url: $(this).attr('href')
      success: ->
        window.location.reload()
        return
    false

  status_map = {
    completed: 'progress-success',
    failed: 'progress-danger',
    working: 'progress-info',
    queued: 'progress-info',
    killed: 'progress-warning'
  }
  # itterate over the holders
  checkStatus = ($status) ->
    status_path = $status.data 'url'
    $.getJSON status_path, (json) ->
      if json
        pct = "0%"
        pct = json.pct_complete + "%"  if json.pct_complete

        $status.find(".progress .bar").animate width: pct
        $status.find(".progress .progress-pct").text pct
        $status.find(".status-message").html json.message  if json.message
        $status.data('status', json.status)
        $status.find(".progress").attr("class", "progress "+status_map[json.status])  if json.status
        $status.find(".status-time").text new Date(json.time * 1000).toString()  if json.time

        $details = $status.find(".status-details-body")
        $details.empty()
        for key of json
          $row = $("<tr>").appendTo($details)
          $("<td>").text(key).appendTo $row
          $("<td>").text(printValue(key, json[key])).appendTo $row

      status = $status.data("status")
      if status is "working" or status is "queued" or status is ""
        setTimeout (->
          checkStatus($status)
        ), 1500
      return

    return
  printValue = (key, value) ->
    if /(^|_)time$/.test(key) and typeof value is "number"
      time = new Date()
      time.setTime value * 1000
      time.toUTCString()
    else
      JSON.stringify value

  $(".status-holder").each ->
    checkStatus $(this)
    return
