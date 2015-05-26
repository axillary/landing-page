wd = require 'wd'
chai = require 'chai'
asPromised = require 'chai-as-promised'
settings = require '../settings'

asPromised.transferPromiseness = wd.transferPromiseness

chai
  .use asPromised
  .should()

before ->
  @browser = wd.promiseChainRemote("http://localhost:#{settings.seleniumServer.port}")

before ->
  @browser
    .init
      browserName: settings.browser
    .configureHttp
      baseUrl: settings.devServerUrl()

after (done) ->
  @browser.quit(done)
