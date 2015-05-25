gulp = require 'gulp'
gutil = require 'gulp-util'
settings = require './settings'

gulp.task 'clean', ->
  del = require 'del'
  del.sync ['build', 'release']

gulp.task 'metalsmith', require './metalsmith'

gulp.task 'build', ['metalsmith']

servers =
  dev: null
  selenium: null

gulp.task 'serve:dev', (done) ->
  connect = require 'connect'
  serveStatic = require 'serve-static'
  portFallback = require 'port-fallback'
  http = require 'http'

  app = connect()
    .use serveStatic('build')
  server = http.createServer app
  portFallback.listen server,
    defaultPort: settings.port, (err, port) ->
      throw err if err
      console.log 'Listing on '+port
      settings.port = server.address().port
      server.unref()
      done()
  servers.dev = server

gulp.task 'serve:selenium', ->
  selenium = require 'selenium-standalone'
  tcpPort = require 'tcp-port-used'
  logProcess = require 'process-logger'

  server = selenium
    stdio: settings.verbose and 'pipe' or 'ignore'
    ['-port', settings.seleniumServer.port]

  if settings.verbose
    logProcess server, prefix: '[selenium-server]'

  # Don't hold gulp open
  [server, server.stdin, server.stdout, server.stderr]
    .filter Boolean
    .map (s) -> s.unref()

  servers.selenium = server
  return tcpPort.waitUntilUsed(settings.seleniumServer.port, 500, 20000)

gulp.task 'crawl', ['build', 'serve:dev'], (done) ->
  Crawler = require 'simplecrawler'
  referrers = {}
  crawler = Crawler.crawl settings.devServerUrl()
    .on 'discoverycomplete', (item, urls) ->
      referrers[url] = item.url for url in urls
    .on 'fetchheaders', (item, res) ->
      unless res.statusCode is 200
        message = "Bad link #{res.statusCode} #{item.url} from #{referrers[item.url]}"
        gutil.log gutil.colors.red message
        throw new Error message
    .on 'complete', done
  crawler.timeout = 2000

gulp.task 'mocha', ['build', 'serve:dev', 'serve:selenium'], (done) ->
  {spawn} = require 'child_process'
  logProcess = require 'process-logger'
  extend = require 'extend'

  mocha = spawn 'mocha', [
    '--compilers', 'coffee:coffee-script/register'
    '--reporter', 'spec'
    '--ui', 'mocha-fibers'
    '--timeout', 10000
    'spec/*.spec.coffee'
  ], env: extend({}, process.env, PORT: settings.port)
  .on 'exit', (code) -> done code or null

  logProcess mocha, prefix: settings.verbose and '[mocha]' or ''
  return null # don't return a stream

gulp.task 'spec', ['crawl', 'mocha']

gulp.task 'watch', ->
  watch = require 'este-watch'
  watch ['src/documents', 'src/files'], (e) ->
    gutil.log 'Changed', gutil.colors.cyan e.filepath
    gulp.start 'metalsmith'
  .start()

gulp.task 'dev', ['build', 'serve:dev', 'watch'], ->
  servers.dev.ref()

gulp.task 'open', ['dev'], ->
  open = require 'open'
  open settings.devServerUrl()

# Fails if there are uncommitted changes
gulp.task 'nochanges', (done) ->
  git = require 'gift'

  git('.').status (err, status) ->
    unless status?.clean
      for filename, status of status.files
        gutil.log gutil.colors.red "#{status.type} #{filename}"
      done new Error 'There are uncommitted changes'
    else
      done()

# Commits built site to gh-pages branch
release = ({push}={}) ->
  (done) ->
    git = require 'gift'
    end = require 'stream-end'
    ghPages = require 'gulp-gh-pages'

    git('.').current_commit (err, commit) ->
      sourceId = commit.id[...12]
      gulp.src 'build/**/*'
      .pipe ghPages
        cacheDir: './release'
        message: "Released from #{sourceId}"
        push: push
      .pipe end done

gulp.task 'stage', ['build'], release push: false

gulp.task 'publish', ['clean', 'nochanges', 'build', 'spec'], release push: true

