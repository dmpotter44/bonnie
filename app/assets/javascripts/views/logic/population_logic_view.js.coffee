class Thorax.Views.PopulationsLogic extends Thorax.LayoutView
  template: JST['logic/layout']
  switchPopulation: (e) ->
    population = $(e.target).model()
    @setView new Thorax.Views.PopulationLogic(model: population)
    @trigger 'population:update', population
  showRationale: (result) -> @getView().showRationale(result)
  clearRationale: -> @getView().clearRationale()
  showCoverage: -> @getView().showCoverage()
  clearCoverage: -> @getView().clearCoverage()
  populationContext: (population) ->
    _(population.toJSON()).extend
      isActive: population is @collection.first()
      populationTitle: population.get('title') || population.get('sub_id')

class Thorax.Views.PopulationLogic extends Thorax.Views.BonnieView

  template: JST['logic/logic']

  events:
    rendered: -> @showCoverage()

  initialize: ->
    @submeasurePopulations = []
    for code in Thorax.Models.Measure.allPopulationCodes
      match = @model.get code
      @submeasurePopulations.push(match) if match

  context: ->
    measure = @model.collection.parent
    _(super).extend
      measure: measure

  showRationale: (result) ->
    # Only show the rationale once the result is populated
    result.calculation.done =>
      @latestResult = result
      rationale = result.get('rationale')
      @clearCoverage()
      @clearRationale()
      # rationale only handles the logical true/false values
      # we need to go in and modify the highlighting based on the final specific contexts for each population
      updatedRationale = result.specificsRationale()
      for code in Thorax.Models.Measure.allPopulationCodes
        if rationale[code]?
          for key, value of rationale
            target = @$(".#{code}_children .#{key}")
            if (target.length > 0)

              [targetClass, targetPanelClass, srTitle] = if updatedRationale[code]?[key] is false
                ['eval-bad-specifics', 'eval-panel-bad-specifics', '(status: bad specifics)']
              else
                bool = !!value
                ["eval-#{bool}", "eval-panel-#{bool}", "(status: #{bool})"]

              target.addClass(targetClass)
              target.closest('.panel-heading').addClass(targetPanelClass)
              target.children('.sr-highlight-status').html(srTitle)
              # this second line is there to fix an issue with sr-only in Chrome making text in inline elements not display
              # by having the sr-only span and the DC title wrapped in a criteria-title span, the odd behavior goes away.
              target.children('.criteria-title').children('.sr-highlight-status').html(srTitle)
    @expandPopulations()

  highlightPatientData: (dataCriteriaKey, populationCriteriaKey) ->
    if @latestResult?.get('finalSpecifics')?[populationCriteriaKey]
      matchingCodedEntries = @latestResult.codedEntriesForDataCriteria(dataCriteriaKey)
      if matchingCodedEntries
        goodElements = @latestResult.codedEntriesPassingSpecifics(dataCriteriaKey, populationCriteriaKey)
        partial = Thorax.Views.EditCriteriaView.highlight.partial
        valid = Thorax.Views.EditCriteriaView.highlight.valid
        for codedEntry in matchingCodedEntries
          type = (if goodElements?.indexOf(codedEntry.id) < 0 then partial else valid)
          # picked up by EditCriteriaView
          for sourceDataCriterium in @latestResult.patient.get('source_data_criteria').models
            if sourceDataCriterium.get('coded_entry_id') == codedEntry.id
              sourceDataCriterium.trigger 'highlight', type

  clearHighlightPatientData: ->
    # picked up by PatientBuilder
    @latestResult?.patient.trigger 'clearHighlight'

  clearRationale: ->
    @$('.rationale .rationale-target').removeClass('eval-false eval-true eval-bad-specifics')
    @$('.rationale .panel-heading').removeClass('eval-panel-false eval-panel-true eval-panel-bad-specifics')
    @$('.sr-highlight-status').empty()

  showCoverage: ->
    @clearRationale()
    for criteria in @model.coverage().rationaleCriteria
      @$(".#{criteria}").addClass('eval-coverage')
    @coverageScreenReaderStatus()

  coverageScreenReaderStatus: ->
    @$('.rationale .rationale-target').find('.sr-highlight-status').html('(status: not covered)')
    @$('.eval-coverage').children('.sr-highlight-status').html('(status: covered)')
    @$('.eval-coverage').children('.criteria-title').children('.sr-highlight-status').html('(status: covered)')
    @$('.conjunction').children('.sr-highlight-status').empty()
    @$('.population-label').children('.sr-highlight-status').empty()

  clearCoverage: ->
    if @$('.eval-coverage').length > 0
      @$('.rationale .rationale-target').removeClass('eval-coverage')
      @$('.sr-highlight-status').empty()

  expandPopulations: ->
    @$('.panel-population > a[data-toggle="collapse"]').removeClass('collapsed')
    @$('.toggle-icon').removeClass('fa-angle-right').addClass('fa-angle-down')
    @$('.panel-collapse').removeClass('collapse').addClass('in').css('height','auto')

