class Thorax.Views.Users extends Thorax.Views.BonnieView
  className: 'user-management'
  template: JST['users/users']

  events:
    'change .users-sort-list': 'sortUsers'

  initialize: ->
    @totalMeasures = 0
    @totalPatients = 0
    @collection.on 'change add reset destroy remove', @updateSummary, this

  updateSummary: ->
    @totalMeasures = @collection.reduce(((sum, user) -> sum + user.get('measure_count')), 0)
    @totalPatients = @collection.reduce(((sum, user) -> sum + user.get('patient_count')), 0)
    @render()

  sortUsers: (e) ->
    attr = $(e.target).val()
    @collection.setComparator(attr).sort()

  emailAllUsers: ->
    if !@emailAllUsersView
      @emailAllUsersView = new Thorax.Views.EmailAllUsers()
      @emailAllUsersView.appendTo(@$el)
    @emailAllUsersView.display()

class Thorax.Views.User extends Thorax.Views.BonnieView
  template: JST['users/user']
  editTemplate: JST['users/edit_user']
  tagName: 'tr'

  context: ->
    _(super).extend
      isCurrentUser: bonnie.currentUserId == @model.get('_id')
      csrfToken: $("meta[name='csrf-token']").attr('content')

  events:
    serialize: (attr) ->
      attr.admin ?= false
      attr.portfolio ?= false
    rendered: ->
      @exportBundleView = new Thorax.Views.ExportBundleView() # Modal dialogs for exporting
      @exportBundleView.appendTo(@$el)
      $('.indicator-circle, .navbar-nav > li').removeClass('active')
      $('.nav-admin').addClass('active')

  approve: -> @model.approve()

  disable: -> @model.disable()

  bundle: ->
    @exportBundleView.exporting()
    $.fileDownload "#{@model.url()}/bundle",
      successCallback: => @exportBundleView.success()
      failCallback: => @exportBundleView.fail()


  edit: ->
    @$el.html(@renderTemplate(@editTemplate))
    @populate()

  save: ->
    @serialize()
    @model.save {}, success: => @$el.html(@renderTemplate(@template))

  cancel: -> @$el.html(@renderTemplate(@template))

  showDelete: -> @$('.delete-user').toggleClass('hide')

  delete: -> @model.destroy()

class Thorax.Views.EmailAllUsers extends Thorax.Views.BonnieView
  template: JST['users/email_all']

  context: ->
    _(super).extend
      token: $("meta[name='csrf-token']").attr('content')

  events:
    'ready': 'setup'
    'keypress input:text': 'enableSend'
    'keypress textarea': 'enableSend'

  setup: ->
    @emailAllUsersDialog = @$("#emailAllUsersDialog")
    @emailAllUsersMessageDialog = @$("#emailAllUsersMessageDialog")
    @emailAllUsersProgressDialog = @$('#emailAllUsersProgressDialog')
    @subjectField = @$("#emailAllSubject")
    @bodyArea = @$("#emailAllBody")
    @sendButton = @$("#sendButton")
    @enableSend();

  display: ->
    @emailAllUsersDialog.modal(
      "backdrop" : "static",
      "keyboard" : true,
      "show" : true).find('.modal-dialog').css('width','650px')

  showMessage: (message) ->
    @emailAllUsersMessageDialog.find('.modal-body').text(message)
    @emailAllUsersMessageDialog.modal(
      "backdrop" : "static",
      "keyboard" : true,
      "show" : true).find('.modal-dialog').css('width','650px')

  trackProgressInterval: 5000

  trackProgress: (jobID) ->
    me = this
    url = @$('form').attr('action') + '/status/' + encodeURIComponent(jobID)
    @emailAllUsersProgressDialog.modal(
      "backdrop" : "static",
      "keyboard" : false,
      "show" : true).find('.modal-dialog').css('width','650px')
    # Reset the everything
    progress_bar = @emailAllUsersProgressDialog.find('.progress_bar')
    progress_bar.css('width', '0%')
    progress_bar.text('0%')
    # Don't immediately ping the server, wait trackProgressInterval
    updateStatus = ->
      $.ajax(url, {
        'error': (jqXHR, textStatus, error) ->
          me.emailAllUsersProgressDialog.modal('hide')
          me.showMessage("Error updating progress: " + jqXHR.status + " " + jqXHR.statusText)
        'success': (data) ->
          if (data['status'] == 'complete')
            me.emailAllUsersProgressDialog.modal('hide')
          else if (data['status'] == 'failed')
            me.emailAllUsersProgressDialog.modal('hide')
            me.showMessage("Failed to send email:\n" + data["last_error"])
          else
            setTimeout(updateStatus, @trackProgressInterval)
      })
    setTimeout(updateStatus, @trackProgressInterval)

  enableSend: ->
    @sendButton.prop('disabled', @subjectField.val().length == 0 || @bodyArea.val().length == 0)

  close: -> ''
    # Should we ask the user to confirm that they want to cancel if there's
    # content? Since we don't blank the form, they can just reopen the dialog
    # and send again, so I guess not.

  submit: ->
    form = @$('form')
    me = this
    $.ajax(form.attr('action'), {
      'type': 'POST',
      'data': form.serialize(),
      'error': (jqXHR, textStatus, error) ->
        # If we've failed, display an error
        m = "Unable to send emails: "
        if (jqXHR.status == 500)
          m += "An internal server error occurred."
        else if (jqXHR.status < 200 || jqXHR.status >= 300)
          m += "Server returned an error: " + jqXHR.status + " " + jqXHR.statusText
        else if (error)
          m += error.toString()
        else
          m += "An error occurred."
        me.showMessage(m)
      'success': (data) ->
        # Kill the subject and body areas if we've successfully sent our message
        me.subjectField.val('')
        me.bodyArea.val('')
        me.trackProgress(data['jobID'])
      'complete': @emailAllUsersDialog.modal('hide')
    })
