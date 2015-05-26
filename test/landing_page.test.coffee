require './test_helper'

describe 'landing page', ->
  before ->
    console.log 'GETTING PAGE'
    @browser.get '/'

  it 'has a title', ->
    @browser
      .title().should.eventually.contain 'Axillary Bud'
