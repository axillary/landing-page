assets = require 'metalsmith-assets'
markdown = require 'metalsmith-markdown'
metalsmith = require 'metalsmith'
{dirname, normalize} = require 'path'

module.exports = (done) ->
  metalsmith __dirname
  .source 'src/documents'
  .metadata
    site:
      title: 'Axillary Bud'
      url: 'http://axillarybud.com/'

  .use markdown()

  ## Absolute paths with trailing slashes
  .use (files, metalsmith, done) ->
    for filename, file of files
      file.path = normalize "/#{file.path or ''}/"
    done()

  .use assets
    source: 'src/files'
    destination: '.'

  .destination 'build'
  .clean false # handled by gulp
  .build done
