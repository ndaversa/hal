# hubot-youtube-v3
[![NPM version][npm-image]][npm-url] [![Build Status][travis-image]][travis-url] [![Dependency Status][daviddm-image]][daviddm-url]

A hubot script for searching YouTube with the YouTube Data API v3

Built as a replacement for [hubot-youtube][hubot-youtube]

See [`src/youtube-v3.coffee`](src/youtube-v3.coffee) for full documentation.

## Installation

In hubot project repo, run:

`npm install hubot-youtube-v3 --save`

Then add **hubot-youtube-v3** to your `external-scripts.json`:

```json
["hubot-youtube-v3"]
```

## Configuration

This package requires the `HUBOT_GOOGLE_API` environment variable to be set. This is an API key for a Google Developers project with access to the YouTube Data API v3. Be sure to generate a Public API access key and not an OAuth ID.

For more information on how to set this up, see the documentation here on [obtaining credentials][google-developer] from Google Developers.

## Sample Interaction

```
user1>> hubot youtube me code monkey
hubot>> http://www.youtube.com/watch?v=v4Wy7gRGgeA
```

[npm-url]: https://npmjs.org/package/hubot-youtube-v3
[npm-image]: http://img.shields.io/npm/v/hubot-youtube-v3.svg?style=flat
[travis-url]: https://travis-ci.org/sprngr/hubot-youtube-v3
[travis-image]: http://img.shields.io/travis/sprngr/hubot-youtube-v3/master.svg?style=flat
[daviddm-url]: https://david-dm.org/sprngr/hubot-youtube-v3.svg?theme=shields.io
[daviddm-image]: http://img.shields.io/david/sprngr/hubot-youtube-v3.svg?style=flat
[hubot-youtube]:https://github.com/hubot-scripts/hubot-youtube
[google-developer]: https://developers.google.com/youtube/registering_an_application
